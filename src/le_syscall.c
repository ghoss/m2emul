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
			hp_free_all(mod, vadr);
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
	uint16_t param = es_pop();	// Address of M2 "SYSParam" record
	uint16_t m2_fd = es_pop();	// Address of M2 file descriptor

	// Mode 1: with filename parameter, mode 2: without
	uint16_t mode = dsh_mem[param];
	char *fn = NULL;
	bool res = false;

	if (mode == 1)
	{
		// Directory commands include a filename parameter
		uint16_t ln = es_pop() + 2;	// HIGH of filename parameter
		uint16_t strp = es_pop();

		// Copy filename to own buffer
		fn = malloc(ln);
		fs_swapcpy(fn, (char *) &(dsh_mem[strp]), ln - 1); 
	}

	// Process command in M2 "SYSParam.com" record variable
	uint16_t cmd = dsh_mem[param + 3];
	switch (cmd)
	{
		case 3 :
			// Lookup (create) file (flag in SYSParam.new)
			bool create = (dsh_mem[param + 4] != 0);
			res = fs_open(modn, fn, create, m2_fd);
			break;

		case 5 :
			// Set read mode
			res = fs_reopen(m2_fd, FS_READ);
			break; 

		case 6 :
			// Set write mode
			res = fs_reopen(m2_fd, FS_WRITE);
			break;

		case 7 :
			// Set modify mode
			res = fs_reopen(m2_fd, FS_MODIFY);
			break;

		case 9 :
			// Do I/O
			break;
		
		default :
			error(1, 0, "Filesystem command %d not implemented", cmd);
			break;
	}

	// Handle error (SYSParam.res = done or notdone)
	dsh_mem[param + 1] = res ? 0 : 1;

	// Release memory for filename if some was assigned
	if (fn != NULL)
		free(fn);
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