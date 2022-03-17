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


// Stack and expression stack
//
#define MACH_STK_SZ		65535	// Stack size in words
#define MACH_EXSTK_SZ	15		// Expression stack size in words

// Stack Memory
typedef uint16_t mach_stack_t[MACH_STK_SZ];
extern mach_stack_t *mem_stack;

// Expression stack
typedef uint16_t mach_exstack_t[MACH_EXSTK_SZ];
extern mach_exstack_t *mem_exstack;


// Module table
//
#define MOD_NAME_MAX    16		// Maximum length of module names
#define MOD_TAB_MAX     255		// Max. size of module table
#define PROC_TAB_MAX	255		// Max. size of procedure entry table

typedef char mod_name_t[MOD_NAME_MAX + 1];

typedef struct {
    uint16_t w[3];                  // Module keys are 3 words long
} mod_key_t;

typedef struct mod_entry *mod_entry_p;
typedef struct mod_entry {
    mod_name_t name;                // Module name
    mod_key_t key;                  // Module key (3 words)
    bool init_flag;                 // FALSE if not initialized yet
    uint8_t *code_ptr;              // Pointer to module's code
    uint16_t *proctab_ptr;          // Pointer to module's procedure table
    mod_entry_p import_ptr;        // Pointer to table of imported modules
} *mod_entry_p;


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