//=====================================================
// le_filesys.h
// Host filesystem functions
// 
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#ifndef _LE_FILESYS_H
#define _LE_FILESYS_H   1

#include "le_mach.h"


// Function declarations
//
void fs_swapcpy(char *dest, char *src, uint16_t n);

#endif