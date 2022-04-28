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

// Structures for terminal input and output
//
WINDOW *app_win;
char kbd_buf;
enum {
	LE_COL_NORMAL,
	LE_COL_ERROR,
	LE_COL_VERBOSE
};

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

		case 1 : {
			// Keyboard status register
			kbd_buf = getch();
			return (kbd_buf > 0) ? 1 : 0;
			break;
		}

		case 2 :
			// Keyboard data register
			return kbd_buf;
			break;

		default :
			le_error(1, 0, "READ from channel #%d not implemented", chan);
			break;
	}
	return val;
}


// le_iowrite()
// Write word to hardware channel
//
void le_iowrite(uint16_t chan, uint16_t w)
{
    le_error(1, 0, "WRITE not implemented (%d,%d)", chan, w);
}


// le_putchar()
// Prints one character to the terminal (implementation of DCH opcode)
//
void le_putchar(char c)
{
	switch (c)
	{
		case 0177 :
			wprintw(app_win, "\010");
			delch();
			break;

		default :
			wprintw(app_win, "%c", c);
			break;
	}
	refresh();
}


// le_cleanup_io()
//
// Reset terminal to previous state
//
void le_cleanup_io()
{
	refresh();
	endwin();
}


// le_init_io()
// Initializes channel-based IO
// (e.g. file descriptors for non-blocking getc)
//
void le_init_io()
{
	app_win = initscr();
	start_color();
	init_pair(LE_COL_NORMAL, COLOR_GREEN, COLOR_BLACK);
	init_pair(LE_COL_ERROR, COLOR_RED, COLOR_BLACK);
	init_pair(LE_COL_VERBOSE, COLOR_CYAN, COLOR_BLACK);
	wattron(app_win, COLOR_PAIR(LE_COL_NORMAL));
	timeout(0);
	noecho();
	scrollok(app_win, true);
}


// le_error()
// Issue error message similar to standard error() call
// but this variant is compatible with ncurses.
//
void le_error(bool ex_code, int errnum, char *msg, ...)
{
	// Get variable argument list
	va_list arg_p;
	va_start(arg_p, msg);

	// Print message and variable arguments
	wattron(app_win, COLOR_PAIR(LE_COL_ERROR));
	vw_printw(app_win, msg, arg_p);

	if (errnum != 0)
		wprintw(app_win, " (%s)", strerror(errno));

	wprintw(app_win, "\n");
	wattroff(app_win, COLOR_PAIR(LE_COL_ERROR));

	// Exit if exit code non-zero
	if (ex_code != 0)
		exit(ex_code);
}


// le_verbose_msg()
// Issue the specified message if verbose mode is on
//
void le_verbose_msg(char *msg, ...)
{
	// Get variable argument list
	if (le_verbose)
	{
		va_list arg_p;
		va_start(arg_p, msg);

		// Print message and variable arguments
		wattron(app_win, COLOR_PAIR(LE_COL_VERBOSE));
		vw_printw(app_win, msg, arg_p);
		wattroff(app_win, COLOR_PAIR(LE_COL_VERBOSE));
	}
}