(******************************************************
**
** MODULE LongInt
**
** By Guido Hoss for MULE M-Code Emulator
**
** Support module for M2 single pass compiler.
**
** 02.04.2022 
**
*******************************************************)

IMPLEMENTATION MODULE LongInt;

  PROCEDURE LONG(hi, lo: CARDINAL): LONGINT;
  VAR
    x: LONGINT;
  BEGIN
    x.hi := hi; 
    x.lo := lo;
    RETURN x;
  END LONG;


  PROCEDURE LGE(x, y: LONGINT): BOOLEAN;
  BEGIN
    RETURN (x.hi > y.hi) OR ((x.hi = y.hi) AND (x.lo >= y.lo));
  END LGE;


  PROCEDURE LADD(x, y: LONGINT): LONGINT;

    PROCEDURE CallDADD(x, y: LONGINT) : LONGINT;
    CODE
      210B;
    END CallDADD;

  BEGIN
    RETURN CallDADD(x, y);
  END LADD;


  PROCEDURE LSUB(x, y: LONGINT): LONGINT;

    PROCEDURE CallDSUB(x, y: LONGINT) : LONGINT;
    CODE
      211B;
    END CallDSUB;

  BEGIN
    RETURN CallDSUB(x, y);
  END LSUB;

END LongInt.