(******************************************************
**
** MODULE compile (originally M3PL)
**
** Niklaus Wirth's Modula-2 single pass compiler
** (believed to be source code version of 2.8.1986)
**
** Origin:
** - "mfk301" Lilith disk image by Jos Dreesen
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - Renamed from "M3PL" to "compile" to avoid name
**   confusion during bootstrap compilation with
**   multipass compiler
** - Adapted IMPORT lists to renamed module names
**
** This is the main module of N. Wirth's M2 single
** pass compiler.
**
** 02.04.2022 
**
*******************************************************)

MODULE compile;   (*NW 6.3.83 / 20.5.85 / 2.8.86*)
  (*One-pass Modula-2 Compiler for Lilith.  Copyright N.Wirth*)

  FROM Terminal IMPORT Read, Write, WriteString, WriteLn;
  FROM FileSystem IMPORT Lookup, Response, GetPos, Close, Rename;
  FROM Clock IMPORT Time, GetTime;
  FROM M2SDL IMPORT 
       WordSize, MaxCodeLength,
       cardtyp, inttyp, realtyp, chartyp, bitstyp, dbltyp, notyp, stringtyp,
       addrtyp, undftyp, mainmod, sysmod,
       ObjPtr, StrPtr, ParPtr, ConstValue, StrForm, ObjClass;
  FROM M2SS IMPORT
       Symbol, sym, id, numtyp, intval, dblval, realval, source, IdBuf, scanerr,
       InitScanner, GetSym, Diff, KeepId, Mark, CloseScanner;
  FROM M2STL IMPORT
       topScope, Scope, NewObj, NewStr, NewPar, NewImp,
       NewScope, CloseScope, Find, FindImport, FindInScope, CheckUDP,
       MarkHeap, ReleaseHeap, InitTableHandler;
  FROM M2SRL IMPORT
       ModNo, ModList, RefFile,
       InitRef, InRef, OpenRef, OutPos, OutUnit, CloseRef;
  FROM M2SGL IMPORT
       LabelRange, ItemMode, Item, curLev, curPrio, pc, rngchk,
       load, loadAdr, fixup, fixupC, FixupEnter, CheckStack, AllocString,
       GenNeg, GenNot, GenAnd, GenOr, GenOp, GenIn, GenSet, GenSingSet,
       GenItem, GenIndex, GenField, GenWith, GenDeRef,
       PrepAss, GenAssign, GenFJ, GenCFJ, GenBJ, GenCBJ,
       PrepCall, GenParam, GenCall, GenEnter, GenEnterMod, GenResult, GenReturn,
       GenCase1, GenCase2, GenCase3, GenTrap, GenFor1, GenFor2, GenFor3, GenFor4,
       GenStParam, GenStFct, GenEndDecl, InitGenerator, OutCodeFile;


  CONST NL = 27;  (*max name length*)
        NofCases     = 128;
        NofExits      = 16;
        LoopLevels     = 4;
        MaxInt     = 32767;
        EnumTypSize    = 1;
        SetTypSize     = 1;
        PointerTypSize = 1;
        ProcTypSize    = 1;
        DynArrDesSize  = 2;
        StartAddress   = 4;

  VAR ch: CHAR;
      pno, pnoI: CARDINAL;
      isdef, isimp, constFlag: BOOLEAN;
      FileName: ARRAY [0..NL] OF CHAR;
      TM: Time;

  PROCEDURE Type(VAR typ: StrPtr); FORWARD;
  PROCEDURE Expression(VAR x: Item); FORWARD;
  PROCEDURE Block(ancestor: ObjPtr; qual: BOOLEAN;
                  VAR adr: INTEGER; VAR L0: CARDINAL); FORWARD;

  PROCEDURE err(n: CARDINAL);
  BEGIN Mark(n)
  END err;

  PROCEDURE CheckSym(s: Symbol; n: CARDINAL);
  BEGIN
    IF sym = s THEN GetSym ELSE Mark(n) END
  END CheckSym;

  PROCEDURE RefPoint;
    VAR p0, p1: CARDINAL;
  BEGIN GetPos(source, p0, p1); OutPos(p1, pc)
  END RefPoint;

  PROCEDURE qualident(VAR obj: ObjPtr);
  BEGIN (*sym = ident*)
    obj := Find(id); GetSym;
    WHILE (sym = period) & (obj # NIL) & (obj^.class = Module) DO
      GetSym;
      IF sym = ident THEN
        obj := FindInScope(id, obj^.root); GetSym;
        IF (obj # NIL) & NOT obj^.exported THEN obj := NIL END
      ELSE err(10)
      END
    END
  END qualident;

  PROCEDURE ConstExpression(VAR x: Item);
  BEGIN constFlag := TRUE; Expression(x);
    IF x.mode # conMd THEN
      err(44); x.mode := conMd; x.val.C := 1
    END ;
    constFlag := FALSE
  END ConstExpression;

  PROCEDURE CheckComp(t0, t1: StrPtr);
  BEGIN
    IF (t0 # t1) & ((t0 # inttyp) OR (t1 # cardtyp)) THEN err(61) END
  END CheckComp;

  PROCEDURE CaseLabelList(Ltyp: StrPtr;
            VAR n: CARDINAL; VAR tab: ARRAY OF LabelRange);
    VAR x,y: Item; i,j: CARDINAL; f: StrForm;
  BEGIN f := Ltyp^.form;
    IF f = Range THEN Ltyp := Ltyp^.RBaseTyp
    ELSIF (f > Int) & (f # Enum) THEN err(83)
    END ;
    LOOP ConstExpression(x); CheckComp(Ltyp, x.typ);
      IF sym = ellipsis THEN
        GetSym; ConstExpression(y); CheckComp(Ltyp, y.typ);
        IF y.val.I < x.val.I THEN err(63); y := x END
      ELSE y := x
      END ;
      (*enter label range into ordered table*)  i := n;
      IF i < NofCases THEN
        LOOP
          IF i = 0 THEN EXIT END ;
          IF tab[i-1].low <= y.val.I THEN
            IF tab[i-1].high >= x.val.I THEN err(62) END ;
            EXIT
          END ;
          tab[i] := tab[i-1]; i := i-1
        END ;
        WITH tab[i] DO
          low := x.val.I; high := y.val.I; label := pc
        END ;
        n := n+1
      ELSE err(92)
      END ;
      IF sym = comma THEN GetSym
      ELSIF (sym = number) OR (sym = ident) THEN err(11)
      ELSE EXIT
      END
    END
  END CaseLabelList;

  PROCEDURE Subrange(VAR typ: StrPtr);
    VAR x, y: Item; f: StrForm;
  BEGIN typ := NewStr(Range); ConstExpression(x); f := x.typ^.form;
    IF (f <= Int) OR (f = Enum) THEN typ^.min := x.val.I ELSE err(82) END ;
    CheckSym(ellipsis, 21); ConstExpression(y); CheckComp(x.typ, y.typ);
    IF (y.typ = cardtyp) & (y.val.C > MaxInt) THEN err(95) END ;
    WITH typ^ DO max := y.val.I;
      IF min > max THEN err(63); min := max END ;
      RBaseTyp := x.typ; size := x.typ^.size
    END
  END Subrange;

  PROCEDURE SimpleType(VAR typ: StrPtr);
    VAR obj, last: ObjPtr; typ0: StrPtr; n: CARDINAL;
  BEGIN typ := undftyp;
    IF sym = ident THEN
      qualident(obj);
      IF (obj # NIL) & (obj^.class = Typ) THEN typ := obj^.typ
        ELSE err(52)
      END ;
      IF sym = lbrak THEN
        GetSym; typ0 := typ; Subrange(typ);
        IF typ^.RBaseTyp # typ0 THEN
          IF (typ0 = inttyp) & (typ^.RBaseTyp = cardtyp) THEN
            typ^.RBaseTyp := inttyp
          ELSE err(61)
          END
        END ;
        IF sym = rbrak THEN GetSym ELSE err(16);
          IF sym = rparen THEN GetSym END
        END
      END
    ELSIF sym = lparen THEN
      GetSym; typ := NewStr(Enum); last := NIL; n := 0;
      LOOP
        IF sym = ident THEN
          obj := NewObj(id, Const); KeepId;
          obj^.conval.C := n; obj^.conval.prev := last;
          obj^.typ := typ; last := obj; n := n+1; GetSym
        ELSE err(10)
        END ;
        IF sym = comma THEN GetSym
        ELSIF sym = ident THEN err(11)
        ELSE EXIT
        END
      END ;
      WITH typ^ DO
        ConstLink := last; NofConst := n; size := EnumTypSize
      END ;
      CheckSym(rparen, 15)
    ELSIF sym = lbrak THEN
      GetSym; Subrange(typ);
      IF sym = rbrak THEN GetSym ELSE err(16);
        IF sym = rparen THEN GetSym END
      END
    ELSE err(32)
    END
  END SimpleType;

  PROCEDURE FieldListSequence(VAR maxadr: INTEGER; adr: INTEGER);
    VAR fld1, last, tagfldtyp: ObjPtr; typ: StrPtr; size: INTEGER;

    PROCEDURE VariantPart;
      (*variables of Fieldlist used: maxadr, adr*)
      VAR lastadr: INTEGER; N: CARDINAL;
          tab: ARRAY [0..NofCases-1] OF LabelRange;
    BEGIN maxadr := adr; N := 0;
      LOOP
        IF sym < bar THEN CaseLabelList(typ, N, tab);
          CheckSym(colon, 13); FieldListSequence(lastadr, adr);
          IF lastadr > maxadr THEN maxadr := lastadr END
        END ;
        IF sym = bar THEN GetSym ELSE EXIT END
      END ;
      IF sym = else THEN
        GetSym; FieldListSequence(lastadr, adr);
        IF lastadr > maxadr THEN maxadr := lastadr END
      END
    END VariantPart;

  BEGIN typ := undftyp;
    IF (sym = ident) OR (sym = case) THEN
      LOOP
        IF sym = ident THEN last := topScope^.last;
          LOOP
            IF sym = ident THEN
              fld1 := NewObj(id, Field); KeepId; GetSym
            ELSE err(10)
            END ;
            IF sym = comma THEN GetSym
            ELSIF sym = ident THEN err(11)
            ELSE EXIT
            END
          END ;
          CheckSym(colon, 13); Type(typ); size := typ^.size;
          fld1 := last^.next;
          WHILE fld1 # NIL DO
            fld1^.typ := typ; fld1^.offset := adr;
            adr := adr + size; fld1 := fld1^.next
          END
        ELSIF sym = case THEN
          GetSym; fld1 := NIL; tagfldtyp := NIL;
          IF sym = ident THEN
            fld1 := NewObj(id, Field); KeepId; GetSym
          END ;
          CheckSym(colon, 13);
          IF sym = ident THEN qualident(tagfldtyp) ELSE err(10) END ;
          IF (tagfldtyp # NIL) & (tagfldtyp^.class = Typ) THEN
            typ := tagfldtyp^.typ
          ELSE err(52)
          END ;
          IF fld1 # NIL THEN
            fld1^.offset := adr; fld1^.typ := typ;
            adr := adr + typ^.size
          END ;
          CheckSym(of, 23); VariantPart; adr := maxadr;
          CheckSym(end, 20)
        END ;
        IF sym = semicolon THEN GetSym
          ELSIF sym = ident THEN err(12)
          ELSE EXIT
        END
      END
    END ;
    maxadr := adr
  END FieldListSequence;

  PROCEDURE FormalType(VAR typ: StrPtr);
    VAR objtyp: ObjPtr;
  BEGIN typ := undftyp;
    IF sym = array THEN
      GetSym; typ := NewStr(Array);
      WITH typ^ DO
        strobj := NIL; size := DynArrDesSize; dyn := TRUE
      END ;
      CheckSym(of, 23);
      IF sym = ident THEN
        qualident(objtyp);
        IF (objtyp # NIL) & (objtyp^.class = Typ) THEN
          typ^.ElemTyp := objtyp^.typ
        ELSE err(52)
        END
      ELSE err(10)
      END
    ELSIF sym = ident THEN
      qualident(objtyp);
      IF (objtyp # NIL) & (objtyp^.class = Typ) THEN
        typ := objtyp^.typ
      ELSE err(52)
      END
    ELSE err(10)
    END
  END FormalType;

  PROCEDURE FormalTypeList(proctyp: StrPtr);
    VAR obj: ObjPtr; par, par0, par1: ParPtr; isvar: BOOLEAN;
  BEGIN par := NIL;
    IF (sym = ident) OR (sym = var) OR (sym = array) THEN
      LOOP
        IF sym = var THEN GetSym; isvar := TRUE ELSE isvar := FALSE END ;
        par := NewPar(0, isvar, par); FormalType(par^.typ);
        IF sym = comma THEN GetSym
        ELSIF sym = ident THEN err(11)
        ELSE EXIT
        END
      END
    END ;
    CheckSym(rparen, 15);
    par1 := NIL; (*reverse list*)
    WHILE par # NIL DO
      par0 := par; par := par0^.next; par0^.next := par1; par1 := par0
    END ;
    proctyp^.firstPar := par1;
    IF sym = colon THEN
      GetSym; proctyp^.resTyp := undftyp;
      IF sym = ident THEN qualident(obj);
        IF (obj # NIL) & (obj^.class = Typ) THEN proctyp^.resTyp := obj^.typ
          ELSE err(52)
        END
      ELSE err(10)
      END
    ELSE proctyp^.resTyp := notyp
    END
  END FormalTypeList;

  PROCEDURE ArrayType(VAR typ: StrPtr);
    VAR a,b: INTEGER;
  BEGIN typ := NewStr(Array); typ^.dyn := FALSE; a := 0;
    SimpleType(typ^.IndexTyp);
    WITH typ^.IndexTyp^ DO
      IF form # Range THEN
        err(94); form := Range; RBaseTyp := cardtyp; min := 0; max := 0
      END ;
      a := min; b := max
    END ;
    IF sym = of THEN
      GetSym; Type(typ^.ElemTyp)
    ELSIF sym = comma THEN
      GetSym; ArrayType(typ^.ElemTyp)
    ELSE err(23)
    END ;
    IF b >= 0 THEN
      IF b - MaxInt >= a THEN err(210); a := b END
    ELSIF a < 0 THEN
      IF b >= a + MaxInt THEN err(210); a := b END
    END ;
    a := b-a+1; b := typ^.ElemTyp^.size;
    IF typ^.ElemTyp^.form = Char THEN a := (a+1) DIV 2
    ELSIF MaxInt DIV b >= a THEN a := a*b
    ELSE err(210); a := 1
    END ;
    typ^.size := a
  END ArrayType;

  PROCEDURE Type(VAR typ: StrPtr);
    VAR obj: ObjPtr; btyp: StrPtr;
  BEGIN
    IF sym < lparen THEN err(33);
      REPEAT GetSym UNTIL sym >= lparen
    END ;
    IF sym = array THEN
      GetSym; ArrayType(typ)
    ELSIF sym = record THEN
      GetSym; typ := NewStr(Record); NewScope(Typ);
      FieldListSequence(typ^.size, 0); typ^.firstFld := topScope^.next;
      CheckSym(end, 20); CloseScope
    ELSIF sym = set THEN
      GetSym; CheckSym(of, 23);
      typ := NewStr(Set); SimpleType(typ^.SBaseTyp);
      btyp := typ^.SBaseTyp;
      IF btyp^.form = Enum THEN
        IF btyp^.NofConst > WordSize THEN err(209) END
      ELSIF btyp^.form = Range THEN
        IF (btyp^.min < 0) OR (btyp^.max >= WordSize) THEN err(209) END
      ELSE err(60)
      END ;
      typ^.size := SetTypSize
    ELSIF sym = pointer THEN
      GetSym; typ := NewStr(Pointer);
      typ^.BaseId := 0; typ^.size := PointerTypSize; CheckSym(to, 24);
      IF sym = ident THEN qualident(obj);
        IF obj = NIL THEN typ^.BaseId := id; KeepId (*forward ref*)
        ELSIF obj^.class = Typ THEN typ^.PBaseTyp := obj^.typ
        ELSE err(52)
        END
      ELSE Type(typ^.PBaseTyp)
      END
    ELSIF sym = procedure THEN
      GetSym; typ := NewStr(ProcTyp); typ^.size := ProcTypSize;
      IF sym = lparen THEN
        GetSym; FormalTypeList(typ)
      ELSE typ^.resTyp := notyp
      END
    ELSE
      SimpleType(typ)
    END ;
    IF (sym < semicolon) OR (else < sym) THEN err(34);
      WHILE (sym < ident) OR (else < sym) & (sym < begin) DO
        GetSym
      END
    END
  END Type;


  PROCEDURE selector(VAR x: Item; obj: ObjPtr);
    VAR y: Item;
  BEGIN GenItem(x, obj, Scope);
    LOOP
      IF sym = lbrak THEN GetSym;
        LOOP loadAdr(x); Expression(y); GenIndex(x, y);
          IF sym = comma THEN GetSym ELSE EXIT END
        END ;
        CheckSym(rbrak, 16)
      ELSIF sym = period THEN
        GetSym;
        IF sym = ident THEN
          IF (x.typ # NIL) & (x.typ^.form = Record) THEN
            obj := FindInScope(id, x.typ^.firstFld); GenField(x, obj)
          ELSE err(57)
          END ;
          GetSym
        ELSE err(10)
        END
      ELSIF sym = arrow THEN
        GetSym; GenDeRef(x)
      ELSE EXIT
      END
    END
  END selector;

  PROCEDURE ActualParameters(VAR x: Item; fpar: ParPtr);
    VAR apar: Item;
  BEGIN
    IF sym # rparen THEN
      LOOP Expression(apar);
        IF fpar # NIL THEN
          GenParam(apar, fpar); fpar := fpar^.next
        ELSE err(64)
        END ;
        IF sym = comma THEN GetSym
        ELSIF (lparen <= sym) & (sym <= ident) THEN GetSym; err(11)
        ELSE EXIT
        END
      END
    END ;
    IF fpar # NIL THEN err(65) END
  END ActualParameters;

  PROCEDURE StandProcCall(VAR p: Item);
    VAR x: Item; m, n: CARDINAL;
  BEGIN m := p.cod^.cnum; n := 0;
    IF m = 1 THEN GenTrap(10); p.typ := notyp ELSE
      CheckSym(lparen, 22);
      LOOP Expression(x); GenStParam(p, x, m, n); n := n+1;
        IF sym = comma THEN GetSym ELSIF sym # ident THEN EXIT END
      END ;
      CheckSym(rparen, 15); GenStFct(p, m, n)
    END
  END StandProcCall;

  PROCEDURE Element(VAR x: Item);
    VAR e1, e2: Item;
  BEGIN Expression(e1);
    IF sym = ellipsis THEN GetSym;
      IF e1.mode = conMd THEN Expression(e2);
        IF e2.mode # conMd THEN err(90) END
      ELSE load(e1); Expression(e2)
      END ;
      GenSet(x, e1, e2)
    ELSE GenSingSet(x, e1)
    END ;
  END Element;

  PROCEDURE Sets(VAR x: Item; styp: StrPtr);
    VAR y: Item;
  BEGIN x.typ := styp; y.typ := styp;
    IF sym # rbrace THEN
      Element(x);
      LOOP
        IF sym = comma THEN GetSym
        ELSIF (lparen <= sym) & (sym <= ident) THEN err(11)
        ELSE EXIT
        END ;
        Element(y); GenOp(ORD(plus), x, y)
      END
    ELSE x.mode := conMd; x.val.S := {}
    END ;
    CheckSym(rbrace, 17)
  END Sets;

  PROCEDURE Factor(VAR x: Item);
    VAR obj: ObjPtr; xt: StrPtr; fpar: ParPtr;
  BEGIN
    IF sym < lparen THEN err(31);
      REPEAT GetSym UNTIL sym >= lparen
    END ;
    IF sym = ident THEN
      qualident(obj);
      IF sym = lbrace THEN
        GetSym;
        IF (obj # NIL) & (obj^.class = Typ) &
           (obj^.typ^.form = Set) THEN Sets(x, obj^.typ)
        ELSE err(52); Sets(x, bitstyp)
        END
      ELSE
        selector(x, obj);
        IF (x.mode = codMd) & (x.cod^.cnum > 0) THEN StandProcCall(x)
        ELSIF sym = lparen THEN GetSym;
          IF x.mode = typMd THEN (*type transfer function*)
            xt := x.typ; Expression(x); load(x); (*may be chartyp!*)
            IF xt^.size # x.typ^.size THEN err(81) END ;
            x.typ := xt
          ELSE PrepCall(x, fpar); ActualParameters(x, fpar); GenCall(x)
          END ;
          CheckSym(rparen, 15)
        END
      END
    ELSIF sym = number THEN
      GetSym; x.mode := conMd;
      CASE numtyp OF
        1: x.typ := cardtyp; x.val.C := intval |
        2: x.typ := dbltyp;  x.val.D := dblval |
        3: x.typ := chartyp; x.val.C := intval |
        4: x.typ := realtyp; x.val.R := realval
      END
    ELSIF sym = string THEN
      x.typ := stringtyp; x.mode := conMd;
      AllocString(id, x.val.D0, x.val.D1); GetSym
    ELSIF sym = lparen THEN
      GetSym; Expression(x); CheckSym(rparen, 15)
    ELSIF sym = lbrace THEN GetSym; Sets(x, bitstyp)
    ELSIF sym = not THEN
      GetSym; Factor(x); GenNot(x)
    ELSE err(31); x.typ := undftyp; x.mode := expMd
    END
  END Factor;

  PROCEDURE Term(VAR x: Item);
    VAR y: Item; mulop: Symbol;
  BEGIN Factor(x);
    IF sym = and THEN
      GetSym; GenAnd(x); Term(y); GenOp(ORD(and), x, y)
    ELSE
      WHILE (times <= sym) & (sym < and) DO
        mulop := sym; GetSym;
        IF ~constFlag & ((x.mode # conMd) OR (mulop # times)) THEN load(x) END ;
        Factor(y); GenOp(ORD(mulop), x, y)
      END
    END
  END Term;

  PROCEDURE SimpleExpression(VAR x: Item);
    VAR y: Item; addop: Symbol;
  BEGIN
    IF sym = minus THEN
      GetSym; Term(x); GenNeg(x)
    ELSE
      IF sym = plus THEN GetSym END ;
      Term(x)
    END ;
    IF sym = or THEN
      GetSym; GenOr(x); SimpleExpression(y); GenOp(ORD(or), x, y)
    ELSE
      WHILE (plus <= sym) & (sym < or) DO
        addop := sym; GetSym;
        IF ~constFlag & ((x.mode # conMd) OR (addop = minus)) THEN load(x) END ;
        Term(y); GenOp(ORD(addop), x, y)
      END
    END
  END SimpleExpression;

  PROCEDURE Expression(VAR x: Item);
    VAR y: Item; relation: Symbol;
  BEGIN SimpleExpression(x);
    IF (eql <= sym) & (sym <= geq) THEN
      relation := sym; GetSym;
      IF ~constFlag THEN load(x) END ;
      SimpleExpression(y); GenOp(ORD(relation), x, y)
    ELSIF sym = in THEN GetSym;
      IF ~constFlag THEN load(x) END ;
      SimpleExpression(y); GenIn(x, y)
    END
  END Expression;

  PROCEDURE Priority;
    VAR x: Item;
  BEGIN
    IF sym = lbrak THEN
      GetSym; ConstExpression(x);
      IF (x.typ = cardtyp) & (x.val.C < 16) THEN curPrio := x.val.C + 1
        ELSE err(147)
      END ;
      CheckSym(rbrak, 16)
    END
  END Priority;

  PROCEDURE ImportList(impmod: ObjPtr);
    VAR obj: ObjPtr;
  BEGIN
    IF (impmod # NIL) & (impmod^.class # Module) THEN
      impmod := NIL; err(55)
    END ;
    LOOP
      IF sym = ident THEN
        IF impmod = NIL THEN obj := FindImport(id)
        ELSE obj := FindInScope(id, impmod^.root);
          IF (obj # NIL) & NOT obj^.exported THEN obj := NIL END
        END ;
        IF obj # NIL THEN NewImp(topScope, obj) ELSE err(50) END ;
        GetSym
      ELSE err(10)
      END ;
      IF sym = comma THEN GetSym
      ELSIF sym = ident THEN err(11)
      ELSE EXIT
      END
    END ;
    CheckSym(semicolon, 12)
  END ImportList;

  PROCEDURE ExportList;
    VAR obj: ObjPtr;
  BEGIN
    LOOP
      IF sym = ident THEN
        obj := NewObj(id, Temp); KeepId; GetSym
      ELSE err(10)
      END ;
      IF sym = comma THEN GetSym
      ELSIF sym = ident THEN err(11)
      ELSE EXIT
      END
    END ;
    CheckSym(semicolon, 12)
  END ExportList;

  PROCEDURE FormalParameters(proc: ObjPtr);
    VAR isvar: BOOLEAN;
        par, par0, par1: ParPtr; typ0: StrPtr;
  BEGIN par := NIL;
    IF (sym = ident) OR (sym = var) THEN
      LOOP par1 := par; isvar := FALSE;
        IF sym = var THEN GetSym; isvar := TRUE END ;
        LOOP
          IF sym = ident THEN
            par := NewPar(id, isvar, par); KeepId; GetSym
          ELSE err(10)
          END ;
          IF sym = comma THEN GetSym
          ELSIF sym = ident THEN err(11)
          ELSIF sym = var THEN err(11); GetSym
          ELSE EXIT
          END
        END ;
        CheckSym(colon, 13); FormalType(typ0); par0 := par;
        WHILE par0 # par1 DO
          par0^.typ := typ0; par0 := par0^.next
        END ;
        IF sym = semicolon THEN GetSym
        ELSIF sym = ident THEN err(12)
        ELSE EXIT
        END
      END
    END ;
    par1 := NIL; (*reverse list*)
    WHILE par # NIL DO
      par0 := par; par := par0^.next; par0^.next := par1; par1 := par0
    END ;
    proc^.firstParam := par1;
    CheckSym(rparen, 15)
  END FormalParameters;

  PROCEDURE CheckParameters(proc: ObjPtr);
    VAR isvar: BOOLEAN;
        par, par0, par1: ParPtr; typ0: StrPtr;
  BEGIN par0 := proc^.firstParam;
    IF (sym = ident) OR (sym = var) THEN
      LOOP par1 := par0; isvar := FALSE;
        IF sym = var THEN GetSym; isvar := TRUE END ;
        LOOP
          IF sym = ident THEN
            IF par0 # NIL THEN par0^.name := id; par0 := par0^.next
              ELSE err(66)
            END ;
            KeepId; GetSym
          ELSE err(10)
          END ;
          IF sym = comma THEN GetSym
          ELSIF sym = ident THEN err(11)
          ELSIF sym = var THEN err(11); GetSym
          ELSE EXIT
          END
        END ;
        CheckSym(colon, 13); FormalType(typ0); par := par1;
        WHILE par # par0 DO
          IF (par^.typ # typ0) &
            ((par^.typ^.form # Array) OR (typ0^.form # Array) OR
             (par^.typ^.ElemTyp # typ0^.ElemTyp)) THEN err(69)
          END ;
          IF par^.varpar # isvar THEN err(68) END ;
          par := par^.next
        END ;
        IF sym = semicolon THEN GetSym
        ELSIF sym = ident THEN err(12)
        ELSE EXIT
        END
      END
    END ;
    IF par0 # NIL THEN err(70) END ;
    CheckSym(rparen, 15)
  END CheckParameters;

  PROCEDURE MakeParameterObjects(proc: ObjPtr; VAR adr: INTEGER);
    VAR par: ParPtr; obj: ObjPtr; typ0: StrPtr; addr: INTEGER;
  BEGIN par := proc^.firstParam; addr := StartAddress;
    WHILE par # NIL DO
      obj := NewObj(par^.name, Var); par^.name := addr;
      (*address used when unstacking parameters*)
      WITH obj^ DO
        typ := par^.typ; vmod := 0; vlev := curLev; vadr := addr;
        IF par^.varpar THEN param := {1} ELSE param := {0} END
      END ;
      IF addr > 255 THEN err(99); addr := 0 END ;
      typ0 := par^.typ;
      IF (typ0^.form = Array) & typ0^.dyn THEN
        addr := addr + DynArrDesSize
      ELSIF par^.varpar THEN addr := addr + PointerTypSize
      ELSIF typ0^.size <= 2 THEN addr := addr + typ0^.size
      ELSE addr := addr+1
      END ;
      par := par^.next
    END ;
    adr := addr
  END MakeParameterObjects;

  PROCEDURE ProcedureDeclaration(VAR proc: ObjPtr);
    VAR i, L0: CARDINAL; adr: INTEGER; res: ObjPtr;
  BEGIN
    IF curLev = 0 THEN proc := Find(id) ELSE proc := NIL END ;
    IF (proc # NIL) & (proc^.class = Proc) &
       (proc^.pmod = 0) & (proc^.pd^.adr = 0) THEN
      (*procedure heading in definition module or forward declaration*)
      CheckSym(ident, 10);
      IF sym = lparen THEN
        GetSym; CheckParameters(proc);
        IF sym = colon THEN GetSym;
          IF sym = ident THEN qualident(res);
            IF (res = NIL) OR (res^.class # Typ) OR (res^.typ # proc^.typ) THEN
              err(71)
            END
          ELSE err(10)
          END
        ELSIF proc^.typ # notyp THEN err(72)
        END
      ELSIF proc^.firstParam # NIL THEN err(73)
      END
    ELSE
      proc := NewObj(id, Proc); KeepId; pno := pno + 1;
      WITH proc^ DO
        pmod := 0; typ := notyp; firstParam := NIL;
        pd^.num := pno; pd^.lev := curLev; pd^.adr := 0
      END ;
      CheckSym(ident, 10);
      IF sym = lparen THEN
        GetSym; FormalParameters(proc);
        IF sym = colon THEN
          GetSym; proc^.typ := undftyp;
          IF sym = ident THEN qualident(res);
            IF (res # NIL) & (res^.class = Typ) THEN proc^.typ := res^.typ
            ELSE err(52)
            END
          ELSE err(10)
          END
        END
      END
    END ;
    IF NOT isdef THEN
      CheckSym(semicolon, 12); MarkHeap;
      NewScope(Proc); curLev := curLev + 1;
      MakeParameterObjects(proc, adr);
      IF sym = code THEN GetSym;
        IF proc^.pd^.num > pnoI THEN pno := pno - 1;
        ELSE (*this procedure declared in definition module*) err(74)
        END ;
        i := 0;
        LOOP
          IF sym = number THEN GetSym;
            IF (i < MaxCodeLength) & (numtyp = 1) & (intval < 400B) THEN
              proc^.cd^.cod[i] := CHAR(intval); i := i+1
            ELSE err(91)
            END
          END ;
          IF sym = semicolon THEN GetSym
          ELSIF sym = number THEN err(12)
          ELSE EXIT
          END
        END ;
        WITH proc^ DO
          class := Code; (*!!!*) cnum := 0; length := i
        END ;
        CheckSym(end, 20);
        IF sym = ident THEN
          IF Diff(id, proc^.name) # 0 THEN err(77) END ;
          GetSym
        ELSE err(10)
        END
      ELSIF sym = forward THEN GetSym
      ELSE proc^.pd^.adr := pc;
        Block(proc, FALSE, adr, L0);
        IF proc^.typ = notyp THEN GenReturn ELSE GenTrap(9) END ;
        FixupEnter(L0, adr)
      END ;
      CloseScope; curLev := curLev - 1; ReleaseHeap
    ELSE proc^.pd^.size := adr; proc^.pd^.adr := 0
    END
  END ProcedureDeclaration;

  PROCEDURE ModuleDeclaration(VAR mod: ObjPtr; VAR adr: INTEGER);
    VAR L0, prio: CARDINAL; qual: BOOLEAN; impmod: ObjPtr;
  BEGIN qual := FALSE; CheckSym(ident, 10);
    mod := NewObj(id, Module); KeepId;
    pno := pno + 1; mod^.modno := pno; prio := curPrio; Priority;
    CheckSym(semicolon, 12); NewScope(Module);
    WHILE (sym = from) OR (sym = import) DO impmod := NIL;
      IF sym = from THEN GetSym;
        IF sym = ident THEN
          impmod := FindImport(id); GetSym
        ELSE err(10)
        END ;
        CheckSym(import, 30)
      ELSE GetSym
      END ;
      ImportList(impmod)
    END ;
    IF sym = export THEN GetSym;
      IF sym = qualified THEN GetSym; qual := TRUE END ;
      ExportList
    END ;
    Block(mod, qual, adr, L0); GenReturn;
    CloseScope; curPrio := prio; curLev := curLev - 1
  END ModuleDeclaration;


  MODULE Loops;
    IMPORT fixup, err, LoopLevels, NofExits;
    EXPORT EnterLoop, RecordExit, ExitLoop;

    VAR h,k: CARDINAL;
        index: ARRAY [0..LoopLevels-1] OF CARDINAL;
        label: ARRAY [0..NofExits-1] OF CARDINAL;

    PROCEDURE EnterLoop;
    BEGIN index[h] := k; h := h+1
    END EnterLoop;

    PROCEDURE RecordExit(L: CARDINAL);
    BEGIN
      IF h = 0 THEN err(39)
      ELSIF k < NofExits THEN label[k] := L; k := k+1
      ELSE err(93)
      END
    END RecordExit;

    PROCEDURE ExitLoop;
    BEGIN h := h-1;
      WHILE k > index[h] DO k := k-1; fixup(label[k]) END
    END ExitLoop;

  BEGIN h := 0; k := 0
  END Loops;

  PROCEDURE Block(ancestor: ObjPtr; qual: BOOLEAN;
                  VAR adr: INTEGER; VAR L0: CARDINAL);
    VAR obj, last: ObjPtr; newtypdef: BOOLEAN;
        id0: CARDINAL; x: Item; typ: StrPtr;

  PROCEDURE StatSeq;
    VAR obj: ObjPtr; fpar: ParPtr; x, y: Item; L0, L1: CARDINAL;

    PROCEDURE ElsePart;
      VAR L0, L1: CARDINAL;
    BEGIN
      IF (sym = elsif) OR (sym = bar) THEN
        GetSym; Expression(x); GenCFJ(x, L0);
        CheckSym(then, 27); StatSeq;
        IF sym = end THEN fixup(L0)
          ELSE GenFJ(L1); fixup(L0); ElsePart; fixup(L1)
        END
      ELSIF sym = else THEN
        GetSym; StatSeq
      END
    END ElsePart;

    PROCEDURE CasePart;
      VAR x: Item; n, L0, L1: CARDINAL;
          tab:  ARRAY [0..NofCases-1] OF LabelRange;
    BEGIN n := 0;
      Expression(x); GenCase1(x, L0); CheckSym(of, 23);
      LOOP
        IF sym < bar THEN
          CaseLabelList(x.typ, n, tab);
          CheckSym(colon, 13); StatSeq; GenCase2
        END ;
        IF sym = bar THEN GetSym ELSE EXIT END
      END ;
      L1 := pc;
      IF sym = else THEN
        GetSym; StatSeq; GenCase2
      ELSE GenTrap(4)
      END ;
      RefPoint; GenCase3(L0, L1, n, tab)
    END CasePart;

    PROCEDURE ForPart;
      VAR obj: ObjPtr;
          v, e1, e2, e3: Item;
          L0, L1: CARDINAL;
    BEGIN obj := NIL;
      IF sym = ident THEN
        obj := Find(id);
        IF obj # NIL THEN
          IF (obj^.class # Var) OR (obj^.param # {}) OR
             (obj^.vmod > 0) THEN err(75) END
        ELSE err(50)
        END ;
        GetSym
      ELSE err(10)
      END ;
      GenItem(v, obj, Scope); loadAdr(v);
      IF sym = becomes THEN GetSym ELSE err(19);
        IF sym = eql THEN GetSym END
      END ;
      Expression(e1); GenFor1(v,e1);
      CheckSym(to, 24); Expression(e2); GenFor2(v,e2);
      IF sym = by THEN
        GetSym; ConstExpression(e3)
      ELSE e3.typ := inttyp; e3.mode := conMd; e3.val.I := 1
      END ;
      GenFor3(e3, L0, L1);
      CheckSym(do, 25); StatSeq; GenFor4(e3, L0, L1)
    END ForPart;

  BEGIN
    LOOP
      IF sym < ident THEN err(35);
        REPEAT GetSym UNTIL sym >= ident
      END ;
      IF sym = ident THEN
        RefPoint; qualident(obj); selector(x, obj);
        IF sym = becomes THEN
          GetSym; PrepAss(x); Expression(y); GenAssign(x, y)
        ELSIF sym = eql THEN
          err(19); GetSym; PrepAss(x); Expression(y); GenAssign(x, y)
        ELSIF (x.mode = codMd) & (x.cod^.cnum > 0) THEN
          StandProcCall(x);
          IF x.typ # notyp THEN err(76) END
        ELSE PrepCall(x, fpar);
          IF sym = lparen THEN
            GetSym; ActualParameters(x, fpar); CheckSym(rparen, 15)
          ELSIF fpar # NIL THEN err(65)
          END ;
          GenCall(x);
          IF x.typ # notyp THEN err(76) END
        END
      ELSIF sym = if THEN
        GetSym; RefPoint; Expression(x); GenCFJ(x, L0);
        CheckSym(then, 27); StatSeq;
        IF sym = end THEN fixup(L0)
          ELSE GenFJ(L1); fixup(L0); ElsePart; fixup(L1)
        END ;
        CheckSym(end, 20)
      ELSIF sym = case THEN
        GetSym; RefPoint; CasePart; CheckSym(end, 20)
      ELSIF sym = while THEN
        GetSym; L1 := pc; RefPoint; Expression(x); GenCFJ(x, L0);
        CheckSym(do, 25); StatSeq; GenBJ(L1); fixup(L0);
        WHILE sym = bar DO
          GetSym; RefPoint; Expression(x); GenCFJ(x, L0);
          CheckSym(do, 25); StatSeq; GenBJ(L1); fixup(L0)
        END ;
        CheckSym(end, 20)
      ELSIF sym = repeat THEN
        GetSym; L0 := pc; StatSeq;
        IF sym = until THEN
          GetSym; RefPoint; Expression(x); GenCBJ(x, L0)
        ELSE err(26)
        END
      ELSIF sym = loop THEN
        GetSym; EnterLoop; L0 := pc; StatSeq; GenBJ(L0); ExitLoop;
        CheckSym(end, 20)
      ELSIF sym = for THEN
        GetSym; RefPoint; ForPart; CheckSym(end, 20)
      ELSIF sym = with THEN
        GetSym; x.typ := NIL;
        IF sym = ident THEN
          qualident(obj); selector(x, obj);
          IF (x.typ # NIL) & (x.typ^.form = Record) THEN
            NewScope(Typ); GenWith(x, adr);
            topScope^.withadr := adr; topScope^.right := x.typ^.firstFld;
            IF adr > 255 THEN err(99); adr := 0 END ;
            adr := adr + 1   (*allocate anonymous variable for address*)
          ELSE err(57); x.typ := NIL
          END
        ELSE err(10)
        END ;
        CheckSym(do, 25); StatSeq; CheckSym(end, 20);
        IF x.typ # NIL THEN CloseScope END
      ELSIF sym = exit THEN
        GetSym; GenFJ(L0); RecordExit(L0)
      ELSIF sym = return THEN GetSym;
        IF sym < semicolon THEN
          Expression(x); GenResult(x, ancestor)
        ELSIF ancestor^.typ # notyp THEN err(139)
        END ;
        GenReturn
      END ;
      CheckStack;
      IF sym = semicolon THEN GetSym
      ELSIF (sym <= ident) OR (if <= sym) & (sym <= for) THEN err(12)
      ELSE EXIT
      END
    END
  END StatSeq;

  PROCEDURE CheckExports(obj: ObjPtr);
  BEGIN
    IF obj # NIL THEN
      IF obj^.class = Temp THEN err(80)
      ELSIF ~qual & obj^.exported THEN (*import in outer scope*)
        NewImp(topScope^.left, obj)
      END ;
      CheckExports(obj^.left); CheckExports(obj^.right)
    END
  END CheckExports;

  BEGIN (*Block*)
    LOOP
      IF sym = const THEN
        GetSym;
        WHILE sym = ident DO
          id0 := id; KeepId; GetSym;
          IF sym = eql THEN
            GetSym; ConstExpression(x)
          ELSIF sym = becomes THEN
            err(18); GetSym; ConstExpression(x)
          ELSE err(18)
          END ;
          obj := NewObj(id0, Const); obj^.typ := x.typ; obj^.conval := x.val;
          IF x.typ = stringtyp THEN obj^.conval.D2 := id; KeepId END ;
          CheckSym(semicolon, 12)
        END
      ELSIF sym = type THEN
        GetSym;
        WHILE sym = ident DO
          typ := undftyp; obj := NIL; newtypdef := TRUE;
          IF isimp & (curLev = 0) THEN
            obj := Find(id);
            IF (obj # NIL) & (obj^.class = Typ) & (obj^.typ^.form = Opaque) THEN
              newtypdef := FALSE
            END
          END ;
          IF newtypdef THEN id0 := id; KeepId END ;
          GetSym;
          IF sym = eql THEN
            GetSym; Type(typ)
          ELSIF (sym = becomes) OR (sym = colon) THEN
            err(18); GetSym; Type(typ)
          ELSIF NOT isdef THEN err(18)
          ELSE typ := NewStr(Opaque); typ^.size := PointerTypSize
          END ;
          IF newtypdef THEN
            obj := NewObj(id0, Typ); obj^.typ := typ; obj^.mod := mainmod;
            IF typ^.strobj = NIL THEN typ^.strobj := obj END ;
          ELSIF typ^.size = PointerTypSize THEN obj^.typ^ := typ^
          ELSE err(87)
          END ;
          CheckUDP(obj, topScope^.right);  (*check for undefined pointer types*)
          CheckSym(semicolon, 12)
        END
      ELSIF sym = var THEN
        GetSym;
        WHILE sym = ident DO last := topScope^.last; obj := last;
          LOOP
            IF sym = ident THEN
              obj := NewObj(id, Var); KeepId; GetSym
            ELSE err(10)
            END ;
            IF sym = comma THEN GetSym
            ELSIF sym = ident THEN err(11)
            ELSE EXIT
            END
          END ;
          CheckSym(colon, 13); Type(typ);
          WHILE last # obj DO
            last := last^.next; last^.typ := typ;
            WITH last^ DO
              param := {}; vmod := 0; vlev := curLev; vadr := adr
            END ;
            IF typ^.size <= 2 THEN adr := adr + typ^.size
            ELSE adr := adr + 1
            END ;
            IF adr > 255 THEN err(99); adr := 0 END
          END ;
          CheckSym(semicolon, 12)
        END
      ELSIF sym = procedure THEN
        GetSym; ProcedureDeclaration(obj); CheckSym(semicolon, 12)
      ELSIF sym = module THEN
        GetSym; ModuleDeclaration(obj, adr); CheckSym(semicolon, 12)
      ELSE
        IF (sym # begin) & (sym # end) THEN err(36);
          REPEAT GetSym UNTIL (sym >= begin) OR (sym = end)
        END ;
        IF (sym <= begin) OR (sym = eof) THEN EXIT END
      END
    END ;

    IF ancestor^.class = Module THEN
      ancestor^.firstObj := topScope^.next; ancestor^.root := topScope^.right;
      IF ancestor = mainmod THEN
        fixupC(L0); GenEndDecl(ancestor, ModNo)
      ELSE CheckExports(topScope^.right);
        curLev := curLev + 1; GenEnterMod(ancestor)
      END
    ELSE (*procedure*) ancestor^.firstLocal := topScope^.next;
      GenEnter(L0, ancestor); GenEndDecl(ancestor, 0)
    END ;
    IF sym = begin THEN
      IF isdef THEN err(37) END ;
      GetSym; StatSeq; RefPoint
    END ;
    CheckSym(end, 20); OutUnit(ancestor);
    IF sym = ident THEN
      IF Diff(id, ancestor^.name) # 0 THEN err(77) END ;
      GetSym
    ELSE err(10)
    END
  END Block;

  PROCEDURE CompilationUnit;
    VAR id0, L0: CARDINAL; adr: INTEGER;
        hdr, importMod: ObjPtr; impok: BOOLEAN;
        FName: ARRAY [0..NL] OF CHAR;

    PROCEDURE GetFileName(j: CARDINAL;
              VAR FName: ARRAY OF CHAR; ext: ARRAY OF CHAR);
      VAR i,L: CARDINAL;
    BEGIN i := 3; L := CARDINAL(IdBuf[j]) + j-1;
      WHILE j < L DO
        j := j+1; FName[i] := IdBuf[j]; i := i+1
      END ;
      j := 0; L := HIGH(ext);
      WHILE j <= L DO
       FName[i] := ext[j]; i := i+1; j := j+1
      END ;
      FName[i] := 0C
    END GetFileName;

    PROCEDURE ImportModule;
      VAR adr: INTEGER; pno: CARDINAL;
    BEGIN
      IF sym = ident THEN
        IF Diff(id, sysmod^.name) = 0 THEN importMod := sysmod
        ELSE GetFileName(id, FileName, ".SBL"); WriteLn;
          WriteString(" - "); WriteString(FileName);
          InRef(FileName, hdr, adr, pno);
          IF hdr # NIL THEN importMod := hdr^.right
          ELSE impok := FALSE;
            importMod := NIL; WriteString(" not found (or bad)")
          END
        END ;
        GetSym
      ELSE err(10)
      END ;
    END ImportModule;

    PROCEDURE Out(n: CARDINAL);
      VAR k: CARDINAL; d: ARRAY [0..5] OF CARDINAL;
    BEGIN k := 0; Write(" ");
      REPEAT d[k] := n MOD 10; n := n DIV 10; k := k+1 UNTIL n = 0;
      REPEAT k := k-1; Write(CHAR(d[k]+60B)) UNTIL k = 0
    END Out;

    PROCEDURE CheckUDProc(obj: ObjPtr);
    BEGIN (*check for undefined procedure bodies*)
      WHILE obj # NIL DO
        IF (obj^.class = Proc) & (obj^.pmod = 0) &
           (obj^.pd^.adr = 0) THEN err(89)
        END ;
        obj := obj^.next
      END
    END CheckUDProc;

  BEGIN isdef := FALSE; isimp := FALSE; impok := TRUE;
    curLev := 0; curPrio := 0; constFlag := FALSE;
    FName := "DK."; GetSym;
    IF sym = definition THEN GetSym; isdef := TRUE
    ELSIF sym = implementation THEN GetSym; isimp := TRUE
    END ;
    IF sym = module THEN
      GetSym;
      IF sym = ident THEN
        id0 := id; mainmod^.name := id0; KeepId; GetSym;
        IF NOT isdef THEN Priority END ;
        CheckSym(semicolon, 12); MarkHeap; NewScope(Module);
        IF isimp THEN
          GetFileName(id0, FName, ".SBL"); WriteLn;
          WriteString(" - "); WriteString(FName);
          InRef(FName, hdr, adr, pno);
          IF hdr # NIL THEN importMod := hdr^.right;
               topScope^.right := importMod^.root;  (*mainmod*)
               topScope^.next := hdr^.next; topScope^.last := hdr^.last
          ELSE importMod := NIL;
            WriteString(" not found (or bad)"); impok := FALSE
          END
        ELSE adr := 3; pno := 0; mainmod^.key := sysmod^.key
        END ;
        WHILE (sym = from) OR (sym = import) DO
          IF sym = from THEN
            GetSym; ImportModule; CheckSym(import, 30);
            ImportList(importMod)
          ELSE (*sym = import*) GetSym;
            LOOP ImportModule;
              IF importMod # NIL THEN NewImp(topScope, importMod) END ;
              IF sym = comma THEN GetSym
              ELSIF sym # ident THEN EXIT
              END
            END ;
            CheckSym(semicolon, 12)
          END
        END ;
        IF sym = export THEN
          GetSym; err(38);
          WHILE sym # semicolon DO GetSym END ;
          GetSym
        END ;
        IF impok THEN
          pnoI := pno;
          IF isdef THEN GetFileName(id0, FName, ".SBL")
            ELSE GetFileName(id0, FName, ".RFC")
          END ;
          WriteLn; WriteString(" + "); WriteString(FName);
          Lookup(RefFile, FName, TRUE);
          IF RefFile.res # done THEN err(222) END ;
          OpenRef; GenFJ(L0); Block(mainmod, TRUE, adr, L0);
          IF sym # period THEN err(14) END ;
          IF NOT isdef THEN CheckUDProc(mainmod^.firstObj) END ;
          IF NOT scanerr THEN
            IF NOT isdef THEN
              GetFileName(id0, FName, ".OBJ"); WriteLn;
              WriteString(" + "); WriteString(FName); Out(pc);
              OutCodeFile(FName, mainmod^.key, adr, pno+1, id0, ModNo, ModList)
            END ;
            CloseRef(adr, pno); Close(RefFile)
          ELSE 
            Rename(RefFile, "");
          END
        END ;
        CloseScope; ReleaseHeap
      ELSE err(10)
      END ;
    ELSE err(28)
    END ;
    IF scanerr THEN WriteString(" errors detected") END
  END CompilationUnit;


  PROCEDURE ReadName;
    CONST DEL = 177C;
    VAR i: CARDINAL;
  BEGIN
    REPEAT Read(ch) UNTIL (ch >= "A") OR (ch = 33C);
    FileName := "DK."; i := 3;
    WHILE (CAP(ch) >= "A") & (CAP(ch) <= "Z")
       OR (ch >= "0") & (ch <= "9")
       OR (ch = ".") OR (ch = DEL) DO
      IF ch = DEL THEN
        IF i > 3 THEN Write(DEL); i := i-1 END
      ELSIF i < NL THEN
        Write(ch); FileName[i] := ch; i := i+1
      END ;
      Read(ch)
    END ;
    IF (3 < i) & (i < NL) & (FileName[i-1] = ".") THEN
      FileName[i] := "M"; i := i+1;
      FileName[i] := "O"; i := i+1;
      FileName[i] := "D"; i := i+1; WriteString("MOD");
    END ;
    FileName[i] := 0C
  END ReadName;

BEGIN WriteString("ETHZ M3L NW 2.8.86"); WriteLn;
  LOOP WriteString("in> "); rngchk := TRUE; ReadName;
    IF (ch = 33C) OR (FileName[3] < "A") THEN EXIT END ;
    IF ch = "/" THEN
      Write("/"); Read(ch);
      IF ch = "r" THEN Write("r"); rngchk := FALSE END
    END ;
    Lookup(source, FileName, FALSE);
    IF source.res = done THEN GetTime(TM);
      WITH sysmod^.key^ DO
        k0 := TM.day; k1 := TM.minute; k2 := TM.millisecond
      END ;
      InitScanner(FileName); InitTableHandler; InitRef; InitGenerator;
      CompilationUnit; Close(source);
    ELSE WriteString(" not found")
    END ;
    WriteLn
  END ;
  CloseScanner; WriteLn
END compile.
