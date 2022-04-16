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

// External variables defined in le_heap.c
//
extern uint16_t gs_H;		// Heap limit address


// Function declarations
//
uint16_t hp_alloc(uint8_t mod, uint16_t sz);
void hp_free(uint16_t ptr);
void hp_init();
void hp_free_all(uint8_t mod, uint16_t limit);

#endif