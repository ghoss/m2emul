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
mod_entry_t *module_tab;    // Pointer to module entries
uint8_t module_num = 1;	    // Number of modules in table


// mach_num_modules()
// Return number of module entries currently in table
//
uint8_t mach_num_modules()
{
    return module_num;
}


// find_mod_index()
// Returns the module entry given by the specified index
//
mod_entry_t *find_mod_index(uint8_t i)
{
    return &(module_tab[i]);
}


// find_mod_entry()
// Finds the module entry given by name and key
// Returns a pointer to it, or NULL if not found
//
mod_entry_t *find_mod_entry(mod_id_t *mod)
{
    mod_entry_t *p = NULL;
    mod_entry_t *q = module_tab;

    for (uint16_t i = 0; i < module_num; i ++, q ++)
    {
        if (strncmp(mod->name, q->id.name, MOD_NAME_MAX) == 0)
        {
            // Name matches; now check keys
            mod_key_t *k1 = &(q->id.key);
            mod_key_t *k0 = &(mod->key);
            if (memcmp(k0, k1, sizeof(mod_key_t)) == 0)
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
                    k0->w[0], k0->w[1], k0->w[2]
                );
            }       
        }
    }
    return p;
}


// init_mod_entry()
// Allocates a new module entry and returns a pointer to it
//
mod_entry_t *init_mod_entry(mod_id_t *mod)
{
    mod_entry_t *p;

    if ((p = find_mod_entry(mod)) == NULL)
    {
        // Register new module
        if (module_num == MOD_TAB_MAX)
            error(1, 0, "Module table overflow");

        // Assign new entry in table
        p = &(module_tab[module_num]);
        p->idx = module_num ++;

        // Copy module name and key to table
        memcpy(&(p->id), mod, sizeof(mod_id_t));

        p->init_flag = false;
        p->import_ptr = NULL;
        p->code_ptr = NULL;
        p->proctab_ptr = NULL;
    }
    return p;
}


// init_module_tab()
// Initialize the empty module table
//
void init_module_tab()
{
	module_tab = malloc(MOD_TAB_MAX * sizeof(mod_entry_t));
	if (module_tab == NULL)
		error(1, errno, "Can't allocate module table");

    // Make a bogus entry for SYSTEM module in index 0 with key 0
    strcpy(module_tab->id.name, "System");
    mod_key_t *k = &(module_tab->id.key);
    k->w[0] = k->w[1] = k->w[2] = 0x0000;
    module_tab->init_flag = false;
    module_tab->load_flag = true;

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