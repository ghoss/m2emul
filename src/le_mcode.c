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

#include "le_mach.h"
#include "le_stack.h"
#include "le_io.h"

#define MCI_TLCADR	016		// Trap location addr
#define MCI_DFTADR	040		// Data frame table addr


// le_transfer()
//
void le_transfer(bool chg, uint16_t to, uint16_t from)
{
	uint16_t j;

	j = (*mem_stack)[to];
	es_save_regs();
	(*mem_stack)[from] = gs_P;
	gs_P = j;
	es_restore_regs(chg);
}


// le_trap()
// Trap handler
//
void le_trap(uint16_t n)
{
	error(1, 0, "It's a TRAP! (%d)", n);
	if (((1 << n) & (*mem_stack)[gs_P + 7]) == 0)
	{
		(*mem_stack)[gs_P + 6] = n;
		le_transfer(true, MCI_TLCADR, MCI_TLCADR + 1);
	}
}


// le_interpret()
// Main interpreter loop
// Executes code starting at code_p
//
void le_interpret(uint8_t *code_p)
{
	// le_next()
	// Fetch next instruction
	//
	uint16_t le_next()
	{
		gs_PC ++;
		return (uint16_t) code_p[(gs_F << 2) + (gs_PC - 1)];
	}

	// le_next2()
	// Fetch next two instructions
	//
	uint16_t le_next2()
	{
		gs_PC += 2;
		return (uint16_t) code_p[(gs_F << 2) + (gs_PC - 2)] << 8
			+ code_p[(gs_F << 2) + (gs_PC - 1)];
	}
	
	// Start interpreter loop
	gs_P = (*mem_stack)[4];
	es_restore_regs(true);

	do {
		if (gs_REQ)
			le_transfer(true, 2 * gs_ReqNo, 2 * gs_ReqNo + 1);

		gs_IR = le_next();

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
			uint16_t i = le_next();
			uint16_t j = le_next();
			es_push((*mem_stack)[MCI_DFTADR + i] + j);
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
				uint16_t i = le_next();
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
				uint16_t i = le_next();
				gs_PC -= i + 1;
			}
			else
			{
				gs_PC ++;
			}
			break;

		case 035 : {
			// JPB  jump backward
			uint16_t i = le_next();
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
				uint16_t i = le_next();
				gs_PC += i - 1;
			}
			break;

		case 037 :
			// ANDJP  short circuit AND
			if (es_pop() == 0)
			{
				es_push(0);
				uint16_t i = le_next();
				gs_PC += i - 1;
			}
			else
			{
				gs_PC ++;
			}
			break;

		case 040 :
			// LLW  load local word
			es_push((*mem_stack)[gs_L + le_next()]);
			break;

		case 041 : {
			// LLD  load local double word
			uint16_t i = gs_L + le_next();
			es_push((*mem_stack)[i]);
			es_push((*mem_stack)[i + 1]);
			break;
		}

		case 042 : {
			// LEW  load external word
			uint16_t i = le_next();
			uint16_t j = le_next();
			es_push((*mem_stack)[(*mem_stack)[MCI_DFTADR + i] + j]);
			break;
		}

		case 043 : {
			// LED
			uint16_t i = le_next();
			uint16_t j = le_next();
			uint16_t k = (*mem_stack)[MCI_DFTADR + i] + j;
			es_push((*mem_stack)[k]);
			es_push((*mem_stack)[k + 1]);
			break;
		}

		case 044 ... 057 :
			// LLW4-LLW15
			es_push((*mem_stack)[gs_L + (gs_IR & 0xf)]);
			break;

		case 060 :
			// SLW  store local word
			(*mem_stack)[gs_L + le_next()] = es_pop();
			break;

		case 061 : {
			// SLD  store local double word
			uint16_t i = gs_L + le_next();
			(*mem_stack)[i + 1] = es_pop();
			(*mem_stack)[i] = es_pop();
			break;
		}

		case 062 : {
			// SEW  store external word
			uint16_t i = le_next();
			uint16_t j = le_next();
			(*mem_stack)[(*mem_stack)[MCI_DFTADR + i] + j] = es_pop();
			break;
		}

		case 063 : {
			// SED  store external double word
			uint16_t i = le_next();
			uint16_t j = le_next();
			uint16_t k = (*mem_stack)[(*mem_stack)[MCI_DFTADR + i] + j];
			(*mem_stack)[k + 1] = es_pop();
			(*mem_stack)[k] = es_pop();
			break;
		}

		case 064 ... 077 :
			// SLW4-SLW15  store local word
			(*mem_stack)[gs_L + (gs_IR & 0xf)] = es_pop();
			break;

		case 0100 :
			// LGW  load global word
			es_push((*mem_stack)[gs_G + le_next()]);
			break;

		case 0101 : {
			// LGD  load global double word
			uint16_t i = le_next() + gs_G;
			es_push((*mem_stack)[i]);
			es_push((*mem_stack)[i + 1]);
			break;
		}

		case 0102 ... 0117 :
			// LGW2 - LGW15  load global word
			es_push((*mem_stack)[gs_G + (gs_IR & 0xf)]);
			break;

		case 0120 :
			// SGW  store global word
			(*mem_stack)[gs_G + le_next()] = es_pop();
			break;

		case 0121 : {
			// SGD  store global double word
			uint16_t i = le_next() + gs_G;
			(*mem_stack)[i + 1] = es_pop();
			(*mem_stack)[i] = es_pop();
			break;
		}

		case 0122 ... 0137 :
			// SGW2 - SGW15  store global word
			(*mem_stack)[gs_G + (gs_IR & 0xf)] = es_pop();
			break;

		case 0140 ... 0157 :
			// LSW0 - LSW15  load stack addressed word
			es_push((*mem_stack)[es_pop() + (gs_IR & 0xf)]);
			break;

		case 0160 ... 0177 : {
			// SSW0 - SSW15  store stack-addressed word
			uint16_t k = es_pop();
			uint16_t i = es_pop() + (gs_IR & 0xf);
			(*mem_stack)[i] = k;
			break;
		}

		case 0200 : {
			// LSW  load stack word
			uint16_t i = es_pop() + le_next();
			es_push((*mem_stack)[i]);
			break;
		}

		case 0201 : {
			// LSD  load stack double word
			uint16_t i = es_pop() + le_next();
			es_push((*mem_stack)[i]);
			es_push((*mem_stack)[i + 1]);
			break;
		}

		case 0202 : {
			// LSD0  load stack double word
			uint16_t i = es_pop();
			es_push((*mem_stack)[i]);
			es_push((*mem_stack)[i + 1]);
			break;
		}

		case 0203 : {
			// LXFW  load indexed frame word
			uint16_t i = es_pop();
			i += es_pop() << 2;
			es_push((*mem_stack)[i]);
			break;
		}

		case 0204 :
			// LSTA  load string address
			es_push((*mem_stack)[gs_G + 2] + le_next());
			break;

		case 0205 : {
			// LXB  load indexed byte
			uint16_t i = es_pop();
			uint16_t j = es_pop();
			uint16_t k = (*mem_stack)[j + (i >> 1)];
			es_push((i & 1) ? (k & 0xff) : (k >> 8));
			break;
		}

		case 0206 : {
			// LXW  load indexed word
			uint16_t i = es_pop();
			i += es_pop();
			es_push((*mem_stack)[i]);
			break;
		}

		case 0207 : {
			// LXD  load indexed double word
			uint16_t i = es_pop() << 1;
			i += es_pop();
			es_push((*mem_stack)[i]);
			es_push((*mem_stack)[i + 1]);
			break;
		}

		case 0210 : {
			// DADD  double add
			floatword_t z;
			z.l = es_dpop().l;
			z.l += es_dpop().l;
			es_dpush(z);
			break;
		}

		case 0211 : {
			// DSUB  double subtract
			floatword_t z;
			z.l = es_dpop().l;
			z.l -= es_dpop().l;
			es_dpush(z);
			break;
		}

		case 0212 : {
			// DMUL  double multiply
			floatword_t z;
			z.l = es_dpop().l;
			z.l *= es_dpop().l;
			es_dpush(z);
			break;
		}

		case 0213 : {
			// DDIV  double divide
			uint32_t j = es_pop();
			floatword_t x = es_dpop();
			es_push(x.l % j);
			es_push(x.l / j);
			break;
		}

		case 0216 : {
			// DSHL  double shift left
			floatword_t x = es_dpop();
			x.l <<= 1;
			es_dpush(x);
			break;
		}

		case 0217 : {
			// DSHR  double shift right
			floatword_t x = es_dpop();
			x.l >>= 1;
			es_dpush(x);
			break;
		}

		case 0220 : {
			// SSW  store stack word
			uint16_t k = es_pop();
			uint16_t i = es_pop() + le_next();
			(*mem_stack)[i] = k;
			break;
		}

		case 0221 : {
			// SSD  store stack double word
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = es_pop() + le_next();
			(*mem_stack)[i] = j;
			(*mem_stack)[i + 1] = k;
			break;
		}

		case 0222 : {
			// SSD0  store stack double word
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			(*mem_stack)[i] = j;
			(*mem_stack)[i + 1] = k;
			break;
		}

		case 0223 : {
			// SXFW  store indexed frame word
			uint16_t i = es_pop();
			uint16_t k = es_pop();
			k += es_pop() << 2;
			(*mem_stack)[k] = i;
			break;
		}

		case 0224 : {
			// TS  test and set
			uint16_t i = es_pop();
			es_push((*mem_stack)[i]);
			(*mem_stack)[i] = 1;
			break;
		}

		case 0225 : {
			// SXB  store indxed byte
			uint16_t k = es_pop();
			uint16_t i = es_pop();
			uint16_t j = es_pop() + (i >> 1);
			if (i & 1)
			{
				(*mem_stack)[j] = ((*mem_stack)[j] & 0xff00) + k;
			}
			else{
				(*mem_stack)[j] = (k << 8) | ((*mem_stack)[j] & 0xff);
			}
			break;
		}

		case 0226 : {
			// SXW  store indexed word
			uint16_t k = es_pop();
			uint16_t i = es_pop();
			i += es_pop();
			(*mem_stack)[i] = k;
			break;
		}

		case 0227 : {
			// SXD  store indexed double word
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = es_pop() << 2;
			i += es_pop();
			(*mem_stack)[i] = j;
			(*mem_stack)[i + 1] = k;
			break;
		}

		case 0230 : {
			// FADD  floating add
			floatword_t x = es_dpop();
			x.f += es_dpop().f;
			es_dpush(x);
			break;
		}

		case 0231 : {
			// FSUB  floating subtract
			floatword_t x = es_dpop();
			x.f -= es_dpop().f;
			es_dpush(x);
			break;
		}

		case 0232 : {
			// FMUL  floating multiply
			floatword_t x = es_dpop();
			x.f *= es_dpop().f;
			es_dpush(x);
			break;
		}

		case 0233 : {
			// FDIV  floating divide
			floatword_t x = es_dpop();
			x.f /= es_dpop().f;
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
			uint16_t i = le_next();
			floatword_t z;

			switch (i)
			{
				case 0 :
					z.f = (float) es_pop();
					es_dpush(z);
					break;

				case 2 :
					z = es_dpop();
					es_push((uint16_t) z.f);
					break;

				case 1 :
				case 3 :
				default :
					error(1, 0, "Invalid FFCT function (%d)", i);
					break;
			}
			break;
		}

		case 0240 : {
			// READ
			uint16_t i = es_pop();
			uint16_t k = es_pop();
			(*mem_stack)[i] = le_ioread(k);
			break;
		}

		case 0241 : {
			// WRITE
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
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push(i);
			if ((i < j) || (i > k))
				le_trap(4);
			break;
		}

		case 0246 :
			// SVC  system hook (emulator only)
			error(0, 0, "HOOK call");
			break;

		case 0247 :
			// SYS  rarely used system functions
			error (1, 0, "SYS not implemented");
			break;

		case 0250 :
			// ENTP  entry priority
			(*mem_stack)[gs_L + 3] = gs_M;
			gs_M = 0xffff << (16 - le_next());
			break;

		case 0251 :
			// EXP  exit priority
			gs_M = (*mem_stack)[gs_L + 3];
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
			uint16_t i = es_pop();
			uint16_t j = es_pop();
			le_transfer((le_next() != 0), i, j);
			break;
		}

		case 0257 : {
			// RDS  read string
			uint16_t k = es_pop();
			int i = le_next();
			do {
				(*mem_stack)[k++] = le_next2();
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
			uint16_t i = es_pop();
			es_save();
			(*mem_stack)[gs_S ++] = i;
			break;
		}

		case 0264 :
			// STOT  copy from stack to procedure stack
			(*mem_stack)[gs_S ++] = es_pop();
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
			(*mem_stack)[gs_L + le_next()] = gs_S;
			uint16_t sz = es_pop();
			uint16_t k = gs_S + sz;
			uint16_t adr = es_pop();
			while (sz-- > 0)
				(*mem_stack)[gs_S++] = (*mem_stack)[adr++];
			break;
		}

		case 0270 : {
			// UADD
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push(i + j);
			break;
		}

		case 0271 : {
			// USUB
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push(i - j);
			break;
		}

		case 0272 : {
			// UMUL
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push(i * j);
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
			uint16_t j = es_pop();
			uint16_t i = es_pop() & 0xf;
			uint32_t k = (j << 16) >> i;
			es_push((k >> 16) | (k & 0xffff));
			break;
		}

		case 0276 : {
			// SHL
			uint16_t j = es_pop();
			uint16_t i = es_pop() & 0xf;
			es_push(j << i);
			break;
		}

		case 0277 : {
			// SHR
			uint16_t j = es_pop();
			uint16_t i = es_pop() & 0xf;
			es_push(j >> i);
			break;
		}

		case 0300 : {
			// FOR1  enter FOR statement
			uint16_t i = le_next();
			uint16_t hi = es_pop();
			uint16_t low = es_pop();
			uint16_t adr = es_pop();
			uint16_t k = gs_PC;
			k += le_next2() - 2;
			if (((i == 0) && (low <= hi))
				|| ((i != 0) && (low >= hi)))
			{
				(*mem_stack)[adr] = low;
				(*mem_stack)[gs_S++] = adr;
				(*mem_stack)[gs_S++] = hi;
			}
			else
			{
				gs_PC = k;
			}
			break;
		}

		case 0301 : {
			// FOR2  exit FOR statement
			uint16_t hi = (*mem_stack)[gs_S - 1];
			uint16_t adr = (*mem_stack)[gs_S - 2];
			int16_t sz = le_next();
			uint16_t k = gs_PC;
			k += le_next2() - 2;
			uint16_t i = (*mem_stack)[adr] + sz;
			if (((sz >= 0) && (i > hi)) || ((sz <= 0) && (i < hi)))
			{
				gs_S -= 2;
			}
			else
			{
				(*mem_stack)[adr] = i;
				gs_PC = k;
			}
			break;
		}

		case 0302 : {
			// ENTC  enter CASE statement
			uint16_t i = le_next2();
			gs_PC += i - 2;
			uint16_t k = es_pop();
			uint16_t low = le_next2();
			uint16_t hi = le_next2();
			(*mem_stack)[gs_S++] = gs_PC + (hi - low) << 1 + 4;
			if ((k >= low) && (k <= hi))
				gs_PC += (k - low + 1) << 1;
			i = le_next2();
			gs_PC += i - 2;
			break;
		}

		case 0303 :
			// EXC  exit CASE statement
			gs_PC = (*mem_stack)[--gs_S];
			break;

		case 0304 : {
			// TRAP
			le_trap(es_pop());
			break;
		}

		case 0305 : {
			// CHK
			int16_t k = es_pop();
			int16_t j = es_pop();
			int16_t i = es_pop();
			es_push(i);
			if ((i < j) || (i > k))
				le_trap(4);
			break;
		}

		case 0306 : {
			// CHKZ
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push(i);
			if (i > j)
				le_trap(4);
			break;
		}

		case 0307 :
			// CHKS  check sign bit
			int16_t k = es_pop();
			es_push(k);
			if (k < 0)
				le_trap(4);
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
			uint16_t i = es_pop() & 0xf;
			es_push( 0xffff << (i - 16) );
			break;
		}

		case 0327 :
			// NOT
			es_push(~es_pop());
			break;

		case 0330 : {
			// IADD
			int16_t j = es_pop();
			int16_t i = es_pop();
			es_push(i + j);
			break;
		}

		case 0331 : {
			// ISUB
			int16_t j = es_pop();
			int16_t i = es_pop();
			es_push(i - j);
			break;
		}

		case 0332 : {
			// IMUL
			int16_t j = es_pop();
			int16_t i = es_pop();
			es_push(i * j);
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
			while (i-- > 0)
				(*mem_stack)[k++] = (*mem_stack[j++]);
			break;
		}

		case 0340 : {
			// MOV  move block
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			while (k-- > 0)
				(*mem_stack)[i ++] = (*mem_stack)[j ++];
			break;
		}

		case 0341 : {
			// CMP  compare blocks
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
				while (((*mem_stack)[i] != (*mem_stack)[j]) && (k > 0))
				{
					i ++; j++; k--;
				}
				es_push((*mem_stack)[i]);
				es_push((*mem_stack)[j]);
			}
			break;
		}

		case 0342 : {
			// DDT  display dot
//          (* display point at <j,k> in mode i inside
//             bitmap dbmd *) |
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t dbmd = es_pop();
			uint16_t i = es_pop();
			error(1, 0, "DDT not implemented");
			break;
		}

		case 0343 : {
			// REPL  replicate pattern
//          (* replicate pattern sb over block db inside
//             bitmap dbmd in mode i *) |
			uint16_t db = es_pop();
			uint16_t sb = es_pop();
			uint16_t dbmd = es_pop();
			uint16_t i = es_pop();
			error(1, 0, "REPL not implemented");
			break;
		}

		case 0344 : {
			// BBLT  bit block transfer
//          (* transfer block sb in bitmap sbmd to block db
//             inside bitmap dbmd in mode i *) |
			uint16_t sbmd = es_pop();
			uint16_t db = es_pop();
			uint16_t sb = es_pop();
			uint16_t dbmd = es_pop();
			uint16_t i = es_pop();
			error(1, 0, "BBLT not implemented");
			break;
		}

		case 0345 : {
			// DCH  display character
//          (* copy bit pattern for character j from font fo
//             to block db inside bitmap dbmd *) |
			uint16_t j = es_pop();
			uint16_t db = es_pop();
			uint16_t fo = es_pop();
			uint16_t dbmd = es_pop();
			error(1, 0, "DCH not implemented");
			break;
		}

		case 0346 : {
			// UNPK  unpack
//          (*extract bits i..j from k, then right adjust*)
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			es_push(k);
			error(1, 0, "UNPK not implemented");
			break;
		}

		case 0347 : {
			// PACK  pack
//          (*pack the rightmost j-i+1 bits of k into positions
//            i..j of word stk[adr] *) |
			uint16_t k = es_pop();
			uint16_t j = es_pop();
			uint16_t i = es_pop();
			uint16_t adr = es_pop();
			es_push(k);
			error(1, 0, "PACK not implemented");
			break;
		}

		case 0350 : {
			// GB  get base adr n levels down
			uint16_t i = gs_L;
			uint16_t j = le_next();
			do {
				i = (*mem_stack)[i];
			} while (--j != 0);
			es_push(i);
			break;
		}

		case 0351 :
			// GB1  get base adr 1 level down
			es_push((*mem_stack)[gs_L]);
			break;

		case 0352 : {
			// ALLOC  allocate block
			uint16_t i = es_pop();
			es_push(gs_S);
			gs_S += i;
			if (gs_S > gs_H)
			{
					gs_S = es_pop();
					le_trap(3);
			}
			break;
		}

		case 0353 : {
			// ENTR  enter procedure
			uint16_t i = le_next();
			gs_S += i;
			if (gs_S > gs_H)
			{
					gs_S -= i;
					le_trap(3);
			}
			break;
		}

		case 0354 : {
			// RTN  return from procedure
			gs_S = gs_L;
			gs_L = (*mem_stack)[gs_S + 1];
			uint16_t i = (*mem_stack)[gs_S + 2];
			if (i < 0100000)
			{
				gs_PC = i;
			}
			else
			{
				gs_G = (*mem_stack)[gs_S];
				gs_F = (*mem_stack)[gs_G];
				gs_PC -= 0100000;
			}
			break;
		}

		case 0355 : {
			// CLX  call external procedure
			uint16_t j = le_next();
			uint16_t i = le_next();
			es_mark(gs_G, true);
			gs_G = (*mem_stack)[MCI_DFTADR + j];
			gs_F = (*mem_stack)[gs_G];
			gs_PC = i << 1;
			gs_PC = le_next2();
			break;
		}

		case 0356 : {
			// CLI  call procedure at intermediate level
			uint16_t i = le_next();
			es_mark(es_pop(), false);
			gs_PC = i << 1;
			gs_PC = le_next2();
			break;
		}

		case 0357 : {
			// CLF  call formal procedure
			uint16_t i = (*mem_stack)[gs_S - 1];
			es_mark(gs_G, true);
			uint16_t j = i >> 8;
			gs_G = (*mem_stack)[MCI_DFTADR + j];
			gs_F = (*mem_stack)[gs_G];
			gs_PC = (i & 0xff) << 1;
			gs_PC = le_next2();
			break;
		}

		case 0360 : {
			// CLL  call local procedure
			uint16_t i = le_next();
			es_mark(gs_L, false);
			gs_PC = i << 1;
			gs_PC = le_next2();
			break;
		}

		case 0361 ... 0377 :
			// CLL1 - CLL15  call local procedure
			es_mark(gs_L, false);
			gs_PC = (gs_IR & 0xf) << 1;
			gs_PC = le_next2();
			break;

		default :
			error(1, 0, "Invalid opcode %d", gs_IR);
			break;
		}
	} while (gs_PC != 0);
}