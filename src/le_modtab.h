//=====================================================
// le_modtab.h
// Module table definitions and routines
// 
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#ifndef _LE_MODTAB_H
#define _LE_MODTAB_H   1

#define MOD_NAME_MAX    16		// Maximum length of module names
#define MOD_TAB_MAX     255		// Max. size of module table
#define PROC_TAB_MAX	255		// Max. size of procedure entry table


// M-Code module entry
typedef struct {
    char name[MOD_NAME_MAX + 1];    // Module name
    uint16_t key[3];                // Module key (3 words)
    bool load_flag;                 // FALSE if entered but not loaded yet
    bool init_flag;                 // FALSE if not initialized yet
    uint8_t *code_ptr;              // Pointer to module's code
    uint16_t *proctab_ptr;          // Pointer to module's procedure table
} mod_entry_t;


// Function declarations
//

#endif