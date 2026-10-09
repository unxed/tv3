program t_status;
{$I ../src/tvdefs.inc}
uses TvCodePg, TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvDrawBuf, TvScreen, TvViews,
  TvUtil, TvObjs, TvMenus;
{$I testlib.inc}

function CommandsOf(const A: array of Integer): TCommandSet;
var
  I: Integer;
begin
  Result := Default(TCommandSet);
  for I := 0 to High(A) do
    Result := Result + A[I];
end;

const
  W = 40;
  H = 12;
  Y = H - 1;

type
  { the top view: a queue of events for the mouse loop of the status line, and the
    event put back }
  TTop = class(TGroup)
    Queue: array[0..7] of TEvent;
    QCount, QPos: Integer;
    LastPut: TEvent;
    procedure GetEvent(var Event: TEvent); override;
    procedure PutEvent(var Event: TEvent); override;
  end;

  { a status line with a hint }
  THintLine = class;
  THintLine = class(TStatusLine)
    function Hint(AHelpCtx: Word): ShortString; override;
  end;

  { a view that has a help context }
  THelpView = class;
  THelpView = class(TView)
    constructor Create(const Bounds: TRect; ACtx: Word);
  end;

var
  Desk: TTop;

procedure TTop.GetEvent(var Event: TEvent);
begin
  if QPos < QCount then
  begin
    Event := Queue[QPos];
    Inc(QPos);
  end
  else
  begin
    ClearEvent(Event);
    Event.What := evMouseUp;
  end;
end;

procedure TTop.PutEvent(var Event: TEvent);
begin
  LastPut := Event;
end;

function THintLine.Hint(AHelpCtx: Word): ShortString;
begin
  if AHelpCtx = 0 then
    Result := 'Help text'
  else
    Result := '';
end;

constructor THelpView.Create(const Bounds: TRect; ACtx: Word);
begin
  inherited Create(Bounds);
  HelpCtx := ACtx;
  Options := Options or ofSelectable;
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

function Row(Yy, X0, X1: Integer): ShortString;
var
  X: Integer;
begin
  Result := '';
  for X := X0 to X1 do
    Result := Result + CellText(X, Yy);
end;

function AttrAt(X, Yy: Integer): Byte;
begin
  Result := Byte(Cell(X, Yy)^.Attribute);
end;

function R(A, B, C, D: Integer): TRect;
begin
  Result := TRect.Create(A, B, C, D);
end;

function Defs: TStatusDef;
begin
  Defs := TStatusDef.Create(0, 99, TStatusItem.Create('~F1~ Help', kbF1, cmHelp, TStatusItem.Create('~Alt-X~ Exit', kbAltX, cmQuit, nil)), TStatusDef.Create(100, 199, TStatusItem.Create('~F2~ Save', kbF2, cmSave, nil), nil));
end;

var
  Line: THintLine;
  Plain: TStatusLine;
  OpDefs: TStatusDef;
  HV: THelpView;
  Ev: TEvent;
  Used0: PtrUInt;
  Mem: TMemoryStream;
  Os: opstream;
  Ip: ipstream;
  Back: TStatusLine;

begin
  ScreenCreate(W, H);
  Desk := TTop.Create(R(0, 0, W, H));
  Desk.Options := 0;
  Desk.Buffer := TScreen.ScreenBuffer;
  Desk.State := sfVisible or sfSelected or sfFocused or sfModal or sfExposed;
  TView.EnableCommands(CommandsOf([cmHelp, cmQuit, cmSave]));
  Used0 := GetFPCHeapStatus.CurrHeapUsed;

  Line := THintLine.Create(R(0, Y, W, H), Defs);
  Desk.Insert(Line);
  Check(Line.Items <> nil, 'the items for the help context 0');
  Check(Line.Items.Text^ = '~F1~ Help', 'the first item');
  Check((Line.Options and ofPreProcess) <> 0, 'the status line sees keys first');
  Check(Line.GrowMode = (gfGrowLoY or gfGrowHiX or gfGrowHiY), 'grow mode');
  Check(Row(Y, 0, 20) = ' F1 Help  Alt-X Exit ', 'the items are drawn');
  Check(AttrAt(0, Y) = $02, 'normal color');
  Check(AttrAt(1, Y) = $04, 'hot key color');
  Check(AttrAt(4, Y) = $02, 'text after the hot key');
  Check(Row(Y, 21, 31) = '│ Help text', 'the hint follows the items after a separator');
  Check(AttrAt(25, Y) = $02, 'the hint has the normal color');

  { keys }
  MakeKeyEvent(Ev, kbF1, 0);
  Line.HandleEvent(Ev);
  Check((Ev.What = evCommand) and (Ev.Message.Command = cmHelp), 'a key of an item becomes its command');
  MakeKeyEvent(Ev, kbAltX, kbAltShift);
  Line.HandleEvent(Ev);
  Check((Ev.What = evCommand) and (Ev.Message.Command = cmQuit), 'Alt-X becomes cmQuit');
  MakeKeyEvent(Ev, kbF2, 0);
  Line.HandleEvent(Ev);
  Check(Ev.What = evKeyDown, 'a key of another help context is not handled');
  { disabled commands }
  TView.DisableCommand(cmQuit);
  ClearEvent(Ev);
  Ev.What := evBroadcast;
  Ev.Message.Command := cmCommandSetChanged;
  Line.HandleEvent(Ev);
  Check(AttrAt(10, Y) = $03, 'a disabled item has the disabled color');
  Check(AttrAt(1, Y) = $04, 'the other items stay normal');
  MakeKeyEvent(Ev, kbAltX, kbAltShift);
  Line.HandleEvent(Ev);
  Check(Ev.What = evKeyDown, 'the key of a disabled item is not handled');
  TView.EnableCommand(cmQuit);

  { mouse: press and release on an item }
  Desk.QCount := 1; Desk.QPos := 0;
  ClearEvent(Desk.Queue[0]);
  Desk.Queue[0].What := evMouseUp;
  Desk.Queue[0].Mouse.Where.X := 3; Desk.Queue[0].Mouse.Where.Y := Y;
  Desk.LastPut.What := evNothing;
  ClearEvent(Ev);
  Ev.What := evMouseDown; Ev.Mouse.Where.X := 3; Ev.Mouse.Where.Y := Y; Ev.Mouse.Buttons := mbLeftButton;
  Line.HandleEvent(Ev);
  Check((Desk.LastPut.What = evCommand) and (Desk.LastPut.Message.Command = cmHelp), 'a click on an item puts its command');
  Check(Ev.What = evNothing, 'the click is handled');
  { press on an item, move away, release: nothing }
  Desk.QCount := 2; Desk.QPos := 0;
  ClearEvent(Desk.Queue[0]);
  Desk.Queue[0].What := evMouseMove;
  Desk.Queue[0].Mouse.Where.X := 30; Desk.Queue[0].Mouse.Where.Y := Y;
  ClearEvent(Desk.Queue[1]);
  Desk.Queue[1].What := evMouseUp;
  Desk.Queue[1].Mouse.Where.X := 30; Desk.Queue[1].Mouse.Where.Y := Y;
  Desk.LastPut.What := evNothing;
  ClearEvent(Ev);
  Ev.What := evMouseDown; Ev.Mouse.Where.X := 3; Ev.Mouse.Where.Y := Y; Ev.Mouse.Buttons := mbLeftButton;
  Line.HandleEvent(Ev);
  Check(Desk.LastPut.What = evNothing, 'released away from the item: no command');
  { release on another item chooses that one }
  Desk.QCount := 2; Desk.QPos := 0;
  ClearEvent(Desk.Queue[0]);
  Desk.Queue[0].What := evMouseMove;
  Desk.Queue[0].Mouse.Where.X := 12; Desk.Queue[0].Mouse.Where.Y := Y;
  ClearEvent(Desk.Queue[1]);
  Desk.Queue[1].What := evMouseUp;
  Desk.Queue[1].Mouse.Where.X := 12; Desk.Queue[1].Mouse.Where.Y := Y;
  ClearEvent(Ev);
  Ev.What := evMouseDown; Ev.Mouse.Where.X := 3; Ev.Mouse.Where.Y := Y; Ev.Mouse.Buttons := mbLeftButton;
  Line.HandleEvent(Ev);
  Check((Desk.LastPut.What = evCommand) and (Desk.LastPut.Message.Command = cmQuit),
    'dragging to another item chooses that one');

  { the help context of the top view selects the items }
  HV := THelpView.Create(R(0, 0, 10, 5), 150);
  Desk.Insert(HV);
  Line.Update;
  Check(Line.HelpCtx = 150, 'Update takes the help context of the top view');
  Check(Line.Items.Text^ = '~F2~ Save', 'and its items');
  Check(Row(Y, 0, 10) = ' F2 Save   ', 'the other items are drawn');
  Check(Row(Y, 21, 23) = '   ', 'and no hint');
  MakeKeyEvent(Ev, kbF2, 0);
  Line.HandleEvent(Ev);
  Check((Ev.What = evCommand) and (Ev.Message.Command = cmSave), 'keys of the new items');
  HV.Free;
  Line.Update;
  Check((Line.HelpCtx = 0) and (Line.Items.Text^ = '~F1~ Help'), 'the items return with the help context');

  Line.Free;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'the status line frees its definitions');

  { the base class has no hint }
  Plain := TStatusLine.Create(R(0, Y, W, H), Defs);
  Desk.Insert(Plain);
  Check(Row(Y, 21, 23) = '   ', 'the base status line has no hint');
  HV := THelpView.Create(R(0, 0, 10, 5), 1000);
  Desk.Insert(HV);
  Plain.Update;
  Check((Plain.HelpCtx = 1000) and (Plain.Items = nil),
    'a help context outside all definitions: no items');
  Check(Row(Y, 0, 10) = '           ', 'and nothing is drawn but blanks');
  HV.Free;
  Plain.Free;

  { the operators + of tvision: a definition gets its items, definitions are chained }
  OpDefs := TStatusDef.Create(0, 999) +
      TStatusItem.Create('~F3~ Open', kbF3, cmOpen) +
      TStatusItem.Create('~Alt-X~ Exit', kbAltX, cmQuit) +
    TStatusDef.Create(1000, $FFFF) +
      TStatusItem.Create('~F1~ Help', kbF1, cmHelp);
  Check((OpDefs.Items.Command = cmOpen) and (OpDefs.Items.Next.Command = cmQuit) and (OpDefs.Items.Next.Next = nil),
    'TStatusDef + TStatusItem adds the items to the last definition');
  Check((OpDefs.Next.Min = 1000) and (OpDefs.Next.Items.Command = cmHelp), 'TStatusDef + TStatusDef chains the definitions');
  Plain := TStatusLine.Create(R(0, Y, W, Y + 1), OpDefs);
  Plain.Free;

  { the streams: a key is read back with its modifiers, as it is written }
  Plain := TStatusLine.Create(R(0, Y, W, Y + 1),
    TStatusDef.Create(0, $FFFF, TStatusItem.Create('~Shift-F3~ Open', TKey.Create(kbF3, kbShift), cmOpen,
      TStatusItem.Create('~F1~ Help', kbF1, cmHelp, nil)), nil));
  Mem := TMemoryStream.Create(0, 256);
  Os := opstream.Create(Mem);
  Os.WritePointer(Plain);
  Os.Free;
  Mem.Seek(0);
  Ip := ipstream.Create(Mem);
  Back := TStatusLine(Ip.ReadPointer);
  Ip.Free;
  Mem.Free;
  Check((Back <> nil) and (Back.Defs <> nil) and (Back.Defs.Items <> nil), 'a status line is read from a stream');
  if (Back <> nil) and (Back.Defs <> nil) and (Back.Defs.Items <> nil) then
  begin
    Check(Back.Defs.Items.KeyCode = Plain.Defs.Items.KeyCode, 'the key of an item comes back with its modifiers');
    Check((Back.Defs.Items.Command = cmOpen) and (Back.Defs.Items.Next <> nil) and
      (Back.Defs.Items.Next.Command = cmHelp) and (Back.Defs.Items.Next.KeyCode = TKey(kbF1)),
      'the command of an item and the next item follow the key');
  end;
  Back.Free;
  Plain.Free;
  Desk.Free;
  Finish;
end.
