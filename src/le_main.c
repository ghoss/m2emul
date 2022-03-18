//=====================================================
// le_main.c
// Main program code
//
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#include <libgen.h>
#include "le_mach.h"
#include "le_loader.h"
#include "le_mcode.h"
#include "le_usage.h"


// Global variables
//
bool verbose = false;	// Checked by all procedures to enable verbosity


// main
//
void main(int argc, char *argv[])
{
	char c;
	char *in_file = NULL;
	FILE *in_fd = NULL;

	// Parse command line options
	opterr = 0;
	while ((c = getopt (argc, argv, "Vvh")) != -1)
	{
		switch (c)
		{
		case 'h' :
			// Help information
			le_usage();
			exit(0);

		case 'V' :
			// Version information
			le_version();
			exit(0);

		case 'v' :
			// Verbose mode
			verbose = true;
			break;

		case '?' :
			error(1, 0,
				"Unrecognized option (run \"" PKG " -h\" for help)."
			);
			break;

		default :
			break;
        }
    }

	// Start interpreter loop with the specified object file
	if (optind < argc)
	{
		char *fn = argv[optind];
		char *dirn, *basn, *fn1, *fn2;

		// Get dirname and basename of input file
		fn1 = strdup(fn);
		fn2 = strdup(fn);
		dirn = dirname(fn1);
		basn = basename(fn2);

		// Change to directory of input file
		if (chdir(dirn) != 0)
		{
			error(0, errno, "Can't change to '%s'", dirn);
		}
		else
		{
			// Initialize machine
			mach_init();
			
			// Try to load basename of input file
			le_load_initfile(basn, "SYS.");
		}
		free(fn1);
		free(fn2);
	}
	else
	{
		// No filename given
		error(1, 0, 
			"No object file specified (run \"" PKG " -h\" for help)."
		);
	}
}