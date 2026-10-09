program t_ascii;
{$I ../src/tvdefs.inc}
uses SysUtils, TvCodePg, TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvDrawBuf, TvScreen, TvObjs, TvViews,
  TvWindow, TvAscii;
{$I testlib.inc}
{$I strmlib.inc}

const
  W = 40;
  H = 14;

type
  { the top view: hands the queued events to the mouse loop of the table }
  TTop = class(TGroup)
    Queue: array[0..7] of TEvent;
    QCount, QPos: Integer;
    procedure GetEvent(var Event: TEvent); override;
  end;

  TCatcher = class
    Picks: Integer;
    Last: LongInt;
    procedure Picked(Sender: TAsciiTable; Code: LongInt);
  end;

  { the window counts the commands of the picks that reach it }
  TCountChart = class(TAsciiChart)
    Commands: Integer;
    LastInfo: LongInt;
    procedure HandleEvent(var Event: TEvent); override;
  end;

procedure TTop.GetEvent(var Event: TEvent);
begin
  if QPos < QCount then
  begin
    Event := Queue[QPos];
    Inc(QPos);
  end
  else
  begin
    FillChar(Event, SizeOf(Event), 0);
    Event.What := evMouseUp;
  end;
end;

procedure TCatcher.Picked(Sender: TAsciiTable; Code: LongInt);
begin
  Inc(Picks);
  Last := Code;
end;

procedure TCountChart.HandleEvent(var Event: TEvent);
begin
  if (Event.What = evCommand) and (Event.Message.Command = AsciiCommandBase + acPicked) then
  begin
    Inc(Commands);
    LastInfo := LongInt(PtrInt(Event.Message.InfoPtr));
    ClearEvent(Event);
  end;
  inherited HandleEvent(Event);
end;

function Cell(X, Y: Integer): PScreenCell;
begin
  Result := TScreen.ScreenBuffer + (Y * TScreen.ScreenWidth + X);
end;

function CellText(X, Y: Integer): ShortString;
var
  Bytes: array[0..7] of Byte;
  C: Byte;
begin
  Result := (Cell(X, Y)^.Character).GetText;
  if Result = #0 then
    Exit(' ');
  if Length(Result) = 1 then
  begin
    C := Byte(Result[1]);
    if (C >= $80) or (C < $20) then
    begin
      SetLength(Result, CpToUtf8(C, @Bytes[0]));
      Move(Bytes[0], Result[1], Length(Result));
    end;
  end;
end;

function Row(Y, X0, X1: Integer): ShortString;
var
  X: Integer;
begin
  Result := '';
  for X := X0 to X1 do
    Result := Result + CellText(X, Y);
end;

function R(A, B, C, D: Integer): TRect;
begin
  Result := TRect.Create(A, B, C, D);
end;

procedure Key(V: TView; Code: Word);
var
  E: TEvent;
begin
  FillChar(E, SizeOf(E), 0);
  E.What := evKeyDown;
  E.KeyDown.KeyCode := Code;
  V.HandleEvent(E);
end;

procedure TypeText(V: TView; const S: ShortString);
var
  E: TEvent;
begin
  FillChar(E, SizeOf(E), 0);
  E.What := evKeyDown;
  if Length(S) = 1 then
    E.KeyDown.CharScan.CharCode := Ord(S[1]);
  Move(S[1], E.KeyDown.Text[0], Length(S));
  E.KeyDown.TextLength := Length(S);
  V.HandleEvent(E);
end;

procedure Click(V: TView; X, Y: Integer; Double: Boolean);
var
  E: TEvent;
begin
  FillChar(E, SizeOf(E), 0);
  E.What := evMouseDown;
  E.Mouse.Buttons := mbLeftButton;
  E.Mouse.Where.X := X;
  E.Mouse.Where.Y := Y;
  if Double then
    E.Mouse.EventFlags := meDoubleClick;
  V.HandleEvent(E);
end;

var
  Desk: TTop;
  Chart, Chart2: TCountChart;
  Loaded, Plain: TAsciiChart;
  Cat: TCatcher;
  Data: LongInt;
  SM: TTestStream;
  Ox, Oy: Integer;

begin
  ScreenCreate(W, H);
  Desk := TTop.Create(R(0, 0, W, H));
  Desk.Options := 0;
  Desk.Buffer := TScreen.ScreenBuffer;
  Desk.State := sfVisible or sfSelected or sfFocused or sfModal or sfExposed;
  Cat := TCatcher.Create;

  { --- the code page mode --- }
  Chart := TCountChart.Create('ASCII', False);
  Chart.MoveTo(1, 0);
  Desk.Insert(Chart);
  Ox := Chart.Origin.X + 1;
  Oy := Chart.Origin.Y + 1;
  Check((Chart.Size.X = 34) and (Chart.Size.Y = 12), 'the window is 34 x 12');
  Check((Chart.Table.Size.X = 32) and (Chart.Table.Size.Y = 8), 'the table is 32 x 8');
  Check(Chart.Table.GetState(sfFocused), 'the table has the focus');
  Check(Row(Oy + 1, Ox, Ox + 9) = ' !"#$%&''()', 'row 1: the codes 32..41');
  Check(Row(Oy + 2, Ox, Ox + 3) = '@ABC', 'row 2: the codes 64..');
  Check(Chart.Table.Code = 0, 'the cursor is at the code 0');
  Check(Pos('Dec:   0', Row(Oy + 9, Ox, Ox + 31)) > 0, 'the report shows the code 0: ' + Row(Oy + 9, Ox, Ox + 31));

  Key(Chart, kbRight);
  Key(Chart, kbDown);
  Check(Chart.Table.Code = 33, 'Right, Down: 33');
  Check(Chart.Report.Code = 33, 'the report follows the cursor');
  Check(TrimRight(Row(Oy + 9, Ox, Ox + 31)) = ' Char: !  Dec:  33  Hex: 21', 'the report: the character, decimal, hex: ' +
    Row(Oy + 9, Ox, Ox + 31));
  Key(Chart, kbEnd);
  Check(Chart.Table.Code = 63, 'End: the end of the row');
  Key(Chart, kbHome);
  Check(Chart.Table.Code = 32, 'Home: the start of the row');
  Key(Chart, kbPgDn);
  Check(Chart.Table.Code = 224, 'PgDn: the bottom of the column');
  Key(Chart, kbPgUp);
  Check(Chart.Table.Code = 0, 'PgUp: the top of the column');
  Key(Chart, kbCtrlEnd);
  Check(Chart.Table.Code = 255, 'Ctrl+End: the last code');
  Key(Chart, kbRight);
  Key(Chart, kbDown);
  Check(Chart.Table.Code = 255, 'the cursor stays inside the table');
  Key(Chart, kbCtrlHome);
  Key(Chart, kbCtrlRight);
  Check(Chart.Table.Code = 5, 'Ctrl+Right: 5 columns');
  Key(Chart, kbCtrlPgDn);
  Check(Chart.Table.Code = 5, 'Ctrl+PgDn does nothing in the code page mode');

  { the picks: Enter, a typed character, a double click }
  Chart.Table.OnPick := @Cat.Picked;
  Chart.Table.SetCode(65);
  Key(Chart, kbEnter);
  Check((Cat.Picks = 1) and (Cat.Last = 65), 'Enter picks the code (OnPick)');
  Check((Chart.Commands = 1) and (Chart.LastInfo = 65), '... and sends the command of the pick to the window');
  TypeText(Chart, 'z');
  Check((Cat.Picks = 2) and (Cat.Last = Ord('z')) and (Chart.Table.Code = Ord('z')), 'a typed character is picked');
  Chart.Table.TypePicks := False;
  TypeText(Chart, 'q');
  Check(Cat.Picks = 2, 'TypePicks = False: a typed character is not');
  Chart.Table.TypePicks := True;
  Click(Chart.Table, Ox + 3, Oy + 1, False);
  Check((Chart.Table.Code = 35) and (Cat.Picks = 2), 'a click moves the cursor');
  Click(Chart.Table, Ox + 4, Oy + 2, True);
  Check((Chart.Table.Code = 68) and (Cat.Picks = 3) and (Cat.Last = 68), 'a double click picks the code under it');

  { data }
  Check(Chart.Table.DataSize = SizeOf(LongInt), 'the data is a LongInt');
  Data := 200;
  Chart.Table.SetData(Data);
  Data := 0;
  Chart.Table.GetData(Data);
  Check((Data = 200) and (Chart.Report.Code = 200), 'SetData and GetData: the code');
  Check(Chart.Table.Cursor.Y = 6, 'the cursor is on the row of the code');

  { the hook of the text }
  Check(AsciiCodePageText(65) = 'A', 'AsciiCodePageText');
  Check((AsciiUnicodeText($E9) = #$C3#$A9) and (AsciiUnicodeText($85) = ' ') and (AsciiUnicodeText($4E00) = ' ') and
    (AsciiUnicodeText(1) = #1), 'AsciiUnicodeText: UTF-8, controls, wide characters');

  { --- streams --- }
  Plain := TAsciiChart.Create('Stored', False);
  Plain.Table.SetCode(200);
  SM := TTestStream.Create;
  SM.Put(Plain);
  SM.Rewind;
  Loaded := TAsciiChart(Pointer(SM.Get));
  Check(Loaded <> nil, 'the window is written to a stream and read from it');
  if Loaded <> nil then
  begin
    Check((Loaded.Table <> nil) and (Loaded.Report <> nil), 'its table and report are found');
    if Loaded.Table <> nil then
      Check(Loaded.Table.Code = 200, 'the loaded table has the code');
    if Loaded.Report <> nil then
      Check(Loaded.Report.Code = 200, 'the loaded report has the code');
    Loaded.Free;
  end;
  SM.Free;
  Plain.Free;
  Chart.Free;

  { --- the Unicode mode --- }
  Chart2 := TCountChart.Create('Unicode', True);
  Desk.Insert(Chart2);
  Ox := Chart2.Origin.X + 1;
  Oy := Chart2.Origin.Y + 1;
  Chart2.Table.SetCode($E9);
  Check(Row(Oy + 7, Ox, Ox + 9) = 'àáâãäåæçèé', 'the Unicode mode: row 7 is U+00E0..');
  Check(TrimRight(Row(Oy + 9, Ox, Ox + 31)) = ' Char: é  Dec: 233  U+00E9', 'the report shows U+: ' + Row(Oy + 9, Ox, Ox + 31));
  Key(Chart2, kbCtrlPgDn);
  Check((Chart2.Table.Block = 1) and (Chart2.Table.Code = $1E9), 'Ctrl+PgDn: the next block');
  Check(CellText(Ox, Oy) = 'Ā', 'the next block starts with U+0100: ' + CellText(Ox, Oy));
  Key(Chart2, kbCtrlPgUp);
  Key(Chart2, kbCtrlPgUp);
  Check(Chart2.Table.Block = 0, 'Ctrl+PgUp stops at the first block');
  TypeText(Chart2, 'ж');
  Check((Chart2.Table.Block = 4) and (Chart2.Table.Code = $436) and (Chart2.LastInfo = $436),
    'a typed character goes to its block and is picked');
  Chart2.Free;

  { --- the palette and the text hooks --- }
  Check(Length(TPalette.Create(PChar(@AsciiPalette[1]), Length(AsciiPalette)).Data) = 3, 'the palette of the views has two entries');

  Cat.Free;
  Desk.Free;
  ScreenDestroy;
  Finish;
end.
