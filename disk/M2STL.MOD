(******************************************************
**
** MODULE M2STL (originally M3TL)
**
** Niklaus Wirth's Modula-2 single pass compiler
** (believed to be source code version of 2.8.1986)
**
** Origin:
** - "mfk301" Lilith disk image by Jos Dreesen
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - Renamed from "M3RL" to "M2SRL" to avoid name
**   confusion during bootstrap compilation with
**   multipass compiler
** - Adapted IMPORT lists to renamed module names
**
** 02.04.2022 
**
*******************************************************)

IMPLEMENTATION MODULE M2STL;  (*NW 7.4.83 / 30.1.86*)
  FROM M2SDL IMPORT
       WordSize, nilval, ObjPtr, Object, ObjClass, StrPtr, Structure, StrForm,
       ParPtr, Parameter, PDesc, PDPtr,
       KeyPtr, Key, mainmod, sysmod,
       undftyp, cardtyp, inttyp, booltyp, chartyp, bitstyp, realtyp,
       dbltyp, proctyp, notyp, stringtyp, addrtyp, wordtyp,
       ALLOCATE, ResetHeap;
  FROM M2SS IMPORT id, Diff, Enter, Mark;

  FROM SYSTEM IMPORT
    TSIZE;

  VAR obj:    ObjPtr;
    universe: ObjPtr;
    BBtyp:    StrPtr;
    expo:     BOOLEAN;

  PROCEDURE FindInScope(id: CARDINAL; root: ObjPtr): ObjPtr;
    VAR obj: ObjPtr; d: INTEGER;
  BEGIN obj := root;
    LOOP IF obj = NIL THEN EXIT END ;
      d := Diff(id, obj^.name);
      IF d < 0 THEN obj := obj^.left
      ELSIF d > 0 THEN obj := obj^.right
      ELSE EXIT
      END
    END ;
    RETURN obj
  END FindInScope;

  PROCEDURE Find(id: CARDINAL): ObjPtr;
    VAR obj: ObjPtr;
  BEGIN Scope := topScope;
    LOOP obj := FindInScope(id, Scope^.right);
      IF obj # NIL THEN EXIT END ;
      IF Scope^.kind = Module THEN
        obj := FindInScope(id, universe^.right); EXIT
      END ;
      Scope := Scope^.left
    END ;
    RETURN obj
  END Find;

  PROCEDURE FindImport(id: CARDINAL): ObjPtr;
    VAR obj: ObjPtr;
  BEGIN Scope := topScope^.left;
    LOOP obj := FindInScope(id, Scope^.right);
      IF obj # NIL THEN EXIT END ;
      IF Scope^.kind = Module THEN
        obj := FindInScope(id, universe^.right); EXIT
      END ;
      Scope := Scope^.left
    END ;
    RETURN obj
  END FindImport;

  PROCEDURE NewObj(id: CARDINAL; cl: ObjClass): ObjPtr;
    VAR ob0, ob1: ObjPtr; d: INTEGER;
  BEGIN ob0 := topScope; ob1 := ob0^.right; d := 1;
    LOOP
      IF ob1 # NIL THEN
        d := Diff(id, ob1^.name);
        IF d < 0 THEN ob0 := ob1; ob1 := ob0^.left
        ELSIF d > 0 THEN ob0 := ob1; ob1 := ob0^.right
        ELSIF ob1^.class = Temp THEN (*export*)
          (*change variant*) ob1^.exported := TRUE;
          topScope^.last^.next := ob1; topScope^.last := ob1; EXIT
        ELSE (*double def*)
          Mark(100); ob0 := ob1; ob1 := ob0^.right
        END
      ELSE (*insert new object*) ALLOCATE(ob1, TSIZE(Object));
        IF d < 0 THEN ob0^.left := ob1 ELSE ob0^.right := ob1 END ;
        ob1^.left := NIL; ob1^.right := NIL; ob1^.next := NIL;
        IF cl # Temp THEN
          topScope^.last^.next := ob1; topScope^.last := ob1
        END ;
        ob1^.exported := FALSE; EXIT
      END
    END ;
    WITH ob1^ DO
      name := id; typ := undftyp; class := cl;
      CASE cl OF
        Header, Const, Typ, Var, Field, Temp: |
        Proc: firstParam := NIL; firstLocal := NIL;
              ALLOCATE(pd, TSIZE(PDesc)) |
        Code: firstArg := NIL; cd := NIL |
        Module: firstObj := NIL; root := NIL; key := NIL; typ := notyp
      END
    END ;
    RETURN ob1
  END NewObj;

  PROCEDURE NewStr(frm: StrForm): StrPtr;
    VAR str: StrPtr;
  BEGIN ALLOCATE(str, TSIZE(Structure));
    WITH str^ DO
      strobj := NIL; size := 0; ref := 0; form := frm;
      CASE frm OF
        Undef .. Enum, Opaque: |
        Range: RBaseTyp := undftyp; min := 0; max := 0 |
        Pointer: PBaseTyp := undftyp |
        Set:     SBaseTyp := undftyp |
        Array:   ElemTyp := undftyp; IndexTyp := undftyp |
        Record:  firstFld := NIL |
        ProcTyp: firstPar := NIL; resTyp := NIL
      END
    END ;
    RETURN str
  END NewStr;

  PROCEDURE NewImp(scope, obj: ObjPtr);
    VAR ob0, ob1, ob1L, ob1R: ObjPtr; d: INTEGER;
  BEGIN ob0 := scope; ob1 := ob0^.right; d := 1;
    LOOP
      IF ob1 # NIL THEN
        d := Diff(obj^.name, ob1^.name);
        IF d < 0 THEN ob0 := ob1; ob1 := ob1^.left
        ELSIF d > 0 THEN ob0 := ob1; ob1 := ob1^.right
        ELSIF ob1^.class = Temp THEN (*export*)
          ob1L := ob1^.left; ob1R := ob1^.right;
          ob1^ := obj^; ob1^.exported := TRUE;
          ob1^.left := ob1L; ob1^.right := ob1R; EXIT
        ELSE Mark(100); EXIT
        END
      ELSE (*insert copy of imported object*)
        ALLOCATE(ob1, TSIZE(Object)); ob1^ := obj^;
        IF d < 0 THEN ob0^.left := ob1 ELSE ob0^.right := ob1 END ;
        ob1^.left := NIL; ob1^.right := NIL; ob1^.exported := FALSE;
        IF (obj^.class = Typ) & (obj^.typ^.form = Enum) THEN
          (*import enumeration constants too*)
          ob0 := obj^.typ^.ConstLink;
          WHILE ob0 # NIL DO
            NewImp(scope, ob0); ob0 := ob0^.conval.prev
          END
        END ;
        EXIT
      END
    END
  END NewImp;

  PROCEDURE NewPar(ident: CARDINAL; isvar: BOOLEAN; last: ParPtr): ParPtr;
    VAR par: ParPtr;
  BEGIN ALLOCATE(par, TSIZE(Parameter));
    par^.name := ident; par^.varpar := isvar; par^.next := last;
    RETURN par
  END NewPar;

  PROCEDURE NewScope(cl: ObjClass);
    VAR hd: ObjPtr;
  BEGIN ALLOCATE(hd, TSIZE(Object));
    WITH hd^ DO
      name := 0; typ := NIL; class := Header;
      left := topScope; right := NIL; last := hd; next := NIL; kind := cl
    END ;
    topScope := hd
  END NewScope;

  PROCEDURE CloseScope;
  BEGIN topScope := topScope^.left
  END CloseScope;

  PROCEDURE CheckUDP(obj, node: ObjPtr);
    (*obj is newly defined type; check for undefined forward references
      pointing to this new type by traversing the tree*)
  BEGIN
    IF node # NIL THEN
      IF (node^.class = Typ) & (node^.typ^.form = Pointer) &
         (node^.typ^.PBaseTyp = undftyp) &
         (Diff(node^.typ^.BaseId, obj^.name) = 0) THEN
        node^.typ^.PBaseTyp := obj^.typ
      END ;
      CheckUDP(obj, node^.left); CheckUDP(obj, node^.right)
    END
  END CheckUDP;

  PROCEDURE MarkHeap;
  BEGIN ALLOCATE(topScope^.heap, 0); topScope^.name := id
  END MarkHeap;

  PROCEDURE ReleaseHeap;
  BEGIN ResetHeap(topScope^.heap); id := topScope^.name
  END ReleaseHeap;

  PROCEDURE InitTableHandler;
  BEGIN topScope := universe; mainmod^.firstObj := NIL; ReleaseHeap
  END InitTableHandler;

  PROCEDURE EnterTyp(VAR str: StrPtr; name: ARRAY OF CHAR;
                     frm: StrForm; sz: CARDINAL);
  BEGIN obj := NewObj(Enter(name), Typ); str := NewStr(frm);
    obj^.typ := str; str^.strobj := obj; str^.size := sz;
    obj^.exported := expo
  END EnterTyp;

  PROCEDURE EnterProc(name: ARRAY OF CHAR; num: CARDINAL);
  BEGIN obj := NewObj(Enter(name), Code);
    obj^.typ := notyp; obj^.cnum := num; obj^.exported := expo
  END EnterProc;

BEGIN topScope := NIL; Scope := NIL;
  NewScope(Module); universe := topScope;
  undftyp := NewStr(Undef); undftyp^.size := 1;
  notyp := NewStr(Undef); notyp^.size := 0;
  stringtyp := NewStr(String); stringtyp^.size := 1;
  BBtyp := NewStr(Range); (*Bitset Basetyp*)
  ALLOCATE(mainmod, TSIZE(Object));
  WITH mainmod^ DO
    class := Module; modno := 0; typ := notyp; next := NIL; exported := FALSE;
    ALLOCATE(key, TSIZE(Key))
  END ;

  (*initialization of module SYSTEM*) expo := TRUE;
  EnterTyp(wordtyp, "WORD", Undef, 1);
  EnterTyp(addrtyp, "ADDRESS", Card, 1);
  EnterProc("TSIZE", 8);
  EnterProc("ADR",  10);
  EnterProc("LONG", 20);
  ALLOCATE(sysmod, TSIZE(Object));
  WITH sysmod^ DO
    name := Enter("SYSTEM"); class := Module; modno := 0; exported := FALSE;
    left := NIL; right := NIL; next := NIL;
    firstObj := topScope^.next; root := topScope^.right;
    ALLOCATE(key, TSIZE(Key))
  END ;
  (*reset header*)
  WITH topScope^ DO
    next := NIL; right := NIL; last := topScope
  END ;
  expo := FALSE;

  (*initialization of Universe*)
  EnterTyp(realtyp, "REAL", Real, 2);
  obj := NewObj(Enter("NIL"), Const);
  obj^.typ := addrtyp; obj^.conval.C := nilval;
  EnterTyp(chartyp, "CHAR", Char, 1);
  EnterTyp(booltyp, "BOOLEAN", Bool, 1);
  obj := NewObj(Enter("FALSE"), Const);
  obj^.typ := booltyp; obj^.conval.B := FALSE;
  obj := NewObj(Enter("TRUE"), Const);
  obj^.typ := booltyp; obj^.conval.B := TRUE;
  EnterTyp(inttyp, "INTEGER", Int, 1);
  EnterTyp(cardtyp, "CARDINAL", Card, 1);
  EnterTyp(bitstyp, "BITSET", Set, 1); bitstyp^.SBaseTyp := BBtyp;
  WITH BBtyp^ DO
    RBaseTyp := cardtyp; min := 0; max := WordSize-1; size := 1
  END ;
  EnterTyp(dbltyp, "LONGINT", Double, 2);
  EnterProc("INC",  15);
  EnterProc("DEC",  16);
  EnterProc("CAP",   3);
  EnterProc("ABS",   2);
  EnterProc("CHR",  14);
  EnterProc("MIN",  11);
  EnterProc("MAX",  12);
  EnterProc("ODD",   5);
  EnterProc("ORD",   6);
  EnterProc("INCL", 17);
  EnterProc("HALT",  1);
  EnterProc("EXCL", 18);
  EnterProc("HIGH", 13);
  EnterProc("SIZE",  8);
  EnterProc("VAL",  19);
  EnterProc("FLOAT", 4);
  EnterProc("TRUNC", 7);
  EnterTyp(proctyp, "PROC", ProcTyp, 1);
  proctyp^.firstPar := NIL; proctyp^.resTyp := notyp;
  MarkHeap
END M2STL.
