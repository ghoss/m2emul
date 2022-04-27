(******************************************************
**
** MODULE TerminalBase
**
** Origin:
** - medos42a Lilith disk image by Jos Dreesen
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - Simplified "Read" and "Write" procedures which now
**   call the corresponding lowest-level I/O routines
**   in "DisplayDriver" and "Monitor".  
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
*          TerminalBase                *
*                                      *
*          Version 4  14.06.82         *    
*                                      *
*                                      *
*          Svend Erik Knudsen          *
*          Institut fuer Informatik    *
*          ETH-Zuerich                 *
*          CH-8092 Zuerich             *
*                                      *
***************************************)

IMPLEMENTATION MODULE TerminalBase;

  IMPORT Monitor, DisplayDriver;

  CONST
    levels = 5;

  VAR
    readtab: ARRAY [0..levels-1] OF
               RECORD rp: ReadProcedure; level: CARDINAL END;
    readtop, rt: CARDINAL;

    writetab: ARRAY [0..levels-1] OF
               RECORD wp: WriteProcedure; level: CARDINAL END;
    writetop, wt: CARDINAL;


  PROCEDURE AssignRead(rp: ReadProcedure; VAR done: BOOLEAN);
    VAR cl: CARDINAL;
  BEGIN
    done := FALSE;
    IF readtop = rt THEN
      cl := Monitor.CurrentLevel();
      IF (readtop = 0) OR (readtab[readtop-1].level < cl) THEN
        IF readtop < levels THEN
          readtab[readtop].rp := rp;
          readtab[readtop].level := cl;
          INC(readtop); rt := readtop;
          done := TRUE
        END
      ELSE
        readtab[readtop-1].rp := rp;
        done := TRUE;
      END
    END
  END AssignRead;

  PROCEDURE Read(VAR ch: CHAR);
  BEGIN
    IF rt = 0 THEN
      Monitor.Read(ch)
    ELSE
      DEC(rt); readtab[rt].rp(ch); INC(rt)
    END;
  END Read;

  PROCEDURE AssignWrite(wp: WriteProcedure; VAR done: BOOLEAN);
    VAR cl: CARDINAL;
  BEGIN
    done := FALSE;
    IF writetop = wt THEN
      cl := Monitor.CurrentLevel();
      IF (writetop = 0) OR (writetab[writetop-1].level < cl) THEN
        IF writetop < levels THEN
          writetab[writetop].wp := wp;
          writetab[writetop].level := cl;
          INC(writetop); wt := writetop;
          done := TRUE
        END
      ELSE
        writetab[writetop-1].wp := wp;
        done := TRUE
      END
    END
  END AssignWrite;

  PROCEDURE Write(ch: CHAR);
  BEGIN
    IF wt = 0 THEN
      DisplayDriver.Write(ch)
    ELSE
      DEC(wt); writetab[wt].wp(ch); INC(wt)
    END
  END Write;

  PROCEDURE Reset;
    VAR cl: CARDINAL;
  BEGIN
    cl := Monitor.CurrentLevel();
    WHILE (readtop > 0) AND (readtab[readtop-1].level >= cl) DO
      DEC(readtop)
    END;
    rt := readtop;
    WHILE (writetop > 0) AND (writetab[writetop-1].level >= cl) DO
      DEC(writetop)
    END;
    wt := writetop
  END Reset;

BEGIN
  readtop := 0; rt := 0; 
  writetop := 0; wt := 0;
  Monitor.TermProcedure(Reset);
END TerminalBase.
