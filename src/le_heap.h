//=====================================================
// le_heap.h
// Dynamic heap allocation functions
// 
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#ifndef _LE_HEAP_H
#define _LE_HEAP_H   1

#include "le_mach.h"


// Function declarations
//
uint16_t hp_alloc(uint16_t sz);
void hp_free(uint16_t ptr);

#endif