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

#include "le_syscall.h"


// le_sys_call()
// Implements the (official) SYS opcode
// (Part of the original M-Code specification)
//
void le_system_call()
{
	error(1, 0, "SYS calls are not implemented");
}


// le_supervisor_call()
// Implements the (informal) SVC opcode
// (NOT part of the original M-Code specification)
//
void le_supervisor_call()
{
	error(1, 0, "SVC calls are not implemented");
}