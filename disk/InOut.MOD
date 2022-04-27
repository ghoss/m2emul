(******************************************************
**
** MODULE InOut
**
** Origin:
** - medos42a Lilith disk image by Jos Dreesen
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - None
**
** 02.04.2022 
**
*******************************************************)

IMPLEMENTATION MODULE InOut;   (*NW 20.12.82*)
  IMPORT Terminal;
  FROM SYSTEM IMPORT WORD;
  FROM FileSystem IMPORT File, Response, Lookup,
       ReadChar, ReadWord, WriteChar, WriteWord, Close;

  CONST ESC = 33C; DEL = 177C; NL = 27;
  VAR ch: CHAR; k: CARDINAL;
      name: ARRAY [0..NL] OF CHAR;
      openIn, openOut: BOOLEAN;

  PROCEDURE ReadName(ext: ARRAY OF CHAR);
    VAR i, j, lim: CARDINAL;
  BEGIN Terminal.Read(ch);
    IF ch = "#" THEN
      Terminal.Write("#"); Terminal.Read(ch); lim := 0
    ELSE lim := 3;
      name[0] := "D"; name[1] := "K"; name[2] := "."
    END ;
    i := lim;
    IF ch = " " THEN
      WHILE i < k DO
        Terminal.Write(name[i]); i := i+1
      END ;
      Terminal.Read(ch)
    END ;
    WHILE ch >= "." DO
      IF ch = DEL THEN
        IF i > lim THEN Terminal.Write(DEL); i := i-1 END
      ELSIF (ch >= ".") & (i < NL) THEN
        Terminal.Write(ch); name[i] := ch; i := i+1
      END ;
      Terminal.Read(ch)
    END ;
    k := i;
    IF (lim < i) & (i < NL) & (name[i-1] = ".") THEN
      (*append extension*) j := 0;
      REPEAT name[i] := ext[j];
        Terminal.Write(ext[j]); i := i+1; j := j+1
      UNTIL (j > HIGH(ext)) OR (i = NL)
    END ;
    name[i] := 0C
  END ReadName;

  PROCEDURE OpenInput(defext: ARRAY OF CHAR);
  BEGIN
    REPEAT Terminal.WriteString("in> "); ReadName(defext);
      IF ch # ESC THEN
        Lookup(in,name,FALSE);
        IF in.res # done THEN
          Terminal.WriteString(" not found")
        END
      END ;
      Terminal.WriteLn
    UNTIL (in.res = done) OR (ch = ESC);
    openIn := ch # ESC; Done := openIn
  END OpenInput;

  PROCEDURE OpenOutput(defext: ARRAY OF CHAR);
  BEGIN
    REPEAT Terminal.WriteString("out> "); ReadName(defext);
      IF ch # ESC THEN
        Lookup(out,name,TRUE);
        IF (out.res = done) & (NOT out.new) THEN
          Terminal.WriteString(" overwrite? ");
          REPEAT Terminal.Read(ch) UNTIL (ch = "y") OR (ch = "n");
          Terminal.Write(ch);
          IF ch = "n" THEN Close(out); ch := ESC END
        END
      END ;
      Terminal.WriteLn
    UNTIL (out.res = done) OR (ch = ESC);
    openOut := ch # ESC; Done := openOut
  END OpenOutput;

  PROCEDURE CloseInput;
  BEGIN
    IF openIn  THEN Close(in); openIn := FALSE END
  END CloseInput;

  PROCEDURE CloseOutput;
  BEGIN
    IF openOut THEN Close(out); openOut := FALSE END
  END CloseOutput;

  PROCEDURE Read(VAR ch: CHAR);
  BEGIN
    IF openIn THEN
      ReadChar(in,ch); Done := NOT in.eof
    ELSE Terminal.Read(ch)
    END
  END Read;

  PROCEDURE ReadWrd(VAR w: WORD);
  BEGIN
    IF openIn THEN
      ReadWord(in,w); Done := NOT in.eof
    ELSE Done := FALSE
    END
  END ReadWrd;

  PROCEDURE ReadString(VAR s: ARRAY OF CHAR);
    CONST DEL = 177C; EOL = 36C;
    VAR i,n: CARDINAL; ch: CHAR;
  BEGIN i := 0; n := HIGH(s);
    IF openIn THEN
      REPEAT ReadChar(in,ch) UNTIL (ch > " ") OR in.eof;
      REPEAT
        IF i <= n THEN
          s[i] := ch; i := i+1
        END ;
        ReadChar(in,ch)
      UNTIL ch <= " "
    ELSE
      REPEAT Terminal.Read(ch) UNTIL (ch > " ") OR (ch = ESC);
      WHILE ch > " " DO
        IF ch = DEL THEN
          IF i > 0 THEN i := i-1; Terminal.Write(DEL) END
        ELSE
          IF i <= n THEN s[i] := ch; i := i+1; Terminal.Write(ch) END
        END ;
        Terminal.Read(ch)
      END
    END ;
    IF i <= n THEN s[i] := 0C END ;
    termCH := ch
  END ReadString;

  PROCEDURE ReadInt(VAR x: INTEGER);
    VAR i: INTEGER; n: CARDINAL;
      ch: CHAR; neg: BOOLEAN;
      buf: ARRAY [0..9] OF CHAR;

    PROCEDURE next;
    BEGIN ch := buf[n]; n := n+1
    END next;

  BEGIN ReadString(buf); n := 0; next;
    WHILE ch = " " DO next END ;
    IF ch = "-" THEN
      neg := TRUE; next
    ELSE neg := FALSE;
      IF ch = "+" THEN next END
    END ;
    IF ("0" <= ch) & (ch <= "9") THEN
      i := 0; Done := TRUE;
      REPEAT i := 10*i + (INTEGER(ch) - 60B); next
      UNTIL (ch < "0") OR ("9" < ch);
      IF neg THEN x := -i ELSE x := i END
    ELSE Done := FALSE
    END
  END ReadInt;

  PROCEDURE ReadCard(VAR x: CARDINAL);
    VAR i,n: CARDINAL;
      ch: CHAR;
      buf: ARRAY [0..9] OF CHAR;

    PROCEDURE next;
    BEGIN ch := buf[n]; n := n+1
    END next;

  BEGIN ReadString(buf); n := 0; next;
    WHILE ch = " " DO next END ;
    IF ("0" <= ch) & (ch <= "9") THEN
      i := 0; Done := TRUE;
      REPEAT i := 10*i + (CARDINAL(ch) - 60B); next
      UNTIL (ch < "0") OR ("9" < ch);
      x := i
    ELSE Done := FALSE
    END
  END ReadCard;

  PROCEDURE Write(ch: CHAR);
  BEGIN
    IF openOut THEN WriteChar(out,ch)
      ELSE Terminal.Write(ch)
    END
  END Write;

  PROCEDURE WriteWrd(w: WORD);
  BEGIN
    IF openOut THEN WriteWord(out,w)
      ELSE Done := FALSE
    END
  END WriteWrd;

  PROCEDURE WriteLn;
  BEGIN
    IF openOut THEN WriteChar(out, EOL)
      ELSE Terminal.WriteLn
    END
  END WriteLn;

  PROCEDURE WriteString(s: ARRAY OF CHAR);
    VAR i,n: CARDINAL;
  BEGIN
    IF openOut THEN
      i := 0; n := HIGH(s);
      WHILE (i <= n) & (s[i] > 0C) DO
        WriteChar(out, s[i]); i := i+1
      END
    ELSE Terminal.WriteString(s)
    END
  END WriteString;

  PROCEDURE WriteInt(x: INTEGER; n: CARDINAL);
    VAR i, x0: CARDINAL;
      a: ARRAY [0..6] OF CHAR;
  BEGIN i := 0; x0 := ABS(x);
    REPEAT a[i] := CHAR(x0 MOD 10 + 60B);
      x0 := x0 DIV 10; i := i+1
    UNTIL x0 = 0;
    IF x < 0 THEN a[i] := "-"; i := i+1 END ;
    WHILE n > i DO
      n := n-1; Write(" ")
    END ;
    REPEAT i := i-1; Write(a[i]) UNTIL i = 0
  END WriteInt;

  PROCEDURE WriteCard(x,n: CARDINAL);
    VAR i: CARDINAL;
      a: ARRAY [0..6] OF CARDINAL;
  BEGIN i := 0;
    REPEAT a[i] := x MOD 10; x := x DIV 10; i := i+1
    UNTIL x = 0;
    WHILE n > i DO
      n := n-1; Write(" ")
    END ;
    REPEAT i := i-1; Write(CHAR(a[i]+60B)) UNTIL i = 0
  END WriteCard;

  PROCEDURE WriteOct(x,n: CARDINAL);
    VAR i: CARDINAL;
      a: ARRAY [0..6] OF CARDINAL;
  BEGIN i := 0;
    REPEAT a[i] := x MOD 8; x := x DIV 8; i := i+1
    UNTIL i = 5;
    IF x = 0 THEN a[i] := 0 ELSE a[i] := 1 END ;
    i := i+1;
    WHILE n > i DO
      n := n-1; Write(" ")
    END ;
    REPEAT i := i-1; Write(CHAR(a[i]+60B)) UNTIL i = 0
  END WriteOct;

  PROCEDURE WriteHex(x,n: CARDINAL);

    PROCEDURE HexDig(d: CARDINAL);
    BEGIN d := d MOD 16;
      IF d < 10 THEN d := d+60B ELSE d := d+67B END ;
      Write(CHAR(d))
    END HexDig;

  BEGIN
    WHILE n > 4 DO
      n := n-1; Write(" ")
    END ;
    HexDig(x DIV 1000H); HexDig(x DIV 100H);
    HexDig(x DIV 10H);  HexDig(x)
  END WriteHex;

BEGIN
  openIn := FALSE; openOut := FALSE; Done := FALSE
END InOut.
