//=====================================================
// le_syscall.h
// System and supervisor calls
//
// Lilith M-Code Emulator
//
// Guido Hoss, 14.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#ifndef _LE_SYSCALL_H
#define _LE_SYSCALL_H   1

#include "le_mach.h"

// Function declarations
//
void le_system_call(uint8_t n);
void le_supervisor_call(uint8_t mod, uint8_t n);

#endif