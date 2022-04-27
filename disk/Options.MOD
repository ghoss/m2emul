(******************************************************
**
** MODULE Options
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

IMPLEMENTATION MODULE Options; (* $T+  AKG 28.05.80 *)
                               (* modified for Lilith  LG 01.07.81 *)

  FROM Terminal IMPORT Read, Write, WriteString;
  FROM FileNames IMPORT ReadFileName;

  (* (* definitons from definition module *)

  EXPORT QUALIFIED FileNameAndOptions, GetOption, Termination;

  TYPE Termination = (normal, empty, can, esc);

  (* end definitions *) *)

  CONST Bell   =   7C;
        CR     =  36C;
        Cancel =  30C; (*cancel line character*)
        Escape =  33C; (*no file character*)
        RubOut = 177C;

  CONST separator = '/';
        inpStrMax =  39;

  VAR inpStr: ARRAY [0..inpStrMax] OF CHAR;
      current,last: INTEGER;

  PROCEDURE FileNameAndOptions(default: ARRAY OF CHAR; VAR name: ARRAY OF CHAR;
                               VAR term: Termination; acceptOption: BOOLEAN);

    (*Read file name and options from terminal.
      Reads until a <cr>, blank, <can>, or <esc> is typped.
      To read the file name a default name can be proposed.
      name returns the read file name.
      term returns the status of the input termination:
          normal : normally terminated
          empty  : normally terminated, but name is empty
          can    : <can> is typed, input line cancelled
          esc    : <esc> is typed, no file specified.
      If acceptOption is TRUE, then options preceded by '/' will be accepted.*)

    VAR ch,chW: CHAR;
        lastSep: INTEGER;
  BEGIN
    ReadFileName(name,default);
    IF name[0] = 0C THEN term := empty ELSE term := normal END;
    current := 0; last := -1; lastSep := 0;
    LOOP
      Read(ch);
      IF ((ch = CR) OR (ch = ' ')) AND (lastSep <> last) THEN
        EXIT;
      ELSIF ch = Cancel THEN
        last := 0; Write('?');
        term := can;
        EXIT;
      ELSIF ch = Escape THEN
        last := 0; WriteString(" -- no file");
        term := esc;
        EXIT;
      END;
      chW := Bell;
      IF (last >= 0) OR (acceptOption AND (ch = separator)) THEN
        IF ch = RubOut THEN
          chW := ch;
          DEC(last); lastSep := 0;
          IF (last >= 0) AND (inpStr[last] = separator) THEN
            lastSep := last;
          END;
        ELSIF last < inpStrMax THEN
          INC(last); chW := ch; ch := CAP(ch);
          IF (ch >= 'A') AND (ch <= 'Z')THEN
            inpStr[last] := ch;
          ELSIF (chW >= '0') AND (chW <= '9') THEN
            inpStr[last] := chW;
          ELSIF (chW = separator) AND (lastSep <> last-1) THEN
            lastSep := last;
            inpStr[last] := separator; chW := separator;
          ELSE DEC(last); chW := Bell;
          END;
        END;
      END;
      Write(chW);
    END;
  END FileNameAndOptions;

  PROCEDURE GetOption(VAR optStr: ARRAY OF CHAR; VAR length: CARDINAL);

    (*To be called repeatedly after FileNameAndOptions, until length = 0.
      The characters of the next option are returned in optstr
      (terminated with a 0C character if length <= HIGH(optstr) ). *)

  BEGIN
    INC(current); length := 0;
    IF current <= last THEN
      LOOP
        IF length <= HIGH(optStr) THEN
          optStr[length] := inpStr[current]
        END;
        INC(length);
        IF current = last THEN EXIT END;
        INC(current);
        IF inpStr[current] = separator THEN EXIT END;
      END;
    END;
    IF length <= HIGH(optStr) THEN
      optStr[length] := 0C;
    END;
  END GetOption;

BEGIN (*Options*)
  current := 0; last := 0;
END Options.
