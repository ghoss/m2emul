//=====================================================
// le_trace.c
// M-Code tracing and disassembly functions
//
// Lilith M-Code Emulator
//
// Guido Hoss, 14.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#include "le_usage.h"
#include "le_mach.h"
#include "le_trace.h"


// Output shorthand
#define OUT(...)		printw(__VA_ARGS__);

// Global variables
bool le_trace = false;		// Enables trace mode
bool show_regs = true;		// Enables register/stack display

// Breakpoint variables
bool breakpoint = false;	// Enables breakpoint
uint8_t bp_module;			// Number of module to break in
uint16_t bp_PC;				// Breakpoint PC


// M-Code mnemonics table
//
#define LE_MNEM_LEN  5

const char *mnem_tab = 
	"LI0  LI1  LI2  LI3  LI4  LI5  LI6  LI7  LI8  LI9  LI10 LI11 LI12 LI13 LI14 LI15 "
	"LIB +---- LIW *LID /LLA +LGA +LSA +LEA *JPC *JP  *JPFC+JPF +JPBC+JPB +ORJP+AJP +"
	"LLW +LLD +LEW -LED -LLW4 LLW5 LLW6 LLW7 LLW8 LLW9 LLW10LLW11LLW12LLW13LLW14LLW15"
	"SLW +SLD +SEW -SED -SLW4 SLW5 SLW6 SLW7 SLW8 SLW9 SLW10SLW11SLW12SLW13SLW14SLW15"
	"LGW +LGD +LGW2 LGW3 LGW4 LGW5 LGW6 LGW7 LGW8 LGW9 LGW10LGW11LGW12LGW13LGW14LGW15"
	"SGW +SGD +SGW2 SGW3 SGW4 SGW5 SGW6 SGW7 SGW8 SGW9 SGW10SGW11SGW12SGW13SGW14SGW15"
	"LSW0 LSW1 LSW2 LSW3 LSW4 LSW5 LSW6 LSW7 LSW8 LSW9 LSW10LSW11LSW12LSW13LSW14LSW15"
	"SSW0 SSW1 SSW2 SSW3 SSW4 SSW5 SSW6 SSW7 SSW8 SSW9 SSW10SSW11SSW12SSW13SSW14SSW15"
	"LSW +LSD +LSD0 LXFW LSTA+LXB  LXW  LXD  DADD DSUB DMUL DDIV ---- ---- DSHL DSHR "
	"SSW +SSD +SSD0 SXFW TS   SXB  SXW  SXD  FADD FSUB FMUL FDIV FCMP FABS FNEG FFCT+"
	"READ WRT  DSKR DSKW TRK  UCHK SVC +SYS +ENTP+EXP  ULSS ULEQ UGTR UGEQ TRA +RDS +"
	"LODFWLODFDSTOR STOFVSTOT COPT DECS PCOP+UADD USUB UMUL UDIV UMOD ROR  SHL  SHR  "
	"FOR1?FOR2?ENTC*EXC  TRAP CHK  CHKZ CHKS EQL  NEQ  LSS  LEQ  GTR  GEQ  ABS  NEG  "
	"OR   XOR  AND  COM  IN   LIN  MSK  NOT  IADD ISUB IMUL IDIV IMOD BIT  NOP  MOVF "
	"MOV  CMP  DDT  REPL BBLT DCH  UNPK PACK GB  +GB1  ALLOCENTR+RTN  CLX -CLI +CLF  "
	"CLL +CLL1 CLL2 CLL3 CLL4 CLL5 CLL6 CLL7 CLL8 CLL9 CLL10CLL11CLL12CLL13CLL14CLL15";


// Trap definitions
//
const char *trap_descr[] = {
	[TRAP_STACK_OVF] = "Stack overflow",
	[TRAP_INDEX] = "Array index out of bounds",
	[TRAP_INT_ARITH] = "Integer arithmetic under/overflow",
	[TRAP_CODE_OVF] = "Code frame overrun",
	[TRAP_INV_FFCT] = "Invalid FFCT function",
	[TRAP_INV_OPC] = "Invalid opcode",
	[TRAP_SYSTEM] = "System-triggered trap"
};


// le_show_callchain()
// Displays the current procedure call chain
//
void le_show_callchain(mod_entry_t *modp)
{
	uint16_t adr = gs_L;
	while (adr > data_top)
	{
		uint16_t m = dsh_mem[adr];
		uint16_t pc = dsh_mem[adr + 2] - 1;

		if (m & 0xff00)
		{
			m &= 0xff;
			modp = &(module_tab[m]);
		}
		VERBOSE("\n%16s(%d):%07o\n", modp->id.name, modp->id.idx, pc)
		
		adr = dsh_mem[adr + 1];
	}
}


// le_trap()
// Trap handler
//
void le_trap(mod_entry_t *modp, uint16_t n)
{
	le_show_callchain(modp);
	error(1, 0, 
		"TRAP #%d: %s\r\n%d:%07o (%s)", 
		n, trap_descr[n], modp->id.idx, gs_PC - 1, modp->id.name
	);
}


// le_code_length()
// Returns the length of the current opcode
//
uint8_t le_opcode_len(uint8_t mcode)
{
    uint16_t i = mcode * LE_MNEM_LEN;
	char c = mnem_tab[i + (LE_MNEM_LEN - 1)];
	uint8_t n;

    switch (c)
    {
        case '+' :
            n = 2;
            break;

        case '-' :
        case '*' :
            n = 3;
            break;

        case '?' :
            n = 4;
            break;

        case '/' :
            n = 5;
            break;

        default :
            // No special type -> print last character of opcode
            n = 1;
            break;
    }
	return n;
}


// le_decode()
// Print an opcode and its arguments at PC counter "pc"
//
void le_decode(mod_entry_t *mod, uint16_t pc)
{
    uint16_t a1 = 0;
    uint8_t b1 = 0;

    // Print octal byte
    uint8_t pr_byte()
    {
        uint8_t byt = mod->code[pc];
        OUT(" %03o", byt)
        pc ++;
        return byt;
    }

    // Print octal word
    uint16_t pr_word()
    {
        uint16_t wrd = (mod->code[pc] << 8) | mod->code[pc + 1];
        OUT(" %06o", wrd)
        pc += 2;
        return wrd;
    }

    // Output mnemonic
	uint8_t mcode = mod->code[pc];
    uint16_t i = mcode * LE_MNEM_LEN;
    char c = mnem_tab[i + (LE_MNEM_LEN - 1)];
    OUT( 
        "\n  %07o  %03o  %c%c%c%c", 
        pc, mcode, mnem_tab[i], mnem_tab[i+1], mnem_tab[i+2], mnem_tab[i+3]
    )
    pc ++;

    // Output parameters of opcode (type indicated by one-character
    // code following mnemonic in table)
    switch (c)
    {
        case '+' :
            a1 = (int8_t) pr_byte();
            break;

        case '-' :
            a1 = pr_byte();
            b1 = pr_byte();
            break;

        case '*' :
            a1 = (int16_t) pr_word();
            break;

        case '/' :
            pr_word();
            pr_word();
            break;

        case '?' :
            b1 = pr_byte();
            a1 = pr_word();
            break;

        default :
            // No special type -> print last character of opcode
            OUT( "%c", c)
            break;
    }

    // Special formatting for some opcodes
    // Jumps: print offset previously fetched in a1
    switch (mcode)
    {
		case 022 :
			// LIW
			OUT("\t; x%04x", a1)
			break;

        case 034 ... 035 :
            // JPB, JPBC
            OUT("\t; <-[%o]", pc - (int16_t) (a1 + 1))
            break;
            
        case 030 ... 033 :
        case 036 ... 037 :
            // Forward jumps
            OUT( "\t; ->[%o]", pc + (int16_t) (a1 - 1))
            break;

		case 0204 : {
			// Load string address
			uint16_t adr = dsh_mem[gs_G + 2] + mod->code[pc - 1];
			OUT("\t; \"%.5s...\"", (char *) &(dsh_mem[adr]))
			break;
		}

        case 0300 :
            // FOR1
            OUT( 
                "\t; ->[%o] %s",
                pc + (int8_t) (a1 & 0xff) - 2,
                (b1 == 0) ? "UP" : "DN"
            )
            break;

        case 0301 :
            // FOR2
            OUT( 
                "\t; ->[%o]",
                pc + (int8_t) (a1 & 0xff) - 2
            )
            break;

		case 0302 :
			// ENTC
            OUT( "\t; ->[%o]", pc + (int16_t) (a1 - 1))
			break;

		case 0355 :
			// CLX
			OUT("\t; ->%s.%d", module_tab[a1].id.name, b1)
			break;
    }
    OUT("\n")
}


// le_show_registers()
// Show registers and stacks
//
void le_show_registers(mod_entry_t *mod)
{
	OUT("%s: S=x%04X, G=x%04X, L=x%04X, ES=x%02X", 
		mod->id.name, gs_S - data_top,
		gs_G, gs_L - data_top, gs_SP
	)

	// Display stack
	for (uint16_t i = data_top; i < gs_S; i ++)
	{
		uint16_t j = i - data_top;

		if (j % 8 == 0)
			OUT("\nSTK:")
		OUT("  %02X: %04X", j, dsh_mem[i])
	}

	// Display expression stack
	for (uint8_t i = 0; i < gs_SP; i ++)
	{
		if (i % 8 == 0)
			OUT("\nES: ")
		OUT("  %02X: %04X", i, exs_mem[i])
	}
	OUT("\n")
}


// le_monitor()
// Waits for a monitor command from keyboard and executes it
//
void le_monitor(mod_entry_t *mod)
{
	bool quit = false;

	// Check if breakpoint enabled
	if (breakpoint)
	{
		if ((bp_module == mod->id.idx) && (gs_PC == bp_PC))
		{
			// Re-enable monitor and disable breakpoint
			le_trace = true;
		}
		else
		{
			// Not at breakpoint; continue execution
			return;
		}
	}
	
	// Return if trace mode disabled
	if (! le_trace) return;

	// Decode current instruction
	le_decode(mod, gs_PC);
	if (show_regs)
		le_show_registers(mod);

	// Enter command loop
	timeout(-1);
	echo();
	while (! quit) {
		refresh();
		VERBOSE("cmd> ")

		switch (getch())
		{
			case '\n' :
				// Ignore EOL
				printw("\n");
				continue;

			case 'r' :
				// Switch register display on/off
				show_regs = ! show_regs;
				VERBOSE("\nRegister display now %s\n", show_regs ? "ON" : "OFF")
				break;

			case 'd' : {
				// Show contents of data word
				uint16_t w;
				scanw("%hx", &w);
				VERBOSE("data[%04X]=x%04X\n", w, dsh_mem[gs_G + w]);
				break;
			}

			case 'c' : 
				// Show procedure callchain
				le_show_callchain(mod);
				break;
				
			case 'b' : {
				// Set breakpoint
				scanw("%hhd:%ho", &bp_module, &bp_PC);
				VERBOSE(
					"Breakpoint set to %s:%07o\n", 
					module_tab[bp_module].id.name, bp_PC
				);
				breakpoint = true;
				break;
			}

			case 'g' :
				// Execute until next breakpoint
				if (bp_module != 0)
				{
					breakpoint = true;
					quit = true;
				}
				else
				{
					VERBOSE("\nNo breakpoint set\n")
				}
				continue;

			case 's' : {
				// Single-step, but skip through proc calls
				uint8_t mcode = mod->code[gs_PC];

				switch (mcode)
				{
					// Don't skip through RTN because of possible
					// module change. Don't skip through jumps.
					//
					case 030 ... 037 :		// Jumps
					case 0300 ... 0302 :	// FOR1, FOR2, ENTC
					case 0354 :				// RTN
						breakpoint = false;
						break;

					default :
						bp_module = mod->id.idx;
						bp_PC = gs_PC + le_opcode_len(mcode);
						breakpoint = true;
						break;
				}
				quit = true;
				break;
			}

			case 'h' :
			case '?' :
				// Built-in help
				le_monitor_usage();
				break;

			case 't' :
				// Do nothing (step one instruction)
				breakpoint = false;
				quit = true;
				break;

			case 'q' :
				// Exit
				VERBOSE("\nQuitting\n")
				exit(0);

			default :
				VERBOSE("\nUnknown command\n")
				break;
		}
	}
	
	timeout(0);
	noecho();
}