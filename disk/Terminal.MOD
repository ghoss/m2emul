(******************************************************
**
** MODULE Terminal
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

(***************************************
*                                      *
*          M E D O S - 2               *
*          *************               *
*                                      *
*                                      *
*          Terminal:                   *
*                                      *
*          Standard Input              *
*          Standard Output             *
*                                      *
*          Version 4  12.06.82         *    
*                                      *
*                                      *
*          Svend Erik Knudsen          *
*          Institut fuer Informatik    *
*          ETH-Zuerich                 *
*          CH-8092 Zuerich             *
*                                      *
***************************************)

IMPLEMENTATION MODULE Terminal;

  IMPORT TerminalBase;
  
  CONST eol =  36C;

  VAR oldch: CHAR; again: BOOLEAN;

  PROCEDURE BusyRead(VAR ch: CHAR);
    VAR status: BITSET;
  BEGIN
    IF again THEN
      ch := oldch; again := FALSE
    ELSE TerminalBase.Read(ch);
      IF ch <> 0C THEN oldch := ch END;
    END;
  END BusyRead;

  PROCEDURE Read(VAR ch: CHAR);
  BEGIN 
    REPEAT
      BusyRead(ch)
    UNTIL ch <> 0C;
  END Read;

  PROCEDURE ReadAgain;
  BEGIN
    again := TRUE
  END ReadAgain;

  PROCEDURE Write(ch: CHAR);
  BEGIN
    TerminalBase.Write(ch);
  END Write;

  PROCEDURE WriteLn;
  BEGIN
    TerminalBase.Write(eol);
  END WriteLn;

  PROCEDURE WriteString(string: ARRAY OF CHAR);
    VAR c, h: CARDINAL; ch: CHAR;
  BEGIN
    h := HIGH(string); c := 0;
    LOOP
      IF c > h THEN EXIT END;
      ch := string[c]; INC(c);
      IF ch = 0C THEN EXIT END;
      TerminalBase.Write(ch);
    END
  END WriteString;

BEGIN
  oldch := ' '; again := FALSE;
END Terminal.

