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
#include "le_heap.h"


// Heap header structure
struct hp_header_t {
	struct hp_header_t *next;	// Pointer to next header
	uint16_t adr;				// Address of block in dsh_mem
	uint16_t sz;				// Size of block
	bool used;					// Block used indicator
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
// to the memory address (heap index)
//
uint16_t hp_alloc(uint16_t sz)
{
	hp_header_ptr cur = heap_top;
	hp_header_ptr prev = NULL;

	// Scan block list for suitable gaps
	while (cur != NULL)
	{
		if ((! cur->used) && (cur->sz >= sz))
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
				p->used = false;
			}
			cur->used = true;
			break;
		}
		else
		{
			prev = cur;
			cur = cur->next;
		}
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
			cur->used = true;
		}
		else
		{
			// Heap overflow error
			error(1, 0, "Heap overflow");
		}
	}
	return cur->adr;
}


// le_heap_free()
// Deallocate the heap memory previously allocated
// to "ptr"
//
void hp_free(uint16_t ptr)
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

	// Scan block list for address
	while (cur != NULL)
	{
		if (cur->adr == ptr)
		{
			// Found
			if (cur->used)
			{
				// Valid pointer, proceed to release
				cur->used = false;

				// Consolidate with next block
				if ((cur->next != NULL) && (! cur->next->used))
					consolidate(cur, cur->next);

				// Consolidate with previous block
				if ((prev != NULL) && (! prev->used))
				{
					consolidate(prev, cur);
					prev->used = false;
				}
			}
			else
			{
				error(1, 0, "Pointer *%04X already released before", ptr);
			}
		}
		else
		{
			prev = cur;
			cur = cur->next;
		}
	}

	// At end of block list?
	if (cur == NULL)
	{
		// Pointer not found
		error(1, 0, "Pointer *%04X invalid", ptr);
	}
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
}