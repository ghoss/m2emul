(******************************************************
**
** MODULE Program
**
** Origin:
** - medos42a Lilith disk image by Jos Dreesen
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - Most procedures have been reduced to stubs as 
**   corresponding functionality is being handled by
**   MULE. In particular, the "Call" procedure invokes
**   the MULE built-in loader via a SVC hook.
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
*          Program:                    *
*                                      *
*          Module for                  *
*          - program execution and     *
*          - storage management.       *
*                                      *
*          Version 4  18.06.82         *    
*                                      *
*                                      *
*          Svend Erik Knudsen          *
*          Institut fuer Informatik    *
*          ETH-Zuerich                 *
*          CH-8092 Zuerich             *
*                                      *
***************************************)

IMPLEMENTATION MODULE Program;

  IMPORT 
    SYSTEM,
    Monitor;

  FROM SYSTEM IMPORT 
    ADDRESS; 


  PROCEDURE Terminate(st: Status);
  BEGIN
    IF st > callerr THEN st := callerr END;
    Monitor.Terminate(VAL(Monitor.Status, ORD(st)));
  END Terminate; 


  PROCEDURE MainProcess(): BOOLEAN; 
  BEGIN 
    RETURN TRUE; 
  END MainProcess;   

 
  PROCEDURE CurrentLevel(): CARDINAL;  
  BEGIN 
    RETURN Monitor.CurrentLevel() 
  END CurrentLevel; 
 
 
  PROCEDURE SharedLevel(): CARDINAL; 
  BEGIN 
    RETURN Monitor.SharedLevel() 
  END SharedLevel; 
 
     
  PROCEDURE AllocateHeap(quantum: CARDINAL): ADDRESS; 
  BEGIN 
    RETURN NIL; 
  END AllocateHeap; 


  PROCEDURE DeallocateHeap(quantum: CARDINAL): ADDRESS; 
  BEGIN 
    RETURN NIL;
  END DeallocateHeap; 


  PROCEDURE Call(pn: ARRAY OF CHAR; sh: BOOLEAN; VAR st: Status); 

    PROCEDURE CallSVC(VAR pn: ARRAY OF CHAR) : BOOLEAN;
    CODE 
      246B; 1;
    END CallSVC;

  BEGIN
    IF CallSVC(pn) THEN
      st := normal;
    ELSE
      st := callerr;
    END;
  END Call;
      
BEGIN
END Program.