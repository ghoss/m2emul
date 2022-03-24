//=====================================================
// le_io.c
// M-Code hardware input/output functions
//
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#include "le_mach.h"
#include "le_io.h"


// le_ioread()
// Read word from hardware channel
//
uint16_t le_ioread(uint16_t chan)
{
	uint16_t val;

	switch (chan)
	{
		case 0 :
			// Display flag (1 = "new", 0 = standard 768x592)
			val = 0;
			break;

		default :
			error(1, 0, "READ from channel #%d not implemented)", chan);
			break;
	}
	return val;
}


// le_iowrite()
// Write word to hardware channel
//
void le_iowrite(uint16_t chan, uint16_t w)
{
    error(1, 0, "WRITE not implemented (%d,%d)", chan, w);
}


// le_putchar()
// Prints one character to the terminal (implementation of DCH opcode)
//
void le_putchar(char c)
{
	printf("\033[1m%c\033[m\017", c);
}