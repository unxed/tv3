{ TvViews: views and groups of views (the core of Turbo Vision).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/views.h        (constants, TCommandSet, TPalette, TView, TGroup)
    source/tvision/tview.cpp, tgroup.cpp, grp.cpp, mapcolor.cpp, palette.cpp,
    tcmdset.cpp, misc.cpp (message), tvwrite.cpp (output engine),
    tvexposd.cpp (exposed), tvcursor.cpp (resetCursor)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - Pascal names: Done (which also detaches the view from its group, like the
      Pascal Turbo Vision), Delete instead of remove;
    - the data of a TPalette is a dynamic array (an assignment shares it); a palette is
      returned by value (getPalette returns a reference);
    - the screen is TvScreen, the output engine only knows TScreenCell buffers;
    - streams (read/write/build) and timers are not translated yet; GetEvent with
      a timeout, TextEvent and the event loop of TProgram come with TvApp.
  The two goto-style engines of the original (tvwrite, tvexposd, translations of
  Borland's assembler) are kept step by step: their L-numbers are the original's. }
unit TvViews;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys,
  TvEvents, TvText, TvDrawBuf, TvScreen,
  TvObjs, TvTimer, TvSys, TvXlat;
{$WARN 3018 OFF}  { "Constructor should be public": Create(streamableInit) is protected, as in tvision }

const
  { Commands of the standard views and of the application (in alphabetical order). }
  cmCancel = 11;      cmCascade = 26;     cmChDir = 35;       cmClear = 24;
  cmClose = 4;        cmCloseAll = 37;    cmCopy = 21;        cmCut = 20;
  cmDefault = 14;     cmDosShell = 36;    cmError = 2;        cmHelp = 9;
  cmMenu = 3;         cmNew = 30;         cmNext = 7;         cmNo = 13;
  cmOK = 10;          cmOpen = 31;        cmPaste = 22;       cmPrev = 8;
  cmQuit = 1;         cmRedo = 27;        cmResize = 6;       cmSave = 32;
  cmSaveAll = 34;     cmSaveAs = 33;      cmTile = 25;        cmUndo = 23;
  cmValid = 0;        cmYes = 12;         cmZoom = 5;

  { Broadcasts that views send to each other. }
  cmCommandSetChanged = 52;   cmListItemSelected = 56;
  cmReceivedFocus = 50;       cmReleasedFocus = 51;
  cmScreenChanged = 57;       cmScrollBarChanged = 53;
  cmScrollBarClicked = 54;    cmSelectWindowNum = 55;
  cmTimerExpired = 58;

  { Bits of TView.State. }
  sfVisible = 1 shl 0;     sfCursorVis = 1 shl 1;   sfCursorIns = 1 shl 2;
  sfShadow = 1 shl 3;      sfActive = 1 shl 4;      sfSelected = 1 shl 5;
  sfFocused = 1 shl 6;     sfDragging = 1 shl 7;    sfDisabled = 1 shl 8;
  sfModal = 1 shl 9;       sfDefault = 1 shl 10;    sfExposed = 1 shl 11;

  { Bits of TView.Options. }
  ofSelectable = 1 shl 0;  ofTopSelect = 1 shl 1;   ofFirstClick = 1 shl 2;
  ofFramed = 1 shl 3;      ofPreProcess = 1 shl 4;  ofPostProcess = 1 shl 5;
  ofBuffered = 1 shl 6;    ofTileable = 1 shl 7;    ofCenterX = 1 shl 8;
  ofCenterY = 1 shl 9;     ofValidate = 1 shl 10;
  ofCentered = ofCenterX or ofCenterY;

  { Bits of TView.GrowMode: which sides follow the owner when it is resized. }
  gfGrowLoX = 1 shl 0;     gfGrowLoY = 1 shl 1;
  gfGrowHiX = 1 shl 2;     gfGrowHiY = 1 shl 3;
  gfGrowAll = gfGrowLoX or gfGrowLoY or gfGrowHiX or gfGrowHiY;
  gfGrowRel = 1 shl 4;     gfFixed = 1 shl 5;

  { Bits of TView.DragMode: how the view may be dragged and where it must stay. }
  dmDragMove = 1 shl 0;    dmDragGrow = 1 shl 1;    dmDragGrowLeft = 1 shl 2;
  dmLimitLoX = 1 shl 4;    dmLimitLoY = 1 shl 5;
  dmLimitHiX = 1 shl 6;    dmLimitHiY = 1 shl 7;
  dmLimitAll = dmLimitLoX or dmLimitLoY or dmLimitHiX or dmLimitHiY;

  { Help contexts. }
  hcNoContext = 0;
  hcDragging = 1;

  { event masks combining several event kinds }
  positionalEvents = evMouse and not evMouseWheel;
  focusedEvents    = evKeyboard or evKeyUp or evCommand;   { a release of a key goes the way of a key, but only a view with evKeyUp in its EventMask gets it }

type
  TView = class;
  TGroup = class;

  { the operators: + and - for += and -=, and, or for &, | (and &=, |=), = and <> }
  TCommandSet = record
  private
    Cmds: array[0..31] of Byte;
    class function Loc(Cmd: Integer): LongWord; static; inline;
    class function Mask(Cmd: Integer): Integer; static; inline;
  public
    function Has(Cmd: Integer): Boolean;
    procedure DisableCmd(Cmd: Integer); overload;
    procedure EnableCmd(Cmd: Integer); overload;
    procedure DisableCmd(const TC: TCommandSet); overload;
    procedure EnableCmd(const TC: TCommandSet); overload;
    function IsEmpty: Boolean;
    class operator +(const TC: TCommandSet; Cmd: Integer): TCommandSet;
    class operator -(const TC: TCommandSet; Cmd: Integer): TCommandSet;
    class operator +(const TC1, TC2: TCommandSet): TCommandSet;
    class operator -(const TC1, TC2: TCommandSet): TCommandSet;
    class operator and(const TC1, TC2: TCommandSet): TCommandSet;
    class operator or(const TC1, TC2: TCommandSet): TCommandSet;
    class operator =(const TC1, TC2: TCommandSet): Boolean;
    class operator <>(const TC1, TC2: TCommandSet): Boolean;
  end;

  { Data[0] holds the number of entries; entries 1..N map a color index of a view to a
    color index of its owner (or, in the palette of the application, to a real color).
    Data is a dynamic array: an assignment shares it (Copy(P.Data) copies it); a
    Default(TPalette) is the empty palette. }
  TPalette = record
  private
    function GetItem(Index: Integer): TColorAttr;
    procedure SetItem(Index: Integer; const A: TColorAttr);
  public
    Data: array of TColorAttr;
    constructor Create(D: PChar; Len: Word); overload;
    constructor Create(D: PColorAttr; Len: Word); overload;
    constructor Create(const A: array of TColorAttr); overload;
    property Items[Index: Integer]: TColorAttr read GetItem write SetItem; default;
  end;

  TForEachProc = procedure(P: TView; Args: Pointer);
  TNestedViewTest = function(P: TView): Boolean is nested;
  TNestedViewAction = procedure(P: TView) is nested;
  TFirstThatFunc = function(P: TView; Args: Pointer): Boolean;

  { a timer of DN: the time of the start and of the end in milliseconds (the fields of DN views) }
  TEventTimer = record
    StartMSecs, ExpireMSecs: LongInt;
  end;

  TView = class(TStreamable)
  public type
    PhaseType = (phFocused, phPreProcess, phPostProcess);
    SelectMode = (normalSelect, enterSelect, leaveSelect);
  public
    Next: TView;
    Size: TPoint;
    Options: Word;
    EventMask: Word;
    State: Word;
    Origin: TPoint;
    Cursor: TPoint;
    GrowMode: Byte;
    DragMode: Byte;
    HelpCtx: Word;
    Owner: TGroup;
    ResizeBalance: TPoint;
    { the fields of DN: the interval of Update in milliseconds, its timer, a flag of the mouse events }
    UpdTicks: LongInt;
    UpTmr: TEventTimer;
    ClearPositionalEvents: Boolean;
    constructor Create(const Bounds: TRect); overload;
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    { Called by the program from time to time for the views that asked for it (DN: RegisterToBackground). }
    procedure Update; virtual;
    { Hides the view and removes it from its owner. }
    destructor Destroy; override;
    procedure SizeLimits(out Min, Max: TPoint); virtual;
    function GetBounds: TRect;
    function GetExtent: TRect;
    function GetClipRect: TRect;
    function MouseInView(Mouse: TPoint): Boolean;
    function ContainsMouse(var Event: TEvent): Boolean;
    procedure Locate(var Bounds: TRect);
    { the commands that are enabled (commands above 255 are always enabled) }
    class var CurCommandSet: TCommandSet;
    class var CommandSetChanged: Boolean;
    class var ShowMarkers: Boolean;
    class var ErrorAttr: TColorAttr;
    class function CommandEnabled(Command: Word): Boolean; static;
    class procedure DisableCommands(const Commands: TCommandSet); static;
    class procedure EnableCommands(const Commands: TCommandSet); static;
    class procedure DisableCommand(Command: Word); static;
    class procedure EnableCommand(Command: Word); static;
    class procedure GetCommands(out Commands: TCommandSet); static;
    class procedure SetCommands(const Commands: TCommandSet); static;
    class procedure SetCmdState(const Commands: TCommandSet; Enable: Boolean); static;
    { as CommandEnabled, but a command that the program has switched off for good (CommandHiddenHook) is not enabled }
    function MenuEnabled(Command: Word): Boolean;
    procedure DragView(var Event: TEvent; Mode: Byte; var Limits: TRect;
      MinSize, MaxSize: TPoint); virtual;
    procedure CalcBounds(var Bounds: TRect; Delta: TPoint); virtual;
    procedure ChangeBounds(const Bounds: TRect); virtual;
    procedure GrowTo(X, Y: Integer);
    procedure MoveTo(X, Y: Integer);
    procedure SetBounds(const Bounds: TRect);
    function GetHelpCtx: Word; virtual;
    function Valid(Command: Word): Boolean; virtual;
    procedure Hide;
    procedure Show;
    procedure Draw; virtual;
    procedure DrawView;
    function Exposed: Boolean;
    function Focus: Boolean;
    procedure HideCursor;
    procedure DrawHide(LastView: TView);
    procedure DrawShow(LastView: TView);
    procedure DrawUnderRect(var R: TRect; LastView: TView);
    procedure DrawUnderView(DoShadow: Boolean; LastView: TView);
    function DataSize: Integer; virtual;
    procedure GetData(var Rec); virtual;
    procedure SetData(var Rec); virtual;
    procedure Awaken; virtual;
    procedure BlockCursor;
    procedure NormalCursor;
    procedure ResetCursor; virtual;
    procedure SetCursor(X, Y: Integer);
    procedure ShowCursor;
    procedure DrawCursor;
    procedure ClearEvent(var Event: TEvent);
    function EventAvail: Boolean;
    procedure GetEvent(var Event: TEvent); virtual;
    { The text of Event (a key down event with text) and of the key down events of a paste (kbPaste: the text that the terminal pastes, bracketed paste) that follow
      it at once: one string for the whole paste instead of a key press for every character (as TView::textEvent of tvision). The first event that is not
      such text is put back (PutEvent: it is handled in the next turn of the event loop); Event is cleared. False if there is no text. }
    function TextEvent(var Event: TEvent; out Text: AnsiString): Boolean;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure PutEvent(var Event: TEvent); virtual;
    procedure EndModal(Command: Word); virtual;
    function Execute: Word; virtual;
    function GetColor(Color: Word): TAttrPair;
    function GetPalette: TPalette; virtual;
    function MapColor(Index: Byte): TColorAttr; virtual;
    function GetState(AState: Word): Boolean;
    procedure Select;
    procedure SetState(AState: Word; Enable: Boolean); virtual;
    procedure KeyEvent(var Event: TEvent);
    function MouseEvent(var Event: TEvent; Mask: Word): Boolean;
    function MakeGlobal(Source: TPoint): TPoint;
    function MakeLocal(Source: TPoint): TPoint;
    function NextView: TView;
    function PrevView: TView;
    function Prev: TView;
    procedure MakeFirst;
    procedure PutInFrontOf(Target: TView);
    function TopView: TView;
    { Timers: the group chain ends at the program, which owns the timer queue; a view
      outside a group has none (SetTimer returns nil). }
    function SetTimer(TimeoutMs: LongWord; PeriodMs: Integer = -1): TTimerId; virtual;
    procedure KillTimer(Id: TTimerId); virtual;
    { Writing into the view: coordinates are in the view, clipped to the part of
      the view that is visible. WriteBuf writes H rows of W cells, taken one
      after the other from B; WriteLine writes the same W cells to H rows. }
    procedure WriteBuf(X, Y, W, H: Integer; B: PScreenCell); overload;
    procedure WriteBuf(X, Y, W, H: Integer; const B: TDrawBuffer); overload;
    procedure WriteChar(X, Y: Integer; C: Byte; Color: Byte; Count: Integer);
    procedure WriteLine(X, Y, W, H: Integer; B: PScreenCell); overload;
    procedure WriteLine(X, Y, W, H: Integer; const B: TDrawBuffer); overload;
    procedure WriteStr(X, Y: Integer; const Str: ShortString; Color: Byte);
    procedure WriteView(X, Y, Count: Integer; B: PScreenCell);
    { The 16-bit interface of Turbo Vision for Borland Pascal, for programs written for it: a cell is a Word
      (low byte: the character, high byte: the BIOS attribute) and a color is a BIOS attribute. B is an array
      of Word (WriteLineW takes W cells, WriteBufW H rows of them); GetColorW(C) = Lo + 256 * Hi of GetColor(C). }
    procedure WriteBufW(X, Y, W, H: Integer; const B);
    procedure WriteLineW(X, Y, W, H: Integer; const B);
    { The same for a row of cells of tv/ (an array of TScreenCell, as the draw buffers of DN are): B is the first cell, as for WriteBuf/WriteLine. }
    procedure WriteBufC(X, Y, W, H: Integer; const B);
    procedure WriteLineC(X, Y, W, H: Integer; const B);
    function GetColorW(Color: Word): Word;
  end;

  TGroup = class(TView)
    Last: TView;
    Clip: TRect;
    Phase: PhaseType;
    Buffer: PScreenCell;
    LockFlag: Byte;
    EndState: Word;
    Current: TView;
    constructor Create(const Bounds: TRect); overload;
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    destructor Destroy; override;
    function ExecView(P: TView): Word;
    function Execute: Word; override;
    procedure Awaken; override;
    procedure InsertView(P, Target: TView);
    procedure Delete(P: TView);
    procedure RemoveView(P: TView);
    procedure ResetCurrent;
    procedure SetCurrent(P: TView; Mode: SelectMode);
    procedure SelectNext(Forwards: Boolean);
    function FirstThat(Func: TFirstThatFunc; Args: Pointer): TView; overload;
    { The forms of Turbo Vision for Borland Pascal (a routine that is declared inside the caller is fine). }
    function FirstThat(Test: TNestedViewTest): TView; overload;
    function FocusNext(Forwards: Boolean): Boolean;
    procedure ForEach(Func: TForEachProc; Args: Pointer); overload;
    procedure ForEach(Action: TNestedViewAction); overload;
    procedure Insert(P: TView);
    procedure InsertBefore(P, Target: TView);
    function At(Index: Integer): TView;
    function FirstMatch(AState, AOptions: Word): TView;
    function IndexOf(P: TView): Integer;
    function First: TView;
    procedure SetState(AState: Word; Enable: Boolean); override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure DrawSubViews(P, Bottom: TView);
    procedure ChangeBounds(const Bounds: TRect); override;
    function DataSize: Integer; override;
    procedure GetData(var Rec); override;
    procedure SetData(var Rec); override;
    procedure Draw; override;
    procedure Redraw;
    procedure Lock;
    procedure Unlock;
    procedure ResetCursor; override;
    procedure EndModal(Command: Word); override;
    procedure EventError(var Event: TEvent); virtual;
    function GetHelpCtx: Word; override;
    function Valid(Command: Word): Boolean; override;
    procedure FreeBuffer;
    procedure GetBuffer;
  private
    function FindNext(Forwards: Boolean): TView;
    procedure FocusView(P: TView; Enable: Boolean);
    procedure SelectView(P: TView; Enable: Boolean);
  end;

var
  { UX guidelines (X.4): the mouse wheel goes to the view under the pointer, like a click, whatever has the focus. False: the old way, every view of a
    group gets the wheel (in practice the scroll bars and the views of the focused window). }
  UxWheelUnderCursor: Boolean = True;
  { the view being run modally by ExecView, if any }
  TheTopView: TView = nil;


{ Sends a message to a view: the view's HandleEvent gets an event with the
  command and Info; if the view cleared the event, its InfoPtr is returned. }
function Message(Receiver: TView; What, Command: Word; InfoPtr: Pointer): Pointer;

var
  { DN: the number of the modal views that are being executed (ExecView calls that have not returned) }
  ModalCount: Word = 0;
  { DN: the commands of the features that are not in the program are never enabled (TView.MenuEnabled) }
  CommandHiddenHook: function(Command: Word): Boolean = nil;
  { the stream classes of TView and TGroup }
  RView, RGroup: TStreamableClass;
  { called at the start of the destructor of every view (DN: the view leaves the list of the views that
    are updated in the background) }
  ViewDoneHook: procedure(P: TView) = nil;

implementation

{ ------------------------------------------------------------------------- }
{ Commands, palettes, message                                               }
{ ------------------------------------------------------------------------- }

{ --- TCommandSet ---------------------------------------------------------------- }

const
  CmdMasks: array[0..7] of Integer = ($0001, $0002, $0004, $0008, $0010, $0020, $0040, $0080);

class function TCommandSet.Loc(Cmd: Integer): LongWord;
begin
  Result := LongWord(Cmd) div 8;
end;

class function TCommandSet.Mask(Cmd: Integer): Integer;
begin
  Result := CmdMasks[Cmd and $07];
end;

function TCommandSet.Has(Cmd: Integer): Boolean;
begin
  if Loc(Cmd) < 32 then
    Result := (Cmds[Loc(Cmd)] and Mask(Cmd)) <> 0
  else
    Result := False;
end;

procedure TCommandSet.DisableCmd(Cmd: Integer);
begin
  if Loc(Cmd) < 32 then
    Cmds[Loc(Cmd)] := Cmds[Loc(Cmd)] and not Mask(Cmd);
end;

procedure TCommandSet.EnableCmd(const TC: TCommandSet);
var
  I: Integer;
begin
  for I := 0 to 31 do
    Cmds[I] := Cmds[I] or TC.Cmds[I];
end;

procedure TCommandSet.DisableCmd(const TC: TCommandSet);
var
  I: Integer;
begin
  for I := 0 to 31 do
    Cmds[I] := Cmds[I] and not TC.Cmds[I];
end;

procedure TCommandSet.EnableCmd(Cmd: Integer);
begin
  if Loc(Cmd) < 32 then
    Cmds[Loc(Cmd)] := Cmds[Loc(Cmd)] or Mask(Cmd);
end;

function TCommandSet.IsEmpty: Boolean;
var
  I: Integer;
begin
  for I := 0 to 31 do
    if Cmds[I] <> 0 then
      Exit(False);
  Result := True;
end;

class operator TCommandSet.+(const TC: TCommandSet; Cmd: Integer): TCommandSet;
begin
  Result := TC;
  Result.EnableCmd(Cmd);
end;

class operator TCommandSet.-(const TC: TCommandSet; Cmd: Integer): TCommandSet;
begin
  Result := TC;
  Result.DisableCmd(Cmd);
end;

class operator TCommandSet.+(const TC1, TC2: TCommandSet): TCommandSet;
begin
  Result := TC1;
  Result.EnableCmd(TC2);
end;

class operator TCommandSet.-(const TC1, TC2: TCommandSet): TCommandSet;
begin
  Result := TC1;
  Result.DisableCmd(TC2);
end;

class operator TCommandSet.and(const TC1, TC2: TCommandSet): TCommandSet;
var
  I: Integer;
begin
  Result := TC1;
  for I := 0 to 31 do
    Result.Cmds[I] := Result.Cmds[I] and TC2.Cmds[I];
end;

class operator TCommandSet.or(const TC1, TC2: TCommandSet): TCommandSet;
var
  I: Integer;
begin
  Result := TC1;
  for I := 0 to 31 do
    Result.Cmds[I] := Result.Cmds[I] or TC2.Cmds[I];
end;

class operator TCommandSet.=(const TC1, TC2: TCommandSet): Boolean;
var
  I: Integer;
begin
  for I := 0 to 31 do
    if TC1.Cmds[I] <> TC2.Cmds[I] then
      Exit(False);
  Result := True;
end;

class operator TCommandSet.<>(const TC1, TC2: TCommandSet): Boolean;
begin
  Result := not (TC1 = TC2);
end;

{ --- the commands of TView ------------------------------------------------------- }

procedure InitCommands;
var
  I: Integer;
begin
  TView.CurCommandSet := Default(TCommandSet);
  for I := 0 to 255 do
    TView.CurCommandSet.EnableCmd(I);
  TView.CurCommandSet.DisableCmd(cmZoom);
  TView.CurCommandSet.DisableCmd(cmClose);
  TView.CurCommandSet.DisableCmd(cmResize);
  TView.CurCommandSet.DisableCmd(cmNext);
  TView.CurCommandSet.DisableCmd(cmPrev);
end;

class function TView.CommandEnabled(Command: Word): Boolean;
begin
  Result := (Command > 255) or CurCommandSet.Has(Command);
end;

class procedure TView.DisableCommands(const Commands: TCommandSet);
begin
  CommandSetChanged := CommandSetChanged or not (CurCommandSet and Commands).IsEmpty;
  CurCommandSet.DisableCmd(Commands);
end;

class procedure TView.EnableCommands(const Commands: TCommandSet);
begin
  CommandSetChanged := CommandSetChanged or ((CurCommandSet and Commands) <> Commands);
  CurCommandSet.EnableCmd(Commands);
end;

class procedure TView.DisableCommand(Command: Word);
begin
  CommandSetChanged := CommandSetChanged or CurCommandSet.Has(Command);
  CurCommandSet.DisableCmd(Command);
end;

class procedure TView.EnableCommand(Command: Word);
begin
  CommandSetChanged := CommandSetChanged or not CurCommandSet.Has(Command);
  CurCommandSet.EnableCmd(Command);
end;

class procedure TView.GetCommands(out Commands: TCommandSet);
begin
  Commands := CurCommandSet;
end;

class procedure TView.SetCommands(const Commands: TCommandSet);
begin
  CommandSetChanged := CommandSetChanged or (CurCommandSet <> Commands);
  CurCommandSet := Commands;
end;

class procedure TView.SetCmdState(const Commands: TCommandSet; Enable: Boolean);
begin
  if Enable then
    EnableCommands(Commands)
  else
    DisableCommands(Commands);
end;

{ --- TPalette ------------------------------------------------------------------- }

constructor TPalette.Create(D: PChar; Len: Word);
var
  I: Integer;
begin
  SetLength(Data, Len + 1);
  Data[0] := Len;
  for I := 0 to Len - 1 do
    Data[I + 1] := Ord(D[I]);
end;

constructor TPalette.Create(D: PColorAttr; Len: Word);
begin
  SetLength(Data, Len + 1);
  Data[0] := Len;
  if Len > 0 then
    Move(D^, Data[1], Len * SizeOf(TColorAttr));
end;

constructor TPalette.Create(const A: array of TColorAttr);
begin
  SetLength(Data, Length(A) + 1);
  Data[0] := Length(A);
  if Length(A) > 0 then
    Move(A[0], Data[1], Length(A) * SizeOf(TColorAttr));
end;

function TPalette.GetItem(Index: Integer): TColorAttr;
begin
  if (Index = 0) and (Data = nil) then
    Result := 0
  else
    Result := Data[Index];
end;

procedure TPalette.SetItem(Index: Integer; const A: TColorAttr);
begin
  Data[Index] := A;
end;

function Message(Receiver: TView; What, Command: Word; InfoPtr: Pointer): Pointer;
var
  Event: TEvent;
begin
  if Receiver = nil then
    Exit(nil);
  ClearEvent(Event);
  Event.What := What;
  Event.Message.Command := Command;
  Event.Message.InfoPtr := InfoPtr;
  Receiver.HandleEvent(Event);
  if Event.What = evNothing then
    Result := Event.Message.InfoPtr
  else
    Result := nil;
end;

{ ------------------------------------------------------------------------- }
{ Arithmetic helpers of TView                                               }
{ ------------------------------------------------------------------------- }

function Range(Val, Min, Max: Integer): Integer;
begin
  if Min > Max then
    Min := Max;
  if Val < Min then
    Result := Min
  else if Val > Max then
    Result := Max
  else
    Result := Val;
end;

function BalancedRange(Val, Min, Max: Integer; var Balance: Integer): Integer;
var
  Offset: Integer;
begin
  if Min > Max then
    Max := Min;
  if Val < Min then
  begin
    Inc(Balance, Val - Min);
    Result := Min;
  end
  else if Val > Max then
  begin
    Inc(Balance, Val - Max);
    Result := Max;
  end
  else
  begin
    Offset := Range(Val + Balance, Min, Max) - Val;
    Dec(Balance, Offset);
    Result := Val + Offset;
  end;
end;

procedure FitToLimits(A: Integer; var B: Integer; Min, Max: Integer; var Balance: Integer);
begin
  B := A + BalancedRange(B - A, Min, Max, Balance);
end;

{ the C++ original divides and shifts as C does: truncating division and an
  arithmetic shift }
procedure GrowCoord(P: TView; S, D: Integer; var I: Integer);
begin
  if (P.GrowMode and gfGrowRel) <> 0 then
  begin
    if S <> D then
      I := (I * S + SarLongint(S - D, 1)) div (S - D);
  end
  else
    Inc(I, D);
end;

function IMin(A, B: Integer): Integer; inline;
begin
  if A < B then Result := A else Result := B;
end;

function IMax(A, B: Integer): Integer; inline;
begin
  if A > B then Result := A else Result := B;
end;

{ ------------------------------------------------------------------------- }
{ The output engine (tvwrite.cpp)                                           }
{ ------------------------------------------------------------------------- }

type
  { state of one write: the part of the row still to be written is X..Count of
    the row Y, in the coordinates of the group being written to; Buffer[X - WOffset]
    is the cell for X; Edx counts the shadows the row passes through }
  TVWrite = record
    X, Y, Count, WOffset: Integer;
    Buffer: PScreenCell;
    Target: TView;
    Edx, Esi: Integer;
  end;

  TCellArray = array[0..MaxInt div SizeOf(TScreenCell) - 1] of TScreenCell;
  PCellArray = ^TCellArray;

procedure WriteL10(var W: TVWrite; Dest: TView); forward;
procedure WriteL20(var W: TVWrite; Dest: TView); forward;

function ApplyShadow(Attr: TColorAttr): TColorAttr;
var
  Style: Word;
begin
  { a style flag says whether the shadow has already been applied }
  Style := Attr.GetStyle;
  if (Style and slWindowShadow) = 0 then
  begin
    if Byte(Attr.GetBackground.ToBIOS(False)) = 0 then
      Attr := ShadowAttr.Reversed    { reverse the shadow on black areas }
    else
      Attr := ShadowAttr;
    Attr.SetStyle(Style or slWindowShadow);
  end;
  Result := Attr;
end;

procedure CopyCells(var W: TVWrite; Dst, Src: PCellArray);
var
  I: Integer;
  C: TScreenCell;
begin
  if W.Edx = 0 then
    Move(Src^, Dst^, SizeOf(TScreenCell) * (W.Count - W.X))
  else
    for I := 0 to W.Count - W.X - 1 do
    begin
      C := Src^[I];
      C.Attribute := ApplyShadow(C.Attribute);
      Dst^[I] := C;
    end;
end;

procedure WriteL50(var W: TVWrite; Owner: TGroup);
var
  Dst: PCellArray;
begin
  Dst := PCellArray(Owner.Buffer + (W.Y * Owner.Size.X + W.X));
  CopyCells(W, Dst, PCellArray(W.Buffer + (W.X - W.WOffset)));
  if Owner.Buffer = TScreen.ScreenBuffer then
    THardwareInfo.ScreenWrite(W.X, W.Y, PScreenCell(Dst), W.Count - W.X);
end;

procedure WriteL40(var W: TVWrite; Dest: TView);
var
  Owner: TGroup;
begin
  Owner := Dest.Owner;
  if Owner.Buffer <> nil then
    WriteL50(W, Owner);
  if Owner.LockFlag = 0 then
    WriteL10(W, Owner);
end;

{ Runs the rest of the row through the views below Dest, with the row cut at
  Esi: used when a view covers the middle of the row. }
procedure WriteL30(var W: TVWrite; Dest: TView);
var
  SaveTarget: TView;
  SaveWOffset, SaveEsi, SaveEdx, SaveCount, SaveY: Integer;
begin
  SaveTarget := W.Target;
  SaveWOffset := W.WOffset;
  SaveEsi := W.Esi;
  SaveEdx := W.Edx;
  SaveCount := W.Count;
  SaveY := W.Y;
  W.Count := W.Esi;
  WriteL20(W, Dest);
  W.Y := SaveY;
  W.Count := SaveCount;
  W.Edx := SaveEdx;
  W.Esi := SaveEsi;
  W.WOffset := SaveWOffset;
  W.Target := SaveTarget;
  W.X := W.Esi;
end;

{ Walks the views that are above the target, from the topmost one down, cutting
  out the parts of the row they cover (and noting the shadows they cast). }
procedure WriteL20(var W: TVWrite; Dest: TView);
var
  Next: TView;
begin
  Next := Dest.Next;
  if Next = W.Target then
  begin
    WriteL40(W, Next);
    Exit;
  end;
  if ((Next.State and sfVisible) <> 0) and (Next.Origin.Y <= W.Y) then
    repeat
      W.Esi := Next.Origin.Y + Next.Size.Y;
      if W.Y < W.Esi then
      begin
        W.Esi := Next.Origin.X;
        if W.X < W.Esi then
        begin
          if W.Count > W.Esi then
            WriteL30(W, Next)
          else
            Break;
        end;
        Inc(W.Esi, Next.Size.X);
        if W.X < W.Esi then
        begin
          if W.Count > W.Esi then
            W.X := W.Esi
          else
            Exit;
        end;
        if ((Next.State and sfShadow) <> 0) and (Next.Origin.Y + ShadowSize.Y <= W.Y) then
          Inc(W.Esi, ShadowSize.X)
        else
          Break;
      end
      else if ((Next.State and sfShadow) <> 0) and (W.Y < W.Esi + ShadowSize.Y) then
      begin
        W.Esi := Next.Origin.X + ShadowSize.X;
        if W.X < W.Esi then
        begin
          if W.Count > W.Esi then
            WriteL30(W, Next)
          else
            Break;
        end;
        Inc(W.Esi, Next.Size.X);
      end
      else
        Break;
      if W.X < W.Esi then
      begin
        Inc(W.Edx);
        if W.Count > W.Esi then
        begin
          WriteL30(W, Next);
          Dec(W.Edx);
        end;
      end;
    until True;
  WriteL20(W, Next);
end;

{ Moves the write into the coordinates of the owner and clips it to the owner's
  clip rectangle. }
procedure WriteL10(var W: TVWrite; Dest: TView);
var
  Owner: TGroup;
begin
  Owner := Dest.Owner;
  if ((Dest.State and sfVisible) <> 0) and (Owner <> nil) then
  begin
    W.Target := Dest;
    Inc(W.Y, Dest.Origin.Y);
    Inc(W.X, Dest.Origin.X);
    Inc(W.Count, Dest.Origin.X);
    Inc(W.WOffset, Dest.Origin.X);
    if (Owner.Clip.A.Y <= W.Y) and (W.Y < Owner.Clip.B.Y) then
    begin
      if W.X < Owner.Clip.A.X then
        W.X := Owner.Clip.A.X;
      if W.Count > Owner.Clip.B.X then
        W.Count := Owner.Clip.B.X;
      if W.X < W.Count then
        WriteL20(W, Owner.Last);
    end;
  end;
end;

procedure WriteL0(var W: TVWrite; Dest: TView; AX, AY, ACount: Integer; B: PScreenCell);
begin
  W.X := AX;
  W.Y := AY;
  W.Count := ACount;
  W.Buffer := B;
  W.WOffset := W.X;
  Inc(W.Count, W.X);
  W.Edx := 0;
  W.Esi := 0;
  W.Target := nil;
  if (0 <= W.Y) and (W.Y < Dest.Size.Y) then
  begin
    if W.X < 0 then
      W.X := 0;
    if W.Count > Dest.Size.X then
      W.Count := Dest.Size.X;
    if W.X < W.Count then
      WriteL10(W, Dest);
  end;
end;

{ ------------------------------------------------------------------------- }
{ The visibility test (tvexposd.cpp)                                        }
{ ------------------------------------------------------------------------- }

type
  { Row Eax (in the coordinates of the current owner), columns Ebx..Ecx }
  TVExposd = record
    Eax, Ebx, Ecx, Esi: Integer;
    Target: TView;
  end;

function ExposdL11(var E: TVExposd; Dest: TView): Boolean; forward;
function ExposdL20(var E: TVExposd; Dest: TView): Boolean; forward;

function ExposdL10(var E: TVExposd; Dest: TView): Boolean;
var
  Owner: TGroup;
begin
  Owner := Dest.Owner;
  if (Owner.Buffer <> nil) or (Owner.LockFlag <> 0) then
    Exit(False);
  Result := ExposdL11(E, Owner);
end;

function ExposdL23(var E: TVExposd; Next: TView): Boolean;
var
  SaveTarget: TView;
  SaveEsi, SaveEcx, SaveEax: Integer;
  B: Boolean;
begin
  SaveTarget := E.Target;
  SaveEsi := E.Esi;
  SaveEcx := E.Ecx;
  SaveEax := E.Eax;
  E.Ecx := Next.Origin.X;
  B := ExposdL20(E, Next);
  E.Eax := SaveEax;
  E.Ecx := SaveEcx;
  E.Ebx := SaveEsi;
  E.Target := SaveTarget;
  if B then
    Result := ExposdL20(E, Next)
  else
    Result := False;
end;

function ExposdL22(var E: TVExposd; Next: TView): Boolean;
begin
  if E.Ecx <= E.Esi then
    Exit(ExposdL20(E, Next));
  Inc(E.Esi, Next.Size.X);
  if E.Ecx > E.Esi then
    Exit(ExposdL23(E, Next));
  E.Ecx := Next.Origin.X;
  Result := ExposdL20(E, Next);
end;

function ExposdL21(var E: TVExposd; Next: TView): Boolean;
begin
  if (Next.State and sfVisible) = 0 then
    Exit(ExposdL20(E, Next));
  E.Esi := Next.Origin.Y;
  if E.Eax < E.Esi then
    Exit(ExposdL20(E, Next));
  Inc(E.Esi, Next.Size.Y);
  if E.Eax >= E.Esi then
    Exit(ExposdL20(E, Next));
  E.Esi := Next.Origin.X;
  if E.Ebx < E.Esi then
    Exit(ExposdL22(E, Next));
  Inc(E.Esi, Next.Size.X);
  if E.Ebx >= E.Esi then
    Exit(ExposdL20(E, Next));
  E.Ebx := E.Esi;
  if E.Ebx < E.Ecx then
    Exit(ExposdL20(E, Next));
  Result := True;
end;

function ExposdL20(var E: TVExposd; Dest: TView): Boolean;
var
  Next: TView;
begin
  Next := Dest.Next;
  if Next = E.Target then
    Result := ExposdL10(E, Next)
  else
    Result := ExposdL21(E, Next);
end;

function ExposdL13(var E: TVExposd; Owner: TGroup): Boolean;
begin
  if E.Ebx >= E.Ecx then
    Exit(True);
  Result := ExposdL20(E, Owner.Last);
end;

function ExposdL12(var E: TVExposd; Owner: TGroup): Boolean;
begin
  if E.Ecx > Owner.Clip.B.X then
    E.Ecx := Owner.Clip.B.X;
  Result := ExposdL13(E, Owner);
end;

function ExposdL11(var E: TVExposd; Dest: TView): Boolean;
var
  Owner: TGroup;
begin
  E.Target := Dest;
  Inc(E.Eax, Dest.Origin.Y);
  Inc(E.Ebx, Dest.Origin.X);
  Inc(E.Ecx, Dest.Origin.X);
  Owner := Dest.Owner;
  if Owner = nil then
    Exit(False);
  if E.Eax < Owner.Clip.A.Y then
    Exit(True);
  if E.Eax >= Owner.Clip.B.Y then
    Exit(True);
  if E.Ebx < Owner.Clip.A.X then
    E.Ebx := Owner.Clip.A.X;
  Result := ExposdL12(E, Owner);
end;

{ True when some cell of the view can be seen: it is exposed, and for some row
  a part of the row is not covered by the views above it nor clipped away. }
function ViewExposed(Dest: TView): Boolean;
var
  E: TVExposd;
  I: Integer;
begin
  if (Dest.State and sfExposed) = 0 then
    Exit(False);
  if (Dest.Size.X <= 0) or (Dest.Size.Y <= 0) then
    Exit(False);
  FillChar(E, SizeOf(E), 0);
  for I := 0 to Dest.Size.Y - 1 do
  begin
    E.Eax := I;
    E.Ebx := 0;
    E.Ecx := Dest.Size.X;
    if not ExposdL11(E, Dest) then
      Exit(True);
  end;
  Result := False;
end;

{ ------------------------------------------------------------------------- }
{ The caret (tvcursor.cpp)                                                  }
{ ------------------------------------------------------------------------- }

function DecideCaretSize(P: TView): Integer;
begin
  if (P.State and sfCursorIns) <> 0 then
    Result := 100
  else
    Result := TScreen.CursorLines and $FF;
end;

function CaretIsCoveredBySiblings(P: TView; X, Y: Integer): Boolean;
var
  U: TView;
begin
  U := P.Owner.Last.Next;
  while U <> P do
  begin
    if ((U.State and sfVisible) <> 0)
      and (U.Origin.Y <= Y) and (Y < U.Origin.Y + U.Size.Y)
      and (U.Origin.X <= X) and (X < U.Origin.X + U.Size.X) then
      Exit(True);
    U := U.Next;
  end;
  Result := False;
end;

function ComputeCaretSize(P: TView; var X, Y: Integer): Integer;
var
  Mask: Word;
  V: TView;
begin
  Mask := sfVisible or sfCursorVis or sfFocused;
  if (P.State and Mask) <> Mask then
    Exit(0);
  V := P;
  while (0 <= Y) and (Y < V.Size.Y) and (0 <= X) and (X < V.Size.X) do
  begin
    Inc(Y, V.Origin.Y);
    Inc(X, V.Origin.X);
    if V.Owner = nil then
      Exit(DecideCaretSize(P));
    if ((V.Owner.State and sfVisible) = 0) or CaretIsCoveredBySiblings(V, X, Y) then
      Break;
    V := V.Owner;
  end;
  Result := 0;
end;

{ ------------------------------------------------------------------------- }
{ TView                                                                      }
{ ------------------------------------------------------------------------- }

constructor TView.Create(const Bounds: TRect);
begin
  inherited Create;       { zeroes all the fields, also those of the descendants }
  Next := nil;
  Options := 0;
  EventMask := evMouseDown or evKeyDown or evCommand;
  State := sfVisible;
  GrowMode := 0;
  DragMode := dmLimitLoY;
  HelpCtx := hcNoContext;
  Owner := nil;
  SetBounds(Bounds);
  Cursor.X := 0;
  Cursor.Y := 0;
  ResizeBalance.X := 0;
  ResizeBalance.Y := 0;
end;

destructor TView.Destroy;
begin
  if Assigned(ViewDoneHook) then
    ViewDoneHook(Self);
  Hide;
  if Owner <> nil then
    Owner.Delete(Self);
  inherited Destroy;
end;

procedure TView.Awaken;
begin
end;

procedure TView.BlockCursor;
begin
  SetState(sfCursorIns, True);
end;

procedure TView.CalcBounds(var Bounds: TRect; Delta: TPoint);
var
  S, D: Integer;
  MinLim, MaxLim: TPoint;
begin
  Bounds := GetBounds;
  S := Owner.Size.X;
  D := Delta.X;
  if (GrowMode and gfGrowLoX) <> 0 then
    GrowCoord(Self, S, D, Bounds.A.X);
  if (GrowMode and gfGrowHiX) <> 0 then
    GrowCoord(Self, S, D, Bounds.B.X);
  S := Owner.Size.Y;
  D := Delta.Y;
  if (GrowMode and gfGrowLoY) <> 0 then
    GrowCoord(Self, S, D, Bounds.A.Y);
  if (GrowMode and gfGrowHiY) <> 0 then
    GrowCoord(Self, S, D, Bounds.B.Y);
  SizeLimits(MinLim, MaxLim);
  FitToLimits(Bounds.A.X, Bounds.B.X, MinLim.X, MaxLim.X, ResizeBalance.X);
  FitToLimits(Bounds.A.Y, Bounds.B.Y, MinLim.Y, MaxLim.Y, ResizeBalance.Y);
end;

procedure TView.ChangeBounds(const Bounds: TRect);
begin
  SetBounds(Bounds);
  DrawView;
end;

procedure TView.ClearEvent(var Event: TEvent);
var
  Key: Word;
begin
  Key := Event.KeyDown.KeyCode;     { InfoPtr overlaps KeyCode (the fields of the win32 input mode are between): the key stays after the clear, as in Borland TV; DN reads it (Enter on an archive) }
  Event.What := evNothing;
  Event.Message.InfoPtr := Self;
  Event.KeyDown.KeyCode := Key;
end;

function TView.ContainsMouse(var Event: TEvent): Boolean;
begin
  Result := ((State and sfVisible) <> 0) and MouseInView(Event.Mouse.Where);
end;

function TView.DataSize: Integer;
begin
  Result := 0;
end;

function TView.MenuEnabled(Command: Word): Boolean;
begin
  if Assigned(CommandHiddenHook) and CommandHiddenHook(Command) then
    Result := False
  else
    Result := (Command > 255) or CurCommandSet.Has(Command);
end;

procedure TView.DragView(var Event: TEvent; Mode: Byte; var Limits: TRect;
  MinSize, MaxSize: TPoint);

  function Fit(V, Lo, Hi: Integer): Integer;
  begin
    Result := V;
    if Result < Lo then
      Result := Lo;
    if Result > Hi then
      Result := Hi;
  end;

  { one coordinate of the origin: at least one cell stays inside the limits,
    or all of the view when Mode asks for it }
  function Place(V, Len, Lo, Hi: Integer; LoBit, HiBit: Byte): Integer;
  begin
    Result := Fit(V, Lo - Len + 1, Hi - 1);
    if ((Mode and LoBit) <> 0) and (Result < Lo) then
      Result := Lo;
    if ((Mode and HiBit) <> 0) and (Result > Hi - Len) then
      Result := Hi - Len;
  end;

  procedure MoveGrow(P, S: TPoint);
  var
    R: TRect;
  begin
    S.X := Fit(S.X, MinSize.X, MaxSize.X);
    S.Y := Fit(S.Y, MinSize.Y, MaxSize.Y);
    R.A.X := Place(P.X, S.X, Limits.A.X, Limits.B.X, dmLimitLoX, dmLimitHiX);
    R.A.Y := Place(P.Y, S.Y, Limits.A.Y, Limits.B.Y, dmLimitLoY, dmLimitHiY);
    R.B := (R.A + S);
    Locate(R);
  end;

  { follows the mouse until the button is released; Grab is the offset from
    the mouse to the point that moves with it }
  procedure Track(const Grab: TPoint);
  var
    Pt: TPoint;
    R: TRect;
  begin
    R := GetBounds;
    repeat
      Pt := (Event.Mouse.Where + Grab);
      if (Mode and dmDragMove) <> 0 then
        MoveGrow(Pt, Size)
      else if (Mode and dmDragGrow) <> 0 then
        MoveGrow(Origin, Pt)
      else
      begin
        { the left bottom corner follows the mouse, the right side stays }
        R.A.X := Fit(Pt.X, R.B.X - MaxSize.X, R.B.X - MinSize.X);
        R.B.Y := Pt.Y;
        MoveGrow(R.A, (R.B - R.A));
      end;
    until not MouseEvent(Event, evMouseMove);
  end;

  { the keyboard: arrows move (with Shift: resize), Enter keeps, Esc undoes }
  procedure Keys;
  var
    Saved: TRect;
    P, S, D: TPoint;
    K: Word;
    Done: Boolean;
  begin
    Saved := GetBounds;
    repeat
      P := Origin;
      S := Size;
      KeyEvent(Event);
      K := Event.KeyDown.KeyCode and $FF00;
      D := Point(0, 0);
      case K of
        kbLeft, kbCtrlLeft, kbRight, kbCtrlRight:
          D.X := 2 * Ord((K = kbRight) or (K = kbCtrlRight)) - 1;
        kbUp, kbCtrlUp, kbDown, kbCtrlDown:
          D.Y := 2 * Ord((K = kbDown) or (K = kbCtrlDown)) - 1;
        { Home and End: to the left and the right edge, PgUp and PgDn: to the top and the bottom }
        kbHome, kbEnd:
          if K = kbEnd then
            P.X := Limits.B.X - S.X
          else
            P.X := Limits.A.X;
        kbPgUp, kbPgDn:
          if K = kbPgDn then
            P.Y := Limits.B.Y - S.Y
          else
            P.Y := Limits.A.Y;
      end;
      { with Ctrl the steps are bigger }
      if (K = kbCtrlLeft) or (K = kbCtrlRight) then
        D.X := D.X * 8
      else if (K = kbCtrlUp) or (K = kbCtrlDown) then
        D.Y := D.Y * 4;
      if (Event.KeyDown.ControlKeyState and kbShift) <> 0 then
      begin
        if (Mode and dmDragGrow) <> 0 then
          S := (S + D);
      end
      else if (Mode and dmDragMove) <> 0 then
        P := (P + D);
      MoveGrow(P, S);
      Done := (Event.KeyDown.KeyCode = kbEnter) or (Event.KeyDown.KeyCode = kbEsc);
    until Done;
    if Event.KeyDown.KeyCode <> kbEnter then
      Locate(Saved);
  end;

var
  Corner: TPoint;
begin
  SetState(sfDragging, True);
  if Event.What <> evMouseDown then
    Keys
  else if (Mode and dmDragMove) <> 0 then
    Track((Origin - Event.Mouse.Where))
  else if (Mode and dmDragGrow) <> 0 then
    Track((Size - Event.Mouse.Where))
  else
  begin
    Corner := Point(Origin.X, Origin.Y + Size.Y);
    Track((Corner - Event.Mouse.Where));
  end;
  SetState(sfDragging, False);
end;

procedure TView.Draw;
var
  B: TDrawBuffer;
  Pair: TAttrPair;
begin
  B := TDrawBuffer.Create(IMax(TScreen.ScreenWidth, TScreen.ScreenHeight));
  Pair := GetColor(1);
  B.MoveChar(0, Ord(' '), Pair[0], Size.X);
  WriteLine(0, 0, Size.X, Size.Y, B);
  B.Free;
end;

procedure TView.DrawCursor;
begin
  if (State and sfFocused) <> 0 then
    ResetCursor;
end;

procedure TView.DrawHide(LastView: TView);
begin
  DrawCursor;
  DrawUnderView((State and sfShadow) <> 0, LastView);
end;

procedure TView.DrawShow(LastView: TView);
begin
  DrawView;
  if (State and sfShadow) <> 0 then
    DrawUnderView(True, LastView);
end;

procedure TView.DrawUnderRect(var R: TRect; LastView: TView);
begin
  Owner.Clip.Intersect(R);
  Owner.DrawSubViews(NextView, LastView);
  Owner.Clip := Owner.GetExtent;
end;

procedure TView.DrawUnderView(DoShadow: Boolean; LastView: TView);
var
  R: TRect;
begin
  R := GetBounds;
  if DoShadow then
    R.B := (R.B + ShadowSize);
  if (Options and ofFramed) <> 0 then
    R.Grow(1, 1);
  DrawUnderRect(R, LastView);
end;

procedure TView.DrawView;
begin
  if Exposed then
  begin
    Draw;
    DrawCursor;
  end;
end;

function TView.EventAvail: Boolean;
var
  Event: TEvent;
begin
  GetEvent(Event);
  if Event.What <> evNothing then
    PutEvent(Event);
  Result := Event.What <> evNothing;
end;

procedure TView.EndModal(Command: Word);
begin
  if TopView <> nil then
    TopView.EndModal(Command);
end;

function TView.Exposed: Boolean;
begin
  Result := ViewExposed(Self);
end;

function TView.Execute: Word;
begin
  Result := cmCancel;
end;

function TView.Focus: Boolean;
begin
  Result := True;
  if (State and (sfSelected or sfModal)) = 0 then
    if Owner <> nil then
    begin
      Result := Owner.Focus;
      if Result then
      begin
        if (Owner.Current = nil)
          or ((Owner.Current.Options and ofValidate) = 0)
          or Owner.Current.Valid(cmReleasedFocus) then
          Select
        else
          Result := False;
      end;
    end;
end;

function TView.GetBounds: TRect;
begin
  Result.A := Origin;
  Result.B := (Origin + Size);
end;

function TView.GetClipRect: TRect;
begin
  Result := GetBounds;
  if Owner <> nil then
    Result.Intersect(Owner.Clip);
  Result.Move(-Origin.X, -Origin.Y);
end;

function TView.GetColor(Color: Word): TAttrPair;
begin
  Result[0] := MapColor(Color and $FF);
  if (Color and $FF00) <> 0 then
    Result[1] := MapColor(Color shr 8)
  else
    Result[1] := TColorAttr(LongInt(0));
end;

procedure TView.GetData(var Rec);
begin
end;

procedure TView.GetEvent(var Event: TEvent);
begin
  if Owner <> nil then
    Owner.GetEvent(Event);
end;

function TView.TextEvent(var Event: TEvent; out Text: AnsiString): Boolean;
const
  MaxPaste = 16 * 1024 * 1024;

  function IsText(const E: TEvent): Boolean;
  begin
    Result := (E.What = evKeyDown) and (E.KeyDown.TextLength > 0) and ((E.KeyDown.ControlKeyState and kbPaste) <> 0);
  end;

  procedure Add(const E: TEvent);
  var
    I: Integer;
  begin
    for I := 0 to E.KeyDown.TextLength - 1 do
      Text := Text + E.KeyDown.Text[I];
  end;

var
  Ev: TEvent;
begin
  Text := '';
  if (Event.What = evKeyDown) and (Event.KeyDown.TextLength > 0) then
    Add(Event);
  repeat
    TEventQueue.GetKeyEvent(Ev);
    if not IsText(Ev) then
      Break;
    Add(Ev);
  until Length(Text) > MaxPaste;
  if Ev.What <> evNothing then
    PutEvent(Ev);
  ClearEvent(Event);
  Result := Text <> '';
end;

function TView.GetExtent: TRect;
begin
  Result := TRect.Create(0, 0, Size.X, Size.Y);
end;

function TView.GetHelpCtx: Word;
begin
  if (State and sfDragging) <> 0 then
    Result := hcDragging
  else
    Result := HelpCtx;
end;

function TView.GetPalette: TPalette;
begin
  Result := Default(TPalette);
end;

function TView.GetState(AState: Word): Boolean;
begin
  Result := (State and AState) = AState;
end;

procedure TView.GrowTo(X, Y: Integer);
var
  R: TRect;
begin
  R.A := Origin;
  R.B.X := Origin.X + X;
  R.B.Y := Origin.Y + Y;
  Locate(R);
end;

procedure TView.HandleEvent(var Event: TEvent);
begin
  { a click on a selectable view that is not selected yet focuses it; the
    click itself goes on only to views that want the first click }
  if (Event.What = evMouseDown)
    and ((Options and ofSelectable) <> 0)
    and ((State and (sfSelected or sfDisabled)) = 0) then
    if not (Focus and ((Options and ofFirstClick) <> 0)) then
      ClearEvent(Event);
end;

procedure TView.Hide;
begin
  if (State and sfVisible) <> 0 then
    SetState(sfVisible, False);
end;

procedure TView.HideCursor;
begin
  SetState(sfCursorVis, False);
end;

procedure TView.KeyEvent(var Event: TEvent);
begin
  repeat
    GetEvent(Event);
  until Event.What = evKeyDown;
end;

procedure TView.Locate(var Bounds: TRect);
var
  MinS, MaxS: TPoint;
  Old: TRect;
begin
  SizeLimits(MinS, MaxS);
  { the size is kept within the limits, the origin stays }
  Bounds.B := (Bounds.A + Point(Range(Bounds.B.X - Bounds.A.X, MinS.X, MaxS.X), Range(Bounds.B.Y - Bounds.A.Y, MinS.Y, MaxS.Y)));
  Old := GetBounds;
  if (Bounds = Old) then
    Exit;
  ChangeBounds(Bounds);
  if (Owner = nil) or ((State and sfVisible) = 0) then
    Exit;
  if (State and sfShadow) <> 0 then
  begin
    Old.Union(Bounds);
    Old.B := (Old.B + ShadowSize);
  end;
  DrawUnderRect(Old, nil);
end;

procedure TView.MakeFirst;
begin
  PutInFrontOf(Owner.First);
end;

function TView.MakeGlobal(Source: TPoint): TPoint;
var
  Cur: TView;
begin
  Result := (Source + Origin);
  Cur := Self;
  while Cur.Owner <> nil do
  begin
    Cur := Cur.Owner;
    Result := (Result + Cur.Origin);
  end;
end;

function TView.MakeLocal(Source: TPoint): TPoint;
var
  Cur: TView;
begin
  Result := (Source - Origin);
  Cur := Self;
  while Cur.Owner <> nil do
  begin
    Cur := Cur.Owner;
    Result := (Result - Cur.Origin);
  end;
end;

function TView.MapColor(Index: Byte): TColorAttr;
var
  P: TPalette;
  Color: TColorAttr;
begin
  P := GetPalette;
  if P[0] <> 0 then
  begin
    if (0 < Index) and (Index <= Byte(P[0])) then
      Color := P[Index]
    else
      Exit(ErrorAttr);
  end
  else
    Color := LongInt(Index);
  if Color = 0 then
    Exit(ErrorAttr);
  if Owner <> nil then
    Result := Owner.MapColor(Byte(Color))
  else
    Result := Color;
end;

function TView.MouseEvent(var Event: TEvent; Mask: Word): Boolean;
begin
  repeat
    GetEvent(Event);
  until (Event.What and (Mask or evMouseUp)) <> 0;
  Result := Event.What <> evMouseUp;
end;

function TView.MouseInView(Mouse: TPoint): Boolean;
var
  R: TRect;
begin
  Mouse := MakeLocal(Mouse);
  R := GetExtent;
  Result := R.Contains(Mouse);
end;

procedure TView.MoveTo(X, Y: Integer);
var
  R: TRect;
begin
  R.A := Point(X, Y);
  R.B := (R.A + Size);
  Locate(R);
end;

function TView.NextView: TView;
begin
  if Self = Owner.Last then
    Result := nil
  else
    Result := Next;
end;

procedure TView.NormalCursor;
begin
  SetState(sfCursorIns, False);
end;

function TView.Prev: TView;
begin
  Result := Self;
  while Result.Next <> Self do
    Result := Result.Next;
end;

function TView.PrevView: TView;
begin
  if Self = Owner.First then
    Result := nil
  else
    Result := Prev;
end;

procedure TView.PutEvent(var Event: TEvent);
begin
  if Owner <> nil then
    Owner.PutEvent(Event);
end;

procedure TView.PutInFrontOf(Target: TView);
var
  Below, P: TView;
  MovesDown: Boolean;
begin
  if (Owner = nil) or (Target = Self) or (Target = NextView) then
    Exit;
  if (Target <> nil) and (Target.Owner <> Owner) then
    Exit;
  if (State and sfVisible) = 0 then
  begin
    Owner.RemoveView(Self);
    Owner.InsertView(Self, Target);
    Exit;
  end;
  { the view goes down when Target is not above it: then what gets uncovered
    is redrawn, else the view itself is drawn over the views it now covers }
  P := Target;
  while (P <> nil) and (P <> Self) do
    P := P.NextView;
  MovesDown := P = nil;
  if MovesDown then
    Below := Target
  else
    Below := NextView;
  State := State and not sfVisible;
  if MovesDown then
    DrawHide(Below);
  Owner.RemoveView(Self);
  Owner.InsertView(Self, Target);
  State := State or sfVisible;
  if not MovesDown then
    DrawShow(Below);
  if (Options and ofSelectable) <> 0 then
    Owner.ResetCurrent;
end;

procedure TView.ResetCursor;
var
  X, Y, CaretSize: Integer;
begin
  X := Cursor.X;
  Y := Cursor.Y;
  CaretSize := ComputeCaretSize(Self, X, Y);
  if CaretSize <> 0 then
    THardwareInfo.SetCaretPosition(X, Y);
  THardwareInfo.SetCaretSize(CaretSize);
end;

procedure TView.Select;
begin
  if ((Options and ofSelectable) <> 0) and (Owner <> nil) then
  begin
    if (Options and ofTopSelect) <> 0 then
      MakeFirst
    else
      Owner.SetCurrent(Self, normalSelect);
  end;
end;

procedure TView.SetBounds(const Bounds: TRect);
begin
  Origin := Bounds.A;
  Size := (Bounds.B - Bounds.A);
end;

procedure TView.SetCursor(X, Y: Integer);
begin
  Cursor.X := X;
  Cursor.Y := Y;
  DrawCursor;
end;

procedure TView.SetData(var Rec);
begin
end;

procedure TView.SetState(AState: Word; Enable: Boolean);
const
  FocusMsg: array[Boolean] of Word = (cmReleasedFocus, cmReceivedFocus);
begin
  if Enable then
    State := State or AState
  else
    State := State and not AState;
  if Owner = nil then
    Exit;
  if AState = sfVisible then
  begin
    { a view is exposed while it is visible inside an exposed owner }
    if Owner.GetState(sfExposed) then
      SetState(sfExposed, Enable);
    if not Enable then
      DrawHide(nil)
    else
      DrawShow(nil);
    if (Options and ofSelectable) <> 0 then
      Owner.ResetCurrent;
  end
  else if AState = sfFocused then
  begin
    ResetCursor;
    Message(Owner, evBroadcast, FocusMsg[Enable], Self);
  end
  else if AState = sfShadow then
    DrawUnderView(True, nil)
  else if (AState = sfCursorIns) or (AState = sfCursorVis) then
    DrawCursor;
end;

procedure TView.Show;
begin
  if (State and sfVisible) = 0 then
    SetState(sfVisible, True);
end;

procedure TView.ShowCursor;
begin
  SetState(sfCursorVis, True);
end;

procedure TView.SizeLimits(out Min, Max: TPoint);
begin
  Min.X := 0;
  Min.Y := 0;
  if ((GrowMode and gfFixed) = 0) and (Owner <> nil) then
    Max := Owner.Size
  else
  begin
    Max.X := MaxInt;
    Max.Y := MaxInt;
  end;
end;

function TView.SetTimer(TimeoutMs: LongWord; PeriodMs: Integer): TTimerId;
begin
  if Owner <> nil then
    Result := Owner.SetTimer(TimeoutMs, PeriodMs)
  else
    Result := nil;
end;

procedure TView.KillTimer(Id: TTimerId);
begin
  if Owner <> nil then
    Owner.KillTimer(Id);
end;

function TView.TopView: TView;
begin
  if TheTopView <> nil then
    Result := TheTopView
  else
  begin
    Result := Self;
    while (Result <> nil) and ((Result.State and sfModal) = 0) do
      Result := TView(Result.Owner);
  end;
end;

function TView.Valid(Command: Word): Boolean;
begin
  Result := True;
end;

procedure TView.WriteView(X, Y, Count: Integer; B: PScreenCell);
var
  W: TVWrite;
begin
  WriteL0(W, Self, X, Y, Count, B);
end;

procedure TView.WriteBuf(X, Y, W, H: Integer; B: PScreenCell);
begin
  while H > 0 do
  begin
    WriteView(X, Y, W, B);
    Inc(Y);
    Inc(B, W);
    Dec(H);
  end;
end;

procedure TView.WriteBuf(X, Y, W, H: Integer; const B: TDrawBuffer);
begin
  WriteBuf(X, Y, IMin(W, B.Capacity - X), H, B.Data);
end;

procedure TView.WriteLine(X, Y, W, H: Integer; B: PScreenCell);
begin
  while H > 0 do
  begin
    WriteView(X, Y, W, B);
    Inc(Y);
    Dec(H);
  end;
end;

procedure TView.WriteLine(X, Y, W, H: Integer; const B: TDrawBuffer);
begin
  WriteLine(X, Y, IMin(W, B.Capacity - X), H, B.Data);
end;

procedure TView.WriteBufW(X, Y, W, H: Integer; const B);
var
  Src: PWord;
  Buf: PScreenCell;
  I: Integer;
begin
  if (W <= 0) or (H <= 0) then
    Exit;
  Src := @B;
  GetMem(Buf, W * SizeOf(TScreenCell));
  while H > 0 do
  begin
    for I := 0 to W - 1 do
      Buf[I] := TScreenCell(Word(Src[I]));
    WriteView(X, Y, W, Buf);
    Inc(Y);
    Inc(Src, W);
    Dec(H);
  end;
  FreeMem(Buf);
end;

procedure TView.WriteLineW(X, Y, W, H: Integer; const B);
var
  Src: PWord;
  Buf: PScreenCell;
  I: Integer;
begin
  if (W <= 0) or (H <= 0) then
    Exit;
  Src := @B;
  GetMem(Buf, W * SizeOf(TScreenCell));
  for I := 0 to W - 1 do
    Buf[I] := TScreenCell(Word(Src[I]));
  while H > 0 do
  begin
    WriteView(X, Y, W, Buf);
    Inc(Y);
    Dec(H);
  end;
  FreeMem(Buf);
end;

procedure TView.WriteBufC(X, Y, W, H: Integer; const B);
begin
  WriteBuf(X, Y, W, H, PScreenCell(@B));
end;

procedure TView.WriteLineC(X, Y, W, H: Integer; const B);
begin
  WriteLine(X, Y, W, H, PScreenCell(@B));
end;

function TView.GetColorW(Color: Word): Word;
var
  P: TAttrPair;
begin
  P := GetColor(Color);
  Result := Byte(P[0]) or (Word(Byte(P[1])) shl 8);
end;

procedure TView.WriteChar(X, Y: Integer; C: Byte; Color: Byte; Count: Integer);
var
  Buf: PScreenCell;
  Attr: TColorAttr;
begin
  if Count > Size.X then
    Count := Size.X;
  if Count > 0 then
  begin
    GetMem(Buf, Count * SizeOf(TScreenCell));
    Attr := MapColor(Color);
    TText.DrawChar(Buf, Count, C, @Attr);
    WriteView(X, Y, Count, Buf);
    FreeMem(Buf);
  end;
end;

procedure TView.WriteStr(X, Y: Integer; const Str: ShortString; Color: Byte);
var
  Buf: PScreenCell;
  Attr: TColorAttr;
  Count: Integer;
begin
  Count := TText.Width(Str);
  if Count > Size.X then
    Count := Size.X;
  if Count > 0 then
  begin
    GetMem(Buf, Count * SizeOf(TScreenCell));
    FillChar(Buf^, Count * SizeOf(TScreenCell), 0);
    Attr := MapColor(Color);
    TText.DrawStr(Buf, Count, 0, Str, 0, @Attr);
    WriteView(X, Y, Count, Buf);
    FreeMem(Buf);
  end;
end;

{ ------------------------------------------------------------------------- }
{ TGroup                                                                     }
{ ------------------------------------------------------------------------- }

constructor TGroup.Create(const Bounds: TRect);
begin
  inherited Create(Bounds);
  Current := nil;
  Last := nil;
  Phase := phFocused;
  Buffer := nil;
  LockFlag := 0;
  EndState := 0;
  Options := Options or ofSelectable or ofBuffered;
  Clip := GetExtent;
  EventMask := $FFFF;
end;

destructor TGroup.Destroy;
var
  P: TView;
begin
  Hide;
  P := Last;
  if P <> nil then
  begin
    repeat
      P.Hide;
      P := P.Prev;
    until P = Last;
    { the top view is disposed again and again, not a view that was taken before: the Done of a view may dispose another
      view of the group (DN: a panel disposes its info panel), which would leave the remembered one dangling }
    while Last <> nil do
      Last.Free;
  end;
  FreeBuffer;
  Current := nil;
  inherited Destroy;
end;

procedure DoCalcChange(P: TView; D: Pointer);
var
  R: TRect;
begin
  P.CalcBounds(R, PPoint(D)^);
  P.ChangeBounds(R);
end;

procedure DoAwaken(V: TView; Args: Pointer);
begin
  V.Awaken;
end;

procedure TGroup.Awaken;
begin
  ForEach(@DoAwaken, nil);
end;

procedure TGroup.ChangeBounds(const Bounds: TRect);
var
  D: TPoint;
begin
  D.X := (Bounds.B.X - Bounds.A.X) - Size.X;
  D.Y := (Bounds.B.Y - Bounds.A.Y) - Size.Y;
  if (D.X = 0) and (D.Y = 0) then
  begin
    SetBounds(Bounds);
    DrawView;
  end
  else
  begin
    SetBounds(Bounds);
    Clip := GetExtent;
    GetBuffer;
    Lock;
    ForEach(@DoCalcChange, @D);
    Unlock;
  end;
end;

procedure AddSubviewDataSize(P: TView; T: Pointer);
begin
  Inc(PInteger(T)^, P.DataSize);
end;

function TGroup.DataSize: Integer;
var
  T: Integer;
begin
  T := 0;
  ForEach(@AddSubviewDataSize, @T);
  Result := T;
end;

procedure TGroup.Delete(P: TView);
var
  SaveState: Word;
begin
  if P <> nil then
  begin
    SaveState := P.State;
    P.Hide;
    RemoveView(P);
    P.Owner := nil;
    P.Next := nil;
    if (SaveState and sfVisible) <> 0 then
      P.Show;
  end;
end;

procedure TGroup.Draw;
var
  Fresh: Boolean;
begin
  Fresh := Buffer = nil;
  if Fresh then
    GetBuffer;
  if Buffer = nil then
  begin
    { no buffer: the subviews draw straight through, clipped to what shows }
    Clip := GetClipRect;
    Redraw;
    Clip := GetExtent;
    Exit;
  end;
  if Fresh then
  begin
    { a new buffer is filled by the subviews first; locked, their output stays in it }
    Inc(LockFlag);
    Redraw;
    Dec(LockFlag);
  end;
  WriteBuf(0, 0, Size.X, Size.Y, Buffer);
end;

procedure TGroup.DrawSubViews(P, Bottom: TView);
begin
  while P <> Bottom do
  begin
    P.DrawView;
    P := P.NextView;
  end;
end;

procedure TGroup.EndModal(Command: Word);
begin
  if (State and sfModal) <> 0 then
    EndState := Command
  else
    inherited EndModal(Command);
end;

procedure TGroup.EventError(var Event: TEvent);
begin
  if Owner <> nil then
    Owner.EventError(Event);
end;

function TGroup.Execute: Word;
var
  E: TEvent;
begin
  repeat
    EndState := 0;
    while EndState = 0 do
    begin
      GetEvent(E);
      HandleEvent(E);
      if E.What <> evNothing then
        EventError(E);
    end;
  until Valid(EndState);
  Result := EndState;
end;

function TGroup.ExecView(P: TView): Word;
var
  OldOptions: Word;
  OldOwner: TGroup;
  OldTop, OldCurrent: TView;
  OldCommands: TCommandSet;
begin
  if P = nil then
    Exit(cmCancel);
  OldOptions := P.Options;
  OldOwner := P.Owner;
  OldTop := TheTopView;
  OldCurrent := Current;
  GetCommands(OldCommands);
  Inc(ModalCount);
  try
    TheTopView := P;
    P.Options := P.Options and not ofSelectable;
    P.SetState(sfModal, True);
    SetCurrent(P, enterSelect);
    if OldOwner = nil then
      Insert(P);
    Result := P.Execute;
    if OldOwner = nil then
      Delete(P);
    SetCurrent(OldCurrent, leaveSelect);
    P.SetState(sfModal, False);
    P.Options := OldOptions;
    TheTopView := OldTop;
    SetCommands(OldCommands);
  finally
    Dec(ModalCount);
  end;
end;

function TGroup.First: TView;
begin
  if Last = nil then
    Result := nil
  else
    Result := Last.Next;
end;

function TGroup.FindNext(Forwards: Boolean): TView;
var
  P: TView;
begin
  Result := nil;
  if Current <> nil then
  begin
    P := Current;
    repeat
      if Forwards then
        P := P.Next
      else
        P := P.Prev;
    until (((P.State and (sfVisible or sfDisabled)) = sfVisible)
      and ((P.Options and ofSelectable) <> 0)) or (P = Current);
    if P <> Current then
      Result := P;
  end;
end;

function TGroup.FocusNext(Forwards: Boolean): Boolean;
var
  P: TView;
begin
  P := FindNext(Forwards);
  if P <> nil then
    Result := P.Focus
  else
    Result := True;
end;

function TGroup.FirstMatch(AState, AOptions: Word): TView;
var
  Temp: TView;
begin
  if Last = nil then
    Exit(nil);
  Temp := Last;
  while True do
  begin
    if ((Temp.State and AState) = AState) and ((Temp.Options and AOptions) = AOptions) then
      Exit(Temp);
    Temp := Temp.Next;
    if Temp = Last then
      Exit(nil);
  end;
end;

procedure TGroup.FreeBuffer;
begin
  if ((Options and ofBuffered) <> 0) and (Buffer <> nil) then
  begin
    FreeMem(Buffer);
    Buffer := nil;
  end;
end;

procedure TGroup.GetBuffer;
var
  Sz: Integer;
begin
  if (State and sfExposed) <> 0 then
    if (Options and ofBuffered) <> 0 then
    begin
      Sz := Size.X * Size.Y * SizeOf(TScreenCell);
      if Sz < 0 then
        Sz := 0;
      if Buffer <> nil then
        FreeMem(Buffer);
      Buffer := nil;
      if Sz > 0 then
      begin
        GetMem(Buffer, Sz);
        FillChar(Buffer^, Sz, 0);
      end;
    end;
end;

procedure TGroup.GetData(var Rec);
var
  I: Integer;
  V: TView;
begin
  I := 0;
  if Last <> nil then
  begin
    V := Last;
    repeat
      V.GetData((PByte(@Rec) + I)^);
      Inc(I, V.DataSize);
      V := V.Prev;
    until V = Last;
  end;
end;

type
  THandleStruct = record
    Event: ^TEvent;
    Grp: TGroup;
  end;
  PHandleStruct = ^THandleStruct;

procedure DoHandleEvent(P: TView; S: Pointer);
var
  Ptr: PHandleStruct;
begin
  Ptr := PHandleStruct(S);
  if (P = nil)
    or (((P.State and sfDisabled) <> 0)
      and ((Ptr^.Event^.What and (positionalEvents or focusedEvents)) <> 0)) then
    Exit;
  case Ptr^.Grp.Phase of
    phFocused: ;
    phPreProcess:
      if (P.Options and ofPreProcess) = 0 then
        Exit;
    phPostProcess:
      if (P.Options and ofPostProcess) = 0 then
        Exit;
  end;
  if (Ptr^.Event^.What and P.EventMask) <> 0 then
    P.HandleEvent(Ptr^.Event^);
end;

function HasMouse(P: TView; S: Pointer): Boolean;
begin
  Result := P.ContainsMouse(PEvent(S)^);
end;

procedure TGroup.HandleEvent(var Event: TEvent);
var
  HS: THandleStruct;
begin
  inherited HandleEvent(Event);
  HS.Event := @Event;
  HS.Grp := Self;
  if (Event.What and focusedEvents) <> 0 then
  begin
    Phase := phPreProcess;
    ForEach(@DoHandleEvent, @HS);
    Phase := phFocused;
    DoHandleEvent(Current, @HS);
    Phase := phPostProcess;
    ForEach(@DoHandleEvent, @HS);
  end
  else if Event.What <> 0 then
  begin
    Phase := phFocused;
    if ((Event.What and positionalEvents) <> 0)
      or ((Event.What = evMouseWheel) and UxWheelUnderCursor) then
      DoHandleEvent(FirstThat(@HasMouse, @Event), @HS)
    else
      ForEach(@DoHandleEvent, @HS);
  end;
end;

function TGroup.At(Index: Integer): TView;
begin
  Result := Last;
  while Index > 0 do
  begin
    Result := Result.Next;
    Dec(Index);
  end;
end;

function TGroup.FirstThat(Func: TFirstThatFunc; Args: Pointer): TView;
var
  Temp: TView;
begin
  Temp := Last;
  if Temp = nil then
    Exit(nil);
  repeat
    Temp := Temp.Next;
    if Func(Temp, Args) then
      Exit(Temp);
  until Temp = Last;
  Result := nil;
end;

procedure TGroup.ForEach(Func: TForEachProc; Args: Pointer);
var
  Term, Temp, NextV: TView;
begin
  Term := Last;
  Temp := Last;
  if Temp = nil then
    Exit;
  NextV := Temp.Next;
  repeat
    Temp := NextV;
    NextV := Temp.Next;
    Func(Temp, Args);
  until Temp = Term;
end;

function TGroup.FirstThat(Test: TNestedViewTest): TView;
var
  Temp: TView;
begin
  Temp := Last;
  if Temp = nil then
    Exit(nil);
  repeat
    Temp := Temp.Next;
    if Test(Temp) then
      Exit(Temp);
  until Temp = Last;
  Result := nil;
end;

procedure TGroup.ForEach(Action: TNestedViewAction);
var
  Term, Temp, NextV: TView;
begin
  Term := Last;
  Temp := Last;
  if Temp = nil then
    Exit;
  NextV := Temp.Next;
  repeat
    Temp := NextV;
    NextV := Temp.Next;
    Action(Temp);
  until Temp = Term;
end;

function TGroup.IndexOf(P: TView): Integer;
var
  Temp: TView;
begin
  if Last = nil then
    Exit(0);
  Result := 0;
  Temp := Last;
  repeat
    Inc(Result);
    Temp := Temp.Next;
  until (Temp = P) or (Temp = Last);
  if Temp <> P then
    Result := 0;
end;

procedure TGroup.Insert(P: TView);
begin
  InsertBefore(P, First);
end;

procedure TGroup.InsertBefore(P, Target: TView);
var
  SaveState: Word;
begin
  if (P <> nil) and (P.Owner = nil) and ((Target = nil) or (Target.Owner = Self)) then
  begin
    if (P.Options and ofCenterX) <> 0 then
      P.Origin.X := (Size.X - P.Size.X) div 2;
    if (P.Options and ofCenterY) <> 0 then
      P.Origin.Y := (Size.Y - P.Size.Y) div 2;
    SaveState := P.State;
    P.Hide;
    InsertView(P, Target);
    if (SaveState and sfVisible) <> 0 then
      P.Show;
    if (SaveState and sfActive) <> 0 then
      P.SetState(sfActive, True);
  end;
end;

procedure TGroup.InsertView(P, Target: TView);
begin
  P.Owner := Self;
  if Target <> nil then
  begin
    Target := Target.Prev;
    P.Next := Target.Next;
    Target.Next := P;
  end
  else
  begin
    if Last = nil then
      P.Next := P
    else
    begin
      P.Next := Last.Next;
      Last.Next := P;
    end;
    Last := P;
  end;
end;

procedure TGroup.Lock;
begin
  if (Buffer <> nil) or (LockFlag <> 0) then
    Inc(LockFlag);
end;

procedure TGroup.Redraw;
begin
  DrawSubViews(First, nil);
end;

procedure TGroup.RemoveView(P: TView);
var
  S: TView;
begin
  if Last <> nil then
  begin
    S := Last;
    while S.Next <> P do
    begin
      if S.Next = Last then
        Exit;
      S := S.Next;
    end;
    S.Next := P.Next;
    if P = Last then
    begin
      if P = P.Next then
        Last := nil
      else
        Last := S;
    end;
  end;
end;

procedure TGroup.ResetCurrent;
begin
  SetCurrent(FirstMatch(sfVisible, ofSelectable), normalSelect);
end;

procedure TGroup.ResetCursor;
begin
  if Current <> nil then
    Current.ResetCursor;
end;

procedure TGroup.SelectNext(Forwards: Boolean);
var
  P: TView;
begin
  if Current <> nil then
  begin
    P := FindNext(Forwards);
    if P <> nil then
      P.Select;
  end;
end;

procedure TGroup.SelectView(P: TView; Enable: Boolean);
begin
  if P <> nil then
    P.SetState(sfSelected, Enable);
end;

procedure TGroup.FocusView(P: TView; Enable: Boolean);
begin
  if ((State and sfFocused) <> 0) and (P <> nil) then
    P.SetState(sfFocused, Enable);
end;

procedure TGroup.SetCurrent(P: TView; Mode: SelectMode);
begin
  if Current <> P then
  begin
    Lock;
    FocusView(Current, False);
    if Mode <> enterSelect then
      if Current <> nil then
        Current.SetState(sfSelected, False);
    if Mode <> leaveSelect then
      if P <> nil then
        P.SetState(sfSelected, True);
    if ((State and sfFocused) <> 0) and (P <> nil) then
      P.SetState(sfFocused, True);
    Current := P;
    Unlock;
  end;
end;

procedure TGroup.SetData(var Rec);
var
  I: Integer;
  V: TView;
begin
  I := 0;
  if Last <> nil then
  begin
    V := Last;
    repeat
      V.SetData((PByte(@Rec) + I)^);
      Inc(I, V.DataSize);
      V := V.Prev;
    until V = Last;
  end;
end;

procedure DoExpose(P: TView; Enable: Pointer);
begin
  if (P.State and sfVisible) <> 0 then
    P.SetState(sfExposed, PBoolean(Enable)^);
end;

type
  TSetBlock = record
    St: Word;
    En: Boolean;
  end;
  PSetBlock = ^TSetBlock;

procedure DoSetState(P: TView; B: Pointer);
begin
  P.SetState(PSetBlock(B)^.St, PSetBlock(B)^.En);
end;

procedure TGroup.SetState(AState: Word; Enable: Boolean);
var
  SB: TSetBlock;
begin
  SB.St := AState;
  SB.En := Enable;
  inherited SetState(AState, Enable);
  if (AState and (sfActive or sfDragging)) <> 0 then
  begin
    Lock;
    ForEach(@DoSetState, @SB);
    Unlock;
  end;
  if (AState and sfFocused) <> 0 then
  begin
    if Current <> nil then
      Current.SetState(sfFocused, Enable);
  end;
  if (AState and sfExposed) <> 0 then
  begin
    ForEach(@DoExpose, @Enable);
    if not Enable then
      FreeBuffer;
  end;
end;

procedure TGroup.Unlock;
begin
  if LockFlag <> 0 then
  begin
    Dec(LockFlag);
    if LockFlag = 0 then
      DrawView;
  end;
end;

function IsInvalid(P: TView; Command: Pointer): Boolean;
begin
  Result := not P.Valid(PWord(Command)^);
end;

function TGroup.Valid(Command: Word): Boolean;
begin
  if Command = cmReleasedFocus then
  begin
    if (Current <> nil) and ((Current.Options and ofValidate) <> 0) then
      Result := Current.Valid(Command)
    else
      Result := True;
  end
  else
    Result := FirstThat(@IsInvalid, @Command) = nil;
end;

function TGroup.GetHelpCtx: Word;
var
  H: Word;
begin
  H := hcNoContext;
  if Current <> nil then
    H := Current.GetHelpCtx;
  if H = hcNoContext then
    H := inherited GetHelpCtx;
  Result := H;
end;


{ --- Streams ------------------------------------------------------------------ }

procedure TView.Write(Os: opstream);
var
  SaveState: Word;
begin
  SaveState := State and not (sfActive or sfSelected or sfFocused or sfExposed);
  Os.WriteBytes(Origin, SizeOf(TPoint));
  Os.WriteBytes(Size, SizeOf(TPoint));
  Os.WriteBytes(Cursor, SizeOf(TPoint));
  Os.WriteByte(GrowMode);
  Os.WriteByte(DragMode);
  Os.WriteWord(HelpCtx);
  Os.WriteWord(SaveState);
  Os.WriteWord(Options);
  Os.WriteWord(EventMask);
end;

function TView.Read(Ip: ipstream): Pointer;
begin
  Ip.ReadBytes(Origin, SizeOf(TPoint));
  Ip.ReadBytes(Size, SizeOf(TPoint));
  Ip.ReadBytes(Cursor, SizeOf(TPoint));
  GrowMode := Ip.ReadByte;
  DragMode := Ip.ReadByte;
  HelpCtx := Ip.ReadWord;
  State := Ip.ReadWord;
  Options := Ip.ReadWord;
  EventMask := Ip.ReadWord;
  Owner := nil;
  Next := nil;
  Result := Self;
end;

class function TView.Build: TStreamable;
begin
  Result := TView.Create(streamableInit);
end;

constructor TView.Create(AInit: TStreamableInit);
begin
  inherited Create;
end;

function TView.StreamableName: ShortString;
begin
  Result := 'TView';
end;

procedure TView.Update;
begin
end;

procedure TGroup.Write(Os: opstream);
var
  Index: Word;
  OwnerSave: TGroup;
  ACount: Integer;
  P: TView;
begin
  inherited Write(Os);
  OwnerSave := Owner;
  Owner := Self;
  ACount := IndexOf(Last);
  Os.WriteBytes(ACount, SizeOf(Integer));
  if Last <> nil then
  begin
    P := Last.Next;
    repeat
      Os.WritePointer(P);
      P := P.Next;
    until P = Last.Next;
  end;
  if Current = nil then
    Index := 0
  else
    Index := IndexOf(Current);
  Os.WriteWord(Index);
  Owner := OwnerSave;
end;

function TGroup.Read(Ip: ipstream): Pointer;
var
  Index: Word;
  OwnerSave: TGroup;
  ACount, I: Integer;
  TV, ACurrent: TView;
begin
  inherited Read(Ip);
  Clip := GetExtent;
  OwnerSave := Owner;
  Owner := Self;
  Last := nil;
  Phase := phFocused;
  Current := nil;
  Buffer := nil;
  LockFlag := 0;
  EndState := 0;
  Ip.ReadBytes(ACount, SizeOf(Integer));
  for I := 0 to ACount - 1 do
  begin
    TV := TView(Ip.ReadPointer);
    if TV <> nil then
      InsertView(TV, nil);
  end;
  Owner := OwnerSave;
  Index := Ip.ReadWord;
  ACurrent := At(Index);
  SetCurrent(ACurrent, normalSelect);
  Awaken;
  Result := Self;
end;

class function TGroup.Build: TStreamable;
begin
  Result := TGroup.Create(streamableInit);
end;

constructor TGroup.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TGroup.StreamableName: ShortString;
begin
  Result := 'TGroup';
end;

initialization
  RView := TStreamableClass.Create('TView', @TView.Build);
  RGroup := TStreamableClass.Create('TGroup', @TGroup.Build);
  InitCommands;
  TView.ErrorAttr := TColorAttr(LongInt($CF));
end.
