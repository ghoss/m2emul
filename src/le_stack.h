//=====================================================
// le_stack.h
// Expression Stack Functions
// 
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#ifndef _LE_STACK_H
#define _LE_STACK_H   1

// Helper type to bytecast floats <-> (double) words
//
typedef struct {
    union {
        float f;
        uint32_t l;
        uint16_t w[2];
    };
} floatword_t;

// Function declarations
//
void es_save_regs();
void es_restore_regs(bool chg_mask);
void es_push(uint16_t x);
uint16_t es_pop();
void es_dpush(floatword_t d);
floatword_t es_dpop();
void es_save();
void es_restore();
void es_mark(uint16_t x, bool ext);

#endif