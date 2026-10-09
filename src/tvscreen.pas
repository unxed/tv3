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
  screen buffer) and then call ScreenWrite for the changed run so that the
  backend can flush it. }
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

var
  { shadow of a view: its offset and attribute (BIOS $08: dark gray on black) }
  ShadowSize: TPoint = (X: 2; Y: 1);
  ShadowAttr: TColorAttr;
  { the caret as last set through SetCaretPosition and SetCaretSize }
  CaretX: Integer = 0;
  CaretY: Integer = 0;
  CaretSize: Integer = 0;
  { hooks of the backend, nil when there is nothing to notify }
  OnScreenWrite: TScreenWriteHook = nil;
  OnCaretPosition: TCaretPositionHook = nil;
  OnCaretSize: TCaretSizeHook = nil;

{ Allocates (or reallocates) a screen of W x H zeroed cells. }
procedure ScreenCreate(W, H: Integer);
procedure ScreenDestroy;
{ The cells at (X, Y), Count of them, have changed in ScreenBuffer. }
procedure ScreenWrite(X, Y: Integer; Cells: PScreenCell; Count: Integer);
procedure SetCaretPosition(X, Y: Integer);
{ Size 0 hides the caret, 1..100 is a percentage of the cell height. }
procedure SetCaretSize(Size: Integer);

implementation

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

procedure ScreenWrite(X, Y: Integer; Cells: PScreenCell; Count: Integer);
begin
  if Assigned(OnScreenWrite) then
    OnScreenWrite(X, Y, Cells, Count);
end;

procedure SetCaretPosition(X, Y: Integer);
begin
  CaretX := X;
  CaretY := Y;
  if Assigned(OnCaretPosition) then
    OnCaretPosition(X, Y);
end;

procedure SetCaretSize(Size: Integer);
begin
  CaretSize := Size;
  if Assigned(OnCaretSize) then
    OnCaretSize(Size);
end;

initialization
  TScreen.ScreenMode := TDisplay.smCO80;
  TScreen.CursorLines := 20;
  ShadowAttr := TColorAttr(LongInt($08));
end.
