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
	char *fname;				// Associated UNIX filename
	char *fname_buf;			// Actual char buffer of filename
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


// fs_cache_last()
// Cache most recent referenced file descriptor for
// faster access
//
void fs_cache_last(fs_index_ptr p)
{
	last_fd = p;
	last_m2file = (p != NULL) ? p->m2file : 0;
}


// fs_find_fd()
// Returns the associated file list entry for a
// Modula-2 file descriptor
//
fs_index_ptr fs_find_fd(uint16_t m2_fd, bool fatal_err)
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
				fs_cache_last(cur);
				return cur;
			}
			else {
				cur = cur->next;
			}
		}

		if (fatal_err)
			error(1, 0, "Invalid M2 file descriptor");
		
		return NULL;
	}
}


// fs_open()
// Open an existing file or create a new one (create=TRUE).
// If the filename is empty, a temporary file is created.
// m2_fd points to the Modula-2 file descriptor of the caller.
//
bool fs_open(uint8_t mod, char *fn, char *fn_buf, bool create, uint16_t m2_fd)
{
	FILE *f;
	bool temp = (*fn == '\0');

	if (temp)
	{
		// Create temporary file
		fn = malloc(16);
		fn_buf = fn;
		strcpy(fn, "mule_tmp.XXXXXX");
		int fno = mkstemp(fn);
		f = fdopen(fno, "w");
		create = true;
	}
	else
	{
		// Create regular file
		f = fopen(fn, create ? "w" : "r");
	}

	// Try to open or create file
	if (f != NULL)
	{
		// Successful; add entry to list of open files
		fs_index_ptr p = malloc(sizeof(struct fs_index_t));
		if (p == NULL)
			error(1, errno, "fs_open malloc failed");
		
		p->fd = f;
		p->m2file = m2_fd;
		p->owner = mod;
		p->temp = temp;
		p->fname = fn;
		p->fname_buf = fn_buf;
		p->next = fd_list;
		fd_list = p;
		fs_cache_last(p);
		return true;
	}
	else
	{
		// Could not open or create file
		return false;
	}
}


// fs_reopen()
// Change file mode of previously opened file
//
bool fs_reopen(uint16_t m2_fd, enum fs_filemode_t fmode)
{
	fs_index_ptr p = fs_find_fd(m2_fd, true);

	return (fdopen(fileno(p->fd), (fmode == FS_READ) ? "r" : "r+") == NULL);
}


// fs_close_int()
// Internal helper function for fs_close() and fs_close_all().
//
bool fs_close_int(fs_index_ptr p)
{
	bool res = true;

	// Physically close file
	fclose(p->fd);

	// Unlink the file if it was temporary
	if (p->temp && (unlink(p->fname) != 0))
	{
		res = false;
		error(0, errno, "fs_close unlink failed");
	}

	// Free filename buffer associated with file
	free(p->fname_buf);

	// Remove file entry from index list
	fs_index_ptr cur = fd_list;
	fs_index_ptr prev = NULL;
	while (cur != NULL)
	{
		if (cur == p)
		{
			if (prev != NULL)
				prev->next = cur->next;
			else
				fd_list = cur->next;

			free(cur);
			break;
		}
		else
		{
			prev = cur;
			cur = cur->next;
		}
	}
	return res;
}


// fs_close()
// Closes an open file. If it was temporary, it is deleted.
//
bool fs_close(uint16_t m2_fd)
{
	fs_index_ptr p = fs_find_fd(m2_fd, false);

	fs_cache_last(NULL);
	if (p != NULL)
		return fs_close_int(p);
	else
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
			fs_index_ptr p = cur->next;
			fs_close_int(cur);
			cur = p;
		}
		else
		{
			cur = cur->next;
		}
	}

	fs_cache_last(NULL);
}


// fs_rename()
// Renames the open file f to a new name
// If the name is empty, f is converted to a temporary file.
//
bool fs_rename(uint16_t m2_fd, char *fn, char *fn_buf)
{
	fs_index_ptr p = fs_find_fd(m2_fd, true);

	if (*fn != '\0')
	{
		// Filename specified -> rename
		p->temp = false;
		bool res = (rename(p->fname, fn) != 0);
		free(p->fname_buf);
		p->fname = fn;
		p->fname_buf = fn_buf;
		return res;
	}
	else
	{
		// Filename empty -> convert to temporary file
		p->temp = true;
		return true;
	}
}


// fs_write()
// Writes a character (is_char=false) or word to the specified file
// If (is_char=true), the word is already assumed to have been swapped
// by the caller.
//
bool fs_write(uint16_t m2_fd, uint16_t w, bool is_char)
{
	uint8_t n = is_char ? 1 : 2;
	fs_index_ptr p = fs_find_fd(m2_fd, true);

	return (fwrite(&w, 1, n, p->fd) == n);
}


// fs_read()
// Reads a character (is_char=false) or word from the specified file
//
bool fs_read(uint16_t m2_fd, uint16_t *w, bool is_char)
{
	uint8_t n = is_char ? 1 : 2;
	fs_index_ptr p = fs_find_fd(m2_fd, true);

	return (fread(w, 1, n, p->fd) == n);
}


// fs_getpos()
// Gets the current file position
//
bool fs_getpos(uint16_t m2_fd, uint32_t *pos)
{
	long x;
	fs_index_ptr p = fs_find_fd(m2_fd, true);

	bool res = ((x = ftell(p->fd)) != -1);
	*pos = res ? x : 0;
	return res;
}


// fs_setpos()
// Sets the current file position
//
bool fs_setpos(uint16_t m2_fd, uint32_t pos)
{
	fs_index_ptr p = fs_find_fd(m2_fd, true);

	return (fseek(p->fd, pos, SEEK_SET) != -1);
}