//=====================================================
// le_trace.h
// M-Code tracing and disassembly functions
//
// Lilith M-Code Emulator
//
// Guido Hoss, 14.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#ifndef _LE_TRACE_H
#define _LE_TRACE_H   1

#include "le_mach.h"

// Trap number definitions
//
#define TRAP_STACK_OVF	3		// Stack overflow
#define TRAP_INDEX		4		// Array index arithmetic
#define TRAP_INT_ARITH	10		// Integer arithmetic
#define TRAP_CODE_OVF	11		// Code overrun
#define TRAP_INV_FFCT	12		// Invalid FFCT function
#define TRAP_INV_OPC	13		// Invalid opcode
#define TRAP_SYSTEM		14		// System-triggered trap

// Function declarations
//
void le_decode(mod_entry_t *mod, uint16_t pc);
void le_monitor(mod_entry_t *mod);
void le_trap(mod_entry_t *modp, uint16_t n);

#endif