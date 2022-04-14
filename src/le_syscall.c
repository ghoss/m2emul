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


// le_supervisor_call()
// Implements the (informal) SVC opcode
// (NOT part of the original M-Code specification)
//
void le_supervisor_call(uint8_t mod, uint8_t n)
{
	switch (n)
	{
		case 0 : {
			// Heap memory allocation procedures
			uint16_t mode = es_pop();	// Alloc = 0, Dealloc = 1
			uint16_t sz = es_pop();		// Allocation size
			uint16_t vadr = es_pop();	// Address of pointer variable
			if (mode == 0)
				dsh_mem[vadr] = hp_alloc(mod, sz);
			else
				hp_free(dsh_mem[vadr]);
			break;
		}

		case 1 :
			// External module/program call, handled in mcode.c
			break;

		default :
			error(1, 0, "Supervisor call %d not implemented", n);
			break;
	}
}