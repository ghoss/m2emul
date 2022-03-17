//=====================================================
// le_mach.h
// M-Code Machine Definitions and Memory Structures
//
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#ifndef _LE_MACH_H
#define _LE_MACH_H   1

#include <stdio.h>
#include <error.h>
#include <errno.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>
#include <string.h>


// Machine constants
#define MACH_STK_SZ		65535	// Stack size in words
#define MACH_EXSTK_SZ	15		// Expression stack size in words

// Stack Memory
typedef uint16_t mach_stack_t[MACH_STK_SZ];
extern mach_stack_t *mem_stack;

// Expression stack
typedef uint16_t mach_exstack_t[MACH_EXSTK_SZ];
extern mach_exstack_t *mem_exstack;

// Entry in module table

// Module table
#define MACH_MODTAB_SZ


// Global State Variables
//
extern uint16_t gs_PC;		// Program counter
extern uint16_t gs_IR;		// Instruction register
extern uint16_t gs_F;		// Code frame base address
extern uint16_t gs_G;		// Data frame base address
extern uint16_t gs_H;		// Stack limit address
extern uint16_t gs_L;		// Local segment address
extern uint16_t gs_S;		// Stack pointer
extern uint16_t gs_P;  		// Process base address
extern uint16_t gs_M;		// process interrupt mask (bitset)
extern uint8_t gs_SP;		// Stack pointer
extern bool gs_REQ;			// Interrupt request
extern uint16_t gs_ReqNo;	// Request number, 8..15

// Tracing and debugging
extern bool verbose;
#define VERBOSE(...)  if (verbose) fprintf(stderr, __VA_ARGS__);

#endif