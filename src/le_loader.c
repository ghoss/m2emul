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
#include "le_io.h"
#include "le_trace.h"
#include "le_loader.h"


// Array of include paths
typedef struct {
	char *path;		// Pointer to path string
} pathentry_t; 

pathentry_t *patharray = NULL;
uint16_t num_paths = 0;


// le_memerr()
// Halt because of failed memory allocation
//
void le_memerr()
{
	le_error(1, errno, "Loader: could not allocate memory");
}


// le_rderr()
// Halt because of file read error
//
void le_rderr(char *msg)
{
	le_error(1, errno, "Object file read error (%s)", msg);
}


// le_skip()
// Skip a number of bytes in input stream
//
void le_skip(FILE *f, uint16_t n)
{
    if (fseek(f, n, SEEK_CUR) != 0)
		le_rderr("le_skip");
}


// le_rword()
// Read a 16-bit word from input
//
uint16_t le_rword(FILE *f)
{
    uint16_t wr;

    if (fread(&wr, MACH_WORD_SZ, 1, f) != 1)
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
		le_rderr("modid");
}


// le_expect()
// Expect a word from the input file and stop if no match
//
void le_expect(FILE *f, uint16_t w)
{
    uint16_t wr = le_rword(f);

    if (wr != w)
        le_error(1, 0, "Object file error: expected %04x, got %04x", w, wr);
}


// le_parse_objfile()
// Decode the specified object file f
//
void le_parse_objfile(FILE *f)
{
    uint16_t w, n, a;
    mod_entry_t *mod = NULL;	// Pointer to current mod in module table
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
            mod_id_t modid;

            n = le_rword(f);
            le_read_modid(f, &modid);
            mod = init_mod_entry(&modid);
            mod->id.loaded = true;

            // Skip bytes following module name/key in later versions
            if (n == 0x11)
                le_skip(f, 6);

            // Allocate memory for module's code and data
            mod->data_sz = le_rword(f);			// words
			mod->data_ofs = data_top;
			data_top += mod->data_sz;
            mod->code_sz = le_rword(f) << 1;	// bytes
            if (((mod->code = calloc(mod->code_sz, 1)) == NULL))
                le_memerr();

            le_verbose_msg(
                "Module %s [%d]  "
				"(%d data words/%d code bytes, offset=%d)\n",
                modid.name, mod->id.idx, 
                mod->data_sz, mod->code_sz,
				mod->data_ofs
            );
            le_rword(f);
            break;
        }

        case 0202 : {
            // Import section
            n = le_rword(f) / 11;   // Each entry is 11 words long

            // Allocate import table for module
            mod->import_n = n;
            if ((mod->import = calloc(n, sizeof(mod_id_t))) == NULL)
                le_memerr();

            for (uint16_t i = 0; i < n; i ++)
            {
                mod_id_t modid;
                mod_entry_t *p;

                // Assign entry in module table if not yet found
                le_read_modid(f, &modid);
                p = init_mod_entry(&modid);

                // Store entry to import table
                memcpy(mod->import + i, &(p->id), sizeof(mod_id_t));

                le_verbose_msg(
					"  imports %s [%d]%c\n", p->id.name, p->id.idx,
					p->id.loaded ? ' ' : '*'
				);
            }
            break;
        }

        case 0204 : {
                // Data sections
                n = le_rword(f) - 1;	// Number of words
                a = le_rword(f);		// Offset in words

                // Check for data frame overrun
                if (a + n > mod->data_sz)
                    le_error(1, 0, 
                        "Module %s: Data frame overrun", mod->id.name
                    );

                // Read byte-swapped data block into memory at offset a
				a += mod->data_ofs;
				while (n-- > 0)
					dsh_mem[a ++] = le_rword(f);
                break;
            }

        case 0203 : 
            if (proc_section)
            {
				proctmp_t *p;

                // Procedure entry point section
                n = le_rword(f) - 1;
				uint16_t pidx = le_rword(f);

				for (uint16_t i = 0; i < n; i ++)
				{
					// Allocate new entry in temporary procedure list
					if ((p = malloc(sizeof(proctmp_t))) == NULL)
						le_memerr();

					// Old format: one entry per procedure section (pidx != 0)
					// New format: all entries in procedure section #0
					p->idx = (pidx != 0) ? pidx : i;

					p->entry = le_rword(f);
					p->next = mod->proc_tmp;
					p->fixup = NULL;
					p->fixup_n = 0;
					mod->proc_tmp = p;
					if (p->idx >= mod->proc_n)
						mod->proc_n = p->idx + 1;
				}
            }
            else {
                n = (le_rword(f) << 1) - 2;
                a = le_rword(f) << 1;

                // Check for code frame overrun
                if (a + n > mod->code_sz)
                    le_error(1, 0, 
                        "Module %s: Code frame overrun", mod->id.name
                    );

                // Read code block into memory at offset a
                if (fread(mod->code + a, n, 1, f) != 1)
                    le_rderr("code");
            }
            proc_section = ! proc_section;
            break;

        case 0205 : {
            // Relocation section
            n = le_rword(f);

			// Allocate memory for fixup table
			uint16_t *p;
			if ((p = calloc(n, MACH_WORD_SZ)) == NULL)
				le_memerr();

			// Read fixups into table
			for (uint16_t i = 0; i < n; i ++)
				p[i] = le_rword(f);

			mod->proc_tmp->fixup = p;
			mod->proc_tmp->fixup_n = n;
            break;
		}

        default :
            // No more readable sections
            eof = true;
            break;
        }
    };
}


// le_fix_extcalls()
// Fixes external calls after modules i..max have been loaded
//
void le_fix_extcalls(uint8_t top)
{
    uint8_t max = mach_num_modules();

    while (top < max)
    {
		uint16_t n;
        mod_entry_t *mod = &(module_tab[top]);

        if (! mod->id.loaded)
            le_error(1, 0, "Module %s missing after load", mod->id.name);
        
		// Part 1: Create final procedure table
		n = mod->proc_n;
        le_verbose_msg("Fixup %s (%d procs)\n", mod->id.name, n);
		if (n > 0) 
		{
			// Allocate memory for procedure table
			// Missing procedures will have an (invalid) entry point 0
			// which will be detected at runtime
			uint16_t *ptab = calloc(n, MACH_WORD_SZ);
			mod->proc = ptab;	

			proctmp_t *pt = mod->proc_tmp;
			while (pt != NULL)
			{
				// Store procedure index in final table
				*(ptab + pt->idx) = pt->entry;

				// Process fixups for code
				for (uint16_t i = 0; i < pt->fixup_n; i ++)
				{
					uint16_t loc = pt->fixup[i];
					if (loc >= mod->code_sz)
						le_error(1, 0, "Fixup codeframe overrun\n");

					// Fixup location depending on opcode in [loc-1]
					uint8_t opc = mod->code[loc - 1];
					uint8_t b1 = mod->code[loc];

					switch (opc)
					{
						case 022 :	// LIW
						case 043 :	// LED
						case 063 :	// SED
						case 027 :	// LEA
						case 042 :	// LEW
						case 062 :	// SEW
						case 0355 :	// CLX
							// Change first opbyte to absolute index of module
							if (b1 > mod->import_n)
								le_error(1, 0, 
									"%s: %07o opc %03o illegal module #%03o", 
									mod->id.name, loc - 1, opc, b1
								);
							mod->code[loc] = mod->import[b1 - 1].idx;
							break;
						
						default :
							le_decode(mod, loc - 1);
							le_error(1, 0, 
								"Module %s: fixup #%03o invalid", 
								mod->id.name, b1
							);
							break;
					}
				}

				// Free fixup table for proc
				free(pt->fixup);

				// Free current proc entry and advance to next one
				proctmp_t *qt = pt;
				pt = pt->next;
				free(qt);
			}
			mod->proc_tmp = NULL;
		}

		// Free module import table
		if (mod->import != NULL)
			free(mod->import);
			
        top ++;
    }
}


// le_load_search()
// Locates an object file by first trying to open "fn",
// then "alt_prefix.fn" if not successful
//
FILE *le_load_search(char *fn, char *alt_prefix)
{
    FILE *f = NULL;
    char *fn1;

    // Reserve a string large enough for SYS./LIB. and .OBJ checks
    uint8_t l = strlen(fn);
    if ((fn1 = malloc(l + 5)) == NULL)
		le_memerr();

    // Make sure filename ends in .OBJ
    strcpy(fn1, fn);
    if ((l < 4) || (strncmp(&(fn1[l - 4]), ".OBJ", 4) != 0))
    {
        strcat(fn1, ".OBJ");
    }

	// Try to open filename and variants in all include paths
	for (uint16_t i = 0; i < num_paths; i ++)
	{
		char *fpath;

		// 1: Try direct lookup
		asprintf(&fpath, "%s/%s", patharray[i].path, fn1);
		le_verbose_msg("Trying '%s'... ", fpath);
		f = fopen(fpath, "r");
		free(fpath);
		if (f != NULL)
			break;

		// 2: Try alt_prefix (if prefix not already specified)
		if (strncmp(fn1, alt_prefix, 4) != 0)
		{
			asprintf(&fpath, "%s/%s.%s", patharray[i].path, alt_prefix, fn1);
			le_verbose_msg("failed\nTrying '%s'... ", fpath);
			f = fopen(fpath, "r");
			free(fpath);
			if (f != NULL)
				break;
		}
		le_verbose_msg("failed\n");
	}
	free(fn1);
	le_verbose_msg((f != NULL) ? "ok\n" : "failed\n");

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
        le_error(0, 0, "Could not load '%s'", fn);
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
        mod_entry_t *p = &(module_tab[top]);

        if (! p->id.loaded)
        {
            // Try to load this module
            if (! le_load_objfile(p->id.name, "LIB"))
                return false;
        }
        top ++;
    }
	return true;
}


// le_load_initfile()
// Loads the initial object file and its dependencies
//
uint8_t le_load_initfile(char *fn, char *alt_prefix)
{
    // The new module will be loaded here if successful
    uint8_t top = mach_num_modules();

    // Load executable and its dependencies
    if (! le_load_objfile(fn, alt_prefix))
        return 0;

    // Fixup all external calls in executable and above
    le_fix_extcalls(top);
	
	return top;
}


// le_include_path()
// Adds the specified path to the list of paths searched
// for objects and libraries
//
void le_include_path(char *path)
{
	// Assign new array element for this path
	if (patharray != NULL)
	{
		patharray = reallocarray(
			patharray, num_paths + 1, sizeof(pathentry_t)
		);
	}
	else
	{
		// First path in list; add the current directory before it
		patharray = malloc(sizeof(pathentry_t));
	}

	// Store path in new array element
	if (patharray != NULL)
	{
		patharray[num_paths].path = path;
		num_paths ++;
	}
	else
	{
		le_memerr();
	}
}


// le_dump_paths
// Dumps the list of include paths (for verbose mode)
//
void le_dump_paths()
{
	for (uint16_t i = 0; i < num_paths; i ++)
		le_verbose_msg("Include path %d: '%s'\n", i + 1, patharray[i].path);
}