(******************************************************
**
** MODULE FileNames
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

(***************************************
*                                      *
*          M E D O S - 2               *
*          *************               *
*                                      *
*                                      *
*          FileNames:                  *
*                                      *
*          FileNames allows to read    *
*          a filename according to     *
*          a default specification.    * 
*                                      *
*          Version 2  12.10.80         *    
*                                      *
*                                      *
*          Svend Erik Knudsen          *
*          Institut fuer Informatik    *
*          ETH-Zuerich                 *
*          CH-8092 Zuerich             *
*                                      *
***************************************)

(*
    Syntax of the different names:

    filename        = mediumname [ "." name ] [ 0C | ' ' ] .
    mediumname      = ident .
    name            = [ qualident "." ] lastident .
    qualident       = ident { "." ident } .
    lastident       = ident .
    ident           = wildletter { wildletter | digit } .
    wildletter      = letter | '*' | '%' .

    defaultfilename = [ mediumname ] [ "." [ defaultname ] ] [ 0C | ' ' ] .
    defaultname     = [ [ qualident ] "." ] lastident .

    inputfilename   = [ "#" [ mediumname ] [ "." inputname ] | inputname ] .
    inputname       = [ qualinput "." ] lastident .
    qualinput       = [ qualident [ "." ] ] [ "." qualident ] .

    The scanning of "inputfilename" is terminated by the characters
    <esc> and <can> or at a syntatically correct position by the
    caracters <eol>, " " and "/". The termination character can be
    read after the call. For correction of typing errors, <del> is
    accepted at any place in the input.
                                                                   *)

IMPLEMENTATION MODULE FileNames;

  FROM Terminal IMPORT
    Read, ReadAgain, Write, WriteString, WriteLn;


  CONST
    maxcardinal = 177777B;

    eol =  36C;
    esc =  33C;
    can =  30C;
    del = 177C;

  TYPE
    CC = (unknown, letter, digit, dot, terminator,
          mediummark, escape, delete, cancel);
    CCS = SET OF CC;
   

  PROCEDURE CharClass(ch: CHAR; wildcards: BOOLEAN): CC;
  BEGIN
    IF ('A' <= ch) AND (ch <= 'Z') OR
       ('a' <= ch) AND (ch <= 'z') OR
       wildcards AND ((ch = '*') OR (ch = '%')) THEN RETURN letter
    ELSIF ('0' <= ch) AND (ch <= '9') THEN RETURN digit
    ELSIF (ch = eol) OR (ch = ' ') OR
          (ch = '/') OR (ch = 0C) THEN RETURN terminator
    ELSIF ch = '.' THEN RETURN dot
    ELSIF ch = '#' THEN RETURN mediummark
    ELSIF ch = del THEN RETURN delete
    ELSIF ch = esc THEN RETURN escape
    ELSIF ch = can THEN RETURN cancel
    ELSE RETURN unknown
    END;
  END CharClass;

  PROCEDURE GetChar(VAR str: ARRAY OF CHAR; VAR pos: CARDINAL; VAR ch: CHAR);
  BEGIN
    IF pos > HIGH(str) THEN ch := 0C
    ELSE
      ch := str[pos];
      IF (40C < ch) AND (ch < 177C) THEN INC(pos)
      ELSE ch := 0C;
      END;
    END;
  END GetChar;

  PROCEDURE Identifiers(fn: ARRAY OF CHAR): CARDINAL;
    
    VAR
      pos, ids: CARDINAL;
      ch: CHAR;

  BEGIN
    ids := 0; pos := 0;
    LOOP
      GetChar(fn, pos, ch);
      IF CharClass(ch, TRUE) <> letter THEN EXIT END;
      INC(ids);
      REPEAT
        GetChar(fn, pos, ch);
      UNTIL NOT (CharClass(ch, TRUE) IN CCS{ letter, digit } );
      IF CharClass(ch, TRUE) <> dot THEN EXIT END;
    END;
    RETURN ids;
  END Identifiers;

  PROCEDURE IdentifierPosition(fn: ARRAY OF CHAR; identno: CARDINAL): CARDINAL;

  VAR
    pos: CARDINAL;
    ch: CHAR;
    cc: CC;
    
  BEGIN
    pos := 0;
    GetChar(fn, pos, ch);
    cc := CharClass(ch, TRUE);
    LOOP
      IF identno = 0 THEN
        IF cc = terminator THEN RETURN pos
        ELSIF cc = letter THEN RETURN pos-1
        ELSE RETURN maxcardinal
        END;
      ELSIF cc <> letter THEN RETURN maxcardinal;
      END;
      DEC(identno);
      REPEAT
        GetChar(fn, pos, ch);
        cc := CharClass(ch, TRUE);
      UNTIL NOT (cc IN CCS{letter, digit});
      IF cc = dot THEN
        GetChar(fn, pos, ch);
        cc := CharClass(ch, TRUE);
      END;
    END;
  END IdentifierPosition;
 
  PROCEDURE ReadFileName(VAR fn: ARRAY OF CHAR; dfn: ARRAY OF CHAR);

    CONST
      fnlength = 32;

    VAR
      ok: BOOLEAN;
  
      ch: CHAR; pos: CARDINAL;
      cc: CC;
      wildcard: BOOLEAN;
      afterdot: BOOLEAN;
   
      kb: BOOLEAN; 
   
      buf: ARRAY [0..fnlength] OF CHAR;  
      inx, outx: CARDINAL;
      echo, savedecho: BOOLEAN; 
  
      dfnpos: CARDINAL; 
  
      fnpos: CARDINAL;
   
      dmnapos, dmnatop: CARDINAL;
      dnapos, dnatop: CARDINAL; 
      dextpos, dexttop: CARDINAL;

    PROCEDURE Get; 
    BEGIN 
      IF NOT ok THEN ch := 0C; cc := unknown;
      ELSIF kb THEN 
        echo := inx = outx; 
        IF echo THEN Read(ch);
        ELSE ch := buf[outx]; INC(outx);  
        END;
        cc := CharClass(ch, wildcard);
        IF cc IN CCS{cancel, delete, escape} THEN ok := FALSE END; 
      ELSE
        pos := dfnpos;
        GetChar(dfn, dfnpos, ch);
        cc := CharClass(ch, TRUE);
        wildcard := wildcard OR (ch = '*') OR (ch = '%'); 
      END;
    END Get; 

    PROCEDURE Put(ch: CHAR); 
    BEGIN 
      IF kb AND ok THEN 
        IF (fnpos > 0) OR (ch <> '#') THEN 
          IF (fnpos <= HIGH(fn)) AND
             ((fnpos <> HIGH(fn)) OR (ch <> '.')) THEN
            fn[fnpos] := ch; INC(fnpos)
          ELSE ok := FALSE 
          END 
        END; 
        IF echo AND ok THEN 
          IF inx <= fnlength THEN 
            buf[inx] := ch;
            IF inx = outx THEN INC(outx) END;
            INC(inx); 
            Write(ch);
          ELSE ok := FALSE;
          END; 
        END; 
      END; 
    END Put; 
     
    PROCEDURE Copy(pos, top: CARDINAL);
    BEGIN
      ok := ok AND (pos < top); 
      WHILE pos < top DO Put(dfn[pos]); INC(pos) END; 
    END Copy; 

    PROCEDURE Ident; 
    BEGIN 
      IF cc = letter THEN 
        WHILE cc IN CCS{letter, digit} DO Put(ch); Get END; 
      ELSE ok := FALSE 
      END 
    END Ident; 

  BEGIN 
    ok := TRUE; kb := FALSE; wildcard := FALSE;
    dfnpos := 0; 
    Get; 
    dmnapos := pos; 
    IF cc = letter THEN Ident END; 
    dmnatop := pos;
    dnapos := pos; dnatop := dnapos;
    dextpos := pos; dexttop := dextpos;
    IF ch = '.' THEN
      Get;
      dnapos := pos; dnatop := dnapos;
      dextpos := pos; dexttop := dextpos;
      LOOP
        IF cc <> letter THEN afterdot := TRUE; EXIT END;
        dnatop := dexttop;
        dextpos := pos;
        Ident;
        dexttop := pos;
        IF ch <> '.' THEN afterdot := FALSE; EXIT END;
        Get;
      END;
      IF afterdot OR (ch = '.') THEN
        dnatop := dexttop;
        Get;
        dextpos := pos;
        IF cc = letter THEN Ident END;
        dexttop := pos;
      END;
    END;
    IF NOT ok OR (ch <> 0C) THEN
      WriteString(' ReadFileName called with incorrect default');
      WriteLn;
      HALT
    ELSE
      kb := TRUE; inx := 0; 
      LOOP 
        outx := 0; fnpos := 0; ok := TRUE;
        Get;
        IF ch = '#' THEN
          Put(ch); Get;
          IF cc = letter THEN Ident
          ELSE Copy(dmnapos, dmnatop);
          END;
          afterdot := ch = '.';
          IF ok AND afterdot THEN Put('.'); Get END;
        ELSE
          afterdot := cc <> terminator;
          IF afterdot THEN
            savedecho := echo; echo := FALSE;
            Put('#'); Copy(dmnapos, dmnatop); Put('.');
            echo := savedecho;
          END;
        END;
        IF ok AND (cc = letter) THEN
          LOOP
            Ident;
            IF ch <> '.' THEN afterdot := FALSE; EXIT END;
            Put(ch); Get;
            IF cc <> letter THEN afterdot := TRUE; EXIT END;
          END;
        END;
        IF ok AND afterdot AND (ch = '.') THEN
            Copy(dnapos, dnatop);
            IF ok THEN Put('.'); Get END;
        END;
        IF ok AND afterdot AND (cc = letter) THEN
          LOOP
            Ident;
            IF ch <> '.' THEN afterdot := FALSE; EXIT END;
            Put(ch); Get;
            IF cc <> letter THEN afterdot := TRUE; EXIT END;
          END;
        END;
        IF afterdot AND (cc = terminator) THEN
          Copy(dextpos, dexttop);
        END;
        IF (cc = terminator) AND ok THEN ReadAgain; EXIT
        ELSIF cc IN CCS{cancel, escape} THEN
          fnpos := 0; ReadAgain; EXIT; 
        ELSIF cc = delete THEN 
          IF inx > 0 THEN Write(del); DEC(inx) END; 
        END; 
      END; 
    END; 
    IF fnpos <= HIGH(fn) THEN fn[fnpos] := 0C END; 
  END ReadFileName;   

END FileNames.
