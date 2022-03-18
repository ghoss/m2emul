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


// le_read_modid()
// Read a module name and key from file and store it
// into "name" and "key"
//
void le_read_modid(FILE *f, mod_id_t *mod)
{
    // Read module name and key
    if ((fread(&(mod->name), MOD_NAME_MAX, 1, f) != 1)
        || (fread(&(mod->key), sizeof(mod_key_t), 1, f) != 1))
    {
        error(1, errno, "Object file read error");
    }
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
void le_parse_objfile(FILE *f)
{
    uint16_t w, n, a;
    uint32_t total_code = 0;	// effective code size
    uint32_t decl_code = 0;		// declared code size
    uint32_t total_data = 0;	// effective data size
	uint32_t decl_data = 0;		// declared data size
    mod_entry_t *this_mod;      // Pointer to current mod in module table
    bool proc_section = true;
    bool eof = false;

    // Parse all sections
    while (! eof) {

        // Read next word
        w = le_rword(f);
        eof = feof(f);

        switch (w)
        {
        case 0xC1 :
            // Alternate start of file, sometimes encountered
            le_rword(f);
            break;

        case 0200 :
            // Start of file
            le_expect(f, 1);
            le_rword(f);
            break;
        
        case 0201 : {
            // Module section
            mod_id_t mod;

            n = le_rword(f);
            le_read_modid(f, &mod);
            this_mod = init_mod_entry(&mod);
            this_mod->load_flag = true;

            // Skip bytes following module name/key in later versions
            if (n == 0x11)
                le_skip(f, 6);

            uint32_t data_sz = le_rword(f) << 1;
            uint32_t code_sz = le_rword(f) << 1;
            VERBOSE(
                "Module %s [%d], %d/%d bytes (data/code)\n", 
                mod.name, this_mod->idx, data_sz, code_sz
            )

            decl_data += data_sz;
            decl_code += code_sz;
            le_rword(f);
            break;
        }

        case 0202 : {
            // Import section         
            n = le_rword(f);
            while (n > 0)
            {
                mod_id_t mod;
                mod_entry_t *p;

                le_read_modid(f, &mod);
                p = init_mod_entry(&mod);
                VERBOSE("  imports %s [%d]", mod.name, p->idx);
                if (p->load_flag)
                    VERBOSE(" (loaded)")

                VERBOSE("\n")
                n -= 11;
            }
            break;
        }

        case 0204 : {
                // Data sections
                n = le_rword(f);
                a = le_rword(f);
                n --;
                VERBOSE("DATA (%d bytes)\n", n << 1)
				total_data += (n + 1) << 1;
                uint16_t num = 0;
                while (n-- > 0)
                {
                    if (num % 8 == 0)
                        VERBOSE("\n  %07o", a)
                    a ++;
                    num ++;

                    w = le_rword(f);
                    VERBOSE("  %04x", w)
                }
                VERBOSE("\n")
                break;
            }

        case 0203 :
            if (proc_section)
            {
                // Procedure entry point section
                n = le_rword(f);
                a = 0;
                w = le_rword(f);

                VERBOSE("PROCEDURE #%03o", w)
                if (n > 2)
                {
                    uint16_t extra = (n - 2) * 2;
                    VERBOSE(
                        "  (%d bytes for extra entries)", extra
                    )
                    total_code += (n - 2) * 2;
                }
                VERBOSE("\n")

                while (n-- > 1)
                {
                    w = le_rword(f);
                    VERBOSE("%7d: %07o\n", a, w)
                    a ++;
                }
            }
            else {
                n = le_rword(f) << 1;
                a = le_rword(f) << 1;
                VERBOSE("CODE (%d bytes)\n", n)
                total_code += n;
                
                // n = a + n - 2;
                le_skip(f, n - 2);
            }
            proc_section = ! proc_section;
            break;

        case 0205 :
            // Relocation section
            VERBOSE("FIXUPS\n")
            n = le_rword(f);

            while (n-- > 0)
            {
                w = le_rword(f);
                VERBOSE("  %07o\n", w)
            }
            break;

        default :
            // No more readable sections
            eof = true;
            break;
        }
    };

    // Final stats
    VERBOSE(
        "STATS\n" 
        "  CodeSize: %6d / %6d\n"
		"  DataSize: %6d / %6d\n",
        total_code, decl_code,
		total_data, decl_data
    )
}


// le_fix_extcalls
// Fixes external calls after modules i..max have been loaded
//
void le_fix_extcalls(uint8_t top)
{
    uint8_t max = mach_num_modules();

    while (top < max)
    {
        mod_entry_t *p = find_mod_index(top);

        if (! p->load_flag)
            error(1, 0, "Module %s missing after load");
        
        VERBOSE("Fixup %s\n", p->id.name)
        top ++;
    }
}


// le_load_search
// Locates an object file by first trying to open "fn",
// then "alt_prefix.fn" if not successful
//
FILE *le_load_search(char *fn, char *alt_prefix)
{
    FILE *f;
    char *fn1;

    // Reserve a string large enough for SYS./LIB. and .OBJ checks
    uint8_t l = strlen(fn);
    fn1 = malloc(l + 5);

    // Make sure filename ends in .OBJ
    strcpy(fn1, fn);
    if ((l < 4) || (strncmp(&(fn1[l - 4]), ".OBJ", 4) != 0))
    {
        strcat(fn1, ".OBJ");
    }

    // Try filename "fn" (assumed to already be a basename)
    VERBOSE("Opening '%s'... ", fn1)
    if (((f = fopen(fn1, "r")) == NULL)
        && (strncmp(fn1, alt_prefix, 4) != 0))
    {
        // Try alt_prefix (must be 3 chars + ".", e.g. LIB. or SYS.)
        char *fn2 = malloc(strlen(fn1) + 5);
        strcpy(fn2, alt_prefix);
        strcat(fn2, fn1);
        VERBOSE(" failed\nTrying '%s'... ", fn2)

        if ((f = fopen(fn2, "r")) == NULL)
            VERBOSE(" failed\n")
        free(fn2);
    }

    if (f != NULL)
        VERBOSE("ok\n")

    free(fn1);
    return f;
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
    uint8_t top = mach_num_modules() + 1;
    le_parse_objfile(f);
    fclose(f);

    // Load missing modules found after current one
    while (top < mach_num_modules())
    {
        // Check all entries in module table
        mod_entry_t *p = find_mod_index(top);

        if (! p->load_flag)
        {
            // Try to load this module
            if (! le_load_objfile(p->id.name, "LIB."))
                break;
        }
        top ++;
    }
}


// le_load_initfile
// Loads the initial object file and its dependencies
//
bool le_load_initfile(char *fn, char *alt_prefix)
{
    // The new module will be loaded here if successful
    uint8_t top = mach_num_modules();

    // Load executable and its dependencies
    if (! le_load_objfile(fn, alt_prefix))
        return false;

    // Fixup all external calls in executable and above
    le_fix_extcalls(top);
}