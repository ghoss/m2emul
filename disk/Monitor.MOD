(******************************************************
**
** MODULE Monitor
**
** Origin:
** - medos42a Lilith disk image by Jos Dreesen
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - Reduced most of the procedures to stub functions
**   since process management is being handled within
**   MULE. The keyboard read function "Read" calls
**   the SVC hook within MULE.
**
** 02.04.2022 
**
*******************************************************)

IMPLEMENTATION MODULE Monitor;

FROM SYSTEM IMPORT
 WORD;     

CONST 
 kbsreg = 1;
 kbdreg = 2; 


PROCEDURE Trap(st: Status);
CODE 304B;
END Trap;


PROCEDURE Terminate(st: Status);
(* Should only be called from a user program *)
BEGIN 
 IF st > callerr THEN 
  st := callerr 
 END;
 Trap(st);
END Terminate;


PROCEDURE CurrentLevel(): CARDINAL;
BEGIN
 RETURN 0; 
END CurrentLevel;


PROCEDURE SharedLevel(): CARDINAL;
BEGIN
 RETURN 0;
END SharedLevel;


PROCEDURE TermProcedure(t: PROC);
BEGIN
END TermProcedure;


PROCEDURE SetTime(t: Time); 
BEGIN 
END SetTime; 

     
PROCEDURE GetTime(VAR t: Time);
BEGIN 
 WITH t DO  
  day := 0;  
  minute := 0; 
  millisecond := 0; 
 END; 
END GetTime; 


PROCEDURE Read(VAR ch: CHAR);

 PROCEDURE Get(channel: CARDINAL; VAR w: WORD);
 CODE 240B;
 END Get;

VAR 
 kbs : BITSET;
BEGIN
 Get(kbsreg, kbs); 
 IF 15 IN kbs THEN 
   Get(kbdreg, ch);
   IF ch = 12C THEN 
    ch := 36C
   END;
 ELSE
  ch := 0C;
 END;
END Read;    

END Monitor.
