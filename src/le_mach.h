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
#include <ncurses.h>
#include <error.h>
#include <errno.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>
#include <string.h>


// Stack and expression stack
//
#define MACH_DSHMEM_SZ	65536	// Memory (data+stack+heap) size in words
#define MACH_EXSMEM_SZ	15		// Expression stack size in words

// Machine word = 16 bits
#define MACH_WORD_SZ    sizeof(uint16_t)

// Main memory for data, stack and heap
extern uint16_t *dsh_mem;	// Points to base of main memory
extern uint16_t data_top;	// Offset of 1st word after data areas

// Memory for expression stack
extern uint16_t *exs_mem;


// Module table
//
#define MOD_NAME_MAX    16			// Maximum length of module names
#define MOD_TAB_MAX     UINT8_MAX	// Max. size of module table
#define PROC_TAB_MAX	UINT8_MAX	// Max. size of procedure entry table

typedef char mod_name_t[MOD_NAME_MAX + 1];

// Module name
typedef struct {
    uint16_t w[3];				// Module keys are 3 words long
} mod_key_t;

// Module ID (name, key)
typedef struct {
    uint8_t idx;                // Index in module table
    mod_name_t name;			// Module name
    mod_key_t key;				// Module key (3 words)
    bool loaded;				// FALSE if not loaded yet
} mod_id_t;

// Temporary procedure list for module
typedef struct proctmp_t {
    uint16_t idx;               // Procedure index
    uint16_t entry;             // Entry point into code
    uint16_t *fixup;            // Pointer to fixup table
    uint16_t fixup_n;           // Number of fixups
    struct proctmp_t *next;		// Pointer to next proc entry or NULL
} proctmp_t;

// Module table entry
typedef struct {
    mod_id_t id;				// Module name and key
    uint8_t *code;				// Pointer to module's code frame
    uint32_t code_sz;           // Size of code frame in bytes
	uint16_t data_ofs;			// Offset to module's data in DSH
    uint32_t data_sz;           // Size of data frame in words
    proctmp_t *proc_tmp;		// Pointer to temp. procedure linked list
    uint16_t *proc;             // Pointer to final procedure table
    uint16_t proc_n;            // Number of entries in procedure table
    mod_id_t *import;	    	// Pointer to table of imported modules
    uint8_t import_n;           // Number of entries in import table
} mod_entry_t;

extern mod_entry_t *module_tab;		// Pointer to module table


// Global State Variables
//
extern uint16_t gs_PC;		// Program counter
extern uint16_t gs_IR;		// Instruction register
extern uint16_t gs_G;		// Data frame base address
extern uint16_t gs_H;		// Stack limit address
extern uint16_t gs_L;		// Local segment address
extern uint16_t gs_S;		// Stack pointer
extern uint16_t gs_P;  		// Process base address
extern uint16_t gs_M;		// process interrupt mask (bitset)
extern uint8_t gs_SP;		// Stack pointer
extern bool gs_REQ;			// Interrupt request
extern uint16_t gs_ReqNo;	// Request number, 8..15


// Function declarations
//
void mach_init();
uint8_t mach_num_modules();
mod_entry_t *find_mod_entry(mod_id_t *mod_id);
mod_entry_t *init_mod_entry(mod_id_t *mod_id);


// Tracing and debugging
extern bool le_verbose;
extern bool le_trace;
#define VERBOSE(...)  if (le_verbose) printw(__VA_ARGS__);

#endif