//=====================================================
// le_loader.c
// M-Code object file dynamic loader
//
// Lilith M-Code Emulator
//
// Guido Hoss, 16.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#include "le_mach.h"
#include "le_loader.h"


// le_load_search
// Locates an object file by first trying to open "fn",
// then "alt_prefix.fn" if not successful
//
FILE *le_load_search(char *fn, char *alt_prefix)
{
    FILE *f;

    // Try filename "fn" (assumed to already be a basename)
    VERBOSE("Opening '%s'... ", fn)
    if ((f = fopen(fn, "r")) == NULL)
    {
        char *fn1;

        // Try alt_prefix (must be 3 chars + ".", e.g. LIB. or SYS.)
        fn1 = malloc(strlen(fn) + 4);
        strncpy(fn1, alt_prefix, 4);
        strcpy(fn1 + 4, fn);
        VERBOSE(" failed (%s)\nTrying '%s'... ", strerror(errno), fn1)

        if ((f = fopen(fn1, "r")) == NULL)
            VERBOSE(" failed (%s)\n", strerror(errno))

        free(fn1);
    }

    if (f != NULL)
        VERBOSE("ok\n")

    return f;
}


// le_skip()
// Skip a number of bytes in input stream
//
void le_skip(FILE *f, uint16_t n)
{
    fseek(f, n, SEEK_CUR);
}


// le_rword()
// Read a 16-bit word from input
//
uint16_t le_rword(FILE *f)
{
    uint16_t wr;

    if (fread(&wr, sizeof(uint16_t), 1, f) != 1)
        wr = 0xffff;

    // Swap byte order
    return ((wr >> 8) | (wr << 8));
}


// le_rbyte()
// Read a byte from input
//
uint8_t le_rbyte(FILE *f)
{
    uint16_t b;

    // Errors will be caught by caller
    if (fread(&b, 1, 1, f) != 1)
        b = 0xff;

    return b;
}


// le_rname()
// Read a module name and key from input
//
void le_rname(FILE *f, FILE *ofd)
{
    for (int i = 0; i < 16; i ++)
    {
        char c = le_rbyte(f);
        fprintf(ofd, "%c", (c < ' ') ? ' ' : c);
    }

    fprintf(ofd, "  (");
    for (int i = 0; i < 3; i ++)
        fprintf(ofd, " %04X", le_rword(f));

    fprintf(ofd, " )\n");
}


// le_expect()
// Expect a word from the input file and stop if no match
//
void le_expect(FILE *f, uint16_t w)
{
    uint16_t wr = le_rword(f);

    if (wr != w)
        error(1, 0, "Object file error: expected %04x, got %04x", w, wr);
}


// le_parse_objfile()
// Decode the specified object file f
//
void le_parse_objfile(FILE *f, FILE *ofd)
{
    uint16_t w, n, a;
    uint16_t vers;
    uint32_t total_code = 0;	// effective code size
    uint32_t decl_code = 0;		// declared code size
    uint32_t total_data = 0;	// effective data size
	uint32_t decl_data = 0;		// declared data size
    bool proc_section = true;
    bool eof = false;

    // Parse all sections
    while (! eof) {

        // Read next word
        w = le_rword(f);
        eof = feof(f);

        switch (w)
        {
        case 0200 :
            // Start of file
            le_expect(f, 1);
            le_rword(f);
            break;
        
        case 0201 :
            // Module section
            vers = le_rword(f);
            fprintf(ofd, "MODULE ");
            le_rname(f, ofd);

            // Skip bytes following filename in later versions
            if (vers == 0x11)
                le_skip(f, 6);

            decl_data += le_rword(f) << 1;
            decl_code += le_rword(f) << 1;
            le_rword(f);
            break;

        case 0202 :
            // Import section
            fprintf(ofd, "IMPORTS\n");
            n = le_rword(f);
            a = 1;
            while (n > 0)
            {
                fprintf(ofd, "  %03o: ", a);
                le_rname(f, ofd);
                n -= 11;
                a++;
            }
            break;

        case 0204 : {
                // Data sections
                n = le_rword(f);
                a = le_rword(f);
                n --;
                fprintf(ofd, "DATA (%d bytes)\n", n << 1);
				total_data += (n + 1) << 1;
                uint16_t num = 0;
                while (n-- > 0)
                {
                    if (num % 8 == 0)
                        fprintf(ofd, "\n  %07o", a);
                    a ++;
                    num ++;

                    w = le_rword(f);
                    fprintf(ofd, "  %04x", w);
                }
                fprintf(ofd, "\n");
                break;
            }

        case 0203 :
            if (proc_section)
            {
                // Procedure entry point section
                n = le_rword(f);
                a = 0;
                w = le_rword(f);

                fprintf(ofd, "PROCEDURE #%03o", w);
                if (n > 2)
                {
                    uint16_t extra = (n - 2) * 2;
                    fprintf(ofd, 
                        "  (%d bytes for extra entries)", extra
                    );
                    total_code += (n - 2) * 2;
                }
                fprintf(ofd, "\n");

                while (n-- > 1)
                {
                    fprintf(ofd, "%7d: %07o\n", a, le_rword(f));
                    a ++;
                }
            }
            else {
                n = le_rword(f) << 1;
                a = le_rword(f) << 1;
                fprintf(ofd, "CODE (%d bytes)\n", n);
                total_code += n;
                
                // n = a + n - 2;
                le_skip(f, n - 2);
            }
            proc_section = ! proc_section;
            break;

        case 0205 :
            // Relocation section
            fprintf(ofd, "FIXUPS\n");
            n = le_rword(f);

            while (n-- > 0)
            {
                w = le_rword(f);
                fprintf(ofd, "  %07o\n", w);
            }
            break;

        default :
            // No more readable sections
            eof = true;
            break;
        }

        // End of section
        if (! eof)
            fprintf(ofd, "\n");
    };

    // Final stats
    fprintf(ofd,
        "STATS\n" 
        "  CodeSize: %6d / %6d\n"
		"  DataSize: %6d / %6d\n",
        total_code, decl_code,
		total_data, decl_data
    );
}


// le_load_objfile
// Loads the specified object file into memory
// Tries again with an alternate prefix ("SYS." or "LIB.") if unsuccessful.
// Returns TRUE if successful
//
bool le_load_objfile(char *fn, char *alt_prefix)
{
    FILE *f;

    // Try to open object file
    if ((f = le_load_search(fn, alt_prefix)) == NULL)
    {
        error(0, 0, "Could not load '%s'", fn);
        return false;
    }

    // Parse the segments in the object file
    le_parse_objfile(f, stdout);

    fclose(f);
}
