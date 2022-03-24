//=====================================================
// le_mcode.c
// M-Code Interpreter
// 
// Lilith M-Code Emulator
//
// Guido Hoss, 12.03.2022
//
// Published by Guido Hoss under GNU Public License V3.
//=====================================================

#include <string.h>
#include "le_mach.h"
#include "le_stack.h"
#include "le_io.h"
#include "le_trace.h"
#include "le_syscall.h"
#include "le_mcode.h"

#define _HALT	{ gs_PC --; error(1, 0, "Halted in %s:%07o at opcode %03o", modp->id.name, gs_PC, gs_IR); }


// le_transfer()
//
void le_transfer(bool chg, uint16_t to, uint16_t from)
{
	uint16_t j;

	j = dsh_mem[gs_S + to];
	es_save_regs();
	dsh_mem[gs_S + from] = gs_P;
	gs_P = j;
	es_restore_regs(chg);
}


// le_interpret()
// Main interpreter loop
// Executes specified module and procedure
//
uint32_t le_execute(uint16_t modn, uint16_t procn)
{
	mod_entry_t *modp;	// Pointer to current module
	uint8_t *code_p;	// Pointer to module code frame
	uint32_t counter = 0;	// M-code counter

	// le_next()
	// Fetch next instruction
	//
	uint8_t le_next()
	{
		return (uint8_t) code_p[gs_PC ++];
	}

	// le_next2()
	// Fetch next two instructions
	//
	uint16_t le_next2()
	{
		uint16_t w = le_next();
		w = (w << 8) | le_next();
		return w;
	}

	// set_module_ptr
	// Set code and data pointers to specified module index
	//
	void set_module_ptr(uint16_t mod)
	{
		modn = mod;
		modp = &(module_tab[mod]);
		code_p = modp->code;
		gs_G = modp->data_ofs;
	}
	
	// Set stack to first location above data frames
	// and clear first 3 bytes to allow RTN from main module (#1)
	gs_PC = gs_L = 0;
	gs_M = 0;
	gs_S = data_top;
	stk_mark(0, false);

	// Setup registers and go
	set_module_ptr(modn);
	gs_PC = modp->proc[procn];

	// gs_P = stack[4];
	// es_restore_regs(true);

	do {
		// Check for code overrun
		if (gs_PC >= modp->code_sz)
			le_trap(modp, TRAP_CODE_OVF);

		// Interrupt handling
		if (gs_REQ)
		{
			_HALT
			le_transfer(true, 2 * gs_ReqNo, 2 * gs_ReqNo + 1);
		}

		// Enter monitor
		le_monitor(modp);

		// Get next instruction
		gs_IR = le_next();
		counter ++;

		// Execute M-Code in IR
		switch (gs_IR)
		{
		case 000 ... 017:
			// LI0 - LI15 load immediate
			es_push(gs_IR & 0xf);
			break;

		case 020 :
			// LIB  load immediate byte
			es_push(le_next());
			break;

		case 022 :
			// LIW  load immediate word
			es_push(le_next2());
			break;

		case 023 :
			// LID  load immediate double word
			es_push(le_next2());
			es_push(le_next2());
			break;

		case 024 :
			// LLA  load local address
			es_push(gs_L + le_next());
			break;

		case 025 :
			// LGA  load global address
			es_push(gs_G + le_next());
			break;

		case 026 :
			// LSA  load stack address
			es_push(es_pop() + le_next());
			break;

		case 027 : {
			// LEA  load external address
			_HALT
			uint16_t ext_mod = le_next();		// Module number
			uint16_t ext_adr = le_next();		// Data word offset number
			es_push(module_tab[ext_mod].data_ofs + ext_adr);
			break;
		}

		case 030 :
			// JPC  jump conditional
			if (es_pop() == 0)
			{
				uint16_t i = le_next2();
				gs_PC += i - 2;
			}
			else
			{
				gs_PC += 2;
			}
			break;

		case 031 : {
			// JP   jump
			uint16_t i = le_next2();
			gs_PC += i - 2;
			break;
		}

		case 032 :
			// JPFC  jump forward conditional
			if (es_pop() == 0)
			{
				uint8_t i = le_next();
				gs_PC += i - 1;
			}
			else
			{
				gs_PC ++;
			}
			break;

		case 033 : {
			// JPF  jump forward
			uint16_t i = le_next();
			gs_PC += i - 1;
			break;
		}

		case 034 :
			// JPBC  jump backward conditional
			if (es_pop() == 0)
			{
				uint8_t i = le_next();
				gs_PC -= i + 1;
			}
			else
			{
				gs_PC ++;
			}
			break;

		case 035 : {
			// JPB  jump backward
			uint8_t i = le_next();
			gs_PC -= i + 1;
			break;
		}

		case 036 :
			// ORJP  short circuit OR
			if (es_pop() == 0)
			{
				gs_PC ++;
			}
			else
			{
				es_push(1);
				uint8_t i = le_next();
				gs_PC += i - 1;
			}
			break;

		case 037 :
			// ANDJP  short circuit AND
			if (es_pop() == 0)
			{
				es_push(0);
				uint8_t i = le_next();
				gs_PC += i - 1;
			}
			else
			{
				gs_PC ++;
			}
			break;

		case 040 :
			// LLW  load local word
			es_push(dsh_mem[gs_L + le_next()]);
			break;

		case 041 : {
			// LLD  load local double word
			uint16_t i = gs_L + le_next();
			es_push(dsh_mem[i]);
			es_push(dsh_mem[i + 1]);
			break;
		}

		case 042 : {
			// LEW  load external word
			uint8_t ext_mod = le_next();		// Module number
			uint8_t ext_adr = le_next();		// Data word offset
			es_push(dsh_mem[module_tab[ext_mod].data_ofs + ext_adr]);
			break;
		}

		case 043 : {
			// LED
			_HALT
			uint8_t ext_mod = le_next();		// Module number
			uint8_t ext_adr = le_next();		// Data word offset
			uint16_t ofs = module_tab[ext_mod].data_ofs + ext_adr;
			es_push(dsh_mem[ofs]);
			es_push(dsh_mem[ofs + 1]);
			break;
		}

		case 044 ... 057 :
			// LLW4-LLW15
			es_push(dsh_mem[gs_L + (gs_IR & 0xf)]);
			break;

		case 060 :
			// SLW  store local word
			dsh_mem[gs_L + le_next()] = es_pop();
			break;

		case 061 : {
			// SLD  store local double word
			uint16_t i = gs_L + le_next();
			dsh_mem[i + 1] = es_pop();
			dsh_mem[i] = es_pop();
			break;
		}

		case 062 : {
			// SEW  store external word
			_HALT
			uint8_t ext_mod = le_next();		// Module number
			uint8_t ext_adr = le_next();		// Data word offset
			dsh_mem[module_tab[ext_mod].data_ofs + ext_adr] = es_pop();
			break;
		}

		case 063 : {
			// SED  store external double word
			_HALT
			uint8_t ext_mod = le_next();		// Module number
			uint8_t ext_adr = le_next();		// Data word offset
			uint16_t ofs = module_tab[ext_mod].data_ofs + ext_adr;
			dsh_mem[ofs + 1] = es_pop();
			dsh_mem[ofs] = es_pop();
			break;
		}

		case 064 ... 077 :
			// SLW4-SLW15  store local word
			dsh_mem[gs_L + (gs_IR & 0xf)] = es_pop();
			break;

		case 0100 :
			// LGW  load global word
			es_push(dsh_mem[gs_G + le_next()]);
			break;

		case 0101 : {
			// LGD  load global double word
			uint8_t i = gs_G + le_next();
			es_push(dsh_mem[i]);
			es_push(dsh_mem[i + 1]);
			break;
		}

		case 0102 ... 0117 :
			// LGW2 - LGW15  load global word
			es_push(dsh_mem[gs_G + (gs_IR & 0xf)]);
			break;

		case 0120 :
			// SGW  store global word
			dsh_mem[gs_G + le_next()] = es_pop();
			break;

		case 0121 : {
			// SGD  store global double word
			uint16_t i = gs_G + le_next();
			dsh_mem[i + 1] = es_pop();
			dsh_mem[i] = es_pop();
			break;
		}

		case 0122 ... 0137 :
			// SGW2 - SGW15  store global word
			dsh_mem[gs_G + (gs_IR & 0xf)] = es_pop();
			break;

		case 0140 ... 0157 :
			// LSW0 - LSW15  load stack addressed word
			es_push(dsh_mem[es_pop() + (gs_IR & 0xf)]);
			break;

		case 0160 ... 0177 : {
			// SSW0 - SSW15  store stack-addressed word
			uint16_t k = es_pop();
			uint16_t i = es_pop() + (gs_IR & 0xf);
			dsh_mem[i] = k;
			break;
		}

		case 0200 : {
			// LSW  load stack word
			_HALT
			uint16_t i = es_pop() + le_next();
			es_push(dsh_mem[i]);
			break;
		}

		case 0201 : {
			// LSD  load stack double word
			_HALT
			uint16_t i = es_pop() + le_next();
			es_push(dsh_mem[i]);
			es_push(dsh_mem[i + 1]);
			break;
		}

		case 0202 : {
			// LSD0  load stack double word
			_HALT
			uint16_t i = es_pop();
			es_push(dsh_mem[i]);
			es_push(dsh_mem[i + 1]);
			break;
		}

		case 0203 : {
			// LXFW  load indexed frame word
			_HALT
			uint16_t i = es_pop();
			i += es_pop() << 2;
			es_push(dsh_mem[i]);
			break;
		}

		case 0204 :
			// LSTA  load string address
			es_push(dsh_mem[gs_G + 2] + le_next());
			break;

		case 0205 : {
			// LXB  load indexed byte
			uint16_t i = es_pop();
			uint16_t j = es_pop();
			uint16_t k = dsh_mem[j + (i >> 1)];
			es_push((i & 1) ? (uint8_t) k : (k >> 8));
			break;
		}

		case 0206 : {
			// LXW  load indexed word
			uint16_t i = es_pop();
			es_push(dsh_mem[i + es_pop()]);
			break;
		}

		case 0207 : {
			// LXD  load indexed double word
			_HALT
			uint16_t i = es_pop() << 1;
			i += gs_S + es_pop();
			es_push(dsh_mem[i]);
			es_push(dsh_mem[i + 1]);
			break;
		}

		case 0210 : {
			// DADD  double add
			_HALT
			floatword_t z;
			z.l = es_dpop().l;
			z.l += es_dpop().l;
			es_dpush(z);
			break;
		}

		case 0211 : {
			// DSUB  double subtract
			_HALT
			floatword_t z;
			z.l = es_dpop().l;
			z.l -= es_dpop().l;
			es_dpush(z);
			break;
		}

		case 0212 : {
			// DMUL  double multiply
			_HALT
			floatword_t z;
			z.l = es_dpop().l;
			z.l *= es_dpop().l;
			es_dpush(z);
			break;
		}

		case 0213 : {
			// DDIV  double divide
			_HALT
			uint32_t j = es_pop();
			floatword_t x = es_dpop();
			es_push(x.l % j);
			es_push(x.l / j);
			break;
		}

		case 0216 : {
			// DSHL  double shift left
			_HALT
			floatword_t x = es_dpop();
			x.l <<= 1;
			es_dpush(x);
			break;
		}

		case 0217 : {
			// DSHR  double shift right
			_HALT
			floatword_t x = es_dpop();
			x.l >>= 1;
			es_dpush(x);
			break;
		}

		case 0220 : {
			// SSW  store stack word
			_HALT
			uint16_t k = es_pop();
			uint16_t i = es_pop() + le_next();
			dsh_mem[gs_S + i] = k;
			break;
		}

		case 0221 : {
			// SSD  store stack double word
			_HALT
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = gs_S + es_pop() + le_next();
			dsh_mem[i] = j;
			dsh_mem[i + 1] = k;
			break;
		}

		case 0222 : {
			// SSD0  store stack double word
			_HALT
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = gs_S + es_pop();
			dsh_mem[i] = j;
			dsh_mem[i + 1] = k;
			break;
		}

		case 0223 : {
			// SXFW  store indexed frame word
			_HALT
			uint16_t i = es_pop();
			uint16_t k = es_pop();
			k += es_pop() << 2;
			dsh_mem[gs_S + k] = i;
			break;
		}

		case 0224 : {
			// TS  test and set
			uint16_t adr = gs_G + es_pop();
			es_push(dsh_mem[adr]);
			dsh_mem[adr] = 1;
			break;
		}

		case 0225 : {
			// SXB  store indxed byte
			_HALT
			uint16_t k = es_pop();
			uint16_t i = es_pop();
			uint16_t j = gs_S + es_pop() + (i >> 1);
			if (i & 1)
			{
				dsh_mem[j] = (dsh_mem[j] & 0xff00) + k;
			}
			else{
				dsh_mem[j] = (k << 8) | (uint8_t) dsh_mem[j];
			}
			break;
		}

		case 0226 : {
			// SXW  store indexed word
			uint16_t k = es_pop();
			uint16_t i = es_pop();
			dsh_mem[i + es_pop()] = k;
			break;
		}

		case 0227 : {
			// SXD  store indexed double word
			_HALT
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = es_pop() << 2;
			i += gs_S + es_pop();
			dsh_mem[i] = j;
			dsh_mem[i + 1] = k;
			break;
		}

		case 0230 : {
			// FADD  floating add
			floatword_t y = es_dpop();
			floatword_t x = es_dpop();
			x.f += y.f;
			es_dpush(x);
			break;
		}

		case 0231 : {
			// FSUB  floating subtract
			floatword_t y = es_dpop();
			floatword_t x = es_dpop();
			x.f -= y.f;
			es_dpush(x);
			break;
		}

		case 0232 : {
			// FMUL  floating multiply
			floatword_t y = es_dpop();
			floatword_t x = es_dpop();
			x.f *= y.f;
			x.bf.e -= 2;	// 4x*4y=16xy, so divide by 4 to fix result
			es_dpush(x);
			break;
		}

		case 0233 : {
			// FDIV  floating divide
			floatword_t y = es_dpop();
			floatword_t x = es_dpop();
			x.f /= y.f;
			x.bf.e += 2;	// 4x/4y=xy, so multiply by 4 to fix result
			es_dpush(x);
			break;
		}

		case 0234 : {
			// FCMP  floating compare
			float x = es_dpop().f;
			float y = es_dpop().f;
			if (x > y)
			{
				es_push(0);
				es_push(1);		
			}
			else if (x < y)
			{
				es_push(1);
				es_push(0);		
			}
			else{
				es_push(0);
				es_push(0);		
			}
			break;
		}

		case 0235 : {
			// FABS  floating absolute value
			floatword_t x = es_dpop();
			if (x.f < 0.0) 
				x.f = -x.f;
			es_dpush(x);
			break;
		}

		case 0236 : {
			// FNEG  floating negative
			floatword_t x = es_dpop();
			x.f = -x.f;
			es_dpush(x);
			break;
		}

		case 0237 : {
			// FFCT  floating functions
			uint8_t i = le_next();
			floatword_t z;
			switch (i)
			{
				case 0 :
					// Convert INTEGER to REAL
					// Multiply result by 4 to fix to IEEE754 standard
					z.f = (float) es_pop();
					z.bf.e += 2;
					es_dpush(z);
					break;

				case 1 :
					// CONVERT REAL TO REAL (?)
					es_dpush(es_dpop());
					break;

				case 2 :
					// Convert REAL to INTEGER
					// Divide value by 4 to fix to IEEE754 standard
					z = es_dpop();
					z.bf.e -= 2;
					es_push((int16_t) z.f);
					break;

				default :
					le_trap(modp, TRAP_INV_FFCT);
					break;
			}
			break;
		}

		case 0240 : {
			// READ
			uint16_t i = es_pop();
			uint16_t k = es_pop();
			dsh_mem[i] = le_ioread(k);
			break;
		}

		case 0241 : {
			// WRITE
			_HALT
			uint16_t i = es_pop();
			uint16_t k = es_pop();
			le_iowrite(k, i);
			break;
		}

		case 0242 :
			// DSKR  disk read
			error (1, 0, "DSKR not implemented");
			break;

		case 0243 :
			// DSKW  disk write
			error (1, 0, "DSKW not implemented");
			break;

		case 0244 :
			// SETRK  set disk track
			error (1, 0, "SETRK not implemented");
			break;

		case 0245 : {
			// UCHK
			_HALT
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push(i);
			if ((i < j) || (i > k))
				le_trap(modp, TRAP_INDEX);
			break;
		}

		case 0246 :
			// SVC  system hook (emulator only)
			le_supervisor_call();
			break;

		case 0247 :
			// SYS  rarely used system functions
			le_system_call(le_next());
			break;

		case 0250 :
			// ENTP  entry priority
			dsh_mem[gs_L + 3] = gs_M;
			gs_M = 0xffff << (16 - le_next());
			break;

		case 0251 :
			// EXP  exit priority
			gs_M = dsh_mem[gs_L + 3];
			break;

		case 0252 : {
			// ULSS
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push((i < j) ? 1 : 0);
			break;
		}

		case 0253 : {
			// ULEQ
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push((i <= j) ? 1 : 0);
			break;
		}

		case 0254 : {
			// UGTR
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push((i > j) ? 1 : 0);
			break;
		}

		case 0255 : {
			// UGEQ
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push((i >= j) ? 1 : 0);
			break;
		}

		case 0256 : {
			// TRA  coroutine transfer
			_HALT
			uint16_t i = es_pop();
			uint16_t j = es_pop();
			le_transfer((le_next() != 0), i, j);
			break;
		}

		case 0257 : {
			// RDS  read string
			_HALT
			uint16_t k = gs_S + es_pop();
			int8_t i = le_next();
			do {
				dsh_mem[k++] = le_next2();
			} while (i-- >= 0);
			break;
		}

		case 0260 : {
			// LODFW  reload stack after function return
			uint16_t i = es_pop();
			es_restore();
			es_push(i);
			break;
		}

		case 0261 :
			// LODFD  reload stack after function return
			_HALT
			uint16_t i = es_pop();
			uint16_t j = es_pop();
			es_restore();
			es_push(j);
			es_push(i);
			break;

		case 0262 :
			// STORE
			es_save();
			break;

		case 0263 : {
			// STOFV
			_HALT
			uint16_t i = es_pop();
			es_save();
			dsh_mem[gs_S ++] = i;
			break;
		}

		case 0264 :
			// STOT  copy from stack to procedure stack
			dsh_mem[gs_S ++] = es_pop();
			break;

		case 0265 : {
			// COPT  copy element on top of expression stack
			uint16_t i = es_pop();
			es_push(i);
			es_push(i);
			break;
		}

		case 0266 :
			// DECS  decrement stackpointer
			gs_S --;
			break;

		case 0267 : {
			// PCOP  allocation and copy of value parameter
			dsh_mem[gs_L + le_next()] = gs_S;
			uint16_t sz = es_pop();
			uint16_t adr = es_pop();

			// Copy words from memory into stack
			while (sz-- > 0)
				dsh_mem[gs_S ++] = dsh_mem[adr ++];
			break;
		}

		case 0270 : {
			// UADD
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			int32_t z = i + j;
			if (z > UINT16_MAX)
				le_trap(modp, TRAP_INT_ARITH);
			es_push(z);
			break;
		}

		case 0271 : {
			// USUB
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			if (i < j)
				le_trap(modp, TRAP_INT_ARITH);
			es_push(i - j);
			break;
		}

		case 0272 : {
			// UMUL
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			int32_t z = i * j;
			if (z > UINT16_MAX)
				le_trap(modp, TRAP_INT_ARITH);
			es_push(z);
			break;
		}

		case 0273 : {
			// UDIV
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push(i / j);
			break;
		}

		case 0274 : {
			// UMOD
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push(i % j);
			break;
		}

		case 0275 : {
			// ROR
			_HALT
			uint16_t i = es_pop() & 0xf;
			uint16_t j = es_pop();
			uint32_t k = (j << 16) >> i;
			es_push((k >> 16) | (k & 0xffff));
			break;
		}

		case 0276 : {
			// SHL
			uint16_t i = es_pop() & 0xf;
			uint16_t j = es_pop();
			es_push(j << i);
			break;
		}

		case 0277 : {
			// SHR
			uint16_t i = es_pop() & 0xf;
			uint16_t j = es_pop();
			es_push(j >> i);
			break;
		}

		case 0300 : {
			// FOR1  enter FOR statement
			uint8_t sign = le_next();
			int16_t hi = es_pop();
			int16_t low = es_pop();
			uint16_t adr = es_pop();
			uint16_t jmp = gs_PC + 2;
			jmp += (int16_t) le_next2() - 2;
			if (((sign == 0) && (low <= hi))
				|| ((sign != 0) && (low >= hi)))
			{
				dsh_mem[adr] = low;
				dsh_mem[gs_S] = adr;
				dsh_mem[gs_S + 1] = hi;
				gs_S += 2;
			}
			else
			{
				gs_PC = jmp;
			}
			break;
		}

		case 0301 : {
			// FOR2  exit FOR statement
			int16_t hi = dsh_mem[gs_S - 1];
			uint16_t adr = dsh_mem[gs_S - 2];
			int8_t step = le_next();
			uint16_t jmp = gs_PC;
			jmp += (int16_t) le_next2();
			int16_t i = dsh_mem[adr] + step;
			if (((step >= 0) && (i > hi)) || ((step <= 0) && (i < hi)))
			{
				gs_S -= 2;
			}
			else
			{
				dsh_mem[adr] = i;
				gs_PC = jmp;
			}
			break;
		}

		case 0302 : {
			// ENTC  enter CASE statement
			_HALT
			uint16_t i = le_next2();
			gs_PC += i - 2;
			uint16_t k = es_pop();
			uint16_t low = le_next2();
			uint16_t hi = le_next2();
			dsh_mem[gs_S++] = gs_PC + ((hi - low) << 1) + 4;
			if ((k >= low) && (k <= hi))
				gs_PC += (k - low + 1) << 1;
			i = le_next2();
			gs_PC += i - 2;
			break;
		}

		case 0303 :
			// EXC  exit CASE statement
			_HALT
			gs_PC = dsh_mem[--gs_S];
			break;

		case 0304 : {
			// TRAP
			le_trap(modp, es_pop());
			break;
		}

		case 0305 : {
			// CHK
			int16_t hi = es_pop();
			int16_t lo = es_pop();
			int16_t i = es_pop();
			es_push(i);
			if ((i < lo) || (i > hi))
				le_trap(modp, TRAP_INDEX);
			break;
		}

		case 0306 : {
			// CHKZ
			int16_t hi = es_pop();
			int16_t i = es_pop();
			es_push(i);
			if ((i < 0) || (i > hi))
				le_trap(modp, TRAP_INDEX);
			break;
		}

		case 0307 :
			// CHKS  check sign bit
			int16_t k = es_pop();
			es_push(k);
			if (k < 0)
				le_trap(modp, TRAP_INDEX);
			break;

		case 0310 : {
			// EQL
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push((i == j) ? 1 : 0);
			break;
		}

		case 0311 : {
			// NEQ
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push((i != j) ? 1 : 0);
			break;
		}

		case 0312 : {
			// LSS
			int16_t j = es_pop();
			int16_t i = es_pop();
			es_push((i < j) ? 1 : 0);
			break;
		}

		case 0313 : {
			// LEQ
			int16_t j = es_pop();
			int16_t i = es_pop();
			es_push((i <= j) ? 1 : 0);
			break;
		}

		case 0314 : {
			// GTR
			int16_t j = es_pop();
			int16_t i = es_pop();
			es_push((i > j) ? 1 : 0);
			break;
		}

		case 0315 : {
			// GEQ
			int16_t j = es_pop();
			int16_t i = es_pop();
			es_push((i >= j) ? 1 : 0);
			break;
		}

		case 0316 : {
			// ABS
			int16_t i = es_pop();
			es_push((i < 0) ? (-i) : i);
			break;
		}

		case 0317 : {
			// NEG
			int16_t i = es_pop();
			es_push(-i);
			break;
		}

		case 0320 : {
			// OR
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push(i | j);
			break;
		}

		case 0321 : {
			// XOR
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push(i ^ j);
			break;
		}

		case 0322 : {
			// AND
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push(i & j);
			break;
		}

		case 0323 :
			// COM
			es_push(~es_pop());
			break;

		case 0324 : {
			// IN
			_HALT
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			if (i > 15)
				es_push(0);
			else
				es_push(((0x8000 >> i) & j) ? 1 : 0);
			break;
		}

		case 0325 :
			// LIN  load immediate NIL
			es_push(0xffff);
			break;

		case 0326 : {
			// MSK
			_HALT
			uint16_t i = es_pop() & 0xf;
			es_push( 0xffff << (i - 16) );
			break;
		}

		case 0327 :
			// NOT
			es_push((es_pop() & 1) ? 0 : 1);
			break;

		case 0330 : {
			// IADD
			int16_t j = es_pop();
			int16_t i = es_pop();
			int32_t z = i + j;
			if (z > INT16_MAX)
				le_trap(modp, TRAP_INT_ARITH);
			es_push(z);
			break;
		}

		case 0331 : {
			// ISUB
			int16_t j = es_pop();
			int16_t i = es_pop();
			int32_t z = i - j;
			if (z < INT16_MIN)
				le_trap(modp, TRAP_INT_ARITH);
			es_push(z);
			break;
		}

		case 0332 : {
			// IMUL
			int16_t j = es_pop();
			int16_t i = es_pop();
			int32_t z = i * j;
			if ((z < INT16_MIN) || (z > INT16_MAX))
				le_trap(modp, TRAP_INT_ARITH);
			es_push(z);
			break;
		}

		case 0333 : {
			// IDIV
			int16_t j = es_pop();
			int16_t i = es_pop();
			es_push(i / j);
			break;
		}

		case 0334 : {
			// MOD
			int16_t j = es_pop();
			int16_t i = es_pop();
			es_push(i % j);
			break;
		}

		case 0335 : {
			// BIT
			_HALT
			uint16_t j = es_pop() & 0xf;
			es_push(0x8000 >> j);
			break;
		}

		case 0336 :
			// NOP
			break;

		case 0337 : {
			// MOVF  move frame
			uint16_t i = es_pop();
			uint16_t j = es_pop();
			j += es_pop() << 2;
			uint16_t k = es_pop();
			k += es_pop() << 2;
			VERBOSE("MOVF ignored (%06X <- %06X for %d bytes)\n", k, j, i)
			// while (i-- > 0)
			// 	dsh_mem[k ++] = dsh_mem[j ++];
			break;
		}

		case 0340 : {
			// MOV  move block
			_HALT
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			while (k-- > 0)
				dsh_mem[i ++] = dsh_mem[j ++];
			break;
		}

		case 0341 : {
			// CMP  compare blocks
			_HALT
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			if (k == 0)
			{
				es_push(0);
				es_push(0);
			}
			else
			{
				while ((dsh_mem[i] != dsh_mem[j]) && (k > 0))
				{
					i ++; j++; k--;
				}
				es_push(dsh_mem[i]);
				es_push(dsh_mem[j]);
			}
			break;
		}

		case 0342 : {
			// DDT  display dot
//          (* display point at <j,k> in mode i inside
//             bitmap dbmd *) |
			_HALT
			// uint16_t k = es_pop();
			// uint16_t j = es_pop();
			// uint16_t dbmd = es_pop();
			// uint16_t i = es_pop();
			break;
		}

		case 0343 : {
			// REPL  replicate pattern
//          (* replicate pattern sb over block db inside
//             bitmap dbmd in mode i *) |
			_HALT
			// uint16_t db = es_pop();
			// uint16_t sb = es_pop();
			// uint16_t dbmd = es_pop();
			// uint16_t i = es_pop();
			break;
		}

		case 0344 : {
			// BBLT  bit block transfer
//          (* transfer block sb in bitmap sbmd to block db
//             inside bitmap dbmd in mode i *) |
			_HALT
			// uint16_t sbmd = es_pop();
			// uint16_t db = es_pop();
			// uint16_t sb = es_pop();
			// uint16_t dbmd = es_pop();
			// uint16_t i = es_pop();
			break;
		}

		case 0345 : {
			// DCH  display character
//          (* copy bit pattern for character ch from font fo
//             to block db inside bitmap dbmd *) |
			uint16_t ch = es_pop();
			// uint16_t db = es_pop();
			// uint16_t fo = es_pop();
			// uint16_t dbmd = es_pop();
			le_putchar(ch);
			break;
		}

		case 0346 : {
			// UNPK  unpack
//          (*extract bits i..j from k, then right adjust*)
			_HALT
			// uint16_t k = es_pop();
			// uint16_t j = es_pop();
			// uint16_t i = es_pop();
			// es_push(k);
			break;
		}

		case 0347 : {
			// PACK  pack
//          (*pack the rightmost j-i+1 bits of k into positions
//            i..j of word stk[adr] *) |
			_HALT
			// uint16_t k = es_pop();
			// uint16_t j = es_pop();
			// uint16_t i = es_pop();
			// uint16_t adr = es_pop();
			// es_push(k);
			break;
		}

		case 0350 : {
			// GB  get base adr n levels down
			_HALT
			uint16_t i = gs_L;
			uint8_t j = le_next();
			do {
				i = dsh_mem[i];
			} while (--j != 0);
			es_push(i);
			break;
		}

		case 0351 :
			// GB1  get base adr 1 level down
			_HALT
			es_push(dsh_mem[gs_L]);
			break;

		case 0352 : {
			// ALLOC  allocate block
			uint16_t i = es_pop();
			if (gs_S < gs_H - i)
			{
				es_push(gs_S);
				gs_S += i;
			}
			else
			{
				le_trap(modp, TRAP_STACK_OVF);
			}
			break;
		}

		case 0353 : {
			// ENTR  enter procedure
			uint8_t i = le_next();
			if (gs_S < gs_H - i)
				gs_S += i;
			else
				le_trap(modp, TRAP_STACK_OVF);
			break;
		}

		case 0354 : {
			// RTN  return from procedure
			// Reset stack pointer to previous state
			gs_S = gs_L;

			// Restore caller status from stack
			gs_L = dsh_mem[gs_S + 1];
			gs_PC = dsh_mem[gs_S + 2];

			uint16_t call_mod = dsh_mem[gs_S];
			if (call_mod & 0xff00)
				// Was an external call
				set_module_ptr((uint8_t) call_mod);
			break;
		}

		case 0355 : {
			// CLX  call external procedure
			uint8_t call_mod = le_next();		// Module number
			uint8_t call_proc = le_next();		// Procedure number
			if ((call_mod != 0) || (call_proc != 0))
			{
				// Ignore calls to System.0
				stk_mark(modn, true);
				set_module_ptr(call_mod);
				gs_PC = modp->proc[call_proc];
			}
			break;
		}

		case 0356 : {
			// CLI  call procedure at intermediate level
			_HALT
			uint8_t i = le_next();
			stk_mark(es_pop(), false);
			gs_PC = i << 1;
			gs_PC = le_next2();
			break;
		}

		case 0357 : {
			// CLF  call formal procedure
			_HALT
			// uint16_t i = dsh_mem[gs_S - 1];
			// stk_mark(gs_G, true);
			// uint16_t j = i >> 8;
			// gs_G = dsh_mem[MCI_DFTADR + j];
			// gs_F = dsh_mem[gs_G];
			// gs_PC = (i & 0xff) << 1;
			// gs_PC = le_next2();
			break;
		}

		case 0360 : {
			// CLL  call local procedure
			uint8_t i = le_next();
			stk_mark(0, false);
			gs_PC = modp->proc[i];
			break;
		}

		case 0361 ... 0377 :
			// CLL1 - CLL15  call local procedure
			stk_mark(0, false);
			gs_PC = modp->proc[gs_IR & 0xf];
			break;

		default :
			le_trap(modp, TRAP_INV_OPC);
			break;
		}
	} while (gs_PC != 0);

	return counter;
}