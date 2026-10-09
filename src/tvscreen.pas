{ TvScreen: the screen as the views see it: its size, the cell buffer of the
  whole screen, the shadow settings and the hooks a backend plugs in.

  Translated from magiblot/tvision @ b4831e2 (the screen-related parts, turned into
  variables and hooks):
    TScreen (screenWidth, screenHeight, screenBuffer, cursorLines),
    THardwareInfo::screenWrite / setCaretPosition / setCaretSize,
    shadowSize and shadowAttr (source/tvision/tview.cpp).
  The platform code behind these (terminal, DOS video memory, a window) is the
  backend (tv/DESIGN.md); the memory backend of the tests just leaves the cells
  in ScreenBuffer. Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Views write cells into ScreenBuffer themselves (the top group's buffer is the
  screen buffer) and then call THardwareInfo.ScreenWrite for the changed run so that the
  backend can flush it. THardwareInfo has the members of tvision that the backend has a
  counterpart for (docs/API-NAMES.md). }
unit TvScreen;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvCell, TvColors;

type
  TScreenWriteHook = procedure(X, Y: Integer; Cells: PScreenCell; Count: Integer);
  TCaretPositionHook = procedure(X, Y: Integer);
  TCaretSizeHook = procedure(Size: Integer);

  TDisplay = class
  public
    const
      { screen modes (BIOS numbers; smFont8x8 is a flag) }
      smBW80    = 2;
      smCO80    = 3;
      smMono    = 7;
      smFont8x8 = $100;
      smUpdate  = $FFFF;    { "the screen has changed: read its size again" }
  end;

  TScreen = class(TDisplay)
  public
    class var ScreenMode: Word;
    class var ScreenWidth: Integer;
    class var ScreenHeight: Integer;
    { ScreenWidth * ScreenHeight cells, row by row; nil until ScreenCreate }
    class var ScreenBuffer: PScreenCell;
    { caret size in percent of a cell when not in insert mode }
    class var CursorLines: Integer;
  end;

  { the procedure that THardwareInfo.RequestClipboardText gives the text to }
  TClipboardAcceptProc = procedure(const Text: AnsiString);

  THardwareInfo = class
  private
    class var CaretSize: Word;
  public
    { the clock in ticks of 55 ms and in milliseconds (TvSys.GetClockMs of the backend, else the tick counter of the system) }
    class function GetTickCount: LongWord; static;
    class function GetTickCountMs: QWord; static;
    { Size 0 hides the caret, 1..100 is a percentage of the cell height. }
    class procedure SetCaretSize(Size: Word); static;
    class function GetCaretSize: Word; static;
    class procedure SetCaretPosition(X, Y: Word); static;
    class function IsCaretVisible: Boolean; static;
    class function GetScreenRows: Word; static;
    class function GetScreenCols: Word; static;
    class function GetScreenMode: Word; static;
    { through TvSys.OnSetVideoMode of the backend; TDisplay.smUpdate: the backend reads the size of the screen again }
    class procedure SetScreenMode(Mode: Word); static;
    { The cells at (X, Y), Len of them, have changed in TScreen.ScreenBuffer. }
    class procedure ScreenWrite(X, Y: Word; Buf: PScreenCell; Len: LongWord); static;
    { the system clipboard of the backend (the hooks of TvClip): False when there is none or it failed }
    class function SetClipboardText(const Text: AnsiString): Boolean; static;
    class function RequestClipboardText(Accept: TClipboardAcceptProc): Boolean; static;
  end;

var
  { shadow of a view: its offset and attribute (BIOS $08: dark gray on black) }
  ShadowSize: TPoint = (X: 2; Y: 1);
  ShadowAttr: TColorAttr;
  { the caret as last set through THardwareInfo.SetCaretPosition }
  CaretX: Integer = 0;
  CaretY: Integer = 0;
  { hooks of the backend, nil when there is nothing to notify }
  OnScreenWrite: TScreenWriteHook = nil;
  OnCaretPosition: TCaretPositionHook = nil;
  OnCaretSize: TCaretSizeHook = nil;

{ Allocates (or reallocates) a screen of W x H zeroed cells. }
procedure ScreenCreate(W, H: Integer);
procedure ScreenDestroy;

implementation

uses
  SysUtils, TvSys, TvClip;

procedure ScreenCreate(W, H: Integer);
begin
  ScreenDestroy;
  TScreen.ScreenWidth := W;
  TScreen.ScreenHeight := H;
  GetMem(TScreen.ScreenBuffer, W * H * SizeOf(TScreenCell));
  FillChar(TScreen.ScreenBuffer^, W * H * SizeOf(TScreenCell), 0);
end;

procedure ScreenDestroy;
begin
  if TScreen.ScreenBuffer <> nil then
    FreeMem(TScreen.ScreenBuffer);
  TScreen.ScreenBuffer := nil;
  TScreen.ScreenWidth := 0;
  TScreen.ScreenHeight := 0;
end;

class function THardwareInfo.GetTickCount: LongWord;
begin
  Result := LongWord(GetTickCountMs div 55);
end;

class function THardwareInfo.GetTickCountMs: QWord;
begin
  if Assigned(GetClockMs) then
    Result := GetClockMs()
  else
    Result := SysUtils.GetTickCount64;
end;

class procedure THardwareInfo.SetCaretSize(Size: Word);
begin
  CaretSize := Size;
  if Assigned(OnCaretSize) then
    OnCaretSize(Size);
end;

class function THardwareInfo.GetCaretSize: Word;
begin
  Result := CaretSize;
end;

class procedure THardwareInfo.SetCaretPosition(X, Y: Word);
begin
  CaretX := X;
  CaretY := Y;
  if Assigned(OnCaretPosition) then
    OnCaretPosition(X, Y);
end;

class function THardwareInfo.IsCaretVisible: Boolean;
begin
  Result := CaretSize <> 0;
end;

class function THardwareInfo.GetScreenRows: Word;
begin
  Result := TScreen.ScreenHeight;
end;

class function THardwareInfo.GetScreenCols: Word;
begin
  Result := TScreen.ScreenWidth;
end;

class function THardwareInfo.GetScreenMode: Word;
begin
  Result := TScreen.ScreenMode;
end;

class procedure THardwareInfo.SetScreenMode(Mode: Word);
begin
  if Assigned(OnSetVideoMode) then
    OnSetVideoMode(Mode);
end;

class procedure THardwareInfo.ScreenWrite(X, Y: Word; Buf: PScreenCell; Len: LongWord);
begin
  if Assigned(OnScreenWrite) then
    OnScreenWrite(X, Y, Buf, Len);
end;

class function THardwareInfo.SetClipboardText(const Text: AnsiString): Boolean;
begin
  Result := Assigned(OnClipboardSet) and OnClipboardSet(Text);
end;

class function THardwareInfo.RequestClipboardText(Accept: TClipboardAcceptProc): Boolean;
var
  Text: AnsiString;
begin
  Result := Assigned(OnClipboardGet) and OnClipboardGet(Text);
  if Result then
    Accept(Text);
end;

initialization
  TScreen.ScreenMode := TDisplay.smCO80;
  TScreen.CursorLines := 20;
  THardwareInfo.CaretSize := 0;
  ShadowAttr := TColorAttr(LongInt($08));
end.
