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

enum fs_filemode_t {
	FS_READ,
	FS_WRITE,
	FS_MODIFY
};


// Function declarations
//
void fs_swapcpy(char *dest, char *src, uint16_t n);
bool fs_open(uint8_t mod, char *fn, char *fn_buf, bool create, uint16_t m2_fd);
bool fs_reopen(uint16_t m2_fd, enum fs_filemode_t fmode);
void fs_close_all(uint16_t owner);
bool fs_close(uint16_t m2_fd);
bool fs_write(uint16_t m2_fd, uint16_t w, bool is_char);
bool fs_read(uint16_t m2_fd, uint16_t *w, bool is_char);
bool fs_getpos(uint16_t m2_fd, uint32_t *pos);
bool fs_setpos(uint16_t m2_fd, uint32_t pos);
bool fs_rename(uint16_t m2_fd, char *fn, char *fn_buf);

#endif