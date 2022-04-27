(******************************************************
**
** MODULE M2SGL (originally M3GL)
**
** Niklaus Wirth's Modula-2 single pass compiler
** (believed to be source code version of 2.8.1986)
**
** Origin:
** - "mfk301" Lilith disk image by Jos Dreesen
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - Renamed from "M3GL" to "M2SGL" to avoid name
**   confusion during bootstrap compilation with
**   multipass compiler
** - Adapted IMPORT lists to renamed module names
**
** 02.04.2022 
**
*******************************************************)

IMPLEMENTATION MODULE M2SGL;    (*NW 19.5.83 / 25.6.85*)
  FROM FileSystem IMPORT
       File, Response, Lookup, WriteChar, WriteWord, SetOpen, Close, Rename;
  FROM M2SDL IMPORT WordSize,
       ObjPtr, StrPtr, ParPtr, PDPtr, ObjClass, StrForm, ConstValue, KeyPtr,
       cardtyp, inttyp, booltyp, chartyp, realtyp, dbltyp, bitstyp, notyp,
       stringtyp, addrtyp, wordtyp, undftyp;
  FROM M2SS IMPORT IdBuf, Mark, id, CloseScanner;

  CONST MaxCard = 177777B; MaxInt = 32767; MinInt = -32767;
    StrTabLength = 2000; StackDepth = 16;
    CodeLength = 12000; RelTabLength = 1000; ProcTabLength = 128;

  VAR sp:     INTEGER;    (*expression stack pointer*)
    relx:     CARDINAL;   (*relocation table index*)
    datasize: INTEGER;    (*of global data*)
    exp:      CARDINAL;   (*side effect of clog*)
    strx:     CARDINAL;   (*string table index*)
    StrTab:   ARRAY [0..StrTabLength-1] OF CHAR;
    code:     ARRAY [0..CodeLength-1] OF CHAR;
    RelTab:   ARRAY [0..RelTabLength-1] OF CARDINAL;
    ProcTab:  ARRAY [0..ProcTabLength-1] OF CARDINAL;

  PROCEDURE ROR(s: BITSET; n: CARDINAL): BITSET;
    (*rotate s right by n*) CODE 275B
  END ROR;
  
  PROCEDURE COM(s: BITSET): BITSET;
    (* {0..15} - s *) CODE 323B
  END COM;

  PROCEDURE MSK(n: CARDINAL): BITSET;
    (* {0 .. n-1} *) CODE 326B
  END MSK;

  PROCEDURE err(n: CARDINAL);
  BEGIN Mark(n)
  END err;

  PROCEDURE PutWord(n: CARDINAL);
  BEGIN code[pc] := CHAR(n DIV 400B);
    code[pc+1] := CHAR(n MOD 400B); pc := pc+2
  END PutWord;

  PROCEDURE PutByte(n: CARDINAL);
  BEGIN code[pc] := CHAR(n); pc := pc+1
  END PutByte;

  PROCEDURE PutOp(n: CARDINAL; s: INTEGER);
  BEGIN code[pc] := CHAR(n); pc := pc+1; sp := sp + s;
    IF sp > StackDepth THEN err(215) END
  END PutOp;

  PROCEDURE PutOpZ(n: CARDINAL);
  BEGIN code[pc] := CHAR(n); pc := pc+1
  END PutOpZ;

  PROCEDURE PutOpU(n: CARDINAL);
  BEGIN code[pc] := CHAR(n); pc := pc+1; sp := sp + 1;
    IF sp > StackDepth THEN err(215) END
  END PutOpU;

  PROCEDURE PutOpD(n: CARDINAL);
  BEGIN code[pc] := CHAR(n); pc := pc+1; sp := sp - 1
  END PutOpD;

  PROCEDURE PutOpArg(m, n: CARDINAL; s: INTEGER);  (*LGW, LLW, SGW, SLW, CLL*)
  BEGIN sp := sp + s;
    IF sp > StackDepth THEN err(215) END;
    IF n < 10H THEN code[pc] := CHAR(m+n); pc := pc+1
    ELSIF n < 100H THEN code[pc] := CHAR(m); code[pc+1] := CHAR(n); pc := pc+2
    ELSE err(211)
    END
  END PutOpArg;

  PROCEDURE PutOpArg1(m, n: CARDINAL; s: INTEGER);  (*LSW, SSW*)
  BEGIN sp := sp + s;
    IF sp > StackDepth THEN err(215) END ;
    IF n < 10H THEN code[pc] := CHAR(m+n); pc := pc+1
    ELSIF n < 100H THEN code[pc] := CHAR(m+40B); code[pc+1] := CHAR(n); pc := pc+2
    ELSE err(211)
    END
  END PutOpArg1;

  PROCEDURE fixupByte(loc: CARDINAL);
  BEGIN code[loc] := CHAR(pc - loc)
  END fixupByte;

  PROCEDURE fixup(loc: CARDINAL);
  BEGIN
    code[loc] := CHAR((pc-loc) DIV 400B); code[loc+1] := CHAR((pc-loc) MOD 400B)
  END fixup;

  PROCEDURE fixupC(loc: CARDINAL);
  BEGIN
    IF loc+2 < pc THEN
      code[loc] := CHAR((pc-loc) DIV 400B); code[loc+1] := CHAR((pc-loc) MOD 400B)
    ELSE pc := pc-3
    END
  END fixupC;

  PROCEDURE reloc;
  BEGIN
    IF relx < RelTabLength THEN RelTab[relx] := pc; relx := relx + 1
      ELSE err(224)
    END
  END reloc;

  PROCEDURE PutLit(n: CARDINAL);
  BEGIN
    IF n < 10H THEN PutOpU(n)                   (*LIn*)
    ELSIF n < 100H THEN PutOpU(20B); PutByte(n) (*LIB*)
    ELSIF n = 177777B THEN PutOpU(325B)         (*LIN*)
    ELSE PutOpU(22B); PutWord(n)                (*LIW*)
    END
  END PutLit;

  PROCEDURE PutLd(obj: ObjPtr; size: INTEGER);
    VAR m, L: CARDINAL; a: INTEGER;
  BEGIN (*obj^.class = Var*)
    m := obj^.vmod; L := obj^.vlev; a := obj^.vadr;
    IF m = 0 THEN
        IF L = 0 THEN
          IF size # 2 THEN PutOpArg(100B,a,1)  (*LGW*)
            ELSE PutOp(101B, 2); PutByte(a)    (*LGD*)
          END
        ELSIF L = curLev THEN
          IF size # 2 THEN PutOpArg(40B,a,1)   (*LLW*)
            ELSE PutOp(41B, 2); PutByte(a)     (*LLD*)
          END
        ELSE
          IF L+1 = curLev THEN PutOpU(351B)    (*GB1*)
            ELSE PutOpU(350B); PutByte(curLev-L)
          END ;
          IF size # 2 THEN PutOpArg1(140B,a,0) (*LSW*)
            ELSE PutOpU(201B); PutByte(a)      (*LSD*)
          END
        END
    ELSE
        IF size # 2 THEN PutOpU(42B) (*LEW*) ELSE PutOp(43B,2) (*LED*) END ;
        reloc; PutByte(m); PutByte(a)
    END
  END PutLd;

  PROCEDURE PutSto(obj: ObjPtr; size: INTEGER);
    VAR m, L: CARDINAL; a: INTEGER;
  BEGIN (*obj^.class = Var*)
    IF size <= 2 THEN
      m := obj^.vmod; L := obj^.vlev; a := obj^.vadr;
      IF m = 0 THEN
        IF L = 0 THEN
          IF size = 1 THEN PutOpArg(120B,a,-1) (*SGW*)
            ELSE PutOp(121B,-2); PutByte(a)    (*SGD*)
          END
        ELSIF L = curLev THEN
          IF size = 1 THEN PutOpArg(60B,a,-1)  (*SLW*)
            ELSE PutOp(61B,-2); PutByte(a)     (*SLD*)
          END
        ELSE err(213)
        END
      ELSE
        IF size = 1 THEN PutOpD(62B) (*SEW*) ELSE PutOp(63B,-2) (*SED*) END ;
        reloc; PutByte(m); PutByte(a)
      END
    ELSE PutLit(size); PutOp(340B,-3)  (*MOV*)
    END
  END PutSto;

  PROCEDURE AllocString(s: CARDINAL; VAR adr, length: CARDINAL);
    VAR L: CARDINAL;
  BEGIN L := ORD(IdBuf[s]); length := L - 1;
    IF strx + L >= StrTabLength THEN err(225); strx := 0 END ;
    adr := strx DIV 2;  (*word address*)
    WHILE L > 1 DO
      s := s+1; StrTab[strx] := IdBuf[s]; strx := strx + 1; L := L-1
    END ;
    StrTab[strx] := 0C; strx := strx + 1;
    IF ODD(strx) THEN strx := strx + 1 END
  END AllocString;

  PROCEDURE loadStrAdr(adr: CARDINAL);
  BEGIN
    IF adr <= 377B THEN
      PutOpU(204B); PutByte(adr)                  (*LSTA adr*)
    ELSE PutOpU(102B); PutLit(adr); PutOpD(270B)  (*LGW2 LIW adr UADD*)
    END
  END loadStrAdr;

  PROCEDURE load(VAR x: Item);
    VAR s: INTEGER;
  BEGIN s := x.typ^.size;
    CASE x.mode OF
      conMd:  CASE x.typ^.form OF
                Undef, Range, Array, Record, ProcTyp: |
                Bool, Char, Card, Int, Enum, Set, Pointer, Opaque:
                        PutLit(x.val.C); x.mode := cldMd |
                Double, Real: PutOp(23B,2); PutWord(x.val.D0); PutWord(x.val.D1) |
                String: loadStrAdr(x.val.D0)
              END |
      typMd:  err(101) |
      varMd:  IF x.var^.param = {1} THEN  (*var par*)
                PutLd(x.var, 1);
                IF s = 1 THEN PutOpZ(140B)           (*LSW0*)
                ELSIF s = 2 THEN PutOpU(202B)        (*LSD0*)
                END
              ELSE PutLd(x.var, s)
              END |
      fldMd:  IF x.off <= 255 THEN
                IF s = 1 THEN PutOpArg1(140B, x.off,0) (*LSW0*)
                ELSIF s = 2 THEN PutOpU(201B); PutByte(x.off)
                ELSE PutOpZ(26B); PutByte(x.off)     (*LSA*)
                END
              ELSE PutOpU(22B); PutWord(x.off); PutOpD(270B); (*LIW UADD*)
                IF s = 1 THEN PutOpZ(140B)           (*LSW0*)
                ELSIF s = 2 THEN PutOpU(202B)        (*LSD0*)
                END
              END |
      procMd, codMd: err(102) |
      expMd, cldMd: |
      adrMd:  IF s = 1 THEN PutOpZ(140B)             (*LSW0*)
              ELSIF s = 2 THEN PutOpU(202B)          (*LSD0*)
              END |
      inxMd:  IF s = 1 THEN
                IF x.typ = chartyp THEN PutOpD(205B) (*LXB*)
                  ELSE PutOpD(206B)                  (*LXW*)
                END
              ELSIF s = 2 THEN PutOpZ(207B)          (*LXD*)
              ELSE PutOpD(270B)                      (*UADD*)
              END
    END ;
    IF x.mode # cldMd THEN x.mode := expMd END
  END load;

  PROCEDURE loadAdr(VAR x: Item);
  BEGIN
    CASE x.mode OF
      conMd:  err(103) |
      typMd:  err(104) |
      varMd:  IF (x.typ^.size > 2) OR (x.var^.param = {1}) OR
                 (x.typ^.form = Array) & x.typ^.dyn THEN PutLd(x.var, 1)
              ELSE
                IF x.var^.vmod = 0 THEN
                  IF x.var^.vlev = 0 THEN PutOpU(25B)             (*LGA*)
                  ELSIF x.var^.vlev = curLev THEN PutOpU(24B)     (*LLA*)
                  ELSE
                    IF x.var^.vlev + 1 = curLev THEN PutOpU(351B) (*GB1*)
                      ELSE PutOpU(350B); PutByte(curLev - x.var^.vlev)
                    END ;
                    PutOpZ(26B)                                   (*LSA*)
                  END
                ELSE PutOpU(27B); reloc; PutByte(x.var^.vmod)     (*LEA*)
                END ;
                PutByte(x.var^.vadr)
              END  |
      fldMd:  IF x.off <= 255 THEN
                PutOpZ(26B); PutByte(x.off)  (*LSA*)
              ELSE PutOpU(22B); PutWord(x.off); PutOpD(270B) (*LIW UADD*)
              END |
      procMd, codMd: err(105) |
      expMd, cldMd:  err(106) |
      adrMd:  |
      inxMd:  IF x.typ^.size = 2 THEN
                PutLit(1); PutOpD(276B)    (*SHL*)
              END ;
              PutOpD(270B);                (*UADD*)
              IF x.typ = chartyp THEN err(212) END
    END ;
    x.mode := adrMd
  END loadAdr;

  PROCEDURE load2(VAR x, y: Item);
  BEGIN
    IF x.mode = conMd THEN load(y); load(x) ELSE load(x); load(y) END
  END load2;

  PROCEDURE loadLim(v: ObjPtr);  (*index limit for dynamic arrays*)
    VAR L: CARDINAL; a: INTEGER;
  BEGIN a := v^.vadr + 1; L := v^.vlev;
    IF L = curLev THEN PutOpArg(40B,a,1)     (*LLW*)
    ELSE
      IF L+1 = curLev THEN PutOpU(351B)      (*GB1*)
        ELSE PutOpU(350B); PutByte(curLev-L)
      END ;
      PutOpArg1(140B,a,0)                    (*LSW*)
    END
  END loadLim;

  PROCEDURE SRTest(VAR x: Item);
  BEGIN
    IF (x.typ # NIL) & (x.typ^.form = Range) THEN x.typ := x.typ^.RBaseTyp END
  END SRTest;


  PROCEDURE GenItem(VAR x: Item; y, scope: ObjPtr);
  BEGIN 
    IF y # NIL THEN
      x.typ := y^.typ;
      CASE y^.class OF
        Const:  x.mode := conMd; x.val := y^.conval;
                IF (x.typ = stringtyp) & (x.val.D0 = 177777B) THEN
                  AllocString(x.val.D2, x.val.D0, x.val.D1);
                  (*imported string*) y^.conval.D0 := x.val.D0
                END |
        Typ:    x.mode := typMd |
        Var:    x.mode := varMd; x.var := y |
        Field:  IF curLev = 0 THEN PutOpArg(100B, scope^.withadr, 1)  (*LGW*)
                  ELSE PutOpArg(40B, scope^.withadr, 1)     (*LLW*)
                END ;
                x.mode := fldMd; x.off := y^.offset |
        Proc:   x.mode := procMd; x.proc := y; x.typ := undftyp |
        Code:   x.mode := codMd; x.cod := y; x.typ := undftyp |
        Module: x.mode := varMd; err(107) |
        Temp:
      END
    ELSE err(50); x.typ := undftyp; x.mode := expMd
    END
  END GenItem;

  PROCEDURE clog(x: CARDINAL): CARDINAL;
  BEGIN exp := 0;
    IF x > 0 THEN
      WHILE NOT ODD(x) DO
        x := x DIV 2; exp := exp + 1
      END
    END ;
    RETURN x
  END clog;

  PROCEDURE GenIndex(VAR x, y: Item);
    VAR i,m,n,sz: INTEGER; inxtyp, eltyp: StrPtr;
  BEGIN SRTest(y);  (*x.mode = adrMd*)
    IF x.typ^.form = Array THEN
      eltyp := x.typ^.ElemTyp;
      IF x.typ^.dyn THEN load(y);
        IF y.typ = inttyp THEN PutOpZ(307B)      (*CHKS*)
          ELSIF y.typ # cardtyp THEN err(109)
        END ;
        IF rngchk THEN loadLim(x.var); PutOpD(306B) END ; (*CHKZ*)
        IF eltyp^.size > 2 THEN
          IF clog(eltyp^.size) = 1 THEN
            PutLit(exp); PutOpD(276B)            (*SHL*)
          ELSE PutLit(eltyp^.size); PutOpD(272B) (*UMUL*)
          END
        END ;
        x.mode := inxMd
      ELSE
        WITH x.typ^.IndexTyp^ DO
          inxtyp := RBaseTyp; m := min; n := max
        END ;
        IF y.mode = conMd THEN
          i := y.val.I;
          IF inxtyp # y.typ THEN
            IF (i < 0) OR (inxtyp = cardtyp) & (y.typ # inttyp) OR
               (inxtyp = inttyp) & (y.typ # cardtyp) THEN err(109)
            END
          END ;
          IF (m <= i) & (i <= n) THEN i := i - m
          ELSE err(108); i := m
          END ;
          sz := eltyp^.size * i;
          IF (sz < 400B) & (eltyp^.form # Char) THEN
            x.mode := fldMd; x.off := sz
          ELSE PutLit(sz); x.mode := inxMd
          END
        ELSE load(y);
          IF inxtyp # y.typ THEN
            IF (inxtyp = cardtyp) & (y.typ = inttyp) OR
               (inxtyp = inttyp) & (y.typ = cardtyp) THEN PutOpZ(307B)
            ELSE err(109)
            END
          END ;
          IF m # 0 THEN
            PutLit(CARDINAL(m)); PutOpD(331B)    (*ISUB*)
          END ;
          IF rngchk THEN PutLit(n-m); PutOpD(306B) END ; (*CHKZ*)
          IF eltyp^.size > 2 THEN
            IF clog(eltyp^.size) = 1 THEN
              PutLit(exp); PutOpD(276B)          (*SHL*)
            ELSE PutLit(eltyp^.size); PutOpD(272B)  (*UMUL*)
            END
          END ;
          x.mode := inxMd
        END
      END ;
      x.typ := eltyp
    ELSE err(109)
    END
  END GenIndex;

  PROCEDURE GenField(VAR x: Item; f: ObjPtr);
  BEGIN (*x.typ^.form = Record*)
    IF (f # NIL) & (f^.class = Field) THEN
      IF x.mode = fldMd THEN x.off := x.off + f^.offset
        ELSE loadAdr(x); x.off := f^.offset
      END ;
      x.typ := f^.typ
    ELSIF (f # NIL) & (f^.class = Const) THEN
      x.mode := conMd; x.typ := f^.typ; x.val := f^.conval
    ELSE err(110); x.typ := undftyp; x.mode := fldMd; x.off := 0
    END ;
    x.mode := fldMd
  END GenField;

  PROCEDURE GenWith(VAR x: Item; adr: INTEGER);
  BEGIN (* WITH clause *) loadAdr(x);
    IF curLev = 0 THEN PutOpArg(120B, adr, -1) (*SGW*)
      ELSE PutOpArg(60B, adr, -1)              (*SLW*)
    END
  END GenWith;

  PROCEDURE GenDeRef(VAR x: Item);
  BEGIN
    IF x.typ^.form = Pointer THEN
      load(x); x.typ := x.typ^.PBaseTyp
    ELSIF x.typ = addrtyp THEN load(x); x.typ := wordtyp
    ELSE err(111)
    END ;
    x.mode := adrMd
  END GenDeRef;

  PROCEDURE GenNeg(VAR x: Item);
    VAR f: StrForm;
  BEGIN SRTest(x); f := x.typ^.form;
    IF x.mode = conMd THEN
      IF (f = Int) OR (f = Card) & (x.val.C <= MaxInt) THEN
        IF x.val.I >= MinInt THEN
           x.val.I := -(INTEGER(x.val.C)); x.typ := inttyp
        ELSE err(201)
        END
      ELSIF f = Real THEN x.val.R := - x.val.R
      ELSE err(112)
      END
    ELSE load(x);
      IF f = Int THEN PutOpZ(317B)         (*NEG*)
      ELSIF f = Card THEN PutOpZ(307B); PutOpZ(317B)
      ELSIF f = Real THEN PutOpZ(236B)     (*FNEG*)
      ELSE err(112)
      END
    END
  END GenNeg;

  PROCEDURE GenNot(VAR x: Item);
  BEGIN
    IF x.typ^.form = Bool THEN
      IF x.mode = conMd THEN x.val.B := NOT x.val.B
        ELSE load(x); PutOpZ(327B)         (*NOT*)
      END
    ELSE err(113)
    END
  END GenNot;

  PROCEDURE GenAnd(VAR x: Item);
  BEGIN
    IF x.typ^.form = Bool THEN
      load(x); PutOpD(37B); x.val.C := pc; PutByte(0)  (*ANDJP*)
    ELSE err(122)
    END ;
    x.mode := expMd
  END GenAnd;

  PROCEDURE GenOr(VAR x: Item);
  BEGIN
    IF x.typ^.form = Bool THEN
      load(x); PutOpD(36B); x.val.C := pc; PutByte(0)  (*ORJP*)
    ELSE err(125)
    END ;
    x.mode := expMd
  END GenOr;

  PROCEDURE GenIn(VAR x, y: Item);
    VAR f: StrForm;
  BEGIN SRTest(x); f := x.typ^.form;
    IF ((Bool <= f) & (f <= Int) OR (f = Enum)) & (y.typ^.form = Set) THEN
      y.typ := y.typ^.SBaseTyp;
      IF y.typ^.form = Range THEN y.typ := y.typ^.RBaseTyp END ;
      IF (x.typ = y.typ) OR (x.typ = inttyp) & (y.typ = cardtyp) THEN
        IF (x.mode = conMd) & (y.mode = conMd) THEN
          IF x.val.C < WordSize THEN x.val.B := x.val.C IN y.val.S
          ELSE x.val.B := FALSE; err(202)
          END
        ELSE load2(x, y); PutOpD(324B)    (*IN*)
        END
      ELSE err(114); x.mode := expMd
      END
    ELSE err(115); x.mode := expMd
    END ;
    x.typ := booltyp
  END GenIn;

  PROCEDURE GenSet(VAR x, e1, e2: Item);
    VAR s: StrPtr; n: CARDINAL;
  BEGIN x.mode := expMd; SRTest(e1); SRTest(e2);
    (*x.typ^.form = Set*) s := x.typ^.SBaseTyp;
    IF s^.form = Range THEN s := s^.RBaseTyp END ;
    IF (e1.typ = s) & (e2.typ = s) THEN
      IF (e1.mode = conMd) & (e2.mode = conMd) THEN
        x.mode := conMd;
        IF (e2.val.C < WordSize) & (e1.val.C <= e2.val.C + 1) THEN
          n := e2.val.C + 1 - e1.val.C;
          IF n < 16 THEN x.val.S := ROR(MSK(n), e1.val.C)
            ELSE x.val.S := {0..15}
          END
        ELSE err(202)
        END
      ELSE err(214)
      END ; 
    ELSE err(116)
    END
  END GenSet;

  PROCEDURE GenSingSet(VAR x, e: Item);
    VAR s: StrPtr;
  BEGIN x.mode := expMd; SRTest(e);
    (*x.typ^.form = Set*) s := x.typ^.SBaseTyp;
    IF s^.form = Range THEN s := s^.RBaseTyp END ;
    IF e.typ = s THEN
      IF e.mode = conMd THEN x.mode := conMd;
        IF e.val.C < WordSize THEN x.val.S := ROR({0}, e.val.C)
        ELSE err(202)
        END
      ELSE load(e); PutOpZ(335B)   (*BIT*)
      END
    ELSE err(116)
    END
  END GenSingSet;

  PROCEDURE GenOp(op: CARDINAL; VAR x, y: Item);
    VAR f,g: StrForm;
  BEGIN SRTest(x); SRTest(y); f := x.typ^.form;
    IF x.typ # y.typ THEN g := y.typ^.form;
      IF (f = Int) & (g = Card) & (y.mode = conMd)
       & (y.val.C <= MaxInt) THEN y.typ := x.typ
      ELSIF (f = Card) & (g = Int) & ((x.mode = conMd) OR (x.mode = cldMd))
       & (x.val.C <= MaxInt) THEN x.typ := y.typ; f := Int
      ELSIF (x.typ = addrtyp) & (g = Pointer) THEN f := Pointer
      ELSIF ((f # Pointer) OR (y.typ # addrtyp)) &
            ((f # Card) OR (g # Card)) THEN err(117)
      END
    END ;
    IF (x.mode = conMd) & (y.mode = conMd) THEN
      CASE op OF
       1:    IF f = Card THEN
               IF (x.val.C = 0) OR (y.val.C <= MaxCard DIV x.val.C) THEN
                 x.val.C := x.val.C * y.val.C
               ELSE err(203)
               END
             ELSIF f = Int THEN
               IF (x.val.I = 0) OR (ABS(y.val.I) <= MaxInt DIV ABS(x.val.I)) THEN
                 x.val.I := x.val.I * y.val.I
               ELSE err(203)
               END
             ELSIF f = Real THEN
               IF (ABS(x.val.R) <= 1.0) OR
                  (ABS(y.val.R) <= MAX(REAL)/ABS(x.val.R)) THEN
                 x.val.R := x.val.R * y.val.R
               ELSE err(203)
               END
             ELSIF f = Set THEN x.val.S := x.val.S * y.val.S
             ELSE err(118)
             END |

       2,3:  IF f = Card THEN
               IF y.val.C > 0 THEN x.val.C := x.val.C DIV y.val.C
                 ELSE err(205)
               END
             ELSIF f = Int THEN
               IF y.val.I # 0 THEN x.val.I := x.val.I DIV y.val.I
                 ELSE err(205)
               END
             ELSIF (f = Real) & (op = 2) THEN
               IF (y.val.R >= 1.0) OR
                  (ABS(x.val.R) <= ABS(y.val.R) * MAX(REAL)) THEN
                 x.val.R := x.val.R / y.val.R
               ELSE err(204)
               END
             ELSIF (f = Set) & (op = 2) THEN x.val.S := x.val.S / y.val.S
             ELSE err(120)
             END |

       4:    IF f = Card THEN
               IF y.val.C > 0 THEN x.val.C := x.val.C MOD y.val.C
                 ELSE err(205)
               END
             ELSIF f = Int THEN
               IF (x.val.I >= 0) & (y.val.I > 0) THEN
                 x.val.I := x.val.I MOD y.val.I
               ELSE err(205)
               END
             ELSE err(121)
             END |

       5:    IF f = Bool THEN x.val.B := x.val.B & y.val.B
             ELSE err(122)
             END |

       6:    IF f = Card THEN
               IF y.val.C <= MaxCard - x.val.C THEN
                 x.val.C := x.val.C + y.val.C
               ELSE err(206)
               END
             ELSIF f = Int THEN
               IF (x.val.I >= 0) & (y.val.I <= MaxInt - x.val.I) OR
                  (x.val.I <  0) & (y.val.I >= MinInt - x.val.I) THEN
                   x.val.I := x.val.I + y.val.I
               ELSE err(206)
               END
             ELSIF f = Real THEN
               IF (x.val.R >= 0.0) & (y.val.R <= MAX(REAL) - x.val.R) OR
                  (x.val.R <  0.0) & (y.val.R >= MIN(REAL) - x.val.R) THEN
                   x.val.R := x.val.R + y.val.R
                 ELSE err(206)
               END
             ELSIF f = Set THEN x.val.S := x.val.S + y.val.S
             ELSE err(123)
             END |

       7:    IF f = Card THEN
               IF y.val.C <= x.val.C THEN x.val.C := x.val.C - y.val.C
               ELSIF y.val.C - x.val.C <= MaxInt THEN
                 x.val.I := -INTEGER(y.val.C - x.val.C); x.typ := inttyp
               ELSE err(207)
               END
             ELSIF f = Int THEN
               IF (x.val.I >= 0) &
                  ((y.val.I >= 0) OR (x.val.I <= MaxInt + y.val.I)) OR
                  (x.val.I < 0) &
                  ((y.val.I < 0) OR (x.val.I >= MinInt + y.val.I)) THEN
                     x.val.I := x.val.I - y.val.I
               ELSE err(207)
               END
             ELSIF f = Real THEN
               IF (x.val.R >= 0.0) &
                  ((y.val.R >= 0.0) OR (x.val.R <= MAX(REAL) + y.val.R)) THEN
                     x.val.R := x.val.R - y.val.R
               ELSIF (x.val.R < 0.0) &
                  ((y.val.R < 0.0) OR (x.val.R >= MIN(REAL) + y.val.R)) THEN
                     x.val.R := x.val.R - y.val.R
               ELSE err(207)
               END
             ELSIF f = Set THEN x.val.S := x.val.S - y.val.S
             ELSE err(124)
             END |

       8:    IF f = Bool THEN x.val.B := x.val.B OR y.val.B
             ELSE err(125)
             END |

       9:    IF f = Card THEN x.val.B := x.val.C = y.val.C
             ELSIF f = Int THEN x.val.B := x.val.I = y.val.I
             ELSIF f = Real THEN x.val.B := x.val.R = y.val.R
             ELSIF f = Bool THEN x.val.B := x.val.B = y.val.B
             ELSIF f = Set THEN x.val.B := x.val.S = y.val.S
             ELSIF f = Char THEN x.val.B := x.val.Ch = y.val.Ch
             ELSE err(126)
             END ;
             x.typ := booltyp |

      10:    IF f = Card THEN x.val.B := x.val.C # y.val.C
             ELSIF f = Int THEN x.val.B := x.val.I # y.val.I
             ELSIF f = Real THEN x.val.B := x.val.R # y.val.R
             ELSIF f = Bool THEN x.val.B := x.val.B # y.val.B
             ELSIF f = Set THEN x.val.B := x.val.S # y.val.S
             ELSIF f = Char THEN x.val.B := x.val.Ch # y.val.Ch
             ELSE err(126)
             END ;
             x.typ := booltyp |

      11:    IF f = Card THEN x.val.B := x.val.C < y.val.C
             ELSIF f = Int THEN x.val.B := x.val.I < y.val.I
             ELSIF f = Real THEN x.val.B := x.val.R < y.val.R
             ELSIF f = Bool THEN x.val.B := x.val.B < y.val.B
             ELSIF f = Char THEN x.val.B := x.val.Ch < y.val.Ch
             ELSE err(126)
             END ;
             x.typ := booltyp |

      12:    IF f = Card THEN x.val.B := x.val.C <= y.val.C
             ELSIF f = Int THEN x.val.B := x.val.I <= y.val.I
             ELSIF f = Real THEN x.val.B := x.val.R <= y.val.R
             ELSIF f = Bool THEN x.val.B := x.val.B <= y.val.B
             ELSIF f = Set THEN x.val.B := x.val.S <= y.val.S
             ELSIF f = Char THEN x.val.B := x.val.Ch <= y.val.Ch
             ELSE err(126)
             END ;
             x.typ := booltyp |

      13:    IF f = Card THEN x.val.B := x.val.C > y.val.C
             ELSIF f = Int THEN x.val.B := x.val.I > y.val.I
             ELSIF f = Real THEN x.val.B := x.val.R > y.val.R
             ELSIF f = Bool THEN x.val.B := x.val.B > y.val.B
             ELSIF f = Char THEN x.val.B := x.val.Ch > y.val.Ch
             ELSE err(126)
             END ;
             x.typ := booltyp |

      14:    IF f = Card THEN x.val.B := x.val.C >= y.val.C
             ELSIF f = Int THEN x.val.B := x.val.I >= y.val.I
             ELSIF f = Real THEN x.val.B := x.val.R >= y.val.R
             ELSIF f = Bool THEN x.val.B := x.val.B >= y.val.B
             ELSIF f = Set THEN x.val.B := y.val.S >= x.val.S
             ELSIF f = Char THEN x.val.B := x.val.Ch >= y.val.Ch
             ELSE err(126)
             END ;
             x.typ := booltyp
      END
    ELSE
      CASE op OF
       1:    IF f = Card THEN
               IF (x.mode = conMd) & (clog(x.val.C) = 1) THEN
                 load(y); PutLit(exp); PutOpD(276B); x.mode := expMd
               ELSIF (y.mode = conMd) & (clog(y.val.C) = 1) THEN
                 load(x); PutLit(exp); PutOpD(276B) (*SHL*)
               ELSE load2(x, y); PutOpD(272B)  (*UMUL*)
               END
             ELSIF f = Int THEN
               IF (x.mode = conMd) & (clog(x.val.C) = 1) THEN
                 load(y); PutLit(exp); PutOpD(276B); x.mode := expMd
               ELSIF (y.mode = conMd) & (clog(y.val.C) = 1) THEN
                 load(x); PutLit(exp); PutOpD(276B) (*SHL*)
               ELSE load2(x, y); PutOpD(332B)  (*IMUL*)
               END
             ELSE load2(x, y);
               IF f = Double THEN err(216)
               ELSIF f = Real THEN PutOp(232B,-2)   (*FMUL*)
               ELSIF f = Set THEN PutOpD(322B)      (*AND*)
               ELSIF f # Undef THEN err(118)
               END
             END  |

       2:    load(y);
             IF f = Card THEN PutOpD(273B)          (*UDIV*)
             ELSIF f = Int THEN PutOpD(333B)        (*IDIV*)
             ELSIF f = Real THEN PutOp(233B,-2)     (*FDIV*)
             ELSIF f = Set THEN PutOpD(321B)        (*XOR*)
             ELSIF f # Undef THEN err(119)
             END  |

       3:    IF f = Card THEN (*DIV*)
               IF (y.mode = conMd) & (clog(y.val.C) = 1) THEN
                 PutLit(exp); PutOpD(277B) (*SHR*)
               ELSE load(y); PutOpD(273B)  (*UDIV*)
               END
             ELSE load(y);
               IF f = Int THEN PutOpD(333B)         (*IDIV*)
               ELSIF f = Double THEN err(216)
               ELSIF f # Undef THEN err(120)
               END
             END  |

       4:    IF f = Card THEN
               IF (y.mode = conMd) & (clog(y.val.C) = 1) THEN
                 PutLit(CARDINAL(COM(MSK(WordSize-exp))));
                 PutOpD(322B)                       (*AND*)
               ELSE load(y); PutOpD(274B)  (*UMOD*)
               END
             ELSE load(y);
               IF f = Int THEN PutOpZ(307B); PutOpD(274B)
               ELSIF f # Undef THEN err(121)
               END
             END  |

       5:    load(y);
             IF f = Bool THEN fixupByte(x.val.C)
             ELSIF f # Undef THEN err(122)
             END  |

       6:    load2(x, y);
             IF f = Card THEN PutOpD(270B)          (*UADD*)
             ELSIF f = Int THEN PutOpD(330B)        (*IADD*)
             ELSIF f = Real THEN PutOp(230B,-2)     (*FADD*)
             ELSIF f = Set THEN PutOpD(320B)        (*OR*)
             ELSIF f = Double THEN PutOp(210B,-2)   (*DADD*)
             ELSIF f # Undef THEN err(123)
             END  |

       7:    load(y);
             IF f = Card THEN PutOpD(271B)          (*USUB*)
             ELSIF f = Int THEN PutOpD(331B)        (*ISUB*)
             ELSIF f = Real THEN PutOp(231B,-2)     (*FSUB*)
             ELSIF f = Set THEN PutOpZ(323B); PutOpD(322B) (*COM AND*)
             ELSIF f = Double THEN PutOp(211B,-2)   (*DSUB*)
             ELSIF f # Undef THEN err(124)
             END  |

       8:    load(y);
             IF f = Bool THEN fixupByte(x.val.C)
             ELSIF f # Undef THEN err(125)
             END  |

       9:    load(y); x.typ := booltyp;
             IF (f <= Int) OR (f = Enum) OR (f = Pointer) OR
                (f = Set) OR (f = Opaque) THEN PutOpD(310B)      (*EQL*)
             ELSIF (f = Real) OR (f = Double) THEN PutOp(234B,-3); PutOpZ(310B)
             ELSE err(126)
             END  |

      10:    load(y); x.typ := booltyp;
             IF (f <= Int) OR (f = Enum) OR (f = Pointer) OR
                (f = Set) OR (f = Opaque) THEN PutOpD(311B)      (*NEQ*)
             ELSIF (f = Real) OR (f = Double) THEN PutOp(234B,-3); PutOpZ(311B)
             ELSE err(126)
             END  |

      11:    load(y); x.typ := booltyp;
             IF (f <= Card) OR (f = Enum) THEN PutOpD(252B)      (*ULSS*)
             ELSIF f = Int THEN PutOpD(312B)                     (*ILSS*)
             ELSIF (f = Real) OR (f = Double) THEN PutOp(234B,-3); PutOpZ(312B)
             ELSE err(126)
             END  |

      12:    load(y); x.typ := booltyp;
             IF (f <= Card) OR (f = Enum) THEN PutOpD(253B)      (*ULEQ*)
             ELSIF f = Int THEN PutOpD(313B)                     (*ILEQ*)
             ELSIF (f = Real) OR (f = Double) THEN PutOp(234B,-3); PutOpZ(313B)
             ELSIF f = Set THEN                      (*COM AND LI0 EQL*)
               PutOpZ(323B); PutOpZ(322B); PutOpZ(0); PutOpD(310B)
             ELSE err(126)
             END |

      13:    load(y); x.typ := booltyp;
             IF (f <= Card) OR (f = Enum) THEN PutOpD(254B)      (*UGTR*)
             ELSIF f = Int THEN PutOpD(314B)                     (*IGTR*)
             ELSIF (f = Real) OR (f = Double) THEN PutOp(234B,-3); PutOpZ(314B)
             ELSE err(126)
             END  |

      14:    load(y); x.typ := booltyp;
             IF (f <= Card) OR (f = Enum) THEN PutOpD(255B)      (*UGEQ*)
             ELSIF f = Int THEN PutOpD(315B)                     (*IGEQ*)
             ELSIF (f = Real) OR (f = Double) THEN PutOp(234B,-3); PutOpZ(315B)
             ELSIF f = Set THEN                       (*COM OR LIN EQL*)
               PutOpZ(323B); PutOpZ(320B); PutOpZ(325B); PutOpD(310B)
             ELSE err(126)
             END
      END
    END
  END GenOp;


  PROCEDURE CheckAssComp(xt: StrPtr; VAR y: Item;
                         param: BOOLEAN; VAR sz: INTEGER);
    VAR f,g: StrForm; xp, yp: ParPtr; vsz: INTEGER;
  BEGIN sz := xt^.size;
    IF (y.mode = procMd) & (xt^.form = ProcTyp) THEN
      (*procedure to proc. variable; check compatibility*)
      IF y.proc^.pd^.lev > 0 THEN err(127)
      ELSIF xt^.resTyp # y.proc^.typ THEN err(128)
      ELSE xp := xt^.firstPar; yp := y.proc^.firstParam;
        WHILE xp # NIL DO
          IF yp # NIL THEN
            IF (xp^.varpar # yp^.varpar) OR ((xp^.typ # yp^.typ) &
                ((xp^.typ^.form # Array) OR NOT xp^.typ^.dyn OR
                 (yp^.typ^.form # Array) OR NOT yp^.typ^.dyn OR
                 (xp^.typ^.ElemTyp # yp^.typ^.ElemTyp))) THEN err(129)
            END ;
            yp := yp^.next
          ELSE err(130)
          END ;
          xp := xp^.next
        END ;
        IF yp # NIL THEN err(131) END ;
        (*generate procedure descriptor*)
        PutOpU(22B) (*LIW*); reloc; PutByte(y.proc^.pmod); PutByte(y.proc^.pd^.num)
      END
    ELSE SRTest(y);
      IF xt^.form = Range THEN xt := xt^.RBaseTyp END ;
      IF y.typ = NIL THEN err(117)
      ELSIF (xt = y.typ) & ~((xt^.form = Array) & xt^.dyn) THEN load(y)
      ELSE
        f := xt^.form; g := y.typ^.form;
        IF (f = Card) & (g = Int) THEN
            IF y.mode = conMd THEN load(y);
              IF y.val.I < 0 THEN err(132) END
            ELSE load(y);
              IF rngchk THEN PutOpZ(307B) END  (*CHKS*)
            END
        ELSIF (f = Int) & (g = Card) THEN
            IF y.mode = conMd THEN load(y);
              IF y.val.C > MaxInt THEN err(208) END
            ELSE load(y);
              IF rngchk THEN PutOpZ(307B) END  (*CHKS*)
            END
        ELSIF (f = Pointer) & (y.typ = addrtyp)
           OR (g = Pointer) & (xt = addrtyp) THEN load(y)
        ELSIF f = Array THEN
          IF xt^.dyn THEN (*dynamic array parameter*)
            IF ~param THEN err(143)
            ELSIF (g = Array) & (xt^.ElemTyp = y.typ^.ElemTyp) THEN
              IF y.typ^.dyn THEN PutLd(y.var, 2)
              ELSE loadAdr(y); PutLit(y.typ^.IndexTyp^.max - y.typ^.IndexTyp^.min)
              END
            ELSIF xt^.ElemTyp = chartyp THEN
              IF g = String THEN
                load(y); PutLit(y.val.D1 - 1)
              ELSIF (g = Char) & (y.mode = conMd) THEN
                loadStrAdr(strx DIV 2); StrTab[strx] := y.val.Ch;
                StrTab[strx+1] := 0C; strx := strx+2; PutLit(0)
              ELSE err(133)
              END
            ELSIF xt^.ElemTyp = wordtyp THEN
              loadAdr(y); PutLit(y.typ^.size-1)
            ELSE err(133)
            END
          ELSIF xt^.ElemTyp = chartyp THEN
            IF g = String THEN  (*string to array variable*)
              load(y); sz := y.val.D1;  (*check length of string*)
              vsz := xt^.IndexTyp^.max - xt^.IndexTyp^.min + 1;
              IF sz < vsz THEN sz := sz+1  (*include 0C terminator*)
              ELSIF sz > vsz THEN  err(146)
              END ;
              sz := (sz+1) DIV 2;
              IF param THEN
                IF vsz <= 2 THEN PutOpZ(140B)     (*LSW0*)
                ELSIF vsz <= 4 THEN PutOpU(202B)  (*LSD0*)
                END
              ELSIF sz = 1 THEN PutOpZ(140B)      (*LSW0*)
              ELSIF sz = 2 THEN PutOpU(202B)      (*LSD0*)
              END
            ELSIF g = Char THEN err(200)
            ELSE err(133)
            END
          ELSE err(133)
          END
        ELSIF param & (xt = wordtyp) & (y.typ^.size = 1) THEN load(y)
        ELSIF (f # Card) OR (g # Card) THEN err(133)
        ELSE load(y)
        END
      END
    END ;
  END CheckAssComp;

  PROCEDURE PrepAss(VAR x: Item);
    VAR L: CARDINAL;
  BEGIN
    IF (x.mode = conMd) OR (x.mode = procMd) THEN err(134) END ;
    IF x.typ^.size <= 2 THEN
      IF x.mode = varMd THEN
        IF x.var^.param = {1} THEN (*var par*)
          loadAdr(x); x.mode := adrMd
        ELSE L := x.var^.vlev;
          IF (L > 0) & (L < curLev) THEN
            IF L+1 = curLev THEN PutOpU(351B)        (*GB1*)
              ELSE PutOpU(350B); PutByte(curLev-L)   (*GB *)
            END ;
            x.mode := fldMd; x.off := x.var^.vadr
          END
        END
      END
    ELSE
      IF x.mode = varMd THEN
        IF x.var^.param = {1} THEN PutLd(x.var, 1) ELSE loadAdr(x) END
      ELSIF x.mode = inxMd THEN PutOpD(270B)         (*UADD*)
      ELSIF x.mode = fldMd THEN PutOpZ(26B) (*LSA*); PutByte(x.off)
      END ;
      x.mode := adrMd
    END
  END PrepAss;

  PROCEDURE GenAssign(VAR x, y: Item);
    VAR s: INTEGER;
  BEGIN CheckAssComp(x.typ, y, FALSE, s);
    IF rngchk & (x.typ^.form = Range) THEN
      WITH x.typ^ DO
        IF min = 0 THEN PutLit(max); PutOpD(306B)      (*CHKZ*)
        ELSE PutLit(CARDINAL(min)); PutLit(CARDINAL(max));
          IF min < 0 THEN PutOp(305B, -2)              (*CHK*)
                     ELSE PutOp(245B, -2)              (*UCHK*)
          END
        END
      END
    END ;
    IF x.mode = varMd THEN
      PutSto(x.var, s)
    ELSIF x.mode = fldMd THEN
      IF s = 1 THEN PutOpArg1(160B, x.off, -2)         (*SSW*)
      ELSIF s = 2 THEN PutOp(221B,-3); PutByte(x.off)  (*SSD*)
      ELSE PutLit(s); PutOp(340B,-3)                   (*MOV*)
      END
    ELSIF x.mode = inxMd THEN
      IF s = 1 THEN                                (*SXB SXW*)
        IF x.typ = chartyp THEN PutOp(225B,-3) ELSE PutOp(226B,-3) END
      ELSIF s = 2 THEN PutOp(227B,-4)                  (*SXD*)
      ELSE PutLit(s); PutOp(340B,-3)                   (*MOV*)
      END
    ELSIF x.mode = adrMd THEN
      IF s = 1 THEN PutOp(160B,-2)                     (*SSW0*)
      ELSIF s = 2 THEN PutOp(222B,-3)                  (*SSD0*)
      ELSE PutLit(s); PutOp(340B,-3)                   (*MOV*)
      END
    ELSE err(134)
    END
  END GenAssign;


  PROCEDURE GenFJ(VAR loc: CARDINAL);
  BEGIN PutOpZ(31B); loc := pc; PutWord(0)             (*JP*)
  END GenFJ;

  PROCEDURE GenCFJ(VAR x: Item; VAR loc: CARDINAL);
  BEGIN
    IF x.typ^.form = Bool THEN load(x) ELSE err(135) END ;
    PutOpD(30B); loc := pc; PutWord(0)                 (*JPC*)
  END GenCFJ;

  PROCEDURE GenBJ(loc: CARDINAL);
  BEGIN
    IF pc < loc+377B THEN PutOpZ(35B); PutByte(pc-loc) (*JPB*)
      ELSE PutOpZ(31B); PutWord(CARDINAL(-INTEGER(pc-loc)))
    END
  END GenBJ;

  PROCEDURE GenCBJ(VAR x: Item; loc: CARDINAL);
  BEGIN
    IF x.typ^.form = Bool THEN load(x) ELSE err(135) END ;
    IF pc < loc+377B THEN PutOpD(34B); PutByte(pc-loc)
      ELSE PutOpD(30B); PutWord(CARDINAL(-INTEGER(pc-loc)))
    END
  END GenCBJ;


  PROCEDURE PrepCall(VAR x: Item; VAR fpar: ParPtr);
  BEGIN x.sp := sp;
    IF x.mode = procMd THEN
      fpar := x.proc^.firstParam;
      IF sp > 0 THEN PutOpZ(262B); (*STORE*) sp := 0 END
    ELSIF x.mode = codMd THEN fpar := x.cod^.firstArg
    ELSIF x.typ^.form = ProcTyp THEN
      fpar := x.typ^.firstPar; load(x);
      IF sp > 1 THEN PutOpZ(263B); sp := 0 (*STOFV*)
        ELSE PutOpD(264B)  (*STOT*)
      END
    ELSE err(136); fpar := NIL; x.typ := undftyp
    END
  END PrepCall;

  PROCEDURE GenParam(VAR ap: Item; fp: ParPtr);
    VAR sz: INTEGER; ftyp, inxtyp: StrPtr;
  BEGIN ftyp := fp^.typ;
    IF fp^.varpar THEN
      IF (ftyp^.form = Array) & ftyp^.dyn &
         (ap.typ^.form = Array) & (ap.typ^.ElemTyp = ftyp^.ElemTyp) THEN
        IF ap.typ^.dyn THEN PutLd(ap.var, 2)
        ELSE loadAdr(ap); inxtyp := ap.typ^.IndexTyp;
          PutLit(inxtyp^.max - inxtyp^.min)
        END
      ELSIF (ap.typ = ftyp) OR
            (ftyp = wordtyp) & (ap.typ^.size = 1) OR
            (ftyp = addrtyp) & (ap.typ^.form = Pointer) THEN loadAdr(ap)
      ELSIF (ftyp^.form = Array) & ftyp^.dyn & (ftyp^.ElemTyp = wordtyp) THEN
        IF (ap.typ^.form = Array) & ap.typ^.dyn THEN PutLd(ap.var, 2)
        ELSE loadAdr(ap); PutLit(ap.typ^.size-1)
        END
      ELSE err(137)
      END
    ELSE CheckAssComp(ftyp, ap, TRUE, sz)
    END
  END GenParam;

  PROCEDURE adjustStack(VAR x: Item);
  BEGIN (*after procedure call*)
    IF (x.typ = NIL) OR (x.typ = notyp) THEN sp := 0
    ELSE sp := x.sp;
      IF sp > 0 THEN
        IF x.typ^.size = 2 THEN PutOp(261B, 2) (*LODFD*)
          ELSE PutOpU(260B) (*LODFW*)
        END
      ELSE sp := x.typ^.size
      END
    END
  END adjustStack;

  PROCEDURE GenCall(VAR x: Item);
    VAR i, L: CARDINAL; pd: PDPtr;
  BEGIN
    IF x.mode = procMd THEN
      pd := x.proc^.pd; L := pd^.lev;
      IF x.proc^.pmod = 0 THEN
        IF (L = 0) OR (L = curLev) THEN PutOpArg(360B, pd^.num, 0) (*CL*) ELSE
          IF pd^.lev + 1 = curLev THEN PutOpU(351B)   (*GB1*) 
            ELSE PutOpU(350B); PutByte(curLev - pd^.lev)
          END ;
          PutOpD(356B); PutByte(pd^.num)  (*CI*)
        END
      ELSE PutOpZ(355B); reloc; PutByte(x.proc^.pmod); PutByte(pd^.num) (*CX*)
      END ;
      x.typ := x.proc^.typ; adjustStack(x)
    ELSIF x.mode = codMd THEN
      x.typ := x.cod^.typ; sp := INTEGER(x.typ^.size) + x.sp;
      L := x.cod^.length; i := 0;
      WHILE i < L DO
        PutByte(CARDINAL(x.cod^.cd^.cod[i])); i := i+1
      END
    ELSIF x.mode = expMd THEN
      PutOpZ(357B); PutOpZ(266B);   (*CF DECS*)
      x.typ := x.typ^.resTyp; adjustStack(x)
    END ;
    x.mode := expMd
  END GenCall;

  PROCEDURE unstack(par: ParPtr);
    VAR a, s: INTEGER; tp: StrPtr;
  BEGIN (*unstack parameters in reverse order when entering procedure*)
    IF par # NIL THEN
      unstack(par^.next); tp := par^.typ;
      IF par^.varpar THEN
        IF (tp^.form = Array) & tp^.dyn THEN
          PutOpZ(61B); PutByte(par^.name)     (*SLD*)
        ELSE PutOpArg(60B, par^.name, 0)      (*SLW*)
        END
      ELSE s := tp^.size; a := par^.name;
        IF s = 1 THEN PutOpArg(60B, a, 0)
        ELSIF (tp^.form = Array) & tp^.dyn THEN
          PutOpZ(61B); PutByte(a); PutOpZ(41B); PutByte(a); (*SLD a, LLD a*)
          IF tp^.ElemTyp = chartyp THEN PutOpZ(1); PutOpZ(277B) END ;
          PutOpZ(26B); PutByte(1);      (*LSA 1*)
          IF tp^.ElemTyp^.size > 1 THEN
            PutLit(tp^.ElemTyp^.size); PutOpD(272B)         (*LIT s, UMUL*)
          END ;
          PutOpZ(267B); PutByte(a)                          (*PCOP a*)
        ELSIF s = 2 THEN PutOpZ(61B); PutByte(a)    (*SLD*)
        ELSE PutLit(s); PutOpD(267B); PutByte(a)            (*PCOP a*)
        END
      END
    END
  END unstack;

  PROCEDURE GenEnter(VAR L: CARDINAL; proc: ObjPtr);
  BEGIN
    IF ODD(pc) THEN PutOpZ(336B) (*NOP*) END ;
    ProcTab[proc^.pd^.num] := pc;
    PutOpZ(353B) (*ENTR*); L := pc; PutByte(0);
    IF curPrio > 0 THEN PutOpZ(250B); PutByte(curPrio) END ;
    unstack(proc^.firstParam)
  END GenEnter;

  PROCEDURE GenEnterMod(mod: ObjPtr);
  BEGIN
    IF ODD(pc) THEN PutOpZ(336B) (*NOP*) END ;
    ProcTab[mod^.modno] := pc;
    IF curPrio > 0 THEN PutOpZ(250B); PutByte(curPrio) END
  END GenEnterMod;

  PROCEDURE FixupEnter(L: CARDINAL; size: INTEGER);
  BEGIN code[L] := CHAR(size-4)
  END FixupEnter;

  PROCEDURE GenReturn;
  BEGIN
    IF curPrio > 0 THEN PutOpZ(251B) END ;
    PutOpZ(354B)   (*RTN*)
  END GenReturn;

  PROCEDURE GenResult(VAR x: Item; proc: ObjPtr);
    VAR sz: INTEGER;
  BEGIN CheckAssComp(proc^.typ, x, FALSE, sz); sp := 0
  END GenResult;


  PROCEDURE GenCase1(VAR x: Item; VAR L0: CARDINAL);
    VAR f: StrForm;
  BEGIN load(x); L0 := pc+1; f := x.typ^.form;
    IF (f <= Int) OR (f = Enum) OR (f = Range) THEN
      PutOpD(302B); PutWord(0)   (*ENTC*)
    ELSE err(140)
    END
  END GenCase1;

  PROCEDURE GenCase2;
  BEGIN PutOpZ(303B)  (*EXC*)
  END GenCase2;

  PROCEDURE GenCase3(L0, L1, n: CARDINAL; VAR tab: ARRAY OF LabelRange);
    VAR i: CARDINAL; j, lim: INTEGER;
  BEGIN fixup(L0);
    IF n > 0 THEN
      PutWord(CARDINAL(tab[0].low)); PutWord(CARDINAL(tab[n-1].high))
    ELSE PutWord(1); PutWord(0)
    END ;
    PutWord(177777B-pc+L1+1);
    i := 0; j := tab[0].low;
    WHILE i < n DO
      lim := tab[i].high;
      IF lim - j + INTEGER(pc) < CodeLength THEN
        WHILE j < tab[i].low DO
          PutWord(177777B-pc+L1+1); j := j+1  (*else*)
        END ;
        WHILE j <= lim DO
          PutWord(177777B-pc+ tab[i].label +1); j := j+1
        END
      ELSE err(217)
      END ;
      i := i+1
    END
  END GenCase3;

  PROCEDURE GenFor1(VAR v, e1: Item);
    VAR f: StrForm; s: INTEGER;
  BEGIN SRTest(v); f := v.typ^.form;
    IF (f <= Int) OR (f = Enum) THEN
      SRTest(e1); CheckAssComp(v.typ, e1, FALSE, s)
    ELSE err(142)
    END
  END GenFor1;

  PROCEDURE GenFor2(VAR v, e2: Item);
  BEGIN SRTest(e2); load(e2);
    IF v.typ # e2.typ THEN
      IF (v.typ = inttyp) & (e2.typ = cardtyp) THEN
        IF e2.mode = conMd THEN
          IF e2.val.C > MaxInt THEN err(208) END
        ELSE PutOpZ(307B)
        END
      ELSIF (v.typ = cardtyp) & (e2.typ = inttyp) THEN
        IF e2.mode = conMd THEN
          IF e2.val.I < 0 THEN err(132) END
        ELSE PutOpZ(307B)
        END
      ELSE err(117)
      END
    END
  END GenFor2;

  PROCEDURE GenFor3(VAR e3: Item; VAR L0, L1: CARDINAL);
  BEGIN PutOp(300B,-3);  (*FOR1*)
    IF e3.val.I > 0 THEN PutByte(0)
      ELSIF e3.val.I < 0 THEN PutByte(1)
      ELSE err(141)
    END ;
    L0 := pc; PutWord(0); L1 := pc
  END GenFor3;

  PROCEDURE GenFor4(VAR e3: Item; L0, L1: CARDINAL);
  BEGIN PutOpZ(301B); PutByte(e3.val.C); PutWord(177777B-pc+L1+1); fixup(L0)
  END GenFor4;

  PROCEDURE GenTrap(n: CARDINAL);
  BEGIN PutLit(n); PutOpD(304B)  (*TRAP*)
  END GenTrap;

  PROCEDURE GenStParam(VAR p, x: Item; fctno, parno: CARDINAL);
    VAR f: StrForm; ii: INTEGER;
  BEGIN
    IF parno = 0 THEN  (*first parameter*)
      CASE fctno OF
     0,1: |
       2: (*ABS*) SRTest(x);
          IF x.typ = inttyp THEN load(x); PutOpZ(316B)
          ELSIF x.typ = realtyp THEN load(x); PutOpZ(235B)
          ELSE err(144)
          END |
       3: (*CAP*) SRTest(x);
          IF x.typ = chartyp THEN load(x); PutLit(137B); PutOpD(322B)
          ELSE err(144); x.typ := chartyp
          END |
       4: (*FLOAT*) SRTest(x); 
          IF x.typ = cardtyp THEN load(x); PutOpU(237B); PutByte(0)
          ELSE err(144)
          END ;
          x.typ := realtyp |
       5: (*ODD*) SRTest(x); 
          IF (x.typ = cardtyp) OR (x.typ = inttyp) THEN
            load(x); PutOpU(1); PutOpD(322B)
          ELSE err(144)
          END ;
          x.typ := booltyp |
       6: (*ORD*) SRTest(x); 
          IF (x.typ^.form <= Card) OR (x.typ^.form = Enum) THEN load(x)
          ELSE err(144)
          END ;
          x.typ := cardtyp |
       7: (*TRUNC*)
          IF x.typ = realtyp THEN load(x); PutOpD(237B); PutByte(2)
          ELSE err(144)
          END ;
          x.typ := cardtyp |
       8: (*SIZE, TSIZE*)
          IF (x.mode = typMd) OR (x.mode = varMd) THEN x.val.I := x.typ^.size
          ELSE err(145); x.val.I := 1
          END ;
          x.mode := conMd; x.typ := cardtyp |
       9: |
      10: (*ADR*) loadAdr(x); x.mode := expMd; x.typ := addrtyp |
      11: (*MIN*)
          IF x.mode = typMd THEN x.mode := conMd;
            CASE x.typ^.form OF
              Bool:  x.val.B := FALSE |
              Char:  x.val.Ch := 0C |
              Int:   x.val.C := 100000B |
              Card:  x.val.C := 0 |
              Real:  x.val.D0 := 177777B; x.val.D1 := 177777B |
              Double: x.val.D0 := 100000B; x.val.D1 := 0 |
              Enum:  x.val.C := 0 |
              Range: x.val.I := x.typ^.min; x.typ := x.typ^.RBaseTyp
            ELSE err(144)
            END
          ELSE err(145)
          END |
      12: (*MAX*)
          IF x.mode = typMd THEN x.mode := conMd;
            CASE x.typ^.form OF
              Bool:  x.val.B := TRUE |
              Char:  x.val.Ch := 377C |
              Int:   x.val.I := 77777B |
              Card:  x.val.C := 177777B |
              Real:  x.val.D0 := 77777B; x.val.D1 := 177777B |
              Double: x.val.D0 := 77777B; x.val.D1 := 177777B |
              Enum:  x.val.C := x.typ^.NofConst - 1 |
              Range: x.val.I := x.typ^.max; x.typ := x.typ^.RBaseTyp 
            ELSE err(144)
            END
          ELSE err(145)
          END |
      13: (*HIGH*)
          IF (x.mode = varMd) & (x.typ^.form = Array) THEN
            IF x.typ^.dyn THEN loadLim(x.var); x.mode := expMd
            ELSE x.mode := conMd; x.val.I := x.typ^.IndexTyp^.max
            END
          ELSE err(144)
          END ;
          x.typ := cardtyp |
      14: (*CHR*) SRTest(x); 
          IF (x.typ = cardtyp) OR (x.typ = inttyp) THEN load(x)
          ELSE err(144)
          END ;
          x.typ := chartyp |
   15,16: (*INC, DEC*) f := x.typ^.form; 
          IF (f <= Int) OR (f = Range) OR (f = Enum) THEN
            (*INC/DEC: adr COPT LSW0 LI1 UADD/IADD SSW0*)
            SRTest(x); loadAdr(x); PutOpU(265B); PutOpZ(140B)
          ELSE err(144)
          END |
   17,18: (*INCL EXCL*)
          IF x.typ^.form = Set THEN (*adr COPT LSW0*)
            x.typ := x.typ^.SBaseTyp; loadAdr(x); PutOpU(265B); PutOpZ(140B)
          ELSE err(144); x.typ := cardtyp
          END |
      19: (*VAL*)
          IF x.mode = typMd THEN f := x.typ^.form;
            IF (f # Enum) & (f > Int) THEN err(144) END
          END |
      20: (*LONG*) SRTest(x); 
          IF x.typ = cardtyp THEN load(x) ELSE err(144) END
      END ;
      p := x

    ELSIF parno = 1 THEN  (*second parameter*)
        IF (fctno = 15) OR (fctno = 16) THEN  (*INC/DEC*)
          SRTest(x); CheckAssComp(p.typ, x, FALSE, ii)
        ELSIF fctno = 17 THEN   (*INCL: n BIT OR SSW0*)
          SRTest(p); SRTest(x);
          IF (x.typ = p.typ) OR (p.typ = cardtyp) & (x.typ = inttyp) THEN
            load(x); PutOpZ(335B); PutOpD(320B); PutOp(160B,-2)
          ELSE err(144)
          END ;
          p.typ := notyp
        ELSIF fctno = 18 THEN  (*EXCL: n BIT COM AND SSW0*)
          SRTest(p); SRTest(x);
          IF (x.typ = p.typ) OR (p.typ = cardtyp) & (x.typ = inttyp) THEN
            load(x); PutOpZ(335B); PutOpZ(323B); PutOpD(322B); PutOp(160B,-2)
          ELSE err(144)
          END ;
          p.typ := notyp
        ELSIF fctno = 19 THEN  (*VAL*)
          IF x.typ^.size > 1 THEN err(144) END ;
          x.typ := p.typ; p := x
        ELSIF fctno = 20 THEN SRTest(x);  (*LONG*)
          IF x.typ = cardtyp THEN load(x) ELSE err(144) END ;
          p.typ := dbltyp
        ELSE err(64)
        END
    ELSE err(64)
    END
  END GenStParam;

  PROCEDURE GenStFct(VAR p: Item; fctno, parno: CARDINAL);
  BEGIN 
    IF parno < 1 THEN err(65)
    ELSIF fctno = 15 THEN (*INC*)
      IF parno = 1 THEN PutOpU(1) END ;
      IF p.typ^.form = Int THEN PutOpD(330B) ELSE PutOpD(270B) END ;
      PutOp(160B,-2); p.typ := notyp
    ELSIF fctno = 16 THEN (*DEC*)
      IF parno = 1 THEN PutOpU(1) END ;
      IF p.typ^.form = Int THEN PutOpD(331B) ELSE PutOpD(271B) END ;
      PutOp(160B,-2); p.typ := notyp
    ELSIF (fctno > 16) & (parno < 2) THEN err(65)
    END
  END GenStFct;

  PROCEDURE CheckStack;
    CONST CodeLimit = CodeLength - RelTabLength;
  BEGIN sp := 0;
    IF pc > CodeLimit THEN err(226); CloseScanner; HALT END
  END CheckStack;


  PROCEDURE scanlist1(obj: ObjPtr);
    (*generate code to allocate dataspace and set indirect adresses*)
    VAR s: INTEGER;
  BEGIN
    WHILE obj # NIL DO
      IF (obj^.class = Var) & (obj^.param = {}) & (obj^.typ^.size > 2) THEN
        s := obj^.typ^.size;
        IF curLev = 0 THEN
          IF obj^.vmod = 0 THEN
            datasize := datasize + s; PutOpU(265B); PutOpArg(120B, obj^.vadr,-1);
            IF s < 400B THEN PutOpZ(26B); PutByte(s)
              ELSE PutLit(s); PutOpD(270B)  (*UADD*)
            END
          END
        ELSE
          PutLit(s); PutOpZ(352B); PutOpArg(60B, obj^.vadr,-1)
        END
      ELSIF obj^.class = Module THEN
        scanlist1(obj^.firstObj)
      END ;
      obj := obj^.next
    END
  END scanlist1;

  PROCEDURE scanlist2(obj: ObjPtr);
  BEGIN (*generate code for initialization calls of modules*)
    WHILE obj # NIL DO
      IF obj^.class = Module THEN
        scanlist2(obj^.firstObj); PutOpArg(360B, obj^.modno, 0)  (*CL*)
      END ;
      obj := obj^.next
    END
  END scanlist2;

  PROCEDURE GenEndDecl(ancestor: ObjPtr; modno: CARDINAL);
    VAR s: CARDINAL; obj: ObjPtr;
  BEGIN
    IF ancestor^.class = Proc THEN obj := ancestor^.firstLocal
    ELSE obj := ancestor^.firstObj
    END ;
    scanlist1(obj);
    IF curLev = 0 THEN  (*main*)
      PutOpZ(122B); (*SGW2*) s := 1; (*initialize imports*)
      WHILE s < modno DO
        PutOpZ(355B); reloc; PutByte(s); PutByte(0); s := s+1
      END
    END ;
    scanlist2(obj); sp := 0
  END GenEndDecl;

  PROCEDURE OutCodeFile(VAR name: ARRAY OF CHAR; stamp: KeyPtr;
            adr: INTEGER;  pno, id, modn: CARDINAL; mods: ObjPtr);
    VAR i,pcw: CARDINAL;
        out: File;

    PROCEDURE W(n: CARDINAL);
    BEGIN WriteWord(out, n)
    END W;

    PROCEDURE WriteNameAndKey(id: CARDINAL; stamp: KeyPtr);
      VAR k,L: CARDINAL;
    BEGIN L := CARDINAL(IdBuf[id])-1; k := id+L;
      WHILE id < k DO id := id+1; WriteChar(out, IdBuf[id]) END ;
      IF ODD(L) THEN WriteChar(out, 0C) END ;
      WHILE L < 15 DO W(0); L := L+2 END ;
      W(stamp^.k0); W(stamp^.k1); W(stamp^.k2)
    END WriteNameAndKey;

  BEGIN PutOpZ(354B);
    IF ODD(pc) THEN PutOpZ(336B) END ;
    code[7] := CHAR(adr); pcw := pc DIV 2;
    Lookup(out, name, TRUE);
    IF out.res = done THEN
      (*version and header blocks*)
      W(200B); W(1); W(4);
      W(201B); W(14); WriteNameAndKey(id, stamp);
      W(CARDINAL(adr)+CARDINAL(datasize)+(strx DIV 2)); W(pno+pcw); W(0);
      IF modn > 1 THEN (*imports*)
        W(202B); W((modn-1)*11); mods := mods^.next^.next;
        REPEAT
          WriteNameAndKey(mods^.name, mods^.key); mods := mods^.next
        UNTIL mods = NIL
      END ;
      (*data and string blocks*)
      W(204B); W(3); W(1); W(0); W(0);
      IF strx > 0 THEN
        W(204B); W(strx DIV 2 +1); W(adr+datasize);
        FOR i := 0 TO strx-1 DO WriteChar(out, StrTab[i]) END
      END ;
      (*code blocks*)
      W(203B); W(pno+1); W(0);
      FOR i := 0 TO pno-1 DO W(ProcTab[i] + 2*pno) END ;
      W(203B); W(pcw+1); W(pno);
      FOR i := 0 TO pc-1 DO WriteChar(out, code[i]) END ;
      (*relocation block*)
      IF relx > 0 THEN
        W(205B); W(relx);
        FOR i := 0 TO relx-1 DO W(RelTab[i] + 2*pno) END
      END ;
      SetOpen(out);
      IF out.res # done THEN 
        err(223); Rename(out, "");
      ELSE
        Close(out);
      END
    ELSE err(222)
    END
  END OutCodeFile;

  PROCEDURE InitGenerator;
  BEGIN pc := 0; sp := 0; ProcTab[0] := 0;
    strx := 0; datasize := 0; relx := 0;
    (*LGA 1, TS, JPFC 2, RTN, LGA 0*)
    PutOpZ(25B); PutByte(1); PutOpZ(224B); PutOpZ(32B); PutByte(2);
    PutOpZ(354B); PutOpZ(25B); PutByte(0)
  END InitGenerator;

BEGIN
END M2SGL.
