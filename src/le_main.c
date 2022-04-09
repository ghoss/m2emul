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
#include "le_io.h"
#include "le_loader.h"
#include "le_mcode.h"
#include "le_usage.h"


// Global variables
//
bool le_verbose = false;	// Checked by all procedures to enable verbosity


// cleanup()
// Exit cleanup routine
//
void cleanup()
{
	le_cleanup_io();
}


// main()
// Main program entry point
//
int main(int argc, char *argv[])
{
	char c;

	// Parse command line options
	opterr = 0;
	while ((c = getopt (argc, argv, "Vtvh")) != -1)
	{
		switch (c)
		{
		case 'h' :
			// Help information
			le_prog_usage();
			exit(0);

		case 'V' :
			// Version information
			le_prog_version();
			exit(0);

		case 'v' :
			// Verbose mode
			le_verbose = true;
			break;

		case 't' :
			// Trace mode enabled (implies verbose mode)
			le_trace = le_verbose = true;
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
			atexit(cleanup);
			mach_init();
			le_init_io();
			
			// Try to load basename of input file
			uint8_t top = le_load_initfile(basn, "SYS.");

			// Execute module
			VERBOSE("Starting execution.\n")
			le_execute(top, 0);
			VERBOSE("Execution terminated normally.\n")
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