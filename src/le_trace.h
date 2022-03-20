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

// Function declarations
//
void le_decode(mod_entry_t *mod, uint16_t pc);
void le_monitor(mod_entry_t *mod, uint16_t pc);

#endif