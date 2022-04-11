//=====================================================
// le_filesys.c
// Host filesystem functions
// 
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#include "le_filesys.h"


// le_swapcpy()
// Copy a string like strncpy, but swap bytes
//
void fs_swapcpy(char *dest, char *src, uint16_t n)
{
	uint16_t i;
	char c = '\0';

	for (i = 0; i < n; i ++, src ++)
	{
		if (i & 1)
		{
			*(dest ++) = *src;
			*(dest ++) = c;
			if ((*src == '\0') || (c == '\0'))
				break;
		}
		else
		{
			c = *src;
		}
	}
	*dest = '\0';
}