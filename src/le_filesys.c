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

#include "le_mach.h"
#include "le_filesys.h"


// List of all open file descriptors
struct fs_index_t {
	struct fs_index_t *next;	// Pointer to next header
	uint16_t m2file;			// Underlying Modula-2 file descriptor
	FILE *fd;					// Associated UNIX file descriptor
	bool temp;					// TRUE if temporary file
	uint8_t owner;				// Module index of owner
};

typedef struct fs_index_t *fs_index_ptr;

// Pointer to head of list
fs_index_ptr fd_list = NULL;
uint16_t last_m2file = 0;		// Last referenced M2 file descriptor
fs_index_ptr last_fd = NULL;	// Last associated file list entry


// fs_swapcpy()
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


// fs_find_fd()
// Returns the associated file list entry for a
// Modula-2 file descriptor
//
fs_index_ptr fs_find_fd(uint16_t m2_fd)
{
	if (m2_fd == last_m2file)
	{
		// Check for last referenced fd in cache
		return last_fd;
	}
	else
	{
		// Search file index list for entry
		fs_index_ptr cur = fd_list;

		while (cur != NULL)
		{
			if (cur->m2file == m2_fd)
			{
				last_m2file = m2_fd;
				last_fd = cur;
				return cur;
			}
			else {
				cur = cur->next;
			}
		}
		error(1, 0, "Invalid M2 file descriptor");
		return NULL;
	}
}


// fs_open()
// Open an existing file or create a new one.
// If the filename is empty, a temporary file is created.
//
bool fs_open(char *fn)
{
	return false;
}


// fs_close()
// Closes an open file. If it was temporary, it is deleted.
//
bool fs_close(FILE *f)
{
	// Reset last_ cache if it referenced this file
	return false;
}


// fs_close_all()
// Closes all files opened by the specified module
//
void fs_close_all(uint16_t owner)
{
	fs_index_ptr cur = fd_list;

	while (cur != NULL)
	{
		if (cur->owner == owner)
		{
			fs_close(cur);
			cur = fd_list;
		}
		else
		{
			cur = cur->next;
		}
	}
}


// fs_setmode()
// Resets the mode of the existing file f to "mode"
//
bool fs_setmode(FILE *f, char *mode)
{
	return false;
}


// fs_rename()
// Renames the open file f to a new name
// If the name is empty, f is converted to a temporary file.
//
bool fs_rename()
{
	return false;
}