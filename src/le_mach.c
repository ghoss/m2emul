//=====================================================
// le_mach.c
// M-Code Machine Definitions and Memory Structures
// 
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#include "le_mach.h"


// Memory structures defined in le_machine.h
//
mach_stack_t *mem_stack;
mach_exstack_t *mem_exstack;

uint16_t gs_PC;
uint16_t gs_IR;
uint16_t gs_F;
uint16_t gs_G;
uint16_t gs_H;
uint16_t gs_L;
uint16_t gs_S;
uint16_t gs_P;
uint16_t gs_M;
uint8_t gs_SP;
bool gs_REQ;
uint16_t gs_ReqNo;


// mach_init()
// Initialize memory structures
//
void mach_init()
{
    // Stack memory
    if ((mem_stack = malloc(sizeof(mach_stack_t))) == NULL)
        error(1, errno, "Can't allocate stack");

    // Allocate and clear expression stack
    gs_SP = 0;
    if ((mem_exstack = malloc(sizeof(mach_exstack_t))) == NULL)
        error(1, errno, "Can't allocate expression stack");
}