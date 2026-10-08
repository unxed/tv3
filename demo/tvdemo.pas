program tvdemo;
{ Demo of the Turbo Vision port: windows with scrollers, menus, a status line.
  DOS: with /auto it types a few keys itself, writes the screen to SCR.DAT and quits (CI);
  /437 selects the code page 437 instead of 866. Unix: runs on the terminal (TvUnix); Alt-X quits.
  /clock: a clock at the right of the menu bar (TvGadgets). }
{$I ../src/tvdefs.inc}
uses SysUtils, TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvDrawBuf, TvScreen, TvViews, TvWindow,
  TvMenus, TvActions, TvSys, TvApp, TvMsgBox, TvAscii, TvGadgets{$IFDEF GO32V2}, TvDos{$ELSE}, TvUnix{$ENDIF};

const
  cmNewWin = 100;
  cmAsciiTable = 101;
  Lines: array[0..17] of string[200] = (
    'Turbo Vision for DOS on Free Pascal',
    '',
    'This program is built by FPC for go32v2 and runs on the',
    'library translated from magiblot/tvision.',
    '',
    'Text is kept in UTF-8 and reaches the screen through the',
    'code page of the video font (CP866 or CP437 now).',
    '',
    'Hotkeys:',
    '  F4         new window',
    '  F5         zoom      F6  next window',
    '  F7         tile      F8  cascade',
    '  Alt-F3     close     Alt-X  exit',
    '',
    'Menu: Alt-F, Alt-W or F10; the mouse works too.',
    '',
    'The scroll bar and the keys Up, Down, PgUp, PgDn work in',
    'every window.');

type
  TLinesView = class;
  TLinesView = class(TScroller)
    constructor Create(const Bounds: TRect; AH, AV: TScrollBar);
    procedure Draw; override;
  end;

  { the window of the ASCII table; the program opens one at a time }
  TDemoChart = class(TAsciiChart)
    destructor Destroy; override;
  end;

  TDemoApp = class(TApplication)
    Auto: Boolean;
    Quiet, Count: Integer;
    Clock: TClockView;
    constructor Create(AAuto: Boolean);
    procedure InitMenuBar; override;
    procedure InitStatusLine; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure Idle; override;
    procedure NewWindow;
    procedure ShowAsciiTable;
    procedure Picked(Sender: TAsciiTable; Code: LongInt);
    procedure AddClock;
  end;

constructor TLinesView.Create(const Bounds: TRect; AH, AV: TScrollBar);
begin
  inherited Create(Bounds, AH, AV);
  GrowMode := gfGrowHiX or gfGrowHiY;
  SetLimit(80, Length(Lines));
end;

procedure TLinesView.Draw;
var
  Buf: TDrawBuffer;
  Color: TColorAttr;
  Row, N: Integer;
begin
  Color := GetColor(1).Lo;
  Buf := TDrawBuffer.Create(Size.X);
  try
    for Row := 0 to Size.Y - 1 do
    begin
      Buf.MoveChar(0, Ord(' '), Color, Size.X);
      N := Delta.Y + Row;
      if (N >= Low(Lines)) and (N <= High(Lines)) then
        Buf.MoveStrS(0, Lines[N], Color, Size.X, Delta.X);
      WriteLineD(0, Row, Size.X, 1, Buf);
    end;
  finally
    Buf.Free;
  end;
end;

constructor TDemoApp.Create(AAuto: Boolean);
begin
  inherited Create;      { Create zeroes the instance: the fields are set after it }
  Auto := AAuto;
  Quiet := 0;
  Count := 0;
end;

procedure TDemoApp.InitMenuBar;
var
  R: TRect;
begin
  R := GetExtent;
  R.B.Y := R.A.Y + 1;
  MenuBar := TMenuBar.Create(R, NewMenu(
    NewSubMenu('~F~ile', hcNoContext, NewMenu(
      NewActionItem('file.new',
      NewActionItem('file.close',
      NewLine(
      NewActionItem('file.exit', nil))))),
    NewSubMenu('~W~indow', hcNoContext, NewMenu(
      NewActionItem('window.tile',
      NewActionItem('window.cascade',
      NewActionItem('window.next',
      NewActionItem('window.zoom', nil))))),
    NewSubMenu('~T~ools', hcNoContext, NewMenu(
      NewActionItem('tools.ascii', nil)), nil)))));
end;

procedure TDemoApp.InitStatusLine;
var
  R: TRect;
begin
  R := GetExtent;
  R.A.Y := R.B.Y - 1;
  StatusLine := TStatusLine.Create(R,
    NewStatusDef(0, $FFFF,
      NewActionStatusKey('~F4~ New', 'file.new',
      NewActionStatusKey('~F5~ Zoom', 'window.zoom',
      NewActionStatusKey('~F6~ Next', 'window.next',
      NewActionStatusKey('~Alt-F3~ Close', 'file.close',
      NewActionStatusKey('~Alt-X~ Exit', 'file.exit',
      NewStatusKey('', kbF10, cmMenu,
      NewActionStatusKey('', 'window.tile',
      NewActionStatusKey('', 'window.cascade', nil)))))))),
    nil));
end;

procedure TDemoApp.NewWindow;
var
  W: TWindow;
  R: TRect;
  H, V: TScrollBar;
  S: TLinesView;
begin
  Inc(Count);
  R.Assign(2 + Count * 3, 1 + Count, 44 + Count * 3, 14 + Count);
  W := TWindow.Create(R, 'Window', Count);
  W.Options := W.Options or ofTileable;
  H := W.StandardScrollBar(sbHorizontal or sbHandleKeyboard);
  V := W.StandardScrollBar(sbVertical or sbHandleKeyboard);
  R := W.GetExtent;
  R.Grow(-1, -1);
  S := TLinesView.Create(R, H, V);
  W.Insert(S);
  InsertWindow(W);
end;

var
  Chart: TDemoChart = nil;

destructor TDemoChart.Destroy;
begin
  Chart := nil;
  inherited Destroy;
end;

procedure TDemoApp.ShowAsciiTable;
begin
  if Chart <> nil then
  begin
    Chart.Select;
    Exit;
  end;
  Chart := TDemoChart.Create('ASCII Table', {$IFDEF GO32V2}False{$ELSE}True{$ENDIF});
  Chart.Table.OnPick := @Picked;
  Chart.MoveTo(40, 3);
  InsertWindow(Chart);
end;

procedure TDemoApp.Picked(Sender: TAsciiTable; Code: LongInt);
begin
  MessageBox('Picked: ' + Sender.CellText(Code) + ' (' + IntToStr(Code) + ')', mfInformation or mfOKButton);
end;

procedure TDemoApp.AddClock;
var
  R: TRect;
begin
  { at the right end of the menu row; the clock of TvGadgets fits its width to the text, one blank cell at the right }
  R.Assign(Size.X - 10, 0, Size.X, 1);
  Clock := TClockView.Create(R);
  Clock.Margin := 1;
  Clock.GrowMode := gfGrowLoX or gfGrowHiX;
  Insert(Clock);
  Clock.Update;
end;

procedure TDemoApp.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evCommand) and (Event.Command = cmNewWin) then
  begin
    NewWindow;
    ClearEvent(Event);
  end;
  if (Event.What = evCommand) and (Event.Command = cmAsciiTable) then
  begin
    ShowAsciiTable;
    ClearEvent(Event);
  end;
end;

procedure TDemoApp.Idle;
var
  Ev: TEvent;
begin
  inherited Idle;
  if Clock <> nil then
    Clock.Update;
{$IFDEF GO32V2}
  if Auto and DosKeyBufferEmpty then
  begin
    Inc(Quiet);
    if Quiet = 4 then
    begin
      DosDumpScreen('SCR.DAT');
      ClearEvent(Ev);
      Ev.What := evCommand;
      Ev.Command := cmQuit;
      PutEvent(Ev);
    end;
  end;
{$ENDIF}
end;

function HasParam(const P: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if ParamStr(I) = P then
      Result := True;
end;

{ the commands of the program are declared once: the menu, the status line and the keys read this table (TvActions) }
procedure DeclareActions;
begin
  RegisterAction('file.new', '~N~ew window', cmNewWin, kbF4);
  RegisterAction('file.close', '~C~lose', cmClose, kbAltF3);
  RegisterAction('file.exit', 'E~x~it', cmQuit, kbAltX);
  RegisterAction('window.tile', '~T~ile', cmTile, kbF7);
  RegisterAction('window.cascade', 'C~a~scade', cmCascade, kbF8);
  RegisterAction('window.next', '~N~ext', cmNext, kbF6);
  RegisterAction('window.zoom', '~Z~oom', cmZoom, kbF5);
  RegisterAction('tools.ascii', '~A~SCII table', cmAsciiTable, kbNoKey);
  { the key of the window switcher (the list while Ctrl is held, where the terminal tells the releases) is an action as well }
  RegisterAction('window.switch', '~S~witch', cmNext, kbCtrlTab);
  UseActionsForSwitcher;
end;

var
  App: TDemoApp;
  Auto: Boolean;
begin
  DeclareActions;
  Auto := HasParam('/auto');
{$IFDEF GO32V2}
  { the text is Russian: CP866 unless /437 (the code page of the video font is the
    setting of the program: DOS says 437 until it is changed with CHCP) }
  if HasParam('/437') then
    DosInit(437)
  else
    DosInit(866);
{$ELSE}
  if not UnixInit then
  begin
    Writeln('tvdemo needs a terminal');
    Halt(1);
  end;
{$ENDIF}
  App := TDemoApp.Create(Auto);
  if HasParam('/clock') then
    App.AddClock;
{$IFDEF GO32V2}
  if Auto then
  begin
    { F4 x3: three windows; F7: tile; Alt-F: the File menu stays open }
    DosStuffKey(kbF4); DosStuffKey(kbF4); DosStuffKey(kbF4);
    DosStuffKey(kbF7);
    DosStuffKey(kbAltF);
  end
  else
{$ENDIF}
    App.NewWindow;
  App.Run;
  App.Free;
{$IFDEF GO32V2}
  DosDone;
{$ELSE}
  UnixDone;
{$ENDIF}
end.
