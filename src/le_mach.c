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
#include "le_stack.h"
#include "le_heap.h"


// Memory structures defined in le_mach.h
//
uint16_t *dsh_mem;
uint16_t data_top;

uint16_t gs_PC;
uint16_t gs_IR;
uint16_t gs_G;
uint16_t gs_L;
uint16_t gs_S;
uint16_t gs_CS;
uint16_t gs_P;
uint16_t gs_M;
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
                    "Object key mismatch: '%s'\r\n"
                    "  Found:    %04X %04X %04X\r\n"
                    "  Expected: %04X %04X %04X\r\n",
                    mod->name,
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

        // Copy module name and key to table
        memcpy(&(p->id), mod, sizeof(mod_id_t));

        p->id.idx = module_num ++;
        p->id.loaded = false;
        p->import = NULL;
        p->import_n = 0;
        p->code = NULL;
        p->data_ofs = UINT16_MAX;
        p->proc_tmp = NULL;
        p->proc_n = 0;
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
    module_tab->id.loaded = true;

    // First user module (boot program) gets assigned entry 1
	module_num = 1;
}


// mach_init()
// Initialize memory structures
//
void mach_init()
{
    // Allocate data/stack/heap memory and zero it
    if ((dsh_mem = calloc(MACH_DSHMEM_SZ, MACH_WORD_SZ)) == NULL)
	{
        error(1, errno, "Can't allocate DSH memory");
	}

	// data_top points to the top of the module data area
	data_top = 0;

	// Allocate heap
	hp_init();

    // Allocate and clear expression stack
	es_init();

    // Initialize and clear module table
    init_module_tab();
}


// mach_unload_top
// Unloads the topmost currently loaded module
// Returns former data segment size of freed module
//
uint16_t mach_unload_top()
{
    mod_entry_t *p = &(module_tab[module_num - 1]);

	// Free code frame and procedure table
	free(p->code);
	free(p->proc);

	// Decrement number of modules
	module_num --;
	return p->data_sz;
}