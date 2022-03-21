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


// es_push()
// Push single word
//
void es_push(uint16_t x)
{
    (*mem_exstack)[gs_SP++] = x;
}


// es_pop()
// Pop single word
//
uint16_t es_pop()
{
    return (*mem_exstack)[--gs_SP];
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
        (*mem_stack)[gs_S ++] = es_pop();
        c ++;
    }
    (*mem_stack)[gs_S ++] = c;
}


// es_restore()
// Restore expression stack from stack
//
void es_restore()
{
    uint16_t c;

    c = (*mem_stack)[--gs_S];
    while (c-- > 0)
        es_push((*mem_stack)[--gs_S]);
}


// es_save_regs()
// Save registers to stack
//
void es_save_regs()
{
    es_save();
    (*mem_stack)[gs_P] = gs_G;
    (*mem_stack)[gs_P + 1] = gs_L;
    (*mem_stack)[gs_P + 2] = gs_PC;
    (*mem_stack)[gs_P + 3] = gs_M;
    (*mem_stack)[gs_P + 4] = gs_S;
    (*mem_stack)[gs_P + 5] = gs_H + 24;
}


// es_restore_regs()
// Restore registers from stack
//
void es_restore_regs(bool chg_mask)
{
    gs_G = (*mem_stack)[gs_P];
    gs_F = (*mem_stack)[gs_G];
    gs_L = (*mem_stack)[gs_P + 1];
    gs_PC = (*mem_stack)[gs_P + 2];

    if (chg_mask)
        gs_M = (*mem_stack)[gs_P + 3];
    
    gs_S = (*mem_stack)[gs_P + 4];
    gs_H = (*mem_stack)[gs_P + 5] - 24;
    es_restore();
}


// stk_mark()
// 
void stk_mark(uint16_t x, bool ext)
{
    uint16_t i = gs_S;

	// S + 0 = flag: 1 if external call, 0 if local call
	(*mem_stack)[i] = ext ? 1 : 0;	

	// S + 1 = previous module number or local ptr
	(*mem_stack)[i + 1] = x;

	// S + 2 = previous local proc. data ptr
	// S + 3 = previous PC
	(*mem_stack)[i + 2] = gs_L;
    (*mem_stack)[i + 3] = gs_PC;

    gs_S += 4;
    gs_L = i;
}