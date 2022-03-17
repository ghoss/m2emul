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


// md_version()
// Show version information
//
void le_version()
{
    fprintf(stderr, 
        PKG " v" PACKAGE_VERSION " (" VERSION_BUILD_DATE ")\n"
        "Modula-2 M-Code Emulator\n\n"
    );
}


// md_usage()
// Show usage information
//
void le_usage()
{
    fprintf(stderr,
        "USAGE: " PKG " [-hV] [object_file]\n\n"
        "-h\tShow this help information\n"
        "-V\tShow version information\n\n"
        "-v\tVerbose mode\n\n"
        "object_file is the filename of a Lilith M-Code (OBJ) file.\n\n"
    );
}