program t_gadgets;
{$I ../src/tvdefs.inc}
uses SysUtils, TvGeom, TvColors, TvCell, TvEvents, TvDrawBuf, TvScreen, TvViews, TvGadgets;
{$I testlib.inc}

const
  W = 40;
  H = 3;

type
  TCounted = class(TClockView)
    Draws: Integer;
    procedure Draw; override;
  end;

  TClicks = class
    Count: Integer;
    procedure Clicked(Sender: TClockView; var Event: TEvent);
  end;

var
  FakeNow: TDateTime;
  FakeHeap: Int64;

procedure TCounted.Draw;
begin
  Inc(Draws);
  inherited Draw;
end;

procedure TClicks.Clicked(Sender: TClockView; var Event: TEvent);
begin
  Inc(Count);
  Sender.ClearEvent(Event);
end;

function GetFakeNow: TDateTime;
begin
  Result := FakeNow;
end;

function GetFakeHeap: Int64;
begin
  Result := FakeHeap;
end;

function At(H, M, S, Ms: Word): TDateTime;
begin
  Result := EncodeTime(H, M, S, Ms);
end;

function Row(Y, X0, X1: Integer): ShortString;
var
  X: Integer;
  T: ShortString;
begin
  Result := '';
  for X := X0 to X1 do
  begin
    T := ((TScreen.ScreenBuffer + (Y * TScreen.ScreenWidth + X))^.Character).GetText;
    if (T = '') or (T = #0) then
      T := ' ';
    Result := Result + T;
  end;
end;

function R(A, B, C, D: Integer): TRect;
begin
  Result := TRect.Create(A, B, C, D);
end;

function CountryFormat(H, M, S: Word; Seconds, Separator, Hour12: Boolean): AnsiString;
begin
  Result := Format('%d.%.2d', [H, M]);
end;

var
  Desk: TGroup;
  Clock: TCounted;
  LeftClock: TClockView;
  Heap: THeapView;
  Clicks: TClicks;
  E: TEvent;
  N: Integer;

begin
  ScreenCreate(W, H);
  Desk := TGroup.Create(R(0, 0, W, H));
  Desk.Options := 0;
  Desk.Buffer := TScreen.ScreenBuffer;
  Desk.State := sfVisible or sfSelected or sfFocused or sfModal or sfExposed;
  ClockNow := @GetFakeNow;

  { the default format }
  Check(ClockFormatDefault(9, 5, 7, True, True, False) = '09:05:07', '24 hours with seconds');
  Check(ClockFormatDefault(9, 5, 7, False, True, False) = '09:05', '24 hours without seconds');
  Check(ClockFormatDefault(9, 5, 7, False, False, False) = '09 05', 'a blank separator');
  Check(ClockFormatDefault(0, 5, 0, False, True, True) = '12:05am', '12 hours: midnight');
  Check(ClockFormatDefault(13, 5, 0, False, True, True) = ' 1:05pm', '12 hours: afternoon');
  Check(ClockFormatDefault(12, 0, 9, True, True, True) = '12:00:09pm', '12 hours: noon with seconds');

  { a clock at the right edge: the width follows the text, the right edge stays }
  FakeNow := At(10, 20, 30, 100);
  Clock := TCounted.Create(R(30, 0, 40, 1));
  Clock.Margin := 1;
  Desk.Insert(Clock);
  Clock.Update;
  Check(Clock.TimeStr = ' 10:20:30 ', 'the text with seconds and margins: ' + Clock.TimeStr);
  Check((Clock.Size.X = 10) and (Clock.Origin.X = 30), 'the width is that of the text');
  Check(Row(0, 30, 39) = ' 10:20:30 ', 'the clock is drawn');
  N := Clock.Draws;
  FakeNow := At(10, 20, 30, 900);
  Clock.Update;
  Check(Clock.Draws = N, 'the same second: not drawn again');
  FakeNow := At(10, 20, 31, 0);
  Clock.Update;
  Check((Clock.Draws = N + 1) and (Row(0, 30, 39) = ' 10:20:31 '), 'the next second: drawn again');
  Check(Clock.MsToNextChange = 1000, 'MsToNextChange with seconds');

  Clock.ShowSeconds := False;
  Clock.BlinkSeparator := True;
  FakeNow := At(10, 20, 31, 100);
  Clock.Update;
  Check((Clock.TimeStr = ' 10:20 ') and (Clock.Size.X = 7) and (Clock.Origin.X + Clock.Size.X = 40),
    'without seconds: narrower, the right edge stays');
  FakeNow := At(10, 20, 31, 600);
  Clock.Update;
  Check(Clock.TimeStr = ' 10 20 ', 'the separator blinks in the second half of a second');
  Check(Clock.MsToNextChange = 400, 'MsToNextChange while blinking');
  Clock.BlinkSeparator := False;
  Clock.Update;
  Check(Clock.TimeStr = ' 10:20 ', 'no blinking: the separator stays');
  Check(Clock.MsToNextChange = 28400, 'MsToNextChange without seconds: the next minute');

  Clock.FormatHook := @CountryFormat;
  Clock.Update;
  Check(Clock.TimeStr = ' 10.20 ', 'the format hook');
  Clock.FormatHook := nil;

  { a clock at the left keeps its left edge }
  LeftClock := TClockView.Create(R(2, 1, 12, 1 + 1));
  Desk.Insert(LeftClock);
  LeftClock.ShowSeconds := False;
  LeftClock.Update;
  Check((LeftClock.Origin.X = 2) and (LeftClock.Size.X = 5), 'a clock in the left half keeps its left edge');
  LeftClock.RightAlign := True;
  LeftClock.Update;
  Check(LeftClock.Origin.X + LeftClock.Size.X = W, 'RightAlign moves it to the right edge of the owner');

  { the click hook }
  Clicks := TClicks.Create;
  Clock.OnClick := @Clicks.Clicked;
  FillChar(E, SizeOf(E), 0);
  E.What := evMouseDown;
  E.Mouse.Where.X := Clock.Origin.X + 1;
  Clock.HandleEvent(E);
  Check((Clicks.Count = 1) and (E.What = evNothing), 'a click calls OnClick');
  Clicks.Free;

  { the palette }
  Check(Length(Clock.GetPalette) = 2, 'the palette of a gadget has one entry');
  Clock.PaletteStr := '';
  Check(Clock.GetPalette = nil, 'an empty PaletteStr: no palette');

  { the heap view }
  Heap := THeapView.Create(R(30, 2, 40, 3));
  Desk.Insert(Heap);
  Heap.ValueHook := @GetFakeHeap;
  FakeHeap := 123456;
  Heap.Update;
  Check(Row(2, 30, 39) = '    123456', 'the heap in use, at the right edge: ' + Row(2, 30, 39));
  Heap.Kb := True;
  Heap.Update;
  Check(Row(2, 30, 39) = '      121K', 'in kilobytes: ' + Row(2, 30, 39));
  Heap.ValueHook := nil;
  Heap.Kb := False;
  Check(StrToInt64Def(Heap.HeapText, -1) > 0, 'the default value: the heap in use');
  Heap.Free;

  LeftClock.Free;
  Clock.Free;
  ClockNow := nil;
  Desk.Free;
  ScreenDestroy;
  Finish;
end.
