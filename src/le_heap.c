//=====================================================
// le_heap.c
// Dynamic heap allocation functions
// 
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#include "le_mach.h"
#include "le_io.h"
#include "le_heap.h"


// Heap header structure
struct hp_header_t {
	struct hp_header_t *next;	// Pointer to next header
	uint16_t adr;				// Address of block in dsh_mem
	uint16_t sz;				// Size of block
	uint8_t owner;				// Module index of owner
};

typedef struct hp_header_t *hp_header_ptr;


// Heap memory
uint16_t gs_H;
hp_header_ptr heap_top;


// hp_hdr_alloc()
// Allocate a header block
//
hp_header_ptr hp_hdr_alloc()
{
	return malloc(sizeof(struct hp_header_t));
}


// le_heap_alloc()
// Allocate sz words on heap and return a pointer
// to the memory address (heap index). Block is
// registered to module index "mod".
//
uint16_t hp_alloc(uint8_t mod, uint16_t sz)
{
	hp_header_ptr cur = heap_top;
	hp_header_ptr prev = NULL;

	// Allocate non-zero size
	if (sz == 0)
		sz = 1;

	// Scan block list for suitable gaps
	while (cur != NULL)
	{
		if ((cur->owner == 0) && (cur->sz >= sz))
		{
			// Suitable gap found
			if (cur->sz > sz)
			{
				// Split block
				hp_header_ptr p = hp_hdr_alloc();
				p->next = cur->next;
				cur->next = p;
				p->sz = cur->sz - sz;
				p->adr = cur->adr;
				cur->adr += p->sz;
				cur->sz = sz;
				p->owner = 0;
			}
			cur->owner = mod;
			break;
		}
		prev = cur;
		cur = cur->next;
	}

	// At end of block list?
	if (cur == NULL)
	{
		// No matching gap found, so extend heap
		if (gs_H - gs_S > sz)
		{
			// Still room left, create new block header
			cur = hp_hdr_alloc();
			prev->next = cur;
			cur->next = NULL;
			gs_H -= sz;
			cur->adr = gs_H;
			cur->sz = sz;
			cur->owner = mod;
		}
		else
		{
			// Heap overflow error
			le_error(1, 0, "Heap overflow");
		}
	}
	return cur->adr;
}


// hp_free_int()
// Deallocate the heap memory previously allocated
// to "ptr" if by_ptr=true, or allocated to "mod"
// if by_ptr=false. Only check pointers below/equal to "limit".
//
void hp_free_int(uint8_t mod, uint16_t ptr, uint16_t limit, bool by_ptr)
{
	hp_header_ptr cur = heap_top;
	hp_header_ptr prev = NULL;

	void consolidate(hp_header_ptr p, hp_header_ptr q)
	{
		p->sz += q->sz;
		p->adr = q->adr;
		p->next = q->next;
		free(q);
	}

	bool is_match(hp_header_ptr p)
	{
		return (p != heap_top) &&
			(((by_ptr && (p->adr == ptr)) ||
			((! by_ptr) && (p->owner == mod))));
	}

	bool is_free(hp_header_ptr p)
	{
		return (p != heap_top) && ((p->owner == 0) || 
			((! by_ptr) && ((p->owner == mod))));
	}

	// Scan block list for address
	while (cur != NULL)
	{
		if ((cur->adr <= limit) && (cur->owner != 0) && is_match(cur))
		{
			// Valid pointer, proceed to release
			cur->owner = 0;

			// Consolidate with previous block
			if ((prev != NULL) && (prev->adr <= limit) && is_free(prev))
			{
				consolidate(prev, cur);
				cur = prev;
			}
			
			// Consolidate with next block
			if ((cur->next != NULL) && is_free(cur->next))
				consolidate(cur, cur->next);

			if (cur->next == NULL)
			{
				// Last block above heap_top
				hp_header_ptr p = heap_top;
				while (p->next != cur)
					p = p->next;
				gs_H = p->adr;
				p->next = NULL;
				free(cur);
				return;
			}

			// Return after one deallocation if pointer mode
			if (by_ptr)
				return;
			else
				continue;
		}
		prev = cur;
		cur = cur->next;
	}

	// At end of block list?
	if ((cur == NULL) && by_ptr)
		le_error(1, 0, "Heap pointer *%04X invalid", ptr);
}


// hp_free()
// Frees specified pointer
//
void hp_free(uint16_t ptr)
{
	hp_free_int(0, ptr, UINT16_MAX, true);
}


// hp_free_all()
// Frees all blocks belonging to the specified module
// above and including pointer address "limit"
//
void hp_free_all(uint8_t mod, uint16_t limit)
{
	hp_free_int(mod, 0, limit, false);
}


// hp_init()
// Initialize the heap space
//
void hp_init()
{
	// Initialize top of heap
	gs_H = MACH_DSHMEM_SZ - 1;
	heap_top = hp_hdr_alloc();
	heap_top->adr = gs_H;
	heap_top->next = NULL;
	heap_top->sz = 0;
	heap_top->owner = 0;
}
