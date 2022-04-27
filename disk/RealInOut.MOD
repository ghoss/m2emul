(******************************************************
**
** MODULE RealInOut
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

IMPLEMENTATION MODULE RealInOut;  (*N.Wirth  16.8.81*)

  FROM InOut IMPORT Read, ReadString, Write;

  TYPE Real =
    RECORD
      CASE : CARDINAL OF
        0: R: REAL |
        1: H,L: CARDINAL
      END
    END ;

  VAR c1: ARRAY [0..5] OF REAL;    (* c1[i] = 10^(2^i)    *)
      c2: ARRAY [2..8] OF REAL;    (* c2[i] = 0.5*10^(-i) *)

  PROCEDURE sum(x,y: REAL): REAL; 
    CODE 210B
  END sum;

  PROCEDURE double(x: REAL): REAL;
    CODE 216B
  END double;

  PROCEDURE float(x: REAL): REAL;
    CODE 237B; 1
  END float;

  PROCEDURE fix(x: REAL; bias: CARDINAL): REAL;
    CODE 237B; 3
  END fix;

  PROCEDURE shr(x,n: CARDINAL): CARDINAL;
    CODE 277B
  END shr;

  PROCEDURE R(H,L: CARDINAL): REAL;
    CODE (*null*)
  END R;

  PROCEDURE unpk(m,n,w: CARDINAL): CARDINAL;
    (*extract bits m..n from w*)
    CODE 346B
  END unpk;

  PROCEDURE mul10(x: REAL): REAL;
  BEGIN
    RETURN double(sum(double(double(x)), x))
  END mul10;

  PROCEDURE ten(e: CARDINAL): REAL;    (*10^e*)
    VAR i: CARDINAL; t: REAL;
  BEGIN i := 0; t := 1.0;
    WHILE e > 0 DO
      IF ODD(e) THEN t := c1[i] * t END ;
      INC(i); e := e DIV 2
    END ;
    RETURN t
  END ten;

  PROCEDURE ReadReal(VAR X: REAL);
    VAR ch: CHAR; i,e: INTEGER; n,k: CARDINAL;
      buf: ARRAY [0..15] OF CHAR;
      x: REAL; neg, negE: BOOLEAN;

    PROCEDURE next;
    BEGIN ch := buf[n]; INC(n)
    END next;

  BEGIN ReadString(buf);
    Done := TRUE; n := 0; next;
    IF ch = "-" THEN
      neg := TRUE; next
    ELSE neg := FALSE;
      IF ch = "+" THEN next END
    END ;
    IF ("0" <= ch) & (ch <= "9") OR (ch = ".") THEN
      e := 0; k := 0; x := 0.0;
      WHILE ch = "0" DO next END ;
      WHILE ("0" <= ch) & (ch <= "9") DO
        IF k < 7 THEN
          x := sum(mul10(x), R(0, CARDINAL(ch)-60B)); INC(k)
        ELSE INC(e)
        END ;
        next
      END ;
      IF ch = "." THEN (*read fraction*)
        next;
        WHILE ("0" <= ch) & (ch <= "9") DO
          IF k < 7 THEN
            x := sum(mul10(x), R(0, CARDINAL(ch)-60B)); DEC(e); INC(k)
          END ;
          next
        END
      END ;
      IF CAP(ch) = "E" THEN (*read scale factor*)
        next; i := 0;
        IF ch = "-" THEN
          negE := TRUE; next
        ELSE negE := FALSE;
          IF ch = "+" THEN next END
        END ;
        IF ("0" <= ch) & (ch <= "9") THEN
          i := CARDINAL(ch) - 60B; next;
          WHILE ("0" <= ch) & (ch <= "9") DO
            i := 10*i + (INTEGER(ch) - 60B); next
          END
        ELSE Done := FALSE
        END ;
        IF negE THEN e := e-i ELSE e := e+i END
      END ;
      x := float(x);
      IF e < 0 THEN x := x / ten(-e)
               ELSE x := x * ten(e)
      END ;
      IF neg THEN X := -x ELSE X := x END
    ELSE Done := FALSE
    END
  END ReadReal;

  PROCEDURE WriteOct(z,n: CARDINAL);
    VAR i: CARDINAL;
        d: ARRAY [0..4] OF CARDINAL;
  BEGIN i := 0;
    REPEAT d[i] := z MOD 10B; z := z DIV 10B; i := i+1
    UNTIL i = n;
    REPEAT i := i-1; Write(CHAR(d[i]+60B))
    UNTIL i = 0
  END WriteOct;

  PROCEDURE WriteRealOct(x: REAL);
    VAR u: Real;
  BEGIN Write(" ");
    IF x = 0.0 THEN Write("0")
    ELSE
      IF x < 0.0 THEN Write("-") ELSE Write(" ") END ;
      u.R := x;
      WriteOct((u.H MOD 200B)*2 + shr(u.L, 15) + 400B, 3);
      WriteOct(u.L, 5); Write("'");
      WriteOct(unpk(1,8,u.H), 3)
    END
  END WriteRealOct;

  PROCEDURE WriteReal(x: REAL; n: CARDINAL);
    VAR e,m: CARDINAL; i: INTEGER;  x0: Real;
  BEGIN
    IF x = 0.0 THEN
      REPEAT Write(" "); DEC(n) UNTIL n <= 1;
      Write("0")
    ELSE
      IF n <= 9 THEN n := 3 ELSE n := n-6 END ;
      REPEAT Write(" "); DEC(n) UNTIL n <= 8;
      (*there are 1 < n <= 8 digits to be written*)
      IF x < 0.0 THEN Write("-"); x := -x ELSE Write(" ") END ;
      x0.R := x; e := x0.H DIV 200B;
      IF e > 200B THEN  (*x >= 1.0*)
        e := (e-200B)*77 DIV 400B; x := x/ten(e); i := e;
        IF x >= 1.0 THEN
          x := R(37314B,146314B)*x; INC(i)
        END
      ELSE
        e := (200B-e)*77 DIV 400B; x := x*ten(e); i := -INTEGER(e);
        IF x < 0.1 THEN
          x := 10.0 *x; DEC(i)
        END
      END ;
      x := x + c2[n];  (*round*)
      IF x >= 1.0 THEN
        x := R(37314B,146315B)*x; INC(i)
      END ;
      (* 0.1 <= x < 1.0 *)
      x0.R := mul10(fix(x, 40000B)); DEC(i);
      m := x0.H DIV 400B; x0.H := x0.H MOD 400B;
      Write(CHAR(m+60B)); Write("."); DEC(n);
      REPEAT x0.R := mul10(x0.R);
        m := x0.H DIV 400B; x0.H := x0.H MOD 400B;
        Write(CHAR(m+60B)); DEC(n)
      UNTIL n = 0;
      Write("E");
      IF i < 0 THEN Write("-"); i := -i
               ELSE Write("+")
      END ;
      Write(CHAR(i DIV 10 + 60B)); Write(CHAR(i MOD 10 + 60B))
    END
  END WriteReal;

BEGIN
  c1[0] := R(41040B,     0 ); c2[2] := R(36243B,153412B);
  c1[1] := R(41710B,     0 ); c2[3] := R(35403B, 11156B);
  c1[2] := R(43434B, 40000B); c2[4] := R(34521B,133427B);
  c1[3] := R(46676B,136040B); c2[5] := R(33647B,142654B);
  c1[4] := R(55416B, 15712B); c2[6] := R(33006B, 33675B);
  c1[5] := R(72635B,142656B); c2[7] := R(32200B,     0 ); c2[8] := 0.0
END RealInOut.
