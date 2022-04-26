//=====================================================
// le_syscall.c
// System and supervisor calls
//
// Lilith M-Code Emulator
//
// Guido Hoss, 14.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#include <time.h>
#include <byteswap.h>
#include "le_mach.h"
#include "le_stack.h"
#include "le_heap.h"
#include "le_filesys.h"
#include "le_loader.h"
#include "le_syscall.h"


// le_sys_call()
// Implements the (official) SYS opcode
// (Part of the original M-Code specification)
//
void le_system_call(uint8_t n)
{
	switch (n)
	{
		case 0 :
			// Boot from track
			// uint16_t trk = es_pop();
		case 1 :
			// Dump
		case 2 :	
			// Toggle trap enable/disable?
			// ("getp" = get process?)
			// See Programs.MOD
		case 3 :
			// Set stack limit
		case 4 :
			// Get stack limit	
		default :
			error(1, 0, "SYS call %d not recognized", n);
			break;
	}
}


// svc_heap_func()
// Heap memory allocation procedures
//
void svc_heap_func(uint8_t mod)
{
	// Heap memory allocation procedures
	uint16_t mode = es_pop();	// Alloc = 0, Dealloc = 1
	uint16_t sz = es_pop();		// Allocation size
	uint16_t vadr = es_pop();	// Address of pointer variable

	switch (mode)
	{
		case 0 :
			// Allocation
			dsh_mem[vadr] = hp_alloc(mod, sz);
			break;
		
		case 1 :
			// Deallocation
			hp_free(dsh_mem[vadr]);
			break;

		case 2 :
			// Reset heap to limit
			hp_free_all(mod, dsh_mem[vadr]);
			break;

		default :
			error(1, 0, "Invalid allocation mode %d", mode);
			break;
	}
}


// svc_time_func()
// Get system time and store it into a structure
// comprised of 3 cardinals "day", "min" and "msec"
//
void svc_time_func()
{
	uint16_t vadr = es_pop();	// Address of target variable

	time_t now = time(NULL);
	struct tm *t_now = localtime(&now);

	dsh_mem[vadr] = bswap_16((t_now->tm_mday + 1)
		+ ((t_now->tm_mon + 1) << 5)
		+ (t_now->tm_year << 9));

	dsh_mem[vadr + 1] = 
		bswap_16((t_now->tm_hour * 60) + t_now->tm_min);

	dsh_mem[vadr + 2] = 0;
}


// svc_file_func()
// Filesystem functions
//
void svc_file_func(uint8_t modn)
{
	char *get_filename(char **fn)
	{
		uint16_t ln = es_pop() + 2;	// HIGH of filename parameter
		uint16_t strp = es_pop();

		// Copy filename to own buffer
		char *p = malloc(ln);
		fs_swapcpy(p, (char *) &(dsh_mem[strp]), ln - 1);
		*fn = (strncmp(p, "DK.", 3) == 0) ? (p + 3) : p;
		return p;
	}

	uint16_t cmd = es_pop();
	uint16_t m2_fd = es_pop();	// Address of M2 file descriptor
	bool res = false;

	// Dispatch command
	switch (cmd)
	{
		case 0 : {
			// Create(VAR f: File; mediumname: ARRAY OF CHAR)
			char *fn = malloc(1);
			es_pop(); es_pop();		// Consume medium name

			*fn = '\0';
			res = fs_open(modn, fn, fn, true, m2_fd);
			break;
		}

		case 1 :
			// Close(VAR f: File)
			res = fs_close(m2_fd);
			break;

		case 2 : {
			// Lookup(VAR f: File; filename: ARRAY OF CHAR; new: BOOLEAN)
			char *fn;
			char *p = get_filename(&fn);
			bool create = dsh_mem[es_pop()];
			res = fs_open(modn, fn, p, create, m2_fd);
			break;
		}

		case 3 : {
			// Rename(VAR f: File; filename: ARRAY OF CHAR)
			char *fn;
			char *p = get_filename(&fn);
			res = fs_rename(m2_fd, fn, p);
			break;
		}

		case 4 :
			// SetRead(VAR f: File)
			fs_reopen(m2_fd, FS_READ);
			VERBOSE("setread\n");
			break;

		case 5 :
			// SetWrite(VAR f: File)
			fs_reopen(m2_fd, FS_WRITE);
			VERBOSE("setwrite\n");
			break; 

		case 6 :
			// SetModify(VAR f: File)
			fs_reopen(m2_fd, FS_MODIFY);
			VERBOSE("setmodify\n");
			break;

		case 7 :
			// SetOpen(VAR f: File)
			// NOP command
			res = true;
			break;

		case 8 : {
			// SetPos(VAR f: File; highpos, lowpos: CARDINAL)
			uint32_t pos = dsh_mem[es_pop()];
			pos |= dsh_mem[es_pop()] << 16;
			res = fs_setpos(m2_fd, pos);
			break;
		}

		case 9 : {
			// GetPos(VAR f: File; VAR highpos, lowpos: CARDINAL)
			uint32_t pos = 0;			
			res = fs_getpos(m2_fd, &pos);
			dsh_mem[es_pop()] = pos & 0xffff;
			dsh_mem[es_pop()] = pos >> 16;
			break;
		}

		case 10 : {
			// Length(VAR f: File; VAR highpos, lowpos: CARDINAL)
			uint32_t pos = 0;
			dsh_mem[es_pop()] = pos & 0xffff;
			dsh_mem[es_pop()] = pos >> 16;
			VERBOSE("length l=%u\n", pos);
			break;
		}

		case 11 :
			// Reset(VAR f: File)
			VERBOSE("reset\n")
			break;

		case 12 :
			// Again(VAR f: File)
			VERBOSE("again\n")
			break;

		case 13 : {
			// ReadWord(VAR f: File; VAR w: WORD)
			uint16_t w;
			res = fs_read(m2_fd, &w, false);
			dsh_mem[es_pop()] = res ? bswap_16(w) : 0;
			break;
		}

		case 14 : {
			// WriteWord(VAR f: File; w: WORD)
			res = fs_write(m2_fd, bswap_16(dsh_mem[es_pop()]), false);
			break;
		}

		case 15 : {
			// ReadChar(VAR f: File; VAR ch: CHAR)
			uint16_t ch;
			res = fs_read(m2_fd, &ch, true);
			dsh_mem[es_pop()] = res ? (ch & 0xff) : 0;
			break;
		}

		case 16 : {
			// WriteChar(VAR f: File; ch: CHAR)
			res = fs_write(m2_fd, dsh_mem[es_pop()], true);
			break;
		}

		default :
			error(1, 0, "Filesystem command %d not implemented", cmd);
			break;
	}

	// Handle error
	es_push(res ? 0 : 1);
}


// le_supervisor_call()
// Implements the (informal) SVC opcode
// (NOT part of the original M-Code specification)
//
void le_supervisor_call(uint8_t modn, uint8_t n)
{
	switch (n)
	{
		case 0 :
			svc_heap_func(modn);
			break;

		case 1 :
			// External module/program call, handled in mcode.c
			break;

		case 2 :
			// Get system time
			svc_time_func();
			break;

		case 3 :
			// Filesystem functions
			svc_file_func(modn);
			break;

		default :
			error(1, 0, "Supervisor call %d not implemented", n);
			break;
	}
}