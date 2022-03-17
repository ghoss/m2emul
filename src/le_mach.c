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

// Module table (entry 0 reserved for SYSTEM module)
mod_entry_p module_tab;     // Pointer to module entries
uint16_t module_num = 1;	// Number of modules in table


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
        if (strncmp(name, q->id.name, MOD_NAME_MAX) == 0)
        {
            // Name matches; now check keys
            mod_key_t *k1 = &(q->id.key);
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
                    k1->w[0], k1->w[1], k1->w[2],
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

    mod_entry_p p = &(module_tab[module_num ++]);
    return p;
}


// init_module_tab()
// Initialize the empty module table
//
void init_module_tab()
{
	module_tab = malloc(MOD_TAB_MAX * sizeof(struct mod_entry));
	if (module_tab == NULL)
		error(1, errno, "Can't allocate module table");

    // Make a bogus entry for SYSTEM module in index 0 with key 0
    strcpy(module_tab->id.name, "System");
    mod_key_t *k = &(module_tab->id.key);
    k->w[0] = k->w[1] = k->w[2] = 0x0000;
    module_tab->init_flag = false;

    // First user module (boot program) gets assigned entry 1
	module_num = 1;
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