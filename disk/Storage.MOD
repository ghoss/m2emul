(******************************************************
**
** MODULE Storage
**
** Origin:
** - medos42a Lilith disk image by Jos Dreesen
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - Reduced entire original implementation to stubs
**   as dynamic (heap) memory management is being
**   handled by MULE.
**
** 02.04.2022 
**
*******************************************************)

IMPLEMENTATION MODULE Storage;

  FROM SYSTEM IMPORT
    ADDRESS;


  PROCEDURE CallSVC(VAR a: ADDRESS; s: CARDINAL; mode: CARDINAL);
  CODE
    246B; 0;
  END CallSVC;


  PROCEDURE ALLOCATE(VAR a: ADDRESS; s: CARDINAL);
  BEGIN 
    CallSVC(a, s, 0);
  END ALLOCATE;   
 

  PROCEDURE DEALLOCATE(VAR a:ADDRESS; s: CARDINAL); 
  BEGIN
    CallSVC(a, s, 1);
  END DEALLOCATE; 
 
 
  PROCEDURE ResetHeap(VAR a: ADDRESS);
  BEGIN
    CallSVC(a, 0, 2);
  END ResetHeap;


BEGIN
END Storage.
