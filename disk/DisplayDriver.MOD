(******************************************************
**
** MODULE DisplayDriver
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - Original bitmap routines reduced to stub procedures
**   as host emulator currently only supports character
**   oriented terminal mode.
** - "Write" procedure calls MULE emulator SVC hook.
**
** 02.04.2022 
**
*******************************************************)

IMPLEMENTATION MODULE DisplayDriver;


PROCEDURE Show(VAR bmd: BMDescriptor; on: BOOLEAN);
BEGIN
END Show;


PROCEDURE BuildBMD(fp, width, height: CARDINAL;
 VAR bmd: BMDescriptor);
BEGIN
END BuildBMD;


PROCEDURE DFF(): CARDINAL;
BEGIN
 RETURN 0;
END DFF;


PROCEDURE CharWidth(): CARDINAL;
BEGIN
 RETURN 8;
END CharWidth;


PROCEDURE LineHeight(): CARDINAL;
BEGIN
 RETURN 8;
END LineHeight;


PROCEDURE BMF(): CARDINAL;
BEGIN
 RETURN 0;
END BMF;


PROCEDURE ChangeBitmap(height: CARDINAL; VAR done: BOOLEAN);
BEGIN
END ChangeBitmap;


PROCEDURE ScreenWidth(): CARDINAL;
BEGIN
 RETURN 1024;
END ScreenWidth;


PROCEDURE ScreenHeight(): CARDINAL;
BEGIN
 RETURN 768;
END ScreenHeight;


PROCEDURE MapHeight(): CARDINAL;
BEGIN
 RETURN ScreenHeight();
END MapHeight;


PROCEDURE DCH(ch: CHAR);
CODE 345B
END DCH;


PROCEDURE Write(ch: CHAR);
(*the following control characters are interpreted:
 10C BS  backspace one character
 12C LF  next line, same x position
 14C FF  clear page
 15C CR  return to start of line
 30C CAN clear line
 36C EOL next line
 177C DEL backspace one character and clear it *)
BEGIN
 IF (ch = 36C) THEN
  ch := 12C;
 END;
 DCH(ch);
END Write;


BEGIN
END DisplayDriver.