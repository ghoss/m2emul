//=====================================================
// le_io.h
// M-Code hardware input/output functions
//
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#ifndef _LE_IO_H
#define _LE_IO_H   1

// Function declarations
//
uint16_t le_ioread(uint16_t chan);
void le_iowrite(uint16_t chan, uint16_t w);
void le_putchar(char ch);

#endif