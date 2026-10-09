program t_hwinfo;
{ THardwareInfo and TClipboard over the hooks of the backend. }
{$I ../src/tvdefs.inc}
{$H+}
uses TvGeom, TvCell, TvEvents, TvKeys, TvSys, TvScreen, TvClip;
{$I testlib.inc}

var
  FakeNow: Int64;
  WrX, WrY, WrCount: Integer;
  WrCells: PScreenCell;
  PosX, PosY, SizeSet: Integer;
  ModeSet: Integer;
  SysText: AnsiString;
  SysOk: Boolean;
  Accepted: AnsiString;

function FakeClock: Int64;
begin
  Result := FakeNow;
end;

procedure FakeWrite(X, Y: Integer; Cells: PScreenCell; Count: Integer);
begin
  WrX := X; WrY := Y; WrCells := Cells; WrCount := Count;
end;

procedure FakePos(X, Y: Integer);
begin
  PosX := X; PosY := Y;
end;

procedure FakeSize(Size: Integer);
begin
  SizeSet := Size;
end;

procedure FakeMode(Mode: Word);
begin
  ModeSet := Mode;
end;

function FakeSet(const Text: AnsiString): Boolean;
begin
  if SysOk then
    SysText := Text;
  Result := SysOk;
end;

function FakeGet(out Text: AnsiString): Boolean;
begin
  Text := SysText;
  Result := SysOk;
end;

procedure Accept(const Text: AnsiString);
begin
  Accepted := Text;
end;

function PasteText: AnsiString;
var
  E: TEvent;
begin
  Result := '';
  repeat
    TEventQueue.GetKeyEvent(E);
    if (E.What = evKeyDown) and ((E.KeyDown.ControlKeyState and kbPaste) <> 0) then
      Result := Result + EventText(E);
  until E.What = evNothing;
end;

var
  Cells: array[0..3] of TScreenCell;
begin
  { the clock }
  Check(THardwareInfo.GetTickCountMs > 0, 'without a backend: the clock of the system');
  GetClockMs := @FakeClock;
  FakeNow := 1100;
  Check(THardwareInfo.GetTickCountMs = 1100, 'the clock of the backend in ms');
  Check(THardwareInfo.GetTickCount = 20, 'and in ticks of 55 ms');
  GetClockMs := nil;

  { the caret }
  OnCaretPosition := @FakePos;
  OnCaretSize := @FakeSize;
  THardwareInfo.SetCaretPosition(7, 3);
  Check((PosX = 7) and (PosY = 3) and (CaretX = 7) and (CaretY = 3), 'the caret position goes to the backend');
  THardwareInfo.SetCaretSize(100);
  Check((SizeSet = 100) and (THardwareInfo.GetCaretSize = 100) and THardwareInfo.IsCaretVisible, 'a block caret');
  THardwareInfo.SetCaretSize(0);
  Check((SizeSet = 0) and not THardwareInfo.IsCaretVisible, 'a hidden caret');
  OnCaretPosition := nil;
  OnCaretSize := nil;

  { the screen }
  ScreenCreate(40, 12);
  Check((THardwareInfo.GetScreenCols = 40) and (THardwareInfo.GetScreenRows = 12), 'the size of the screen');
  Check(THardwareInfo.GetScreenMode = TDisplay.smCO80, 'the mode of the screen');
  OnScreenWrite := @FakeWrite;
  THardwareInfo.ScreenWrite(2, 5, @Cells[0], 4);
  Check((WrX = 2) and (WrY = 5) and (WrCells = @Cells[0]) and (WrCount = 4), 'a written run goes to the backend');
  OnScreenWrite := nil;
  THardwareInfo.ScreenWrite(0, 0, @Cells[0], 1);
  OnSetVideoMode := @FakeMode;
  THardwareInfo.SetScreenMode(TDisplay.smUpdate);
  Check(ModeSet = TDisplay.smUpdate, 'the mode goes to the backend');
  OnSetVideoMode := nil;
  ScreenDestroy;

  { the clipboard of the backend }
  Check(not THardwareInfo.SetClipboardText('x'), 'no system clipboard: False');
  Accepted := '-';
  Check(not THardwareInfo.RequestClipboardText(@Accept) and (Accepted = '-'), 'and nothing to request');
  OnClipboardSet := @FakeSet;
  OnClipboardGet := @FakeGet;
  SysOk := True;
  Check(THardwareInfo.SetClipboardText('Привет') and (SysText = 'Привет'), 'the text goes to the system clipboard');
  Check(THardwareInfo.RequestClipboardText(@Accept) and (Accepted = 'Привет'), 'and comes back');

  { TClipboard }
  TClipboard.SetText('one'#13#10'two');
  Check((SysText = 'one'#13#10'two') and ClipboardIsSystem, 'SetText reaches the system clipboard');
  TClipboard.RequestText;
  Check(PasteText = 'one'#10'two', 'RequestText gives the text as paste events');
  SysOk := False;
  TClipboard.SetText('local');
  Check(not ClipboardIsSystem, 'a failed system clipboard');
  TClipboard.RequestText;
  Check(PasteText = 'local', 'the text of the program then');
  OnClipboardSet := nil;
  OnClipboardGet := nil;
  TClipboard.SetText('');
  TClipboard.RequestText;
  Check(PasteText = '', 'an empty clipboard: no events');
  Finish;
end.
