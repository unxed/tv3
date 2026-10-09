{ TvWindow: window frame, scroll bars, scroller and window.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/views.h  (TFrame, TScrollBar, TScroller, TWindow, constants)
    source/tvision/tframe.cpp, framelin.cpp, tscrlbar.cpp, tscrolle.cpp, twindow.cpp,
    tvtext1.cpp (frame tables), drivers2.cpp (ctrlToArrow, in TvKeys)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the frame is created by the virtual method InitFrame (as in the Pascal Turbo
      Vision) instead of the TWindowInit helper class;
    - the title is a ShortString, an empty title is drawn like no title;
    - Done replaces shutDown: it clears the pointers to other views;
    - the frame characters are the CP437 ones and go through the code page of
      TvText; the original's replacement of frameChars[30] for other code pages is
      not needed (a code page maps the double-line characters itself);
    - streams are not translated yet. }
unit TvWindow;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvText, TvDrawBuf, TvScreen, TvObjs, TvViews, TvUtil, TvGlyphs;
{$WARN 3018 OFF}  { "Constructor should be public": Create(streamableInit) is protected, as in tvision }

const
  { TWindow.Number of a window without a number }
  wnNoNumber = 0;

  { TWindow.Palette }
  wpBlueWindow = 0;
  wpCyanWindow = 1;
  wpGrayWindow = 2;

  { TWindow.Flags: what the frame offers }
  wfClose = $04;
  wfGrow  = $02;
  wfMove  = $01;
  wfZoom  = $08;

  { the parts of a scroll bar (GetPartCode, ScrollStep): bit 0 = forwards,
    bit 1 = a page, bit 2 = vertical }
  sbLeftArrow  = 0;   sbUpArrow   = 4;
  sbRightArrow = 1;   sbDownArrow = 5;
  sbPageLeft   = 2;   sbPageUp    = 6;
  sbPageRight  = 3;   sbPageDown  = 7;
  sbIndicator  = 8;

  { options of TWindow.StandardScrollBar }
  sbHorizontal     = $000;
  sbVertical       = $001;
  sbHandleKeyboard = $002;

type
  TFrame = class;
  TScrollBar = class;
  TScroller = class;
  TWindow = class;

  { Palette: 1 = passive frame, 2 = passive title, 3 = active frame, 4 = active
    title, 5 = icons }
  TFrame = class(TView)
    constructor Create(const Bounds: TRect);
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
  public
    procedure Draw; override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure SetState(AState: Word; Enable: Boolean); override;
    procedure FrameLine(var FrameBuf: TDrawBuffer; Y, N: Integer; Color: TColorAttr);
    procedure DragWindow(var Event: TEvent; Mode: Byte);
  end;

  TScrollChars = array[0..4] of Byte;

  { Palette: 1 = page areas, 2 = arrows, 3 = indicator }
  TScrollBar = class(TView)
    Value: Integer;
    Chars: TScrollChars;
    MinVal: Integer;
    MaxVal: Integer;
    PgStep: Integer;
    ArStep: Integer;
    { used by DN: the last step that ScrollStep returned, and True while the step is repeated by a held mouse button }
    Step: LongInt;
    ForceScroll: Boolean;
    constructor Create(const Bounds: TRect);
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    procedure Draw; override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure ScrollDraw; virtual;
    function ScrollStep(Part: Integer): Integer; virtual;
    procedure SetParams(AValue, AMin, AMax, APgStep, AArStep: Integer);
    procedure SetRange(AMin, AMax: Integer);
    procedure SetStep(APgStep, AArStep: Integer);
    procedure SetValue(AValue: Integer);
    procedure DrawPos(Pos: Integer);
    function GetPos: Integer;
    function GetSize: Integer;
    function GetPartCode: Integer;
  end;

  { Palette: 1 = normal text, 2 = selected text }
  TScroller = class(TView)
    Delta: TPoint;
    DrawLock: Byte;
    DrawFlag: Boolean;
    HScrollBar: TScrollBar;
    VScrollBar: TScrollBar;
    Limit: TPoint;
    constructor Create(const Bounds: TRect; AHScrollBar, AVScrollBar: TScrollBar);
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    destructor Destroy; override;
    procedure ChangeBounds(const Bounds: TRect); override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure ScrollDraw; virtual;
    procedure ScrollTo(X, Y: Integer);
    procedure SetLimit(X, Y: Integer);
    procedure SetState(AState: Word; Enable: Boolean); override;
    procedure CheckDraw;
    procedure ShowSBar(SBar: TScrollBar);
  end;

  { Palette: 1 = passive frame, 2 = active frame, 3 = frame icon, 4 = scroll bar
    page area, 5 = scroll bar controls, 6 = scroller normal text, 7 = scroller
    selected text, 8 = reserved }
  TWindow = class(TGroup)
    Flags: Byte;
    ZoomRect: TRect;
    Number: Integer;
    Palette: Integer;
    Frame: TFrame;
    Title: PStr;   { as in Borland TV: a heap string (NewStr/DisposeStr), nil = none; DN changes it directly }
    constructor Create(const Bounds: TRect; const ATitle: ShortString; ANumber: Integer);
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    destructor Destroy; override;
    procedure Close; virtual;
    function GetPalette: TPalette; override;
    function GetTitle(MaxSize: Integer): ShortString; virtual;
    procedure HandleEvent(var Event: TEvent); override;
    procedure InitFrame; virtual;
    procedure SetState(AState: Word; Enable: Boolean); override;
    procedure SizeLimits(out Min, Max: TPoint); override;
    function StandardScrollBar(AOptions: Word): TScrollBar;
    procedure Zoom; virtual;
  end;

var
  { DN: called when a window with a number is destroyed (DN hands the numbers out itself: Views.GetNum) }
  WindowNumberFreeHook: procedure(Number: Integer) = nil;
  { stream records (see RView of TvViews) }
  RFrame, RScrollBar, RScroller, RWindow: TStreamableClass;

implementation

const
  MinWinSize: TPoint = (X: 16; Y: 6);

  { Frame line masks: bit 0 = up, 1 = right, 2 = down, 3 = left, +16 for a double
    line. FrameInit holds the masks of the left, middle and right part of the top,
    middle and bottom line, first for a passive, then for an active frame. }
  FramePassive: array[0..8] of Byte = (
    $06, $0A, $0C,      { top }
    $05, $00, $05,      { middle }
    $03, $0A, $09);     { bottom }
  DoubleLine = $10;

  { mask -> the glyph of the frame (a Unicode code point, TvGlyphs; 32 is a blank) }
  FrameGlyphs: array[0..31] of LongWord = (
    32, 32, 32, glLightUR, 32, glLightV, glLightDR, glLightVR, 32, glLightUL, glLightH, glLightUH, glLightDL, glLightVL, glLightDH, glLightVH,
    32, 32, 32, glDblUR, 32, glDblV, glDblDR, glVertDblRightSgl, 32, glDblUL, glDblH, glUpSglHorizDbl, glDblDL, glVertDblLeftSgl, glDownSglHorizDbl, 32);

  VChars: TScrollChars = (Ord(gcTriUp), Ord(gcTriDown), Ord(gcShadeMedium), Ord(gcSquare), Ord(gcShadeDark));
  HChars: TScrollChars = (Ord(gcTriLeft), Ord(gcTriRight), Ord(gcShadeMedium), Ord(gcSquare), Ord(gcShadeDark));

{ the icons of the frame: the text of a title bar element (the '~' pairs switch the color), in the text mode of the program (UTF-8, or the page) }
function CloseIcon: ShortString;
begin
  Result := '[~' + GlyphStr(glSquare) + '~]';
end;

function ZoomIcon: ShortString;
begin
  Result := '[~' + GlyphStr(glArrowUp) + '~]';
end;

function UnZoomIcon: ShortString;
begin
  Result := '[~' + GlyphStr(glUpDown) + '~]';
end;

function DragIcon: ShortString;
begin
  Result := '~' + GlyphStr(glLightH) + GlyphStr(glLightUL) + '~';
end;

function DragLeftIcon: ShortString;
begin
  Result := '~' + GlyphStr(glLightUR) + GlyphStr(glLightH) + '~';
end;

var
  { FramePassive, then the same masks with double lines for an active frame }
  FrameInit: array[0..17] of Byte;
  FramePalette, ScrollBarPalette, ScrollerPalette: TPalette;
  BluePalette, CyanPalette, GrayPalette: TPalette;

function Min2(A, B: Integer): Integer; inline;
begin
  if A < B then Result := A else Result := B;
end;

function Max2(A, B: Integer): Integer; inline;
begin
  if A > B then Result := A else Result := B;
end;

{ --- TFrame ------------------------------------------------------------------ }

constructor TFrame.Create(const Bounds: TRect);
begin
  inherited Create(Bounds);
  GrowMode := gfGrowHiX + gfGrowHiY;
  EventMask := EventMask or evBroadcast or evMouseUp;
end;

procedure TFrame.FrameLine(var FrameBuf: TDrawBuffer; Y, N: Integer; Color: TColorAttr);
var
  FrameMask: array of Byte;
  X, Start, Finish: Integer;
  V: TView;
  Mask: Word;
  MaskLow, MaskHigh: Byte;
begin
  if Size.X <= 0 then
    Exit;
  SetLength(FrameMask, Size.X);
  FrameMask[0] := FrameInit[N];
  for X := 1 to Size.X - 2 do
    FrameMask[X] := FrameInit[N + 1];
  FrameMask[Size.X - 1] := FrameInit[N + 2];
  { the framed views in front of this one cross the line }
  V := Owner.Last.Next;
  while V <> TView(Self) do
  begin
    if ((V.Options and ofFramed) <> 0) and ((V.State and sfVisible) <> 0) then
    begin
      Mask := 0;
      if Y < V.Origin.Y then
      begin
        if Y = V.Origin.Y - 1 then
          Mask := $0A06;
      end
      else if Y < V.Origin.Y + V.Size.Y then
        Mask := $0005
      else if Y = V.Origin.Y + V.Size.Y then
        Mask := $0A03;
      if Mask <> 0 then
      begin
        Start := Max2(V.Origin.X, 1);
        Finish := Min2(V.Origin.X + V.Size.X, Size.X - 1);
        if Start < Finish then
        begin
          MaskLow := Mask and $00FF;
          MaskHigh := (Mask and $FF00) shr 8;
          FrameMask[Start - 1] := FrameMask[Start - 1] or MaskLow;
          FrameMask[Finish] := FrameMask[Finish] or (MaskLow xor MaskHigh);
          if MaskLow <> 0 then
            for X := Start to Finish - 1 do
              FrameMask[X] := FrameMask[X] or MaskHigh;
        end;
      end;
    end;
    V := V.Next;
  end;
  for X := 0 to Size.X - 1 do
  begin
    FrameBuf.PutGlyph(X, FrameGlyphs[FrameMask[X]]);
    FrameBuf.PutAttribute(X, Color);
  end;
end;

procedure TFrame.Draw;
var
  B: TDrawBuffer;
  Win: TWindow;
  FrameColor, TitleColor: TAttrPair;
  Base, Room, TitleWidth, X, Y: Integer;
  Caption: ShortString;
  MinSize, MaxSize: TPoint;
begin
  Win := TWindow(Owner);
  if GetState(sfDragging) then
  begin
    FrameColor := GetColor($0505);
    TitleColor := GetColor($0005);
    Base := 0;
  end
  else if GetState(sfActive) then
  begin
    FrameColor := GetColor($0503);
    TitleColor := GetColor($0004);
    Base := 9;
  end
  else
  begin
    FrameColor := GetColor($0101);
    TitleColor := GetColor($0002);
    Base := 0;
  end;

  B := TDrawBuffer.Create(Size.X);
  try
    { top line: icons, number and title }
    Room := Size.X - 10;
    if (Win.Flags and (wfClose or wfZoom)) <> 0 then
      Dec(Room, 6);
    FrameLine(B, 0, Base, FrameColor[0]);
    if (Win.Number <> wnNoNumber) and (Win.Number < 10) then
    begin
      Dec(Room, 4);
      if (Win.Flags and wfZoom) <> 0 then
        X := Size.X - 7
      else
        X := Size.X - 3;
      B.PutChar(X, Ord('0') + Win.Number);
    end;
    Caption := Win.GetTitle(Room);
    if Caption <> '' then
    begin
      TitleWidth := Max2(Min2(TText.Width(Caption), Size.X - 10), 0);
      X := (Size.X - TitleWidth) div 2;
      B.PutChar(X - 1, Ord(' '));
      B.MoveStrS(X, Caption, TitleColor[0], TitleWidth);
      B.PutChar(X + TitleWidth, Ord(' '));
    end;
    if GetState(sfActive) then
    begin
      if (Win.Flags and wfClose) <> 0 then
        B.MoveCStrS(2, CloseIcon, FrameColor);
      if (Win.Flags and wfZoom) <> 0 then
      begin
        Win.SizeLimits(MinSize, MaxSize);
        if (Win.Size = MaxSize) then
          B.MoveCStrS(Size.X - 5, UnZoomIcon, FrameColor)
        else
          B.MoveCStrS(Size.X - 5, ZoomIcon, FrameColor);
      end;
    end;
    WriteLine(0, 0, Size.X, 1, B);

    { sides }
    for Y := 1 to Size.Y - 2 do
    begin
      FrameLine(B, Y, Base + 3, FrameColor[0]);
      WriteLine(0, Y, Size.X, 1, B);
    end;

    { bottom line, with the resize corners }
    FrameLine(B, Size.Y - 1, Base + 6, FrameColor[0]);
    if GetState(sfActive) and ((Win.Flags and wfGrow) <> 0) then
    begin
      B.MoveCStrS(0, DragLeftIcon, FrameColor);
      B.MoveCStrS(Size.X - 2, DragIcon, FrameColor);
    end;
    WriteLine(0, Size.Y - 1, Size.X, 1, B);
  finally
    B.Free;
  end;
end;

function TFrame.GetPalette: TPalette;
begin
  Result := FramePalette;
end;

procedure TFrame.DragWindow(var Event: TEvent; Mode: Byte);
var
  Limits: TRect;
  Min, Max: TPoint;
begin
  Limits := Owner.Owner.GetExtent;
  Owner.SizeLimits(Min, Max);
  Owner.DragView(Event, Owner.DragMode or Mode, Limits, Min, Max);
  ClearEvent(Event);
end;

procedure TFrame.HandleEvent(var Event: TEvent);
var
  Win: TWindow;
  P: TPoint;
  Active: Boolean;

  procedure PostToOwner(Command: Word);
  begin
    Event.What := evCommand;
    Event.Message.Command := Command;
    Event.Message.InfoPtr := Owner;
    PutEvent(Event);
    ClearEvent(Event);
  end;

  function OnCloseIcon: Boolean;
  begin
    Result := (P.Y = 0) and (P.X >= 2) and (P.X <= 4);
  end;

begin
  inherited HandleEvent(Event);
  if Event.What <> evMouseDown then
    Exit;
  Win := TWindow(Owner);
  Active := GetState(sfActive);
  P := MakeLocal(Event.Mouse.Where);
  if P.Y = 0 then
  begin
    if Active and ((Win.Flags and wfClose) <> 0) and OnCloseIcon then
    begin
      { the window is closed only if the button is released over the icon }
      while MouseEvent(Event, evMouse) do
        ;
      P := MakeLocal(Event.Mouse.Where);
      if OnCloseIcon then
        PostToOwner(cmClose);
    end
    else if Active and ((Win.Flags and wfZoom) <> 0) and
      (((P.X >= Size.X - 5) and (P.X <= Size.X - 3)) or
       ((Event.Mouse.EventFlags and meDoubleClick) <> 0)) then
      PostToOwner(cmZoom)
    else if (Win.Flags and wfMove) <> 0 then
      DragWindow(Event, dmDragMove);
  end
  else if Active and (P.Y >= Size.Y - 1) and ((Win.Flags and wfGrow) <> 0) then
  begin
    if P.X >= Size.X - 2 then
      DragWindow(Event, dmDragGrow)
    else if P.X <= 1 then
      DragWindow(Event, dmDragGrowLeft);
  end
  else if (Event.Mouse.Buttons = mbMiddleButton) and ((Win.Flags and wfMove) <> 0) and
    (P.X > 0) and (P.X < Size.X - 1) and (P.Y > 0) and (P.Y < Size.Y - 1) then
    DragWindow(Event, dmDragMove);
end;

procedure TFrame.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if (AState and (sfActive or sfDragging)) <> 0 then
    DrawView;
end;

{ --- TScrollBar -------------------------------------------------------------- }

{ the state of the mouse handling of a bar (static in the original, so a bar
  cannot be handled while another one is: that never happens) }
var
  SbMouse: TPoint;
  SbP, SbS: Integer;
  SbExtent: TRect;

constructor TScrollBar.Create(const Bounds: TRect);
begin
  inherited Create(Bounds);
  Value := 0;
  MinVal := 0;
  MaxVal := 0;
  PgStep := 1;
  ArStep := 1;
  if Size.X = 1 then
  begin
    GrowMode := gfGrowLoX or gfGrowHiX or gfGrowHiY;
    Chars := VChars;
  end
  else
  begin
    GrowMode := gfGrowLoY or gfGrowHiX or gfGrowHiY;
    Chars := HChars;
  end;
  EventMask := EventMask or evMouseWheel;
end;

procedure TScrollBar.Draw;
begin
  DrawPos(GetPos);
end;

procedure TScrollBar.DrawPos(Pos: Integer);
var
  B: TDrawBuffer;
  S: Integer;
begin
  B := TDrawBuffer.Create(GetSize);
  S := GetSize - 1;
  B.MoveChar(0, Chars[0], GetColor(2)[0], 1);
  if MaxVal = MinVal then
    B.MoveChar(1, Chars[4], GetColor(1)[0], S - 1)
  else
  begin
    B.MoveChar(1, Chars[2], GetColor(1)[0], S - 1);
    B.MoveChar(Pos, Chars[3], GetColor(3)[0], 1);
  end;
  B.MoveChar(S, Chars[1], GetColor(2)[0], 1);
  WriteBuf(0, 0, Size.X, Size.Y, B);
  B.Free;
end;

function TScrollBar.GetPalette: TPalette;
begin
  Result := ScrollBarPalette;
end;

function TScrollBar.GetSize: Integer;
begin
  if Size.X = 1 then
    Result := Size.Y
  else
    Result := Size.X;
  if Result < 3 then
    Result := 3;
end;

function TScrollBar.GetPos: Integer;
var
  R: Integer;
begin
  R := MaxVal - MinVal;
  if R = 0 then
    Result := 1
  else
    Result := Integer((((Int64(Value - MinVal) * (GetSize - 3)) + (R shr 1)) div R) + 1);
end;

function TScrollBar.GetPartCode: Integer;
var
  Mark: Integer;
begin
  if not SbExtent.Contains(SbMouse) then
    Exit(-1);
  if Size.X = 1 then
    Mark := SbMouse.Y
  else
    Mark := SbMouse.X;
  if Mark = SbP then
    Exit(sbIndicator);
  if Mark < 1 then
    Result := sbLeftArrow
  else if Mark < SbP then
    Result := sbPageLeft
  else if Mark < SbS then
    Result := sbPageRight
  else
    Result := sbRightArrow;
  { the vertical parts are the horizontal ones + 4 }
  if Size.X = 1 then
    Inc(Result, sbUpArrow);
end;

procedure TScrollBar.HandleEvent(var Event: TEvent);
var
  Part, NewValue, Delta, Pos: Integer;
  Vertical: Boolean;

  procedure Clicked;
  begin
    Message(Owner, evBroadcast, cmScrollBarClicked, Self);
  end;

  { the part a key selects; False for a key the bar does not use. Home/End
    (Ctrl+PgUp/PgDn when vertical) go to the ends and leave sbIndicator. }
  function KeyPart(Key: Word; out APart, AValue: Integer): Boolean;
  begin
    Result := True;
    APart := sbIndicator;
    AValue := Value;
    if Size.Y = 1 then
      case Key of
        kbLeft: APart := sbLeftArrow;
        kbRight: APart := sbRightArrow;
        kbCtrlLeft: APart := sbPageLeft;
        kbCtrlRight: APart := sbPageRight;
        kbCtrlUp: APart := sbPageUp;
        kbCtrlDown: APart := sbPageDown;
        kbHome: AValue := MinVal;
        kbEnd: AValue := MaxVal;
      else
        Result := False;
      end
    else
      case Key of
        kbUp: APart := sbUpArrow;
        kbDown: APart := sbDownArrow;
        kbPgUp: APart := sbPageUp;
        kbPgDn: APart := sbPageDown;
        kbCtrlPgUp: AValue := MinVal;
        kbCtrlPgDn: AValue := MaxVal;
      else
        Result := False;
      end;
  end;

begin
  inherited HandleEvent(Event);
  Vertical := Size.X = 1;
  case Event.What of
    evMouseWheel:
      begin
        Delta := 0;
        if GetState(sfVisible) then
          if Vertical then
          begin
            if Event.Mouse.Wheel = mwUp then Delta := -ArStep
            else if Event.Mouse.Wheel = mwDown then Delta := ArStep;
          end
          else
          begin
            if Event.Mouse.Wheel = mwLeft then Delta := -ArStep
            else if Event.Mouse.Wheel = mwRight then Delta := ArStep;
          end;
        if Delta <> 0 then
        begin
          { lets a list that owns the bar become selected }
          Clicked;
          SetValue(Value + 3 * Delta);
          ClearEvent(Event);
        end;
      end;

    evMouseDown:
      begin
        Clicked;
        SbMouse := MakeLocal(Event.Mouse.Where);
        SbExtent := GetExtent;
        SbExtent.Grow(1, 1);
        SbP := GetPos;
        SbS := GetSize - 1;
        Part := GetPartCode;
        if Part in [sbLeftArrow, sbRightArrow, sbUpArrow, sbDownArrow] then
        begin
          { step while the button is held over the arrow }
          ForceScroll := False;
          repeat
            SbMouse := MakeLocal(Event.Mouse.Where);
            if GetPartCode = Part then
              SetValue(Value + ScrollStep(Part));
            ForceScroll := True;
          until not MouseEvent(Event, evMouseAuto);
          ForceScroll := False;
        end
        else
          { the thumb follows the mouse, between the two arrows }
          repeat
            SbMouse := MakeLocal(Event.Mouse.Where);
            if Vertical then
              Pos := SbMouse.Y
            else
              Pos := SbMouse.X;
            Pos := Min2(Max2(Pos, 1), SbS - 1);
            SbP := Pos;
            if SbS > 2 then
              SetValue(Integer((Int64(Pos - 1) * (MaxVal - MinVal) + ((SbS - 2) shr 1))
                div (SbS - 2)) + MinVal);
            DrawPos(Pos);
          until not MouseEvent(Event, evMouseMove);
        ClearEvent(Event);
      end;

    evKeyDown:
      if GetState(sfVisible) and KeyPart(CtrlToArrow(Event.KeyDown.KeyCode), Part, NewValue) then
      begin
        Clicked;
        if Part <> sbIndicator then
          NewValue := Value + ScrollStep(Part);
        SetValue(NewValue);
        ClearEvent(Event);
      end;
  end;
end;

procedure TScrollBar.ScrollDraw;
begin
  Message(Owner, evBroadcast, cmScrollBarChanged, Self);
end;

function TScrollBar.ScrollStep(Part: Integer): Integer;
var
  St: Integer;
begin
  if (Part and 2) = 0 then
    St := ArStep
  else
    St := PgStep;
  if (Part and 1) = 0 then
    St := -St;
  Step := St;
  Result := St;
end;

procedure TScrollBar.SetParams(AValue, AMin, AMax, APgStep, AArStep: Integer);
var
  OldValue: Integer;
begin
  if AMax < AMin then
    AMax := AMin;
  if AValue < AMin then
    AValue := AMin
  else if AValue > AMax then
    AValue := AMax;
  OldValue := Value;
  if (AValue <> OldValue) or (AMin <> MinVal) or (AMax <> MaxVal) then
  begin
    Value := AValue;
    MinVal := AMin;
    MaxVal := AMax;
    DrawView;
    if AValue <> OldValue then
      ScrollDraw;
  end;
  PgStep := APgStep;
  ArStep := AArStep;
end;

procedure TScrollBar.SetRange(AMin, AMax: Integer);
begin
  SetParams(Value, AMin, AMax, PgStep, ArStep);
end;

procedure TScrollBar.SetStep(APgStep, AArStep: Integer);
begin
  SetParams(Value, MinVal, MaxVal, APgStep, AArStep);
end;

procedure TScrollBar.SetValue(AValue: Integer);
begin
  SetParams(AValue, MinVal, MaxVal, PgStep, ArStep);
end;

{ --- TScroller --------------------------------------------------------------- }

constructor TScroller.Create(const Bounds: TRect; AHScrollBar, AVScrollBar: TScrollBar);
begin
  inherited Create(Bounds);
  DrawLock := 0;
  DrawFlag := False;
  HScrollBar := AHScrollBar;
  VScrollBar := AVScrollBar;
  Delta.X := 0;
  Delta.Y := 0;
  Limit.X := 0;
  Limit.Y := 0;
  Options := Options or ofSelectable;
  EventMask := EventMask or evBroadcast;
end;

destructor TScroller.Destroy;
begin
  HScrollBar := nil;
  VScrollBar := nil;
  inherited Destroy;
end;

procedure TScroller.ChangeBounds(const Bounds: TRect);
begin
  Inc(DrawLock);
  SetBounds(Bounds);
  { the bars get the new page sizes; the view is drawn once, below }
  SetLimit(Limit.X, Limit.Y);
  DrawFlag := False;
  Dec(DrawLock);
  DrawView;
end;

procedure TScroller.CheckDraw;
begin
  if (DrawLock = 0) and DrawFlag then
  begin
    DrawFlag := False;
    DrawView;
  end;
end;

function TScroller.GetPalette: TPalette;
begin
  Result := ScrollerPalette;
end;

procedure TScroller.HandleEvent(var Event: TEvent);
var
  Sender: Pointer;
begin
  inherited HandleEvent(Event);
  Sender := Event.Message.InfoPtr;
  if (Sender <> nil) and (Event.What = evBroadcast) and (Event.Message.Command = cmScrollBarChanged) and
    ((Sender = Pointer(HScrollBar)) or (Sender = Pointer(VScrollBar))) then
    ScrollDraw;
end;

procedure TScroller.ScrollDraw;
var
  NewDelta: TPoint;
begin
  NewDelta.X := 0;
  NewDelta.Y := 0;
  if HScrollBar <> nil then
    NewDelta.X := HScrollBar.Value;
  if VScrollBar <> nil then
    NewDelta.Y := VScrollBar.Value;
  if (NewDelta = Delta) then
    Exit;
  SetCursor(Cursor.X + Delta.X - NewDelta.X, Cursor.Y + Delta.Y - NewDelta.Y);
  Delta := NewDelta;
  if DrawLock = 0 then
    DrawView
  else
    DrawFlag := True;
end;

procedure TScroller.ScrollTo(X, Y: Integer);
begin
  Inc(DrawLock);
  if HScrollBar <> nil then
    HScrollBar.SetValue(X);
  if VScrollBar <> nil then
    VScrollBar.SetValue(Y);
  Dec(DrawLock);
  CheckDraw;
end;

procedure TScroller.SetLimit(X, Y: Integer);

  procedure Fit(Bar: TScrollBar; Total, Visible: Integer);
  begin
    if Bar <> nil then
      Bar.SetParams(Bar.Value, 0, Total - Visible, Visible - 1, Bar.ArStep);
  end;

begin
  Limit := Point(X, Y);
  Inc(DrawLock);
  Fit(HScrollBar, X, Size.X);
  Fit(VScrollBar, Y, Size.Y);
  Dec(DrawLock);
  CheckDraw;
end;

procedure TScroller.ShowSBar(SBar: TScrollBar);
begin
  if SBar <> nil then
  begin
    { both bits are asked for at once: the original calls getState(sfActive | sfSelected) }
    if GetState(sfActive or sfSelected) then
      SBar.Show
    else
      SBar.Hide;
  end;
end;

procedure TScroller.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if (AState and (sfActive or sfSelected)) <> 0 then
  begin
    ShowSBar(HScrollBar);
    ShowSBar(VScrollBar);
  end;
end;

{ --- TWindow ----------------------------------------------------------------- }

constructor TWindow.Create(const Bounds: TRect; const ATitle: ShortString; ANumber: Integer);
begin
  inherited Create(Bounds);
  Flags := wfMove or wfGrow or wfClose or wfZoom;
  ZoomRect := GetBounds;
  Number := ANumber;
  Palette := wpBlueWindow;
  Title := NewStr(ATitle);
  State := State or sfShadow;
  Options := Options or (ofSelectable or ofTopSelect);
  GrowMode := gfGrowAll or gfGrowRel;
  Frame := nil;
  InitFrame;
  if Frame <> nil then
    Insert(Frame);
end;

destructor TWindow.Destroy;
begin
  { the frame is destroyed with the other subviews }
  if Assigned(WindowNumberFreeHook) and (Number > 0) then
    WindowNumberFreeHook(Number);
  Frame := nil;
  inherited Destroy;
  DisposeStr(Title);
  Title := nil;
end;

procedure TWindow.InitFrame;
var
  R: TRect;
begin
  R := GetExtent;
  Frame := TFrame.Create(R);
end;

procedure TWindow.Close;
begin
  if Valid(cmClose) then
  begin
    Frame := nil;   { so the frame is not used after it has been deleted }
    Free;
  end;
end;

function TWindow.GetPalette: TPalette;
begin
  case Palette of
    wpCyanWindow: Result := CyanPalette;
    wpGrayWindow: Result := GrayPalette;
  else
    Result := BluePalette;
  end;
end;

function TWindow.GetTitle(MaxSize: Integer): ShortString;
begin
  if Title <> nil then
    Result := Title^
  else
    Result := '';
end;

type
  TWheelPick = record
    Vert, Horz: TScrollBar;
  end;
  PWheelPick = ^TWheelPick;

procedure PickScrollBar(P: TView; S: Pointer);
begin
  if P is TScrollBar then
    with PWheelPick(S)^ do
      if P.Size.X = 1 then
      begin
        if Vert = nil then
          Vert := TScrollBar(P);
      end
      else if Horz = nil then
        Horz := TScrollBar(P);
end;

procedure TWindow.HandleEvent(var Event: TEvent);
var
  Limits: TRect;
  MinSize, MaxSize: TPoint;
  Pick: TWheelPick;
  Bar: TScrollBar;
  Steps: Integer;
  Cancel: TEvent;

  { a command with no target, or with this window as its target }
  function Addressed: Boolean;
  begin
    Result := (Event.Message.InfoPtr = Pointer(Self)) or (Event.Message.InfoPtr = nil);
  end;

begin
  inherited HandleEvent(Event);
  case Event.What of
    evKeyDown:
      if (Event.KeyDown.KeyCode = kbTab) or (Event.KeyDown.KeyCode = kbShiftTab) then
      begin
        FocusNext(Event.KeyDown.KeyCode = kbShiftTab);
        ClearEvent(Event);
      end;

    evBroadcast:
      if (Event.Message.Command = cmSelectWindowNum) and (Event.Message.InfoInt = Number) and
        ((Options and ofSelectable) <> 0) then
      begin
        Select;
        ClearEvent(Event);
      end;

    evCommand:
      if (Event.Message.Command = cmZoom) and ((Flags and wfZoom) <> 0) and Addressed then
      begin
        Zoom;
        ClearEvent(Event);
      end
      else if (Event.Message.Command = cmClose) and ((Flags and wfClose) <> 0) and Addressed then
      begin
        ClearEvent(Event);
        if not GetState(sfModal) then
          Close
        else
        begin
          { a modal window ends its modal loop instead }
          TvEvents.ClearEvent(Cancel);
          Cancel.What := evCommand;
          Cancel.Message.Command := cmCancel;
          PutEvent(Cancel);
        end;
      end
      else if (Event.Message.Command = cmResize) and ((Flags and (wfMove or wfGrow)) <> 0) then
      begin
        Limits := Owner.GetExtent;
        SizeLimits(MinSize, MaxSize);
        DragView(Event, DragMode or (Flags and (wfMove or wfGrow)), Limits, MinSize, MaxSize);
        ClearEvent(Event);
      end;

    evMouseWheel:
      { no view under the pointer took the wheel: the scroll bars of the
        window move, even when hidden (the window is not active) }
      if ContainsMouse(Event) then
      begin
        Pick.Vert := nil;
        Pick.Horz := nil;
        ForEach(@PickScrollBar, @Pick);
        Bar := nil;
        Steps := 0;
        case Event.Mouse.Wheel of
          mwUp:    begin Bar := Pick.Vert; Steps := -3; end;
          mwDown:  begin Bar := Pick.Vert; Steps := 3; end;
          mwLeft:  begin Bar := Pick.Horz; Steps := -3; end;
          mwRight: begin Bar := Pick.Horz; Steps := 3; end;
        end;
        if Bar <> nil then
        begin
          Bar.SetValue(Bar.Value + Steps * Bar.ArStep);
          ClearEvent(Event);
        end;
      end;
  end;
end;

procedure TWindow.SetState(AState: Word; Enable: Boolean);
var
  WindowCommands: TCommandSet;
begin
  inherited SetState(AState, Enable);
  if (AState and sfSelected) <> 0 then
  begin
    SetState(sfActive, Enable);
    if Frame <> nil then
      Frame.SetState(sfActive, Enable);
    WindowCommands := Default(TCommandSet);
    WindowCommands := WindowCommands + cmNext;
    WindowCommands := WindowCommands + cmPrev;
    if (Flags and (wfGrow or wfMove)) <> 0 then
      WindowCommands := WindowCommands + cmResize;
    if (Flags and wfClose) <> 0 then
      WindowCommands := WindowCommands + cmClose;
    if (Flags and wfZoom) <> 0 then
      WindowCommands := WindowCommands + cmZoom;
    if Enable then
      EnableCommands(WindowCommands)
    else
      DisableCommands(WindowCommands);
  end;
end;

function TWindow.StandardScrollBar(AOptions: Word): TScrollBar;
var
  R: TRect;
begin
  { inside the right or the bottom side of the frame }
  R := GetExtent;
  if (AOptions and sbVertical) = 0 then
  begin
    R.A.Y := R.B.Y - 1;
    Inc(R.A.X, 2);
    Dec(R.B.X, 2);
  end
  else
  begin
    R.A.X := R.B.X - 1;
    Inc(R.A.Y);
    Dec(R.B.Y);
  end;
  Result := TScrollBar.Create(R);
  Insert(Result);
  if (AOptions and sbHandleKeyboard) <> 0 then
    Result.Options := Result.Options or ofPostProcess;
end;

procedure TWindow.SizeLimits(out Min, Max: TPoint);
begin
  inherited SizeLimits(Min, Max);
  Min := MinWinSize;
end;

procedure TWindow.Zoom;
var
  MinSize, MaxSize: TPoint;
  R: TRect;
begin
  SizeLimits(MinSize, MaxSize);
  if not (Size = MaxSize) then
  begin
    ZoomRect := GetBounds;
    R := TRect.Create(0, 0, MaxSize.X, MaxSize.Y);
    Locate(R);
  end
  else
    Locate(ZoomRect);
end;

{ --- Streams ------------------------------------------------------------------ }

class function TFrame.Build: TStreamable;
begin
  Result := TFrame.Create(streamableInit);
end;

constructor TFrame.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TFrame.StreamableName: ShortString;
begin
  Result := 'TFrame';
end;

procedure TScrollBar.Write(Os: opstream);
begin
  inherited Write(Os);
  Os.WriteBytes(Value, SizeOf(Integer));
  Os.WriteBytes(MinVal, SizeOf(Integer));
  Os.WriteBytes(MaxVal, SizeOf(Integer));
  Os.WriteBytes(PgStep, SizeOf(Integer));
  Os.WriteBytes(ArStep, SizeOf(Integer));
  Os.WriteBytes(Chars, SizeOf(Chars));
end;

function TScrollBar.Read(Ip: ipstream): Pointer;
begin
  inherited Read(Ip);
  Ip.ReadBytes(Value, SizeOf(Integer));
  Ip.ReadBytes(MinVal, SizeOf(Integer));
  Ip.ReadBytes(MaxVal, SizeOf(Integer));
  Ip.ReadBytes(PgStep, SizeOf(Integer));
  Ip.ReadBytes(ArStep, SizeOf(Integer));
  Ip.ReadBytes(Chars, SizeOf(TScrollChars));
  Result := Self;
end;

class function TScrollBar.Build: TStreamable;
begin
  Result := TScrollBar.Create(streamableInit);
end;

constructor TScrollBar.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TScrollBar.StreamableName: ShortString;
begin
  Result := 'TScrollBar';
end;

procedure TScroller.Write(Os: opstream);
begin
  inherited Write(Os);
  Os.WritePointer(HScrollBar);
  Os.WritePointer(VScrollBar);
  Os.WriteBytes(Delta, SizeOf(TPoint));
  Os.WriteBytes(Limit, SizeOf(TPoint));
end;

function TScroller.Read(Ip: ipstream): Pointer;
begin
  inherited Read(Ip);
  HScrollBar := TScrollBar(Ip.ReadPointer);
  VScrollBar := TScrollBar(Ip.ReadPointer);
  Ip.ReadBytes(Delta, SizeOf(TPoint));
  Ip.ReadBytes(Limit, SizeOf(TPoint));
  DrawLock := 0;
  DrawFlag := False;
  Result := Self;
end;

class function TScroller.Build: TStreamable;
begin
  Result := TScroller.Create(streamableInit);
end;

constructor TScroller.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TScroller.StreamableName: ShortString;
begin
  Result := 'TScroller';
end;

procedure TWindow.Write(Os: opstream);
var
  N: SmallInt;
begin
  inherited Write(Os);
  Os.WriteByte(Flags);
  Os.WriteBytes(ZoomRect, SizeOf(TRect));
  N := Number;
  Os.WriteBytes(N, SizeOf(SmallInt));
  N := Palette;
  Os.WriteBytes(N, SizeOf(SmallInt));
  Os.WritePointer(Frame);
  Os.WriteString(Title);
end;

function TWindow.Read(Ip: ipstream): Pointer;
var
  N: SmallInt;
begin
  inherited Read(Ip);
  Flags := Ip.ReadByte;
  Ip.ReadBytes(ZoomRect, SizeOf(TRect));
  Ip.ReadBytes(N, SizeOf(SmallInt));
  Number := N;
  Ip.ReadBytes(N, SizeOf(SmallInt));
  Palette := N;
  Frame := TFrame(Ip.ReadPointer);
  Title := Ip.ReadString;
  Result := Self;
end;

class function TWindow.Build: TStreamable;
begin
  Result := TWindow.Create(streamableInit);
end;

constructor TWindow.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TWindow.StreamableName: ShortString;
begin
  Result := 'TWindow';
end;

var
  FrameI: Integer;

initialization
  RFrame := TStreamableClass.Create('TFrame', @TFrame.Build);
  RScrollBar := TStreamableClass.Create('TScrollBar', @TScrollBar.Build);
  RScroller := TStreamableClass.Create('TScroller', @TScroller.Build);
  RWindow := TStreamableClass.Create('TWindow', @TWindow.Build);
  for FrameI := 0 to High(FramePassive) do
  begin
    FrameInit[FrameI] := FramePassive[FrameI];
    if FramePassive[FrameI] <> 0 then
      FrameInit[FrameI + 9] := FramePassive[FrameI] or DoubleLine
    else
      FrameInit[FrameI + 9] := 0;
  end;
  FramePalette := TPalette.Create(#1#1#2#2#3, 5);
  ScrollBarPalette := TPalette.Create(#4#5#5, 3);
  ScrollerPalette := TPalette.Create(#6#7, 2);
  BluePalette := TPalette.Create(#8#9#10#11#12#13#14#15, 8);
  CyanPalette := TPalette.Create(#16#17#18#19#20#21#22#23, 8);
  GrayPalette := TPalette.Create(#24#25#26#27#28#29#30#31, 8);
end.
