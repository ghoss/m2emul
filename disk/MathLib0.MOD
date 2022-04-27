(******************************************************
**
** MODULE MathLib0
**
** Origin:
** - medos42a Lilith disk image by Jos Dreesen
**
** 02.04.2022 
**
*******************************************************)

IMPLEMENTATION MODULE MathLib0;
  (*REAL Functions.  J.Waldvogel / N.Wirth  10.12.80*)
  FROM Terminal IMPORT WriteString;

  TYPE Real =
    RECORD
      CASE : CARDINAL OF
        0: R: REAL |
        1: H: INTEGER; L: CARDINAL
      END
    END ;

  PROCEDURE UNPK(m,n,x: INTEGER): INTEGER;
    CODE 346B
  END UNPK;

  PROCEDURE PACK(VAR res: INTEGER; m,n,x: INTEGER);
    CODE 347B
  END PACK;

  PROCEDURE float(x: INTEGER): REAL;
    CODE 237B; 0
  END float;

  PROCEDURE fix(x: REAL): INTEGER;
    CODE 237B; 2
  END fix;

  PROCEDURE R(H,L: CARDINAL): REAL;
    CODE (*null*)
  END R;

  PROCEDURE real(i: INTEGER): REAL;
  BEGIN
    IF i >= 0 THEN RETURN float(i)
      ELSE RETURN -float(-i)
    END
  END real;

  PROCEDURE entier(x: REAL): INTEGER;
    VAR k: INTEGER;
  BEGIN
    IF x >= 0.0 THEN RETURN fix(x)
    ELSE k := fix(-x);
      IF float(k) = -x THEN RETURN -k ELSE RETURN -k-1 END
    END
  END entier;

  PROCEDURE sqrt(x: REAL): REAL;
    VAR e,h: INTEGER;
      X: Real; s: REAL;
  BEGIN
    IF x = 0.0 THEN RETURN x END ;
    IF x < 0.0 THEN
      WriteString("Sqrt with neg arg"); HALT
    END ;
    X.R := x;
    e := UNPK(1, 8, X.H) - 128; h := 128;
    IF ODD(e) THEN INC(e); DEC(h) END ;
    PACK(X.H, 1, 8, h); x := X.R;
    s := R(37657B,135201B)*x + R(40146B,51042B) +
         R(137672B,61621B)/(R(40000B,16B) + x);
    X.R := (s + x/s)*0.5; X.H := e*64 + X.H; RETURN X.R
  END sqrt;

  PROCEDURE exp(x: REAL): REAL;
    VAR n,h: INTEGER;
      X: Real; x2, y: REAL;
  BEGIN x := R(40270B,125073B) * x;   (*x/ln 2*)
    n := entier(x+0.5); x := x - real(n);
    IF n < -128 THEN RETURN 0.0
      ELSIF n > 127 THEN WriteString("arg of exp too large"); HALT
    END ;
    x2 := x*x;
    y := (R(40746B,160654B) + R(37154B,53145B)*x2)*x;
    X.R := y/(R(41246B,105673B) + x2 - y) + 0.5;
    X.H := (n+1)*128 + X.H; RETURN X.R
  END exp;

  PROCEDURE ln(x: REAL): REAL;
    VAR e: INTEGER;
      X: Real;
  BEGIN
    IF x <= 0.0 THEN 
      WriteString("log with neg arg"); HALT
    END ;
    X.R := x;
    e := UNPK(1, 8, X.H) - 128; PACK(X.H, 1, 8, 128);
    x := R(40265B,2363B)* X.R; x := (x - 1.0)/(x + 1.0);
    x := R(40061B,71030B)*(real(e) - 0.5) +
         x * (R(40145B,41046B) + R(40352B,34126B)/(R(40324B,10515B) - x*x));
    RETURN x
  END ln;

  PROCEDURE sin(x: REAL): REAL;
    VAR n: INTEGER; x2,y: REAL;
  BEGIN x := R(40042B,174603B) *x; (* 2/pi *)
    n := entier(x + 0.5); x := (x - real(n)) * 2.0; x2 := x*x;
    IF NOT ODD(n) THEN
      y := x*(R(41523B,43077B) + x2*(R(140624B,121065B) + x2*R(37261B,126131B))) /
           (R(41606B,100140B) + x2)
    ELSE
      y := (R(41476B,137711B) + x2*(R(141133B,51770B) + x2*R(37745B,44370B))) /
           (R(41476B,137711B) + x2)
    END ;
    IF ODD(CARDINAL(n) DIV 2) THEN y := -y END ;
    RETURN y
  END sin;

  PROCEDURE cos(x: REAL): REAL;
    VAR n: INTEGER; x2,y: REAL;
  BEGIN x := R(40042B,174603B) *x; (* 2/pi *)
    n := entier(x + 0.5); x := (x - real(n)) * 2.0; x2 := x*x;
    IF ODD(n) THEN
      y := x*(R(41523B,43077B) + x2*(R(140624B,121065B) + x2*R(37261B,126131B))) /
           (R(41606B,100140B) + x2)
    ELSE
      y := (R(41476B,137711B) + x2*(R(141133B,51770B) + x2*R(37745B,44370B))) /
           (R(41476B,137711B) + x2)
    END ;
    IF ODD(CARDINAL(n+1) DIV 2) THEN y := -y END ;
    RETURN y
  END cos;

  PROCEDURE arctan(x: REAL): REAL;
    VAR x1, x2, s: REAL;
  BEGIN x1 := ABS(x); s := 0.0;
    IF x1 > R(40432B,101172B) THEN
      x1 := -1.0 / x1; s := R(40311B,7733B);  (*pi/2*)
    ELSIF x1 > R(37724B,11715B) THEN          (*sqrt(2)-1*)
      x1 := (x1 - 1.0) / (x1 + 1.0); s := R(40111B,7733B)
    END ;
    x2 := x1 * x1;
    s := s + R(40713B,150145B)*x1 /
         (x2 + R(41011B,117552B) + R(140615B,175713B)/(x2 + R(40376B,66262B)));
    IF x < 0.0 THEN s := -s END ;
    RETURN s
  END arctan;
END MathLib0.
