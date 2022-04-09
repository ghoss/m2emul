//=====================================================
// le_stack.h
// Stack and Expression Stack Functions
// 
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#ifndef _LE_STACK_H
#define _LE_STACK_H   1

// Expression stack
#define MACH_EXSMEM_SZ	15		// Expression stack size in words

// Memory for expression stack
extern uint16_t *exs_mem;
extern uint8_t gs_SP;		// Expression stack pointer

// Helper type to bytecast floats <-> (double) words
//
typedef struct {
    union {
        float f;		// Float representation
        uint32_t l;		// 32-bit long representation
        uint16_t w[2];	// High/low 16-bit word representation
		struct			// IEEE 754 bitfield representation
		{
			uint32_t m:23;	// Mantissa
			uint32_t e:8;	// Exponent
			uint32_t s:1;	// Sign
		} bf __attribute__((packed));
    };
} floatword_t;

// Function declarations
//
void es_init();
uint16_t es_stack(uint8_t i);
void es_save_regs();
void es_restore_regs(bool chg_mask);
void es_push(uint16_t x);
uint16_t es_pop();
void es_dpush(floatword_t d);
floatword_t es_dpop();
void es_save();
void es_restore();
void stk_mark(uint16_t x, bool ext);

#endif