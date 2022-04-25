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


// stk_mark()
// 
void stk_mark(enum es_calltype_t ct, uint16_t arg)
{
    uint16_t old_S = gs_S;

	// S + 0 = previous module number or (gs_CS+0xff) for local call
	dsh_mem[old_S] =
		((ct == CALL_EXT) || (ct == CALL_FORMAL)) ? arg : (gs_CS + 0x100);

	// S + 1 = previous local proc. data ptr
	// S + 2 = previous PC
	dsh_mem[old_S + 1] = (ct == CALL_LEVEL) ? arg : gs_L;
    dsh_mem[old_S + 2] = gs_PC;

    gs_S += 4;
	gs_CS = old_S;
	gs_L = old_S;
}