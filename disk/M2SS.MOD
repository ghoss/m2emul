(******************************************************
**
** MODULE M2SS (originally M2S)
**
** Niklaus Wirth's Modula-2 single pass compiler
** (believed to be source code version of 2.8.1986)
**
** Origin:
** - "mfk301" Lilith disk image by Jos Dreesen
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - Renamed from "M2S" to "M2SS" to avoid name
**   confusion during bootstrap compilation with
**   multipass compiler
** - Imports LONGINT from special support module to 
**   allow for compilation with multipass compiler
**
** 02.04.2022 
**
*******************************************************)

IMPLEMENTATION MODULE M2SS; (*NW 17.8.83 / 31.3.85*)

  FROM LongInt IMPORT 
    LONGINT, LONG,
    LGE, LSUB, LADD;

  FROM FileSystem IMPORT
    File, Response, Lookup, ReadChar, WriteChar, GetPos, SetPos, Close;

  CONST KW = 42; (*number of keywords*)
        maxDig = 7;
        maxCard = 177777B;
        maxExp = 38;
        IdBufLim = IdBufLeng - 100;
        FNM = 300C;
        ERR = 301C;

  VAR ch:     CHAR;      (*current character*)
    id0, id1: CARDINAL;  (*indices of identifier buffer*)
    keyTab:   ARRAY [0..KW-1] OF
                RECORD sym: Symbol; ind: CARDINAL END;
    K:        CARDINAL;
    pow:      ARRAY [0..5] OF REAL;
    lastPos:  CARDINAL;
    errDat,
    errLog:   File;

  PROCEDURE Times16(x: LONGINT): LONGINT;
    CODE 216B; 216B; 216B; 216B
  END Times16;

  PROCEDURE ErrorBlock(errPos: LONGINT; errCod: CARDINAL);
    VAR i: CARDINAL;
        conv: RECORD
                 CASE :CARDINAL OF
                  0: long: LONGINT
                | 1: sys:  ARRAY [0..3] OF CHAR;
                END;
              END;
  BEGIN
    IF LGE(errPos, LONG(0, 2)) THEN 
      errPos := LSUB(errPos, LONG(0, 2));
    END;
    WriteChar(errDat, ERR);
    WITH conv DO
      long := errPos; FOR i := 3 TO 0 BY -1 DO WriteChar(errDat, sys[i]) END;
    END;
    WriteChar(errDat, CHR(errCod MOD 256)); WriteChar(errDat, CHR(errCod DIV 256));
  END ErrorBlock;

  PROCEDURE Mark(n: CARDINAL);
    VAR k, p0, p1: CARDINAL; buf: CHAR;
      dig: ARRAY [0..3] OF CARDINAL;
  BEGIN scanerr := TRUE; k := 4; GetPos(source, p0, p1);
    IF lastPos + 8 < p1 THEN
      ErrorBlock(LONG(p0, p1), n);
      IF lastPos + 100 < p1 THEN
        lastPos := p1 - 100; SetPos(source, p0, lastPos);
        (* WriteChar(errLog, 36C); WriteChar(errLog, 36C); *)
        WriteChar(errLog, 12C); WriteChar(errLog, 12C);
        REPEAT ReadChar(source, buf); INC(lastPos)
        UNTIL (buf = 36C) OR (buf = 12C) OR (lastPos = p1)
      ELSE SetPos(source, p0, lastPos)
      END ;
      WHILE lastPos < p1 DO
        ReadChar(source, buf); WriteChar(errLog, buf); INC(lastPos)
      END ;
      WriteChar(errLog, " ");
      REPEAT WriteChar(errLog, "*"); DEC(k) UNTIL k = 0;
      REPEAT dig[k] := n MOD 10; n := n DIV 10; INC(k) UNTIL n = 0;
      REPEAT DEC(k); WriteChar(errLog, CHR(dig[k] + 60B)) UNTIL k = 0;
      WriteChar(errLog, " ")
    END
  END Mark;

  PROCEDURE GetCh;
  BEGIN ReadChar(source, ch)
  END GetCh;
  
  PROCEDURE Diff(i, j: CARDINAL): INTEGER;
    VAR k: CARDINAL;
  BEGIN k := ORD(IdBuf[i]);
    LOOP
      IF k = 0 THEN RETURN 0
      ELSIF IdBuf[i] # IdBuf[j] THEN
        RETURN INTEGER(ORD(IdBuf[i])) - INTEGER(ORD(IdBuf[j]))
      ELSE INC(i); INC(j); DEC(k)
      END
    END
  END Diff;

  PROCEDURE KeepId;
  BEGIN id := id1
  END KeepId;
    
  PROCEDURE String(termCh: CHAR);
  BEGIN id1 := id + 1;
    IF id1 > IdBufLim THEN Mark(91); id1 := 1 END ;
    LOOP GetCh;
      IF ch = termCh THEN EXIT END ;
      IF ch < " " THEN Mark(45); EXIT END ;
      IdBuf[id1] := ch; INC(id1)
    END ;
    GetCh; IdBuf[id] := CHR(id1-id); (*length*)
    IF IdBuf[id] = 2C THEN
      sym := number; numtyp := 3; intval := ORD(IdBuf[id+1])
    ELSE sym := string;
      IF IdBuf[id] = 1C THEN  (*empty string*)
        IdBuf[id1] := 0C; INC(id1); IdBuf[id] := 2C
      END
    END
  END String;

  PROCEDURE Identifier;
    VAR k, l, m: CARDINAL;
  BEGIN id1 := id + 1;
    IF id1 > IdBufLim THEN Mark(91); id1 := 1 END;
    REPEAT
      IdBuf[id1] := ch; INC(id1); GetCh
    UNTIL (ch < "0") OR ("9" < ch) & (CAP(ch) < "A") OR ("Z" < CAP(ch));
    IdBuf[id] := CHR(id1-id); (*Length*)
    k := 0; l := KW;
    REPEAT m := (k + l) DIV 2;
      IF Diff(id, keyTab[m].ind) <= 0 THEN l := m ELSE k := m + 1 END
    UNTIL k >= l;
    IF (k < KW) & (Diff(id, keyTab[k].ind) = 0) THEN sym := keyTab[k].sym
    ELSE sym := ident
    END
  END Identifier;

  PROCEDURE Number;
    VAR i, j, l, d, e, n: CARDINAL;
    x, f:   REAL;
    d0, d1: LONGINT;
    neg:    BOOLEAN;
    lastCh: CHAR;
    dig:    ARRAY [0..31] OF CHAR;

    PROCEDURE Ten(e: CARDINAL): REAL;
        VAR k: CARDINAL; u: REAL;
    BEGIN k := 0; u := 1.0;
      WHILE e > 0 DO
        IF ODD(e) THEN u := pow[k] * u END ;
        e := e DIV 2; INC(k)
      END ;
      RETURN u
    END Ten;

  BEGIN sym := number; i := 0;
    REPEAT dig[i] := ch; INC(i); GetCh
    UNTIL (ch < "0") OR ("9" < ch) & (CAP(ch) < "A") OR ("Z" < CAP(ch));
    lastCh := ch; j := 0;
    WHILE (j < i) & (dig[j] = "0") DO INC(j) END ;
    IF ch = "." THEN GetCh;
      IF ch = "." THEN
        lastCh := 0C; ch := 177C (*ellipsis*)
      END
    END ;
    IF lastCh = "." THEN (*decimal point*)
      x := 0.0; l := 0;
      WHILE j < i DO (*read int part*)
        IF l < maxDig THEN
          IF dig[j] > "9" THEN Mark(40) END ;
          x := x * 10.0 + FLOAT(ORD(dig[j])-60B); INC(l)
        ELSE Mark(41)
        END;
        INC(j)
      END ;
      l := 0; f := 0.0;
      WHILE ("0" <= ch) & (ch <= "9") DO (*read fraction*)
        IF l < maxDig THEN
          f := f * 10.0 + FLOAT(ORD(ch)-60B); INC(l)
        END ;
        GetCh
      END ;
      x := f / Ten(l) + x; e := 0; neg := FALSE;
      IF ch = "E" THEN GetCh;
        IF ch = "-" THEN
          neg := TRUE; GetCh
        ELSIF ch = "+" THEN GetCh
        END ;
        WHILE ("0" <= ch) & (ch <= "9") DO (*read exponent*)
          e := e * 10 + ORD(ch)-60B;
          GetCh
        END
      END ;
      IF neg THEN
        IF e <= maxExp THEN x := x / Ten(e) ELSE x := 0.0 END
      ELSE
        IF e <= maxExp THEN f := Ten(e);
          IF MAX(REAL) / f >= x THEN x := f*x ELSE Mark(41) END
        ELSE Mark(41)
        END
      END ;
      numtyp := 4; realval := x
    ELSE (*integer*)
      lastCh := dig[i-1];
      IF lastCh = "B" THEN
        DEC(i); intval := 0; numtyp := 1;
        WHILE j < i DO
          d := ORD(dig[j]) - 60B;
          IF (d < 10B) & ((maxCard - d) DIV 10B >= intval) THEN
            intval := 10B * intval + d
          ELSE Mark(29); intval := 0
          END ;
          INC(j)
        END
      ELSIF lastCh = "H" THEN DEC(i);
        IF i <= j+4 THEN
          numtyp := 1; intval := 0;
          WHILE j < i DO
            d := ORD(dig[j]) - 60B;
            IF d > 26B THEN Mark(29); d := 0
               ELSIF d > 9 THEN d := d-7
            END ;
            intval := 10H * intval + d; INC(j)
          END
        ELSIF i <= j+8 THEN
          numtyp := 2; dblval := LONG(0, 0);
          REPEAT d := ORD(dig[j]) - 60B;
            IF d > 26B THEN Mark(29); d := 0
               ELSIF d > 9 THEN d := d-7
            END ;
            dblval := LADD(Times16(dblval), LONG(0,d)); INC(j)
          UNTIL j = i
        ELSE Mark(29); numtyp := 2
        END
      ELSIF lastCh = "D" THEN
        DEC(i); d1 := LONG(0, 0); numtyp := 2;
        WHILE j < i DO
          d := ORD(dig[j]) - 60B;
          IF d < 10 THEN (*no overflow check*)
            d1 := LADD(d1, d1);
            d0 := LADD(d1, d1);
            d1 := LADD(d1, d0);
            d1 := LADD(d1, d0);
            d1 := LADD(d1, LONG(0, d));
          ELSE 
            Mark(29); 
            d1 := LONG(0, 0);
          END ;
          INC(j)
        END ;
        dblval := d1
      ELSIF lastCh = "C" THEN
        DEC(i); intval := 0; numtyp := 3;
        WHILE j < i DO
          d := ORD(dig[j]) - 60B; intval := 10B * intval + d;
          IF (d >= 10B) OR (intval >= 400B) THEN
            Mark(29); intval := 0
          END ;
          INC(j)
        END
      ELSE (*decimal?*)
        numtyp := 1; intval := 0;
        WHILE j < i DO
          d := ORD(dig[j]) - 60B;
          IF (d < 10) & ((maxCard-d) DIV 10 >= intval) THEN
            intval := 10*intval + d
          ELSE Mark(29); intval := 0
          END ;
          INC(j)
        END
      END
    END
  END Number;

  PROCEDURE GetSym;
    VAR xch: CHAR;

    PROCEDURE Comment;
    BEGIN GetCh;
      REPEAT
        WHILE (ch # "*") & (ch > 0C) DO
          IF ch = "(" THEN GetCh;
            IF ch = "*" THEN Comment END
          ELSE GetCh
          END
        END ;
        GetCh
      UNTIL (ch = ")") OR (ch = 0C);
      IF ch > 0C THEN GetCh ELSE Mark(42) END
    END Comment;

  BEGIN
    LOOP (*ignore control characters*)
      IF ch <= " " THEN
        IF ch = 0C THEN ch := " "; EXIT ELSE GetCh END ;
      ELSIF ch > 177C THEN GetCh
      ELSE EXIT
      END
    END ;
    CASE ch OF   (* " " <= ch <= 177C *)
        " "  : sym := eof; ch := 0C |
        "!"  : sym := null; GetCh |
        '"'  : String('"') |
        "#"  : sym := neq; GetCh  |
        "$"  : sym := null; GetCh |
        "%"  : sym := null; GetCh |
        "&"  : sym := and; GetCh  |
        "'"  : String("'") |
        "("  : GetCh;
               IF ch = "*" THEN Comment; GetSym
                 ELSE sym := lparen
               END |
        ")"  : sym := rparen; GetCh|
        "*"  : sym := times; GetCh |
        "+"  : sym := plus; GetCh  |
        ","  : sym := comma; GetCh |
        "-"  : sym := minus; GetCh |
        "."  : GetCh;
               IF ch = "." THEN GetCh; sym := ellipsis
                 ELSE sym := period
               END |
        "/"  : sym := slash; GetCh |
        "0".."9": Number |
        ":"  : GetCh;
               IF ch = "=" THEN GetCh; sym := becomes
                 ELSE sym := colon
               END |
        ";"  : sym := semicolon; GetCh |
        "<"  : GetCh;
               IF ch = "=" THEN GetCh; sym := leq
                 ELSIF ch = ">" THEN GetCh; sym := neq
                 ELSE sym := lss
               END |
        "="  : sym := eql; GetCh   |
        ">"  : GetCh;
               IF ch = "=" THEN GetCh; sym := geq
                 ELSE sym := gtr
               END |
        "?"  : sym := null; GetCh  |
        "@"  : sym := null; GetCh  |
        "A".."Z": Identifier       |
        "["  : sym := lbrak; GetCh |
        "\"  : sym := null; GetCh  |
        "]"  : sym := rbrak; GetCh |
        "^"  : sym := arrow; GetCh |
        "_"  : sym := becomes; GetCh  |
        "`"  : sym := null; GetCh  |
        "a".."z": Identifier       |
        "{"  : sym := lbrace; GetCh|
        "|"  : sym := bar; GetCh   |
        "}"  : sym := rbrace; GetCh|
        "~"  : sym := not; GetCh   |
        177C : sym := ellipsis; GetCh
    END
  END GetSym;

  PROCEDURE Enter(name: ARRAY OF CHAR): CARDINAL;
    VAR j, l: CARDINAL;
  BEGIN l := HIGH(name)+2; id1 := id;
    IF id1+l < IdBufLeng THEN
      IdBuf[id] := CHR(l); INC(id);
      FOR j := 0 TO l-2 DO IdBuf[id] := name[j]; INC(id) END
    END ;
    RETURN id1
  END Enter;

  PROCEDURE InitScanner(VAR name: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN ch := " "; scanerr := FALSE; lastPos := 0;
    IF id0 = 0 THEN
      id0 := id; Lookup(errLog, "DK.err.LST", TRUE);
      Lookup(errDat, "DK.err.DAT", TRUE)
    ELSE id := id0; WriteChar(errLog, "-"); WriteChar(errLog, 12C)
    END;
    WriteChar(errDat, FNM); i := 0;
    WHILE name[i] > 0C  DO
      WriteChar(errDat, name[i]); WriteChar(errLog, name[i]); i := i+1
    END ;
    WriteChar(errLog, " "); WriteChar(errDat, 0C)
  END InitScanner;
  
  PROCEDURE CloseScanner;
  BEGIN Close(errLog); Close(errDat)
  END CloseScanner;
  
  PROCEDURE EnterKW(sym: Symbol; name: ARRAY OF CHAR);
  VAR l, L: CARDINAL;
  BEGIN
    keyTab[K].sym := sym;
    keyTab[K].ind := id;
    l := 0; L := HIGH(name);
    IdBuf[id] := CHR(L+2); INC(id);
    WHILE l <= L DO
      IdBuf[id] := name[l];
      INC(id); INC(l)
    END;
    INC(K)
  END EnterKW;
  
BEGIN K := 0; IdBuf[0] := 1C; id := 1; id0 := 0;
  pow[0] := 1.0E1;
  pow[1] := 1.0E2;
  pow[2] := 1.0E4;
  pow[3] := 1.0E8;
  pow[4] := 1.0E16;
  pow[5] := 1.0E32;
  EnterKW(by,"BY");
  EnterKW(do,"DO");
  EnterKW(if,"IF");
  EnterKW(in,"IN");
  EnterKW(of,"OF");
  EnterKW(or,"OR");
  EnterKW(to,"TO");
  EnterKW(and,"AND");
  EnterKW(div,"DIV");
  EnterKW(end,"END");
  EnterKW(for,"FOR");
  EnterKW(mod,"MOD");
  EnterKW(not,"NOT");
  EnterKW(set,"SET");
  EnterKW(var,"VAR");
  EnterKW(case,"CASE");
  EnterKW(code,"CODE");
  EnterKW(else,"ELSE");
  EnterKW(exit,"EXIT");
  EnterKW(from,"FROM");
  EnterKW(loop,"LOOP");
  EnterKW(then,"THEN");
  EnterKW(type,"TYPE");
  EnterKW(with,"WITH");
  EnterKW(array,"ARRAY");
  EnterKW(begin,"BEGIN");
  EnterKW(const,"CONST");
  EnterKW(elsif,"ELSIF");
  EnterKW(until,"UNTIL");
  EnterKW(while,"WHILE");
  EnterKW(export,"EXPORT");
  EnterKW(import,"IMPORT");
  EnterKW(module,"MODULE");
  EnterKW(record,"RECORD");
  EnterKW(repeat,"REPEAT");
  EnterKW(return,"RETURN");
  EnterKW(forward,"FORWARD");
  EnterKW(pointer,"POINTER");
  EnterKW(procedure,"PROCEDURE");
  EnterKW(qualified,"QUALIFIED");
  EnterKW(definition,"DEFINITION");
  EnterKW(implementation,"IMPLEMENTATION");
END M2SS.
