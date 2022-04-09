//=====================================================
// le_stack.c
// Stack and Expression Stack Functions
// 
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#include "le_mach.h"
#include "le_stack.h"


// Memory structures defined in le_stack.h
//
uint16_t *exs_mem;
uint8_t gs_SP;


// es_init()
// Initialize expression stack
//
void es_init()
{
    gs_SP = 0;
    if ((exs_mem = calloc(MACH_EXSMEM_SZ, MACH_WORD_SZ)) == NULL)
        error(1, errno, "Can't allocate expression stack");
}


// es_stack()
// Return contents of stack position i
uint16_t es_stack(uint8_t i)
{
	return exs_mem[i];
}


// es_push()
// Push single word
//
void es_push(uint16_t x)
{
    exs_mem[gs_SP++] = x;
}


// es_pop()
// Pop single word
//
uint16_t es_pop()
{
    return exs_mem[--gs_SP];
}


// es_dpush()
// Push long as two words
//
void es_dpush(floatword_t x)
{
    es_push(x.w[1]);
    es_push(x.w[0]);
}


// es_dpop()
// Pop two words as long
//
floatword_t es_dpop()
{
    floatword_t x;

    x.w[0] = es_pop();
    x.w[1] = es_pop();
    return x;
}


// es_empty()
// Return TRUE if stack is empty
//
bool es_empty()
{
    return (gs_SP == 0);
}


// es_save()
// Save expression stack to stack
//
void es_save()
{
    uint16_t c;

    c = 0;
    while (! es_empty())
    {
        dsh_mem[gs_S ++] = es_pop();
        c ++;
    }
    dsh_mem[gs_S ++] = c;
}


// es_restore()
// Restore expression stack from stack
//
void es_restore()
{
    uint16_t c;

    c = dsh_mem[--gs_S];
    while (c-- > 0)
        es_push(dsh_mem[--gs_S]);
}


// es_save_regs()
// Save registers to stack
//
void es_save_regs()
{
	error(1, 0, "save_regs not implemented yet");
    // es_save();
    // stack[gs_P] = gs_G;
    // stack[gs_P + 1] = gs_L;
    // stack[gs_P + 2] = gs_PC;
    // stack[gs_P + 3] = gs_M;
    // stack[gs_P + 4] = gs_S;
    // stack[gs_P + 5] = gs_H + 24;
}


// es_restore_regs()
// Restore registers from stack
//
void es_restore_regs(bool chg_mask)
{
	error(1, 0, "restore_regs not implemented yet");
    // gs_G = stack[gs_P];
    // gs_F = stack[gs_G];
    // gs_L = stack[gs_P + 1];
    // gs_PC = stack[gs_P + 2];

    // if (chg_mask)
    //     gs_M = stack[gs_P + 3];
    
    // gs_S = stack[gs_P + 4];
    // gs_H = stack[gs_P + 5] - 24;
    // es_restore();
}


// stk_mark()
// 
void stk_mark(uint16_t x, bool ext)
{
    uint16_t i = gs_S;

	// S + 0 = previous module number + high bit set or zero for local call
	dsh_mem[i] = ext ? (x | 0xff00) : x;

	// S + 1 = previous local proc. data ptr
	// S + 2 = previous PC
	dsh_mem[i + 1] = gs_L;
    dsh_mem[i + 2] = gs_PC;

    gs_S += 4;
    gs_L = i;
}