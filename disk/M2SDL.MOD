(******************************************************
**
** MODULE M2SDL (originally M3DL)
**
** Niklaus Wirth's Modula-2 single pass compiler
** (believed to be source code version of 2.8.1986)
**
** Origin:
** - "mfk301" Lilith disk image by Jos Dreesen
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - Renamed from "M3DL" to "M2SDL" to avoid name
**   confusion during bootstrap compilation with
**   multipass compiler
** - Original implementation replaced by calls to 
**   "Storage" since MULE handles dynamic (heap) memory 
**   management by itself
**
** 02.04.2022 
**
*******************************************************)

IMPLEMENTATION MODULE M2SDL; (*NW 2.1.84 / 27.5.85*)

  IMPORT
    SYSTEM,
    Storage;

  FROM SYSTEM IMPORT 
    ADDRESS;


  PROCEDURE ALLOCATE(VAR a: ADDRESS; n: CARDINAL);
  BEGIN
    Storage.ALLOCATE(a, n);
  END ALLOCATE;

  PROCEDURE ResetHeap(a: ADDRESS);
  BEGIN
    Storage.ResetHeap(a);
  END ResetHeap;

BEGIN
END M2SDL.
