(******************************************************
**
** MODULE Comint
**
** By Guido Hoss for MULE M-Code Emulator
**
** A simple command line interpreter for MULE, similar
** to Lilith's original "SEK.Comint". Calls and executes
** programs in a loop. Still needs some work to develop
** this into a full-blown, user-friendly shell.
**
** 02.04.2022 
**
*******************************************************)

MODULE Comint;

IMPORT
  Program;

FROM InOut IMPORT
  ReadString,
  WriteString, 
  WriteLn;

VAR
  s: ARRAY [0..255] OF CHAR;
  st: Program.Status;
  exit: BOOLEAN;


PROCEDURE ExitInterpreter;
BEGIN
	exit := TRUE;
END ExitInterpreter;


BEGIN
  WriteString("MULE Comint 1.0");
  WriteLn;
  exit := FALSE;

  WHILE NOT exit DO
    WriteString("* ");
    ReadString(s); 
    WriteLn;

	IF (s[0] # 0C) THEN
		WriteString("Executing "); 
		WriteString(s);
		WriteLn;
		Program.Call(s, FALSE, st);
	END;
  END;

  WriteString("Terminated.");
  WriteLn;
END Comint.
