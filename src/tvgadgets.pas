{ TvGadgets: small views that show a value of the system: a clock (TClockView) and the memory in use (THeapView).
  Their Update is called by the program (TProgram.Idle, a timer); it draws again only when the text changes.

  MIT (see LICENSE).

  The clock: ShowSeconds; BlinkSeparator (without seconds the ':' is blank in the second half of every second);
  Hour12 (1..12 with am/pm); Margin (spaces on both sides); FormatHook (the text of a time, e.g. in the format of
  the country); AutoSize (the width follows the text: a clock in the right half of its owner keeps its right edge,
  else its left edge); RightAlign (the clock stays at the right edge of its owner); OnClick (a mouse click).
  ClockNow gives the time (a test sets its own). MsToNextChange tells a program with a timer when the text changes.
  PaletteStr is the palette of the view ('' = none: the colors of the owner). }
unit TvGadgets;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvGeom, TvColors, TvEvents, TvDrawBuf, TvViews;

type
  TClockView = class;

  { the text of a time; Separator = False: the separator between the hours and the minutes is blank }
  TClockFormat = function(H, M, S: Word; Seconds, Separator, Hour12: Boolean): AnsiString;
  TClockClick = procedure(Sender: TClockView; var Event: TEvent) of object;
  TClockNowFunc = function: TDateTime;
  THeapValueFunc = function: Int64;

  { Palette: 1 = the text. }
  TClockView = class(TView)
    ShowSeconds: Boolean;
    BlinkSeparator: Boolean;
    Hour12: Boolean;
    AutoSize: Boolean;
    RightAlign: Boolean;
    Margin: Integer;
    FormatHook: TClockFormat;
    OnClick: TClockClick;
    PaletteStr: ShortString;
    { the text that is shown }
    TimeStr: AnsiString;
    constructor Create(const Bounds: TRect);
    function GetPalette: TPalette; override;
    { the text for the time of ClockNow (with the margins) }
    function ClockText: AnsiString; virtual;
    procedure Update; override;
    procedure Draw; override;
    procedure HandleEvent(var Event: TEvent); override;
    { milliseconds until the text of the time changes }
    function MsToNextChange: Integer;
    { the width of the view becomes W, the edge that stays is chosen as the description of the unit says }
    procedure FitWidth(W: Integer);
  end;

  { Palette: 1 = the text. The value (ValueHook, else the memory of the heap in use) is drawn at the right edge, in
    kilobytes with a K when Kb is set. }
  THeapView = class(TView)
    Kb: Boolean;
    ValueHook: THeapValueFunc;
    PaletteStr: ShortString;
    HeapStr: AnsiString;
    constructor Create(const Bounds: TRect);
    constructor CreateKb(const Bounds: TRect);
    function GetPalette: TPalette; override;
    function HeapText: AnsiString; virtual;
    procedure Update; override;
    procedure Draw; override;
  end;

function ClockFormatDefault(H, M, S: Word; Seconds, Separator, Hour12: Boolean): AnsiString;
function HeapInUse: Int64;

var
  ClockNow: TClockNowFunc = nil;   { nil: SysUtils.Now }
  GadgetPalette: ShortString = #2;  { the PaletteStr of new views: the normal text of the menu bar of TProgram }

implementation

uses
  TvText;

function NowTime: TDateTime;
begin
  if Assigned(ClockNow) then
    Result := ClockNow()
  else
    Result := Now;
end;

function Two(N: Word): AnsiString;
begin
  Result := IntToStr(N);
  if Length(Result) < 2 then
    Result := '0' + Result;
end;

function ClockFormatDefault(H, M, S: Word; Seconds, Separator, Hour12: Boolean): AnsiString;
var
  Sep, Suffix: AnsiString;
  HH: Word;
begin
  if Separator then
    Sep := ':'
  else
    Sep := ' ';
  Suffix := '';
  HH := H;
  if Hour12 then
  begin
    if H < 12 then
      Suffix := 'am'
    else
      Suffix := 'pm';
    HH := H mod 12;
    if HH = 0 then
      HH := 12;
    Result := IntToStr(HH);
    if HH < 10 then
      Result := ' ' + Result;
  end
  else
    Result := Two(HH);
  Result := Result + Sep + Two(M);
  if Seconds then
    Result := Result + ':' + Two(S);
  Result := Result + Suffix;
end;

function HeapInUse: Int64;
begin
  Result := GetFPCHeapStatus.CurrHeapUsed;
end;

procedure DrawText(V: TView; const S: AnsiString; Right: Boolean);
var
  B: TDrawBuffer;
  C: TColorAttr;
  W: Integer;
begin
  C := V.GetColor(1)[0];
  B := TDrawBuffer.Create(V.Size.X);
  try
    B.MoveChar(0, Ord(' '), C, V.Size.X);
    if S <> '' then
    begin
      W := 0;
      if Right then
      begin
        W := V.Size.X - TText.Width(@S[1], Length(S));
        if W < 0 then
          W := 0;
      end;
      B.MoveStr(W, @S[1], Length(S), C, V.Size.X - W);
    end;
    V.WriteLine(0, 0, V.Size.X, 1, B);
  finally
    B.Free;
  end;
end;

{ --- TClockView --- }

constructor TClockView.Create(const Bounds: TRect);
begin
  inherited Create(Bounds);
  ShowSeconds := True;
  AutoSize := True;
  PaletteStr := GadgetPalette;
  EventMask := EventMask or evMouseDown;
end;

function TClockView.GetPalette: TPalette;
begin
  if PaletteStr = '' then
    Result := Default(TPalette)
  else
    Result := TPalette.Create(PChar(@PaletteStr[1]), Length(PaletteStr));
end;

function TClockView.ClockText: AnsiString;
var
  H, M, S, Ms: Word;
  Sep: Boolean;
  Pad: AnsiString;
begin
  DecodeTime(NowTime, H, M, S, Ms);
  Sep := not BlinkSeparator or ShowSeconds or (Ms < 500);
  if Assigned(FormatHook) then
    Result := FormatHook(H, M, S, ShowSeconds, Sep, Hour12)
  else
    Result := ClockFormatDefault(H, M, S, ShowSeconds, Sep, Hour12);
  if Margin > 0 then
  begin
    Pad := StringOfChar(' ', Margin);
    Result := Pad + Result + Pad;
  end;
end;

function TClockView.MsToNextChange: Integer;
var
  H, M, S, Ms: Word;
begin
  DecodeTime(NowTime, H, M, S, Ms);
  if BlinkSeparator and not ShowSeconds then
    Result := 500 - Ms mod 500
  else if ShowSeconds then
    Result := 1000 - Ms
  else
    Result := (60 - S) * 1000 - Ms;
end;

procedure TClockView.FitWidth(W: Integer);
var
  R: TRect;
begin
  R := GetBounds;
  if RightAlign and (Owner <> nil) then
  begin
    R.B.X := Owner.Size.X;
    R.A.X := R.B.X - W;
  end
  else if (Owner <> nil) and (Origin.X + Size.X div 2 > Owner.Size.X div 2) then
    R.A.X := R.B.X - W
  else
    R.B.X := R.A.X + W;
  if (R.A.X = Origin.X) and (R.B.X = Origin.X + Size.X) then
    Exit;
  if Owner <> nil then
    Locate(R)
  else
    SetBounds(R);
end;

procedure TClockView.Update;
var
  T: AnsiString;
begin
  T := ClockText;
  if T = TimeStr then
  begin
    if RightAlign and (Owner <> nil) and (Origin.X + Size.X <> Owner.Size.X) then
      FitWidth(Size.X);
    Exit;
  end;
  TimeStr := T;
  if AutoSize then
    FitWidth(TText.Width(PByte(PAnsiChar(T)), Length(T)))
  else if RightAlign then
    FitWidth(Size.X);
  DrawView;
end;

procedure TClockView.Draw;
begin
  DrawText(Self, TimeStr, False);
end;

procedure TClockView.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evMouseDown) and Assigned(OnClick) then
    OnClick(Self, Event);
end;

{ --- THeapView --- }

constructor THeapView.Create(const Bounds: TRect);
begin
  inherited Create(Bounds);
  PaletteStr := GadgetPalette;
end;

constructor THeapView.CreateKb(const Bounds: TRect);
begin
  Create(Bounds);
  Kb := True;
end;

function THeapView.GetPalette: TPalette;
begin
  if PaletteStr = '' then
    Result := Default(TPalette)
  else
    Result := TPalette.Create(PChar(@PaletteStr[1]), Length(PaletteStr));
end;

function THeapView.HeapText: AnsiString;
var
  V: Int64;
begin
  if Assigned(ValueHook) then
    V := ValueHook()
  else
    V := HeapInUse;
  if Kb then
    Result := IntToStr((V + 1023) div 1024) + 'K'
  else
    Result := IntToStr(V);
end;

procedure THeapView.Update;
var
  T: AnsiString;
begin
  T := HeapText;
  if T = HeapStr then
    Exit;
  HeapStr := T;
  DrawView;
end;

procedure THeapView.Draw;
begin
  if HeapStr = '' then
    HeapStr := HeapText;
  DrawText(Self, HeapStr, True);
end;

end.
