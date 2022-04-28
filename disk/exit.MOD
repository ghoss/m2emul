(******************************************************
**
** MODULE Exit
**
** By Guido Hoss for MULE M-Code Emulator
**
** Implements the "exit" command for the "Comint" shell.
**
** 02.04.2022 
**
*******************************************************)

MODULE exit;

FROM Comint IMPORT
	ExitInterpreter;

BEGIN
	ExitInterpreter;
END exit.