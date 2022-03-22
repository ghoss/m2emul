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
#define OUT(...)		fprintf(ofd, __VA_ARGS__);

// Global variables
bool trace = false;			// Enables trace mode
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
	[TRAP_SYSTEM] = "Compiler-triggered trap"
};


// le_trap()
// Trap handler
//
void le_trap(mod_entry_t *modp, uint16_t n)
{
	switch (n)
	{
		case TRAP_STACK_OVF :
		case TRAP_INDEX :
		case TRAP_INT_ARITH :
		case TRAP_CODE_OVF :
		case TRAP_INV_FFCT :
		case TRAP_INV_OPC :
		case TRAP_SYSTEM :
			VERBOSE("%s\n", trap_descr[n])
			break;
	}
	error(1, 0, "%s: It's a TRAP (%d)!  PC=%07o", modp->id.name, n, gs_PC);
}


// le_decode()
// Print an opcode and its arguments at PC counter "pc"
//
void le_decode(mod_entry_t *mod, uint16_t pc)
{
    uint16_t a1 = 0;
    uint8_t b1 = 0;
	FILE *ofd = stdout;

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
        "  %07o  %03o  %c%c%c%c", 
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
	FILE *ofd = stdout;

	OUT("%s: S=x%04x, L=x%04x, ES=x%04x", 
		mod->id.name, 
		gs_S, gs_L, gs_SP
	)

	// Display stack
	for (uint8_t i = 0; i < gs_S; i ++)
	{
		if (i % 8 == 0)
			OUT("\nSTK:")
		OUT("  %02d: %04X", i, stack[i])
	}

	// Display expression stack
	for (uint8_t i = 0; i < gs_SP; i ++)
	{
		if (i % 8 == 0)
			OUT("\nES: ")
		OUT("  %02d: %04X", i, (*mem_exstack)[i])
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
			trace = true;
		}
		else
		{
			// Not at breakpoint; continue execution
			return;
		}
	}
	
	// Return if trace mode disabled
	if (! trace) return;

	// Decode current instruction
	le_decode(mod, gs_PC);
	if (show_regs)
		le_show_registers(mod);

	// Enter command loop
	printf("cmd> ");
	while (! quit) {
		switch (getchar())
		{
			case '\n' :
				// Ignore EOL
				continue;

			case 'r' :
				// Switch register display on/off
				show_regs = ! show_regs;
				VERBOSE("Register display now %s\n", show_regs ? "ON" : "OFF")
				break;

			case 'd' : {
				// Show contents of data word
				uint16_t w;
				scanf("%hd", &w);
				VERBOSE("data[%d]=x%04x\n", w, mod->data[w]);
				break;
			}

			case 'b' : {
				// Set breakpoint
				scanf("%hhd:%ho", &bp_module, &bp_PC);
				VERBOSE(
					"Breakpoint set to %s:%07o\n", 
					module_tab[bp_module].id.name, bp_PC
				);
				breakpoint = true;
				break;
			}

			case 'g' :
				// Execute until next breakpoint or end of program
				trace = false;
				quit = true;
				continue;

			case 'h' :
			case '?' :
				// Built-in help
				le_monitor_usage();
				break;

			case 't' :
				// Do nothing (step one instruction)
				quit = true;
				break;

			case 'q' :
				// Exit
				exit(0);

			default :
				continue;
		}
		printf("cmd> ");
	}
}