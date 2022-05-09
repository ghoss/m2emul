//=====================================================
// le_usage.c
// Help description
//
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#include <config.h>
#include "le_mach.h"
#include "le_usage.h"


// le_prog_version()
// Show program version information
//
void le_prog_version()
{
    printf(PKG " v" PACKAGE_VERSION 
		" by " PACKAGE_BUGREPORT" (" VERSION_BUILD_DATE ")\n"
        "Modula-2 M-Code Emulator\n\n"
	);
}


// le_prog_usage()
// Show program usage information
//
void le_prog_usage()
{
    printf(
        "USAGE: " PKG " [-htvV] {-i path} [object_file]\n\n"
		"-i\tSearch specified path(s) for objects and libraries\n"
 		"-t\tEnable trace mode (runtime debugging)\n"
		"-h\tShow this help information\n"
        "-V\tShow version information\n\n"
        "-v\tVerbose mode\n\n"
        "object_file is the filename of a Lilith M-Code (OBJ) file.\n\n"
		"Additional include paths may be specified in the\n"
		"environment variable MULE_PATH (delimited by colons).\n\n"
    );
}


// le_monitor_usage()
// Show program usage information
//
void le_monitor_usage()
{
    wprintw(app_win,
        "\nt\tExecute one instruction\n"
		"s\tExecute one instruction, but skip through proc calls"
		"g\tExecute until next breakpoint or end of program\n"
		"r\tSwitch register/stack display on/off\n"
		"d num\tShow contents of data word 'num'\n"
		"c\tShow current procedure call chain\n"
		"b m:pc\tSet breakpoint to program counter pc in module number m\n"
		"q\tExit interpreter\n"
        "h, ?\tShow this help summary\n\n"
    );
}