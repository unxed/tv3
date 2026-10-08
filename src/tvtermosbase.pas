{ TvTermOsBase: the types and the state shared by the facade TvTermOs and its backends (TvTermOsUnix, TvTermOsWin, TvTermOsNone).

  MIT, see tv/LICENSE. }
unit TvTermOsBase;

{$I tvdefs.inc}

interface

type
  TOsHook = procedure;

var
  { set by the backend when the size of the terminal changes }
  OsResizeFlag: LongInt = 0;
  { the size that the terminal told in its input (the far2l extensions), used when the kernel does not know the size; 0: none }
  OsToldCols: LongInt = 0;
  OsToldRows: LongInt = 0;

implementation

end.
