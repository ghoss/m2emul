//=====================================================
// le_mach.c
// M-Code Machine Definitions and Memory Structures
// 
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#include "le_mach.h"


// Memory structures defined in le_mach.h
//
mach_stack_t *mem_stack;
mach_exstack_t *mem_exstack;

uint16_t gs_PC;
uint16_t gs_IR;
uint16_t gs_F;
uint16_t gs_G;
uint16_t gs_H;
uint16_t gs_L;
uint16_t gs_S;
uint16_t gs_P;
uint16_t gs_M;
uint8_t gs_SP;
bool gs_REQ;
uint16_t gs_ReqNo;

// Module table
mod_entry_p module_tab;     // Pointer to module entries
uint16_t module_num = 0;	// Number of modules in table


// find_mod_entry()
// Finds the module entry given by name and key
// Returns a pointer to it, or NULL if not found
//
mod_entry_p find_mod_entry(mod_name_t name, mod_key_t *key)
{
    mod_entry_p p = NULL;
    mod_entry_p q = module_tab;

    for (uint16_t i = 0; i < module_num; i ++, q ++)
    {
        if (strncmp(name, q->name, MOD_NAME_MAX) == 0)
        {
            // Name matches; now check keys
            mod_key_t *k1 = &(q->key);
            if (memcmp(key, k1, sizeof(mod_key_t)) == 0)
            {
                // Name and key match; everything good
                p = q;
                break;
            }
            else
            {
                // Key mismatch
                error(1, 0, 
                    "Object file mismatch: '%s'\n"
                    "  Loaded:   %04x %04x %04x\n"
                    "  Imported: %04X %04X %04X\n",
                    k1[0], k1[1], k1[2],
                    key[0], key[1], key[2]
                );
            }       
        }
    }
    return p;
}


// init_mod_entry()
// Allocates a new module entry and returns a pointer to it
//
mod_entry_p init_mod_entry()
{
    if (module_num == MOD_TAB_MAX)
        error(1, 0, "Module table overflow");

    module_num ++;
}


// init_module_tab()
// Initialize the empty module table
//
void init_module_tab()
{
	module_tab = malloc(MOD_TAB_MAX * sizeof(struct mod_entry));
	if (module_tab == NULL)
		error(1, errno, "Can't allocate module table");

	module_num = 0;
}


// mach_init()
// Initialize memory structures
//
void mach_init()
{
    // Stack memory
    if ((mem_stack = malloc(sizeof(mach_stack_t))) == NULL)
        error(1, errno, "Can't allocate stack");

    // Allocate and clear expression stack
    gs_SP = 0;
    if ((mem_exstack = malloc(sizeof(mach_exstack_t))) == NULL)
        error(1, errno, "Can't allocate expression stack");

    // Initialize and clear module table
    init_module_tab();
}