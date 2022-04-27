(******************************************************
**
** MODULE Clock
**
** Modifications by Guido Hoss for MULE M-Code Emulator
** - "GetTime" handled by MULE SVC function
** - "SetTime" ignored
**
** 02.04.2022 
**
*******************************************************)

IMPLEMENTATION MODULE Clock;


  PROCEDURE SetTime(t: Time);
  BEGIN
  END SetTime;


  PROCEDURE GetTime(VAR t: Time);

    PROCEDURE CallSVC(VAR t: Time);
    CODE
      246B; 2;
    END CallSVC;

  BEGIN
    CallSVC(t);
  END GetTime;


BEGIN
END Clock.
