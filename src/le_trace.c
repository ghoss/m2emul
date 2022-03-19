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

#include "le_trace.h"


// Output shorthand
#define OUT(...)		fprintf(ofd, __VA_ARGS__);


// M-Code mnemonics table
//
#define LE_MNEM_LEN  5

char *mnem_tab = 
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


// le_decode()
// Print an opcode and its arguments at PC counter "pc"
//
void le_decode(mod_entry_t *mod, uint16_t pc)
{
    uint16_t a1;
    uint8_t b1;
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
        case 034 ... 035 :
            // JPB, JPBC
            OUT("\t<-[%o]", pc - (int16_t) a1)
            break;
            
        case 030 ... 033 :
        case 036 ... 037 :
            // Forward jumps
            OUT( "\t->[%o]", pc + (int16_t) a1)
            break;

        case 0300 :
            // FOR1
            OUT( 
                "\t->[%o] %s",
                pc + (int8_t) (a1 & 0xff) - 3,
                (b1 == 0) ? "UP" : "DN"
            )
            break;

        case 0301 :
            // FOR2
            OUT( 
                "\t->[%o]",
                pc + (int8_t) (a1 & 0xff) - 3
            )
            break;

		case 0355 :
			// CLX
			OUT("\t; ->%s.%d", find_mod_index(a1)->id.name, b1)
			break;
    }
    OUT("\n")
}