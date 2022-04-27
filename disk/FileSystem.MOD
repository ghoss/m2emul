(******************************************************
**
** MODULE FileSystem
**
** Origin:
** - medos42a Lilith disk image by Jos Dreesen
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - Replaced basically the entire original code as
**   all filesystem functions are now handled by MULE
**   and the underlying host system and called via the
**   MULE SVC hook.
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
*          FileSystem:                 *
*                                      *
*          Interface for               *
*          - FileSystem users  and     *
*          - FileSystem drivers.       *
*                                      *
*          Version 2   2.10.80         *    
*                                      *
*                                      *
*          Svend Erik Knudsen          *
*          Institut fuer Informatik    *
*          ETH-Zuerich                 *
*          CH-8092 Zuerich             *
*                                      *
***************************************)

IMPLEMENTATION MODULE FileSystem;

  FROM SYSTEM IMPORT
    ADDRESS, WORD;
    
  
  PROCEDURE Create(VAR f: File; mediumname: ARRAY OF CHAR);

    PROCEDURE SVC(VAR s: ARRAY OF CHAR; VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(mediumname, f, 0);
  END Create;
 

  PROCEDURE Close(VAR f: File);

    PROCEDURE SVC(VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(f, 1);
  END Close;
 

  PROCEDURE Lookup(VAR f: File; filename: ARRAY OF CHAR; new: BOOLEAN);

    PROCEDURE SVC(
      VAR new: BOOLEAN;
      VAR s: ARRAY OF CHAR; 
      VAR f: File; 
      cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(new, filename, f, 2);
  END Lookup;

 
  PROCEDURE Rename(VAR f: File; filename: ARRAY OF CHAR);

    PROCEDURE SVC(VAR s: ARRAY OF CHAR; VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(filename, f, 3);
  END Rename;
 

  PROCEDURE SetRead(VAR f: File);

    PROCEDURE SVC(VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(f, 4);
  END SetRead;
 
 
  PROCEDURE SetWrite(VAR f: File);    

    PROCEDURE SVC(VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(f, 5);
  END SetWrite;
 
 
  PROCEDURE SetModify(VAR f: File); 

    PROCEDURE SVC(VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(f, 6);
  END SetModify;
 
   
  PROCEDURE SetOpen(VAR f: File); 

    PROCEDURE SVC(VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(f, 7);
  END SetOpen;


  PROCEDURE SetPos(VAR f: File; highpos, lowpos: CARDINAL);

    PROCEDURE SVC(VAR hi, lo: CARDINAL; VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(highpos, lowpos, f, 8);
  END SetPos;

 
  PROCEDURE GetPos(VAR f: File; VAR highpos, lowpos: CARDINAL);

    PROCEDURE SVC(VAR hi, lo: CARDINAL; VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(highpos, lowpos, f, 9);
  END GetPos;

 
  PROCEDURE Length(VAR f: File; VAR highpos, lowpos: CARDINAL);

    PROCEDURE SVC(VAR hi, lo: CARDINAL; VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(highpos, lowpos, f, 10);
  END Length;
 
 
  PROCEDURE Reset(VAR f: File);

    PROCEDURE SVC(VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(f, 11);
  END Reset;
 
 
  PROCEDURE Again(VAR f: File);

    PROCEDURE SVC(VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(f, 12);
  END Again;

 
  PROCEDURE ReadWord(VAR f: File; VAR w: WORD);

    PROCEDURE SVC(VAR w: WORD; VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(w, f, 13);
    f.eof := (f.res # done);
  END ReadWord;  
 
 
  PROCEDURE WriteWord(VAR f: File; w: WORD);

    PROCEDURE SVC(VAR w: WORD; VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(w, f, 14);
  END WriteWord;
 
 
  PROCEDURE ReadChar(VAR f: File; VAR ch: CHAR);

    PROCEDURE SVC(VAR ch: CHAR; VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(ch, f, 15);
    f.eof := (f.res # done);
  END ReadChar;
 
 
  PROCEDURE WriteChar(VAR f: File; ch: CHAR);

    PROCEDURE SVC(VAR ch: CHAR; VAR f: File; cmd: CARDINAL): Response;
    CODE
      246B; 3;
    END SVC;

  BEGIN
    f.res := SVC(ch, f, 16);
  END WriteChar;


  PROCEDURE CreateMedium(mt: MediumType; mediumno: CARDINAL;
                         fp: FileProc; dp: DirectoryProc;
                         VAR done: BOOLEAN); 
  BEGIN
    done := TRUE;
  END CreateMedium;

 
  PROCEDURE RemoveMedium(mt: MediumType; mediumno: CARDINAL;
                         VAR done: BOOLEAN);           
  BEGIN
    done := TRUE;
  END RemoveMedium;

END FileSystem.
