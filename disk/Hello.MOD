(******************************************************
**
** MODULE Hello
**
** By Guido Hoss for MULE M-Code Emulator
**
** A simple "Hello World" program in Modula-2
**
** 27.04.2022 
**
*******************************************************)

MODULE Hello;

FROM InOut IMPORT
	WriteCard, 
	WriteString, 
	WriteLn;

PROCEDURE Countdown;
VAR
	i: CARDINAL;
BEGIN
	FOR i := 10 TO 1 BY -1 DO
		WriteCard(i, 3);
	END;
	WriteLn;
END Countdown;

BEGIN
	WriteString("Hello World!");
	WriteLn;
	Countdown;
END Hello.