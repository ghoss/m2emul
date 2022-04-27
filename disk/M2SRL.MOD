(******************************************************
**
** MODULE M2SRL (originally M3RL)
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

IMPLEMENTATION MODULE M2SRL; (*JG 6.11.85 / NW 31.10.85*)

  FROM SYSTEM IMPORT
    TSIZE;

  FROM FileSystem IMPORT File, Response, Lookup, SetOpen, Close, ReadWord,
    WriteWord;
  FROM M2SS IMPORT IdBuf, id, Diff, Mark;
  FROM M2SDL IMPORT ObjClass, Object, ObjPtr, StrForm, Structure, StrPtr,
    Parameter, ParPtr, PDesc, Key, KeyPtr, undftyp, booltyp, chartyp, inttyp,
    cardtyp, dbltyp, realtyp, stringtyp, wordtyp, addrtyp, bitstyp,
    proctyp, notyp, mainmod, ALLOCATE, ResetHeap; 

  CONST REFFILE = 333B;
    CTL = 170000B; anchor = 0; ModTag = 1; ProcTag = 2; RefTag = 3; linkage = 4;
    STR = 171000B; enum = 0; range = 1; pointer = 2; set = 3; procTyp = 4;
          funcTyp = 5; array = 6; dynarr = 7; record = 8; opaque = 9;
    CMP = 172000B; parref = 0; par = 1; field = 2;
    OBJ = 173000B; varref = 0; var = 1; const = 2; string = 3; type = 4;
          proc = 5; func = 6; module = 7; svc = 8; 
    maxM = 64; minS = 32 (*first non-standard structure*); maxS = 1024;

  VAR CurStr: CARDINAL;
      f: File; err: BOOLEAN;
      Temps, Fields: ObjPtr;
      Params, lastPar: ParPtr;

  PROCEDURE ReadId;
    VAR i, l, L: CARDINAL; u: CARDINAL;
  BEGIN i := id; l := 0;
    ReadWord(f, u); L := u DIV 256;
    LOOP
      IdBuf[i] := CHR(u DIV 256); i := i+1; l := l+1; IF l = L THEN EXIT END;
      IdBuf[i] := CHR(u MOD 256); i := i+1; l := l+1; IF l = L THEN EXIT END;
      ReadWord(f, u)
    END;
    id := i
  END ReadId;

  PROCEDURE InitRef;
  BEGIN
    WITH mainmod^ DO left := NIL; right := NIL; next := NIL END;
    ALLOCATE(ModList, TSIZE(Object)); ALLOCATE(Temps, TSIZE(Object));
    ALLOCATE(Fields, TSIZE(Object)); ALLOCATE(Params, TSIZE(Parameter));
    WITH ModList^ DO class := Header;
      next := mainmod; last := mainmod; left := NIL; right := NIL
    END;
    ModNo := 1;
    WITH Temps^ DO class := Header;
      next := NIL; last := Temps; left := NIL; right := NIL
    END;
    WITH Fields^ DO class := Header;
      next := NIL; last := Fields; left := NIL; right := NIL
    END;
    Params^.next := NIL; lastPar := Params
  END InitRef;

  PROCEDURE Insert(root, obj: ObjPtr): ObjPtr;
    VAR ob0, ob1: ObjPtr; d: INTEGER;
  BEGIN ob0 := root; ob1 := ob0^.right; d := 1;
    LOOP
      IF ob1 # NIL THEN
        d := Diff(obj^.name, ob1^.name);
        IF d < 0 THEN ob0 := ob1; ob1 := ob1^.left
        ELSIF d > 0 THEN ob0 := ob1; ob1 := ob1^.right
        ELSE EXIT
        END
      ELSE ob1 := obj;
        IF d < 0 THEN ob0^.left := ob1 ELSE ob0^.right := ob1 END ;
        ob1^.left := NIL; ob1^.right := NIL; EXIT
      END
    END;
    RETURN ob1
  END Insert;

  PROCEDURE InRef(VAR filename: ARRAY OF CHAR; VAR hdr: ObjPtr;
                  VAR adr: INTEGER; VAR pno: CARDINAL);
    VAR GlbMod: ARRAY [0..maxM] OF ObjPtr;
        Struct: ARRAY [0..maxS] OF StrPtr;
        CurMod, FileType, block, m, p, s, id0: CARDINAL;
        lev0, newobj, obj: ObjPtr;
        newpar: ParPtr; newstr: StrPtr;
  BEGIN
    Lookup(f, filename, FALSE);
    IF f.res = done THEN ReadWord(f, FileType);
      IF FileType = REFFILE THEN
        Struct[1] := undftyp; Struct[2] := booltyp; Struct[3] := chartyp;
        Struct[4] := inttyp; Struct[5] := cardtyp; Struct[6] := dbltyp;
        Struct[7] := realtyp; Struct[8] := NIL; Struct[9] := stringtyp;
        Struct[10] := wordtyp; Struct[11] := addrtyp; Struct[12] := bitstyp;
        Struct[13] := proctyp;
        CurMod := 0; CurStr := minS; err := FALSE;
        id0 := id; ALLOCATE(lev0, 0);
        LOOP ReadWord(f, block);
          IF block >= OBJ THEN block := block - OBJ;
            IF block > svc THEN err := TRUE; Mark(86); EXIT END;
            ALLOCATE(newobj, TSIZE(Object)); m := 0;
            WITH newobj^ DO next := NIL;
              CASE block OF
                var    : class := Var; ReadWord(f, s); typ := Struct[s];
                         param := {}; vmod := GlbMod[0]^.right^.modno;
                         ReadWord(f, vlev); ReadWord(f, vadr) 
              | const  : class := Const; ReadWord(f, s); typ := Struct[s];
                         ReadWord(f, m);
                         ReadWord(f, conval.D0); ReadWord(f, conval.D1)
              | string : class := Const; ReadWord(f, s); typ := Struct[s];
                         conval.D2 := id; ReadId;
                         conval.D1 := id - conval.D2;
                         conval.D0 := 177777B
              | type   : class := Typ; ReadWord(f, s); typ := Struct[s];
                         IF typ^.strobj = NIL THEN typ^.strobj := newobj END;
                         ReadWord(f, m); mod := GlbMod[m]^.right
              | proc, func : class := Proc;
                         IF block = func THEN ReadWord(f, s); typ := Struct[s]
                           ELSE typ := notyp 
                         END;
                         ALLOCATE(pd, TSIZE(PDesc));
                         ReadWord(f, pd^.num); ReadWord(f, pd^.lev);
                         ReadWord(f, pd^.adr); ReadWord(f, pd^.size);
                         firstLocal := NIL; firstParam := Params^.next;
                         Params^.next := NIL; lastPar := Params;
                         pmod := GlbMod[0]^.right^.modno
              | svc    : class := Code; ReadWord(f, cnum);
                         typ := NIL; firstArg := Params^.next;
                         Params^.next := NIL; lastPar := Params
              END;
              name := id; ReadId; exported := TRUE;
              obj := Insert(GlbMod[m]^.right, newobj);
              IF obj = newobj THEN (*new object*)
                GlbMod[m]^.last^.next := newobj; GlbMod[m]^.last := newobj;
                IF (class = Const) & (typ^.form = Enum) THEN
                  conval.prev := typ^.ConstLink; typ^.ConstLink := newobj
                END;
                id0 := id; ALLOCATE(lev0, 0)
              ELSE
                IF obj^.class = Typ THEN Struct[s] := obj^.typ END;
                id := id0; ResetHeap(lev0)
              END
            END
          ELSIF block >= CMP THEN block := block - CMP;
            IF block > field THEN err := TRUE; Mark(86); EXIT END;
            IF block = field THEN
              ALLOCATE(newobj, TSIZE(Object));
              WITH newobj^ DO
                class := Field; next := NIL;
                ReadWord(f, s); typ := Struct[s];
                ReadWord(f, offset); name := id; ReadId;
                newobj := Insert(Fields, newobj)
              END;
              Fields^.last^.next := newobj; Fields^.last := newobj
            ELSE (*parameter*)
              ALLOCATE(newpar, TSIZE(Parameter));
              WITH newpar^ DO
                next := NIL; ReadWord(f, s); typ := Struct[s];
                name := 0; varpar := block = parref;
                lastPar^.next := newpar; lastPar := newpar
              END
            END 
          ELSIF block >= STR THEN block := block - STR;
            IF block > opaque THEN err := TRUE; Mark(86); EXIT END;
            ALLOCATE(newstr, TSIZE(Structure));
            WITH newstr^ DO
              strobj := NIL; ReadWord(f, size); ref := 0;
              CASE block OF
                enum    : form := Enum; ReadWord(f, NofConst);
                          ConstLink := NIL      
              | range   : form := Range;
                          ReadWord(f, s); RBaseTyp := Struct[s];
                          ReadWord(f, min); ReadWord(f, max)
              | pointer : form := Pointer; PBaseTyp := NIL;
                          BaseId := 0
              | set     : form := Set; ReadWord(f, s);
                          SBaseTyp := Struct[s]
              | procTyp, funcTyp : form := ProcTyp;
                          IF block = funcTyp THEN
                            ReadWord(f, s); resTyp := Struct[s] 
                          ELSE resTyp := notyp
                          END;
                          firstPar := Params^.next;
                          Params^.next := NIL; lastPar := Params
              | array   : form := Array; ReadWord(f, s);
                          ElemTyp := Struct[s]; dyn := FALSE;
                          ReadWord(f, s); IndexTyp := Struct[s]
              | dynarr  : form := Array; ReadWord(f, s);
                          ElemTyp := Struct[s]; dyn := TRUE;
                          IndexTyp := NIL
              | record  : form := Record;
                          firstFld := Fields^.right; Fields^.right := NIL;
                          Fields^.next := NIL; Fields^.last := Fields
              | opaque  : form := Opaque
              END
            END;
            IF CurStr > maxS THEN err := TRUE; Mark(98); EXIT END;
            Struct[CurStr] := newstr;
            CurStr := CurStr + 1
          ELSIF block >= CTL THEN block := block - CTL;
            IF block = linkage THEN ReadWord(f, s); ReadWord(f, p);
              IF Struct[p]^.PBaseTyp # NIL THEN
                id := id0; ResetHeap(lev0)
              ELSE Struct[p]^.PBaseTyp := Struct[s];
                id0 := id; ALLOCATE(lev0, 0)
              END
            ELSIF block = ModTag THEN (*main module*) ReadWord(f, m) 
            ELSIF block = anchor THEN
              ALLOCATE(newobj, TSIZE(Object));
              WITH newobj^ DO
                class := Module; typ := NIL; left := NIL; right := NIL;
                ALLOCATE(key, TSIZE(Key));
                ReadWord(f, key^.k0); ReadWord(f, key^.k1); ReadWord(f, key^.k2);
                firstObj := NIL; root := NIL; name := id; ReadId
              END;
              IF CurMod > maxM THEN Mark(96); EXIT END;
              ALLOCATE(GlbMod[CurMod], TSIZE(Object));
              id0 := id; ALLOCATE(lev0, 0);
              WITH GlbMod[CurMod]^ DO
                class := Header; kind := Module; typ := NIL;
                next := NIL; left := NIL; last := GlbMod[CurMod];
                obj := ModList^.next; (*find mod*)
                WHILE (obj # NIL) & (Diff(obj^.name, newobj^.name) # 0) DO
                  obj := obj^.next
                END;
                IF obj # NIL THEN GlbMod[CurMod]^.right := obj;
                  IF (CurMod = 0) & (obj = mainmod) THEN
                    (*newobj is own definition module*)
                    obj^.key^ := newobj^.key^
                  ELSIF (obj^.key^.k0 # newobj^.key^.k0)
                     OR (obj^.key^.k1 # newobj^.key^.k1)
                     OR (obj^.key^.k2 # newobj^.key^.k2) THEN Mark(85)
                  ELSIF (CurMod = 0) & (obj^.firstObj # NIL) THEN
                    CurMod := 1; EXIT (*module already loaded*)
                  END;
                  id := id0; ResetHeap(lev0)
                ELSE GlbMod[CurMod]^.right := newobj;
                  newobj^.next := NIL; newobj^.modno := ModNo; INC(ModNo);
                  ModList^.last^.next := newobj; ModList^.last := newobj;
                  id0 := id; ALLOCATE(lev0, 0)
                END
              END;
              CurMod := CurMod + 1
            ELSIF block = RefTag THEN
              ReadWord(f, adr); ReadWord(f, pno); EXIT
            ELSE err := TRUE; Mark(86); EXIT
            END
          ELSE (*line block*) err := TRUE; Mark(86); EXIT
          END
        END;
        IF NOT err & (CurMod # 0) THEN hdr := GlbMod[0];
          hdr^.right^.root := hdr^.right^.right;
          (*leave hdr^.right.right for later searches*)
          hdr^.right^.firstObj := hdr^.next
        ELSE hdr := NIL
        END
      ELSE Mark(86); hdr := NIL
      END;
      Close(f)
    ELSE Mark(88); hdr := NIL
    END
  END InRef;

  PROCEDURE WriteId(i: CARDINAL);
    VAR l, L: CARDINAL; u: CARDINAL;
  BEGIN l := 0; L := ORD(IdBuf[i]);
    REPEAT
      u := ORD(IdBuf[i])*256; i := i+1; l := l+1;
      IF l # L THEN u := u + ORD(IdBuf[i]); i := i+1; l := l+1 END;
      WriteWord(RefFile, u)
    UNTIL l = L
  END WriteId;

  PROCEDURE OpenRef;
    VAR obj: ObjPtr;
  BEGIN WriteWord(RefFile, REFFILE);
    obj := ModList^.next;
    WHILE obj # NIL DO
      WriteWord(RefFile, CTL+anchor);
      WITH obj^ DO WriteWord(RefFile, key^.k0);
        WriteWord(RefFile, key^.k1); WriteWord(RefFile, key^.k2);
        WriteId(name)
      END;
      obj := obj^.next
    END;
    CurStr := minS
  END OpenRef;
  
  PROCEDURE OutPar(prm: ParPtr);
  BEGIN
    WHILE prm # NIL DO (*out param*)
      WITH prm^ DO
        IF varpar THEN WriteWord(RefFile, CMP+parref)
          ELSE WriteWord(RefFile, CMP+par)
        END;
        WriteWord(RefFile, typ^.ref)
      END;        
      prm := prm^.next
    END
  END OutPar;

  PROCEDURE OutStr(str: StrPtr);
    VAR obj: ObjPtr; par: ParPtr;

    PROCEDURE OutFldStrs(fld: ObjPtr);
    BEGIN
      WHILE fld # NIL DO
        IF fld^.typ^.ref = 0 THEN OutStr(fld^.typ) END;
        fld := fld^.next
      END
    END OutFldStrs;

    PROCEDURE OutFlds(fld: ObjPtr);
    BEGIN
      WHILE fld # NIL DO
        WITH fld^ DO
          WriteWord(RefFile, CMP+field); WriteWord(RefFile, typ^.ref);
          WriteWord(RefFile, offset); WriteId(name)
        END;
        fld := fld^.next
      END
    END OutFlds;

  BEGIN
    WITH str^ DO
      CASE form OF
        Enum    : WriteWord(RefFile, STR+enum); WriteWord(RefFile, size);
                  WriteWord(RefFile, NofConst)
      | Range   : IF RBaseTyp^.ref = 0 THEN OutStr(RBaseTyp) END;
                  WriteWord(RefFile, STR+range); WriteWord(RefFile, size);
                  WriteWord(RefFile, RBaseTyp^.ref);
                  WriteWord(RefFile, min); WriteWord(RefFile, max)
      | Pointer : ALLOCATE(obj, TSIZE(Object));
                  WITH obj^ DO left := NIL; next := NIL;
                    class := Temp; typ := PBaseTyp; baseref := CurStr;
                    Temps^.last^.next := obj; Temps^.last := obj
                  END;
                  WriteWord(RefFile, STR+pointer); WriteWord(RefFile, size)
      | Set     : IF SBaseTyp^.ref = 0 THEN OutStr(SBaseTyp) END;
                  WriteWord(RefFile, STR+set); WriteWord(RefFile, size);
                  WriteWord(RefFile, SBaseTyp^.ref)
      | ProcTyp : par := firstPar;
                  WHILE par # NIL DO (*out param structure*)
                    IF par^.typ^.ref = 0 THEN OutStr(par^.typ) END;
                    par := par^.next
                  END;
                  OutPar(firstPar);
                  IF resTyp # notyp THEN
                    IF resTyp^.ref = 0 THEN OutStr(resTyp) END;
                    WriteWord(RefFile, STR+funcTyp); WriteWord(RefFile, size);
                    WriteWord(RefFile, resTyp^.ref)
                  ELSE WriteWord(RefFile, STR+procTyp); WriteWord(RefFile, size)
                  END
      | Array   : IF ElemTyp^.ref = 0 THEN OutStr(ElemTyp) END;
                  IF dyn THEN WriteWord(RefFile, STR+dynarr);
                    WriteWord(RefFile, size); WriteWord(RefFile, ElemTyp^.ref)
                  ELSE
                    IF IndexTyp^.ref = 0 THEN OutStr(IndexTyp) END;
                    WriteWord(RefFile, STR+array); WriteWord(RefFile, size);
                    WriteWord(RefFile, ElemTyp^.ref);
                    WriteWord(RefFile, IndexTyp^.ref)
                  END
      | Record  : OutFldStrs(firstFld); OutFlds(firstFld);
                  WriteWord(RefFile, STR+record); WriteWord(RefFile, size)
      | Opaque  : WriteWord(RefFile, STR+opaque); WriteWord(RefFile, size)
      END;
      ref := CurStr; CurStr := CurStr + 1
    END
  END OutStr;

  PROCEDURE OutExt(str: StrPtr);
    VAR obj: ObjPtr; par: ParPtr;

    PROCEDURE OutFlds(fld: ObjPtr);
    BEGIN
      WHILE fld # NIL DO
        IF fld^.typ^.ref = 0 THEN OutExt(fld^.typ) END;
        fld := fld^.next
      END
    END OutFlds;

  BEGIN
    WITH str^ DO
      CASE form OF
        Range   : IF RBaseTyp^.ref = 0 THEN OutExt(RBaseTyp) END
      | Set     : IF SBaseTyp^.ref = 0 THEN OutExt(SBaseTyp) END
      | ProcTyp : par := firstPar;
                  WHILE par # NIL DO
                    IF par^.typ^.ref = 0 THEN OutExt(par^.typ) END;
                    par := par^.next
                  END;
                  IF (resTyp # notyp) & (resTyp^.ref = 0) THEN OutExt(resTyp) END
      | Array   : IF ElemTyp^.ref = 0 THEN OutExt(ElemTyp) END;
                  IF NOT dyn THEN OutExt(IndexTyp) END
      | Record  : OutFlds(firstFld)
      | Enum, Pointer, Opaque :
      END;
      IF (strobj # NIL) & (strobj^.mod^.modno # 0) THEN
        IF ref = 0 THEN OutStr(str) END;
        IF form = Enum THEN obj := ConstLink;
          WHILE obj # NIL DO
            WriteWord(RefFile, OBJ+const);
            WriteWord(RefFile, ref);
            WriteWord(RefFile, strobj^.mod^.modno);
            WriteWord(RefFile, obj^.conval.D0);
            WriteWord(RefFile, obj^.conval.D1);
            WriteId(obj^.name);
            obj := obj^.conval.prev
          END
        END;
        WriteWord(RefFile, OBJ+type);
        WriteWord(RefFile, ref);
        WriteWord(RefFile, strobj^.mod^.modno);
        WriteId(strobj^.name)
      END
    END
  END OutExt;

  PROCEDURE OutObj(obj: ObjPtr);
    VAR par: ParPtr;
  BEGIN
    WITH obj^ DO
      CASE class OF
        Module : WriteWord(RefFile, OBJ+module); WriteWord(RefFile, modno)
      | Proc   : par := firstParam;
                 WHILE par # NIL DO
                   IF par^.typ^.ref = 0 THEN OutExt(par^.typ) END;
                   par := par^.next
                 END;
                 IF (typ # notyp) & (typ^.ref = 0) THEN OutExt(typ) END;
                 par := firstParam;
                 WHILE par # NIL DO (*out param structure*)
                   IF par^.typ^.ref = 0 THEN OutStr(par^.typ) END;
                   par := par^.next
                 END;
                 IF (typ # notyp) & (typ^.ref = 0) THEN OutStr(typ) END;
                 OutPar(firstParam);
                 IF typ # notyp THEN
                   WriteWord(RefFile, OBJ+func); WriteWord(RefFile, typ^.ref)
                 ELSE WriteWord(RefFile, OBJ+proc)
                 END;
                 WriteWord(RefFile, pd^.num); WriteWord(RefFile, pd^.lev);
                 WriteWord(RefFile, pd^.adr); WriteWord(RefFile, pd^.size)
      | Code   : par := firstArg;
                 WHILE par # NIL DO
                   IF par^.typ^.ref = 0 THEN OutExt(par^.typ) END;
                   par := par^.next
                 END;
                 par := firstArg;
                 WHILE par # NIL DO (*out param structure*)
                   IF par^.typ^.ref = 0 THEN OutStr(par^.typ) END;
                   par := par^.next
                 END;
                 OutPar(firstArg);
                 WriteWord(RefFile, OBJ+svc); WriteWord(RefFile, cnum)
      | Const  : IF typ^.ref = 0 THEN OutExt(typ) END;
                 IF typ^.ref = 0 THEN OutStr(typ) END;
                 IF typ^.form = String THEN WriteWord(RefFile, OBJ+string);
                   WriteWord(RefFile, typ^.ref); WriteId(conval.D2)
                 ELSE WriteWord(RefFile, OBJ+const);
                   WriteWord(RefFile, typ^.ref);
                   WriteWord(RefFile, 0); (*main*)
                   WriteWord(RefFile, conval.D0); WriteWord(RefFile, conval.D1) 
                 END
      | Typ    : IF typ^.ref = 0 THEN OutExt(typ) END;
                 IF typ^.ref = 0 THEN OutStr(typ) END;
                 WriteWord(RefFile, OBJ+type);
                 WriteWord(RefFile, typ^.ref); WriteWord(RefFile, 0) (*main*)
      | Var    : IF typ^.ref = 0 THEN OutExt(typ) END;
                 IF typ^.ref = 0 THEN OutStr(typ) END;
                 IF 1 IN param THEN WriteWord(RefFile, OBJ+varref)
                   ELSE WriteWord(RefFile, OBJ+var)
                 END;
                 WriteWord(RefFile, typ^.ref);
                 WriteWord(RefFile, vlev); WriteWord(RefFile, vadr)
      | Temp   :
      END;
      WriteId(name)
    END
  END OutObj;

  PROCEDURE OutLink;
    VAR obj: ObjPtr;
  BEGIN obj := Temps^.next;
    WHILE obj # NIL DO
      WITH obj^ DO
        IF typ^.ref = 0 THEN OutExt(typ) END;
        IF typ^.ref = 0 THEN OutStr(typ) END;
        WriteWord(RefFile, CTL+linkage);
        WriteWord(RefFile, typ^.ref);
        WriteWord(RefFile, baseref)
      END;
      obj := obj^.next
    END;
    Temps^.next := NIL; Temps^.last := Temps
  END OutLink;
 
  PROCEDURE OutUnit(unit: ObjPtr);
    VAR lev0, obj: ObjPtr;
  BEGIN ALLOCATE(lev0, 0);
    IF unit^.class = Proc THEN obj := unit^.firstLocal;
      WHILE obj # NIL DO OutObj(obj); obj := obj^.next END;
      OutLink;
      WriteWord(RefFile, CTL+ProcTag);
      WriteWord(RefFile, unit^.pd^.num)
    ELSIF unit^.class = Module THEN obj := unit^.firstObj;
      WHILE obj # NIL DO OutObj(obj); obj := obj^.next END;
      OutLink;
      WriteWord(RefFile, CTL+ModTag);
      WriteWord(RefFile, unit^.modno)
    END;
    ResetHeap(lev0)
  END OutUnit;

  PROCEDURE OutPos(sourcepos, pc: CARDINAL);
  BEGIN
    IF pc < CTL THEN
      WriteWord(RefFile, pc); WriteWord(RefFile, sourcepos)
    ELSE Mark(226)
    END
  END OutPos;

  PROCEDURE CloseRef(adr: INTEGER; pno: CARDINAL);
  BEGIN
    WriteWord(RefFile, CTL+RefTag);
    WriteWord(RefFile, adr); WriteWord(RefFile, pno);
    SetOpen(RefFile);
    IF RefFile.res # done THEN Mark(88) END
  END CloseRef;

BEGIN
  undftyp^.ref := 1; booltyp^.ref := 2; chartyp^.ref := 3; inttyp^.ref := 4;
  cardtyp^.ref := 5; dbltyp^.ref := 6; realtyp^.ref := 7;
  stringtyp^.ref := 9; wordtyp^.ref := 10; addrtyp^.ref := 11; bitstyp^.ref := 12;
  proctyp^.ref := 13
END M2SRL.
