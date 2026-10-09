{ TvApp: the application: desktop, background, TProgram and TApplication.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/app.h, source/tvision/tprogram.cpp, tapplica.cpp, tdesktop.cpp,
    tbkgrnd.cpp, tvtext2.cpp (defaultBkgrnd, exitText)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the desktop, menu bar and status line are created by the virtual methods
      InitDeskTop, InitMenuBar and InitStatusLine, which set the variables DeskTop,
      MenuBar and StatusLine (as in the Pascal Turbo Vision);
    - the variables of the class (Application, StatusLine, ...) are variables of the unit;
    - events come from the hooks of TvSys (a backend) instead of TEventQueue; the screen
      and the clock too;
    - there is no LowMemory check (an allocation that fails raises an exception);
    - the dialog of ExecuteDialog is any view (TDialog is not translated yet);
    - streams are not translated yet. }
unit TvApp;

{$I tvdefs.inc}

interface

uses
  SysUtils,
  TvUtil, TvGeom, TvColors, TvCell, TvGlyphs, TvDrawBuf, TvScreen,
  TvKeys, TvEvents, TvXlat, TvSys, TvTimer,
  TvViews, TvWindow, TvMenus;

const
  { AppPalette }
  apColor      = 0;
  apBlackWhite = 1;
  apMonochrome = 2;

  { the text of the exit key of the default status line }
  ExitText = '~Alt-X~ Exit';
  { the character the desktop is filled with: the light shade }
  DefaultBackground = Ord(gcShadeLight);

  { help contexts of the standard commands ($FF0x file, $FF1x edit, $FF2x window) }
  hcCascade   = $FF21;
  hcChangeDir = $FF06;
  hcClear     = $FF14;
  hcClose     = $FF27;
  hcCloseAll  = $FF22;
  hcCopy      = $FF12;
  hcCut       = $FF11;
  hcDosShell  = $FF07;
  hcExit      = $FF08;
  hcNew       = $FF01;
  hcNext      = $FF25;
  hcOpen      = $FF02;
  hcPaste     = $FF13;
  hcPrev      = $FF26;
  hcResize    = $FF23;
  hcSave      = $FF03;
  hcSaveAll   = $FF05;
  hcSaveAs    = $FF04;
  hcTile      = $FF20;
  hcUndo      = $FF10;
  hcZoom      = $FF24;

var
  { UX guidelines of vtui, tier 0: Ctrl+Tab and Ctrl+Shift+Tab walk through the windows of the desktop. False: the keys are left to the application. }
  UxCtrlTab: Boolean = True;
  { UX guidelines 0.2, 0.3: with key releases at hand (TvSys.KeyUpAvailable: the win32 input mode, the keyboard protocol of Kitty) Ctrl+Tab opens a list of the
    windows in the middle of the screen, more presses walk it, and the choice is made when Ctrl is released (Esc cancels). False, or no key releases: the
    switch is at once. }
  UxSwitcher: Boolean = True;
  { the list closes by itself (the choice is made) when no key came for so long: the guard against a terminal that does not tell the release }
  SwitcherTimeoutMs: Integer = 8000;
  { Which key starts and walks the switcher: nil is Ctrl+Tab (Ctrl+Shift+Tab backwards). TvActions.UseActionsForSwitcher sets one that reads the action
    'window.switch', so the key can be rebound. True when the event is a key of the switcher; Backward tells the direction. }
  OnSwitcherKey: function(const Event: TEvent; out Backward: Boolean): Boolean = nil;

const
  { the item of the list of the switcher (always enabled) }
  cmSwitcherItem = 4001;

type
  TBackground = class;
  TDeskTop = class;
  TProgram = class;
  TApplication = class;

  { Palette: 1 = background }
  TBackground = class(TView)
    Pattern: Byte;
    constructor Create(const Bounds: TRect; APattern: Byte);
    procedure Draw; override;
    function GetPalette: TPalette; override;
  end;

  TDeskTop = class(TGroup)
    Background: TBackground;
    TileColumnsFirst: Boolean;
    constructor Create(const Bounds: TRect);
    destructor Destroy; override;
    procedure Cascade(const R: TRect);
    procedure HandleEvent(var Event: TEvent); override;
    { The window switcher. A step moves to the next window (the one under the current in the order of use) or the previous one. Held: the modifiers of the
      key (Ctrl, Alt); with Held <> 0 and key releases available the list is shown and the switch is made when they are let go (SwitcherEnd), else the switch
      is at once. True when a switch was done or the list moved. }
    function SwitcherStep(Backward: Boolean; Held: Word): Boolean;
    function SwitcherActive: Boolean;
    { Closes the list; Commit: go to the window that is chosen. }
    procedure SwitcherEnd(Commit: Boolean);
    { Called when the program is idle: closes the list that has waited too long. }
    procedure SwitcherIdle;
  private
    FSwitchBox: TView;
    FSwitchList: array of TView;
    FSwitchSel: Integer;
    FSwitchHeld: Word;
    FSwitchLast: Int64;
    function FindSwitchWindows: Boolean;
    procedure ShowSwitchBox;
    function IsSwitcherKey(const Event: TEvent; out Backward: Boolean): Boolean;
    function HasWindow(V: TView): Boolean;
  protected
    procedure InitBackground; virtual;
    procedure Tile(const R: TRect);
    { Called when the windows do not fit the rectangle. }
    procedure TileError; virtual;
  end;

  TProgram = class(TGroup)
    constructor Create;
    destructor Destroy; override;
    function CanMoveFocus: Boolean; virtual;
    function ExecuteDialog(P: TView; Data: Pointer): Word; virtual;
    procedure Draw; override;
    procedure EventError(var Event: TEvent); override;
    procedure GetEvent(var Event: TEvent); override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure Idle; virtual;
    procedure InitDeskTop; virtual;
    procedure InitMenuBar; virtual;
    procedure InitScreen; virtual;
    procedure InitStatusLine; virtual;
    procedure OutOfMemory; virtual;
    procedure PutEvent(var Event: TEvent); override;
    procedure Run; virtual;
    function InsertWindow(P: TWindow): TWindow; virtual;
    procedure SetScreenMode(Mode: Word);
    function ValidView(P: TView): TView;
    { Timers send cmTimerExpired (InfoPtr = the timer id) to the program. }
    function SetTimer(TimeoutMs: LongWord; PeriodMs: Integer = -1): TTimerId; override;
    procedure KillTimer(Id: TTimerId); override;
    procedure Suspend; virtual;
    procedure Resume; virtual;
  public
    class var Application: TProgram;
    class var StatusLine: TStatusLine;
    class var MenuBar: TMenuBar;
    class var DeskTop: TDeskTop;
    { the palette of the program: apColor, apBlackWhite, apMonochrome }
    class var AppPalette: Integer;
    { how long the program waits for an event before it calls Idle, in ms (-1: until something happens) }
    class var EventTimeoutMs: Integer;
  protected
    class var Pending: TEvent;
  end;

  TApplication = class(TProgram)
    constructor Create;
    destructor Destroy; override;
    procedure Suspend; override;
    procedure Resume; override;
    procedure Cascade;
    procedure DosShell;
    function GetTileRect: TRect; virtual;
    procedure HandleEvent(var Event: TEvent); override;
    procedure Tile;
    procedure WriteShellMsg; virtual;
  end;

var
  { DN: the palettes of the program by AppPalette (apColor, apBlackWhite, apMonochrome) as strings of attributes; the
    program can change them (the colors dialog); they start as the palettes of Turbo Vision }
  SystemColors: array[0..2] of ShortString;

implementation

const
  BackgroundPalette = #1;

{$I tvapppal.inc}

var
  TimerQueue: TTimerQueue;

{ --- TBackground ------------------------------------------------------------- }

constructor TBackground.Create(const Bounds: TRect; APattern: Byte);
begin
  inherited Create(Bounds);
  Pattern := APattern;
  GrowMode := gfGrowHiX or gfGrowHiY;
end;

procedure TBackground.Draw;
var
  B: TDrawBuffer;
begin
  B := TDrawBuffer.Create(Size.X);
  B.MoveChar(0, Pattern, GetColor($01)[0], Size.X);
  WriteLine(0, 0, Size.X, Size.Y, B);
  B.Free;
end;

function TBackground.GetPalette: TPalette;
begin
  Result := MakePalette(BackgroundPalette);
end;

{ --- TDeskTop ---------------------------------------------------------------- }

constructor TDeskTop.Create(const Bounds: TRect);
begin
  inherited Create(Bounds);
  GrowMode := gfGrowHiX or gfGrowHiY;
  TileColumnsFirst := False;
  Background := nil;
  InitBackground;
  if Background <> nil then
    Insert(Background);
end;

destructor TDeskTop.Destroy;
begin
  Background := nil;
  inherited Destroy;
end;

procedure TDeskTop.InitBackground;
var
  R: TRect;
begin
  R := GetExtent;
  Background := TBackground.Create(R, DefaultBackground);
end;

function Tileable(P: TView): Boolean;
begin
  Result := ((P.Options and ofTileable) <> 0) and ((P.State and sfVisible) <> 0);
end;

var
  CascadeNum: Integer;
  LastView: TView;

procedure DoCount(P: TView; Args: Pointer);
begin
  if Tileable(P) then
  begin
    Inc(CascadeNum);
    LastView := P;
  end;
end;

procedure DoCascade(P: TView; R: Pointer);
var
  Bounds: TRect;
begin
  if (CascadeNum < 0) or not Tileable(P) then
    Exit;
  Bounds := PRect(R)^;
  Inc(Bounds.A.X, CascadeNum);
  Inc(Bounds.A.Y, CascadeNum);
  P.Locate(Bounds);
  Dec(CascadeNum);
end;

procedure TDeskTop.Cascade(const R: TRect);
var
  MinSize, MaxSize: TPoint;
  Area: TRect;
begin
  CascadeNum := 0;
  ForEach(@DoCount, nil);
  if CascadeNum = 0 then
    Exit;
  LastView.SizeLimits(MinSize, MaxSize);
  if (MinSize.X > R.B.X - R.A.X - CascadeNum) or (MinSize.Y > R.B.Y - R.A.Y - CascadeNum) then
  begin
    TileError;
    Exit;
  end;
  { the front window gets the largest offset }
  Dec(CascadeNum);
  Area := R;
  Lock;
  try
    ForEach(@DoCascade, @Area);
  finally
    Unlock;
  end;
end;

{ the list of the windows is drawn by a menu box that takes no input }
type
  TSwitcherBox = class(TMenuBox)
    constructor Create(const Bounds: TRect; AMenu: PMenu);
    destructor Destroy; override;
    procedure HandleEvent(var Event: TEvent); override;
  end;

constructor TSwitcherBox.Create(const Bounds: TRect; AMenu: PMenu);
begin
  inherited Create(Bounds, AMenu, nil);
  Options := Options and not ofPreProcess;
  EventMask := 0;
end;

destructor TSwitcherBox.Destroy;
begin
  DisposeMenu(Menu);
  Menu := nil;
  inherited Destroy;
end;

procedure TSwitcherBox.HandleEvent(var Event: TEvent);
begin
end;

function TDeskTop.HasWindow(V: TView): Boolean;
var
  P: TView;
begin
  Result := False;
  if (V = nil) or (Last = nil) then
    Exit;
  P := Last;
  repeat
    if P = V then
      Exit(True);
    P := P.Next;
  until P = Last;
end;

{ the windows that can be chosen, the current one first and then the one under it, and so on: the order of use }
function TDeskTop.FindSwitchWindows: Boolean;
var
  P: TView;
  N: Integer;
begin
  SetLength(FSwitchList, 0);
  N := 0;
  if Current <> nil then
  begin
    P := Current;
    repeat
      if ((P.State and (sfVisible or sfDisabled)) = sfVisible) and ((P.Options and ofSelectable) <> 0) then
      begin
        SetLength(FSwitchList, N + 1);
        FSwitchList[N] := P;
        Inc(N);
      end;
      P := P.Prev;
    until P = Current;
  end;
  Result := N > 1;
end;

function TDeskTop.SwitcherActive: Boolean;
begin
  Result := FSwitchBox <> nil;
end;

procedure TDeskTop.ShowSwitchBox;
const
  MaxShown = 12;
var
  I, FirstIdx, Last_, W, H: Integer;
  Items, Sel: PMenuItem;
  T: ShortString;
  Menu: PMenu;
  R: TRect;
  Box: TSwitcherBox;
  Prog: TGroup;
begin
  Prog := Owner;
  if Prog = nil then
    Exit;
  { hide the old box }
  if FSwitchBox <> nil then
  begin
    Prog.Delete(FSwitchBox);
    FSwitchBox.Free;
    FSwitchBox := nil;
  end;
  FirstIdx := 0;
  if FSwitchSel >= MaxShown then
    FirstIdx := FSwitchSel - MaxShown + 1;
  Last_ := Length(FSwitchList) - 1;
  if Last_ > FirstIdx + MaxShown - 1 then
    Last_ := FirstIdx + MaxShown - 1;
  Items := nil;
  Sel := nil;
  for I := Last_ downto FirstIdx do
  begin
    if FSwitchList[I] is TWindow then
      T := TWindow(FSwitchList[I]).GetTitle(40)
    else
      T := '';
    if T = '' then
      T := '(untitled)';
    while Pos('~', T) > 0 do
      System.Delete(T, Pos('~', T), 1);
    Items := NewItem(T, '', kbNoKey, cmSwitcherItem, hcNoContext, Items);
    if I = FSwitchSel then
      Sel := Items;
  end;
  Menu := NewMenu(Items);
  R := TRect.Create(0, 0, Prog.Size.X, Prog.Size.Y);
  Box := TSwitcherBox.Create(R, Menu);
  Menu^.Deflt := Sel;
  Box.Current := Sel;
  W := Box.Size.X;
  H := Box.Size.Y;
  Box.MoveTo((Prog.Size.X - W) div 2, (Prog.Size.Y - H) div 2);
  Prog.Insert(Box);
  FSwitchBox := Box;
end;

function TDeskTop.IsSwitcherKey(const Event: TEvent; out Backward: Boolean): Boolean;
var
  K: TKey;
begin
  Backward := False;
  if Event.What <> evKeyDown then
    Exit(False);
  if Assigned(OnSwitcherKey) then
    Exit(OnSwitcherKey(Event, Backward));
  K := KeyMake(Event.KeyDown.KeyCode, Event.KeyDown.ControlKeyState);
  Result := (K.Code = kbTab) and ((K.Mods and kbCtrlShift) <> 0);
  Backward := Result and ((K.Mods and kbShift) <> 0);
end;

function TDeskTop.SwitcherStep(Backward: Boolean; Held: Word): Boolean;
begin
  Result := False;
  if UxSwitcher and KeyUpAvailable and (Held <> 0) and (FSwitchBox <> nil) then
  begin
    { the list is open: walk it }
    if Backward then
    begin
      Dec(FSwitchSel);
      if FSwitchSel < 0 then
        FSwitchSel := High(FSwitchList);
    end
    else
    begin
      Inc(FSwitchSel);
      if FSwitchSel > High(FSwitchList) then
        FSwitchSel := 0;
    end;
    FSwitchLast := ClockMs;
    ShowSwitchBox;
    Exit(True);
  end;
  if not Valid(cmReleasedFocus) then
    Exit;
  if UxSwitcher and KeyUpAvailable and (Held <> 0) and (Owner <> nil) and FindSwitchWindows then
  begin
    FSwitchHeld := Held;
    FSwitchSel := 0;
    if Backward then
      FSwitchSel := High(FSwitchList)
    else
      FSwitchSel := 1;
    FSwitchLast := ClockMs;
    KeyUpForApp := True;
    ShowSwitchBox;
    Exit(True);
  end;
  { no releases to wait for: at once }
  if Backward then
    Current.PutInFrontOf(Background)
  else
    SelectNext(False);
  Result := True;
end;

procedure TDeskTop.SwitcherEnd(Commit: Boolean);
var
  V: TView;
begin
  if FSwitchBox = nil then
    Exit;
  if Owner <> nil then
    Owner.Delete(FSwitchBox);
  FSwitchBox.Free;
  FSwitchBox := nil;
  KeyUpForApp := False;
  V := nil;
  if Commit and (FSwitchSel >= 0) and (FSwitchSel <= High(FSwitchList)) then
    V := FSwitchList[FSwitchSel];
  SetLength(FSwitchList, 0);
  if (V <> nil) and (V <> Current) and HasWindow(V) and Valid(cmReleasedFocus) then
    V.Select;
end;

procedure TDeskTop.SwitcherIdle;
begin
  if (FSwitchBox <> nil) and (ClockMs - FSwitchLast > SwitcherTimeoutMs) then
    SwitcherEnd(True);
end;

procedure TDeskTop.HandleEvent(var Event: TEvent);
var
  Back: Boolean;
begin
  { the list of the switcher is open: the release of the modifiers makes the choice, Esc cancels, the key again walks, any other input closes it }
  if FSwitchBox <> nil then
    case Event.What of
      evKeyUp:
        if (Event.KeyDown.KeyCode = 0) and ((Event.KeyDown.ControlKeyState and FSwitchHeld) <> FSwitchHeld) then
        begin
          SwitcherEnd(True);
          ClearEvent(Event);
          Exit;
        end;
      evKeyDown:
        if Event.KeyDown.KeyCode = kbEsc then
        begin
          SwitcherEnd(False);
          ClearEvent(Event);
          Exit;
        end
        else if IsSwitcherKey(Event, Back) then
        begin
          SwitcherStep(Back, FSwitchHeld);
          ClearEvent(Event);
          Exit;
        end
        else
          SwitcherEnd(True);
      evMouseDown:
        SwitcherEnd(True);
    end;
  inherited HandleEvent(Event);
  { UX guidelines, tier 0: Ctrl+Tab goes to the next window, Ctrl+Shift+Tab to the previous one (when no view took the key: a tabbed dialog or an
    editor keeps it). Where the terminal tells the releases of keys, a list of the windows is shown while Ctrl is held (SwitcherStep). }
  if (Event.What = evKeyDown) and UxCtrlTab and IsSwitcherKey(Event, Back) then
  begin
    SwitcherStep(Back, Event.KeyDown.ControlKeyState and (kbCtrlShift or kbAltShift));
    ClearEvent(Event);
  end;
  if Event.What = evCommand then
  begin
    case Event.Message.Command of
      cmNext:
        if Valid(cmReleasedFocus) then
          SelectNext(False);
      cmPrev:
        if Valid(cmReleasedFocus) then
          Current.PutInFrontOf(Background);
    else
      Exit;
    end;
    ClearEvent(Event);
  end;
end;

function ISqr(I: Integer): Integer;
var
  Res1, Res2: Integer;
begin
  Res1 := 2;
  Res2 := I div Res1;
  while Abs(Res1 - Res2) > 1 do
  begin
    Res1 := (Res1 + Res2) div 2;
    Res2 := I div Res1;
  end;
  if Res1 < Res2 then
    Result := Res1
  else
    Result := Res2;
end;

procedure MostEqualDivisors(N: Integer; var X, Y: Integer; FavorY: Boolean);
var
  D: Integer;
begin
  D := ISqr(N);
  if (N mod D <> 0) and (N mod (D + 1) = 0) then
    Inc(D);
  if D < N div D then
    D := N div D;
  if FavorY then
  begin
    Y := D;
    X := N div D;
  end
  else
  begin
    X := D;
    Y := N div D;
  end;
end;

var
  NumCols, NumRows, NumTileable, LeftOver, TileNum: Integer;

procedure DoCountTileable(P: TView; Args: Pointer);
begin
  if Tileable(P) then
    Inc(NumTileable);
end;

function DividerLoc(Lo, Hi, Num, Pos: Integer): Integer;
begin
  Result := Integer(Int64(Hi - Lo) * Pos div Num + Lo);
end;

function CalcTileRect(Pos: Integer; const R: TRect): TRect;
var
  Col, Row, Rows, Full: Integer;
begin
  { the first columns have NumRows windows, the LeftOver last ones one more }
  Full := (NumCols - LeftOver) * NumRows;
  if Pos < Full then
  begin
    Rows := NumRows;
    Col := Pos div Rows;
    Row := Pos mod Rows;
  end
  else
  begin
    Rows := NumRows + 1;
    Col := (Pos - Full) div Rows + NumCols - LeftOver;
    Row := (Pos - Full) mod Rows;
  end;
  Result.A.X := DividerLoc(R.A.X, R.B.X, NumCols, Col);
  Result.B.X := DividerLoc(R.A.X, R.B.X, NumCols, Col + 1);
  Result.A.Y := DividerLoc(R.A.Y, R.B.Y, Rows, Row);
  Result.B.Y := DividerLoc(R.A.Y, R.B.Y, Rows, Row + 1);
end;

procedure DoTile(P: TView; LR: Pointer);
var
  R: TRect;
begin
  if Tileable(P) then
  begin
    R := CalcTileRect(TileNum, PRect(LR)^);
    P.Locate(R);
    Dec(TileNum);
  end;
end;

procedure TDeskTop.Tile(const R: TRect);
var
  Area: TRect;
begin
  NumTileable := 0;
  ForEach(@DoCountTileable, nil);
  if NumTileable = 0 then
    Exit;
  MostEqualDivisors(NumTileable, NumCols, NumRows, TileColumnsFirst = False);
  { every window needs at least one cell }
  if (R.B.X - R.A.X < NumCols) or (R.B.Y - R.A.Y < NumRows) then
  begin
    TileError;
    Exit;
  end;
  LeftOver := NumTileable mod NumCols;
  TileNum := NumTileable - 1;
  Area := R;
  Lock;
  try
    ForEach(@DoTile, @Area);
  finally
    Unlock;
  end;
end;

procedure TDeskTop.TileError;
begin
end;

{ --- TProgram ---------------------------------------------------------------- }

constructor TProgram.Create;
var
  R: TRect;
begin
  R := TRect.Create(0, 0, TScreen.ScreenWidth, TScreen.ScreenHeight);
  inherited Create(R);
  Application := Self;
  InitScreen;
  State := sfVisible or sfSelected or sfFocused or sfModal or sfExposed;
  Options := 0;
  Buffer := TScreen.ScreenBuffer;
  DeskTop := nil;
  StatusLine := nil;
  MenuBar := nil;
  InitDeskTop;
  if DeskTop <> nil then
    Insert(DeskTop);
  InitStatusLine;
  if StatusLine <> nil then
    Insert(StatusLine);
  InitMenuBar;
  if MenuBar <> nil then
    Insert(MenuBar);
end;

destructor TProgram.Destroy;
begin
  StatusLine := nil;
  MenuBar := nil;
  DeskTop := nil;
  inherited Destroy;
  Application := nil;
end;

function TProgram.CanMoveFocus: Boolean;
begin
  Result := DeskTop.Valid(cmReleasedFocus);
end;

function EventWaitTimeout: Integer;
var
  TimerTimeout: Integer;
begin
  TimerTimeout := TimerQueue.TimeUntilNextTimeout;
  if TimerTimeout < 0 then
    Exit(TProgram.EventTimeoutMs);
  if TProgram.EventTimeoutMs < 0 then
    Exit(TimerTimeout);
  if TProgram.EventTimeoutMs < TimerTimeout then
    Result := TProgram.EventTimeoutMs
  else
    Result := TimerTimeout;
end;

function TProgram.ExecuteDialog(P: TView; Data: Pointer): Word;
var
  C: Word;
begin
  C := cmCancel;
  if ValidView(P) <> nil then
  begin
    if Data <> nil then
      P.SetData(Data^);
    C := DeskTop.ExecView(P);
    if (C <> cmCancel) and (Data <> nil) then
      P.GetData(Data^);
    P.Free;
  end;
  Result := C;
end;

function ViewHasMouse(P: TView; S: Pointer): Boolean;
begin
  Result := ((P.State and sfVisible) <> 0) and P.MouseInView(PEvent(S)^.Mouse.Where);
end;

procedure TProgram.EventError(var Event: TEvent);
begin
  { Alt+Ы, Ctrl+К of a Russian layout that nothing took (the hot keys of the program in that script are tried first): the shortcut
    of the Latin letter of the same key, Alt+S, Ctrl+R, goes round again }
  if (Event.What = evKeyDown) and XlatModded(Event) then
  begin
    Pending := Event;
    ClearEvent(Event);
    Exit;
  end;
  inherited EventError(Event);
end;

procedure TProgram.GetEvent(var Event: TEvent);
begin
  if Pending.What <> evNothing then
  begin
    Event := Pending;
    Pending.What := evNothing;
  end
  else
  begin
    PollEvent(EventWaitTimeout, Event);
    if Event.What = evNothing then
      Idle
  end;
  if StatusLine <> nil then
  begin
    if ((Event.What and evKeyDown) <> 0) or
      (((Event.What and evMouseDown) <> 0) and (FirstThat(@ViewHasMouse, @Event) = StatusLine)) then
      StatusLine.HandleEvent(Event);
  end;
  if (Event.What = evCommand) and (Event.Message.Command = cmScreenChanged) then
  begin
    SetScreenMode(TDisplay.smUpdate);
    ClearEvent(Event);
  end;
end;

function TProgram.GetPalette: TPalette;
begin
  case AppPalette of
    apBlackWhite: Result := MakePalette(SystemColors[apBlackWhite]);
    apMonochrome: Result := MakePalette(SystemColors[apMonochrome]);
  else
    Result := MakePalette(SystemColors[apColor]);
  end;
end;

procedure TProgram.HandleEvent(var Event: TEvent);
var
  C: Char;
begin
  { Alt+1..Alt+9 select the window with that number }
  if Event.What = evKeyDown then
  begin
    C := GetAltChar(Event.KeyDown.KeyCode);
    if C in ['1'..'9'] then
      if not CanMoveFocus then
        ClearEvent(Event)
      else if Message(DeskTop, evBroadcast, cmSelectWindowNum,
        Pointer(PtrUInt(Ord(C) - Ord('0')))) <> nil then
        ClearEvent(Event);
  end;
  inherited HandleEvent(Event);
  if (Event.What <> evCommand) or (Event.Message.Command <> cmQuit) then
    Exit;
  ClearEvent(Event);
  EndModal(cmQuit);
end;

procedure HandleTimeout(Id: TTimerId; Self: Pointer);
begin
  Message(TView(Self), evBroadcast, cmTimerExpired, Id);
end;

procedure TProgram.Idle;
begin
  if (DeskTop <> nil) and DeskTop.SwitcherActive then
    DeskTop.SwitcherIdle;
  if StatusLine <> nil then
    StatusLine.Update;
  if CommandSetChanged then
  begin
    Message(Self, evBroadcast, cmCommandSetChanged, nil);
    CommandSetChanged := False;
  end;
  TimerQueue.CollectExpiredTimers(@HandleTimeout, Self);
end;

procedure TProgram.InitDeskTop;
var
  R: TRect;
begin
  R := GetExtent;
  Inc(R.A.Y);
  Dec(R.B.Y);
  DeskTop := TDeskTop.Create(R);
end;

procedure TProgram.InitMenuBar;
var
  R: TRect;
begin
  R := GetExtent;
  R.B.Y := R.A.Y + 1;
  MenuBar := TMenuBar.Create(R, nil);
end;

{ The buffer of the program is the screen itself, so the Draw of a group (WriteBuf of the buffer) would copy it onto itself and
  repaint nothing: what was lost while the program was locked (Lock / Unlock, DN does it) must be drawn by the subviews. }
procedure TProgram.Draw;
begin
  DrawSubViews(First, nil);
end;

procedure TProgram.InitScreen;
begin
  case TScreen.ScreenMode and $00FF of
    TDisplay.smMono:
      begin
        ShowMarkers := True;
        ShadowSize := Point(0, 0);
        AppPalette := apMonochrome;
      end;
    TDisplay.smBW80:
      AppPalette := apBlackWhite;
  else
    AppPalette := apColor;
  end;
  if AppPalette <> apMonochrome then
  begin
    ShowMarkers := False;
    { a narrow font has square cells: a shadow of one column looks right }
    if (TScreen.ScreenMode and TDisplay.smFont8x8) = 0 then
      ShadowSize := Point(2, 1)
    else
      ShadowSize := Point(1, 1);
  end;
end;

procedure TProgram.InitStatusLine;
var
  R: TRect;
  Keys: PStatusItem;
begin
  R := GetExtent;
  R.A.Y := R.B.Y - 1;
  Keys := NewStatusKey('', kbCtrlF5, cmResize, nil);
  Keys := NewStatusKey('', kbF5, cmZoom, Keys);
  Keys := NewStatusKey('', kbAltF3, cmClose, Keys);
  Keys := NewStatusKey('', kbF10, cmMenu, Keys);
  Keys := NewStatusKey(ExitText, kbAltX, cmQuit, Keys);
  StatusLine := TStatusLine.Create(R, NewStatusDef(0, $FFFF, Keys, nil));
end;

function TProgram.InsertWindow(P: TWindow): TWindow;
begin
  Result := nil;
  if ValidView(P) <> nil then
  begin
    if CanMoveFocus then
    begin
      DeskTop.Insert(P);
      Result := P;
    end
    else
      P.Free;
  end;
end;

procedure TProgram.KillTimer(Id: TTimerId);
begin
  TimerQueue.KillTimer(Id);
end;

procedure TProgram.OutOfMemory;
begin
end;

procedure TProgram.PutEvent(var Event: TEvent);
begin
  Pending := Event;
end;

procedure TProgram.Resume;
begin
end;

procedure TProgram.Run;
begin
  Execute;
end;

procedure TProgram.SetScreenMode(Mode: Word);
var
  Whole: TRect;
begin
  if Assigned(OnSetVideoMode) then
    OnSetVideoMode(Mode);
  Buffer := TScreen.ScreenBuffer;
  InitScreen;
  Whole.A := Point(0, 0);
  Whole.B := Point(TScreen.ScreenWidth, TScreen.ScreenHeight);
  ChangeBounds(Whole);
  { hide and show again, so that every view knows it must draw itself }
  SetState(sfExposed, False);
  SetState(sfExposed, True);
  Redraw;
end;

function TProgram.SetTimer(TimeoutMs: LongWord; PeriodMs: Integer): TTimerId;
begin
  Result := TimerQueue.SetTimer(TimeoutMs, PeriodMs);
end;

procedure TProgram.Suspend;
begin
end;

function TProgram.ValidView(P: TView): TView;
begin
  Result := nil;
  if P = nil then
    Exit;
  if not P.Valid(cmValid) then
  begin
    P.Free;
    Exit;
  end;
  Result := P;
end;

{ --- TApplication ------------------------------------------------------------ }

constructor TApplication.Create;
begin
  inherited Create;
end;

destructor TApplication.Destroy;
begin
  inherited Destroy;
end;

procedure TApplication.Suspend;
begin
  if Assigned(OnSuspend) then
    OnSuspend();
end;

procedure TApplication.Resume;
begin
  if Assigned(OnResume) then
    OnResume();
end;

procedure TApplication.Cascade;
begin
  if DeskTop <> nil then
    DeskTop.Cascade(GetTileRect);
end;

procedure TApplication.DosShell;
var
  Shell: string;
begin
  Suspend;
  WriteShellMsg;
  { the shell of the system: SHELL on Unix (COMSPEC there is a leftover of another system), COMSPEC elsewhere }
{$IFDEF UNIX}
  Shell := GetEnvironmentVariable('SHELL');
{$ELSE}
  Shell := GetEnvironmentVariable('COMSPEC');
{$ENDIF}
  if Shell = '' then
{$IFDEF UNIX}
    Shell := '/bin/sh';
{$ELSE}
    Shell := GetEnvironmentVariable('SHELL');
{$ENDIF}
  if Shell <> '' then
    ExecuteProcess(Shell, '');
  Resume;
  Redraw;
end;

function TApplication.GetTileRect: TRect;
begin
  Result := DeskTop.GetExtent;
end;

procedure TApplication.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evCommand then
  begin
    case Event.Message.Command of
      cmDosShell: DosShell;
      cmCascade: Cascade;
      cmTile: Tile;
    else
      Exit;
    end;
    ClearEvent(Event);
  end;
end;

procedure TApplication.Tile;
begin
  if DeskTop <> nil then
    DeskTop.Tile(GetTileRect);
end;

procedure TApplication.WriteShellMsg;
begin
  WriteLn('Type EXIT to return...');
end;

initialization
  SystemColors[apColor] := AppColorPalette;
  SystemColors[apBlackWhite] := AppBlackWhitePalette;
  SystemColors[apMonochrome] := AppMonochromePalette;
  TProgram.AppPalette := apColor;
  TProgram.EventTimeoutMs := 20;
  TProgram.Pending.What := evNothing;
  TimerQueue := TTimerQueue.Create(nil);

finalization
  TimerQueue.Free;
end.
