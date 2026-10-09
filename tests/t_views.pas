program t_views;
{$I ../src/tvdefs.inc}
uses TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvDrawBuf, TvScreen, TvObjs, TvViews;
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

type
  { a view that fills itself with one character, in one color }
  TFill = class;
  TFill = class(TView)
    Ch: Byte;
    Col: Byte;
    Peer: TView;
    constructor Create(const Bounds: TRect; ACh: Char; ACol: Byte);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    destructor Destroy; override;
    procedure Draw; override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
  end;

var
  Desk: TGroup;
  DoneCount: Integer = 0;

constructor TFill.Create(const Bounds: TRect; ACh: Char; ACol: Byte);
begin
  inherited Create(Bounds);
  Peer := nil;
  Ch := Ord(ACh);
  Col := ACol;
end;

constructor TFill.Load(S: TStream);
begin
  inherited Load(S);
  S.Read(Ch, 1);
  S.Read(Col, 1);
  GetPeerViewPtr(S, Peer);
end;

procedure TFill.Store(S: TStream);
begin
  inherited Store(S);
  S.Write(Ch, 1);
  S.Write(Col, 1);
  PutPeerViewPtr(S, Peer);
end;

function BuildFill(S: TStream): TStreamable;
begin
  Result := TStreamable(Pointer(TFill.Load(S)));
end;

procedure StoreFill(P: TStreamable; S: TStream);
begin
  TFill(Pointer(P)).Store(S);
end;

var
  RFill: TStreamRec;

destructor TFill.Destroy;
begin
  Inc(DoneCount);
  inherited Destroy;
end;

procedure TFill.Draw;
var
  B: TDrawBuffer;
  Pair: TAttrPair;
begin
  B := TDrawBuffer.Create(W);
  Pair := GetColor(1);
  B.MoveChar(0, Ch, Pair.Lo, Size.X);
  WriteLine(0, 0, Size.X, Size.Y, B);
  B.Free;
end;

function TFill.GetPalette: TPalette;
begin
  Result := MakePalette(Chr(Col));
end;

procedure TFill.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evCommand) and (Event.Message.Command = cmOK) then
    ClearEvent(Event);
end;

type
  { a view that draws with the 16-bit interface of Borland Pascal }
  TLeg = class;
  TLeg = class(TView)
    procedure Draw; override;
  end;

procedure TLeg.Draw;
var
  Line: array[0..3] of Word;
begin
  Line[0] := $1E41;       { 'A', yellow on blue }
  Line[1] := $1F42;       { 'B', white on blue }
  Line[2] := $4743;       { 'C' }
  Line[3] := $4744;       { 'D' }
  WriteLineW(0, 0, 2, Size.Y, Line);
  WriteBufW(2, 0, 2, 1, Line[2]);
end;

function Cell(X, Y: Integer): PScreenCell;
begin
  Result := TScreen.ScreenBuffer + (Y * TScreen.ScreenWidth + X);
end;

{ the characters of a row between two columns; '_' for a cell nothing drew }
function Row(Y, X0, X1: Integer): ShortString;
var
  X: Integer;
  T: ShortString;
begin
  Result := '';
  for X := X0 to X1 do
  begin
    T := ScText(Cell(X, Y)^.Character);
    if T = #0 then
      Result := Result + '_'
    else
      Result := Result + T[1];
  end;
end;

function AttrAt(X, Y: Integer): Byte;
begin
  Result := AttrAsBIOSByte(Cell(X, Y)^.Attribute);
end;

function Shadowed(X, Y: Integer): Boolean;
begin
  Result := (AttrStyle(Cell(X, Y)^.Attribute) and slWindowShadow) <> 0;
end;

function R(A, B, C, D: Integer): TRect;
begin
  Result := TRect.Create(A, B, C, D);
end;

var
  Bg, A, B, E, F, C: TFill;
  Rc: TRect;
  Pt, Pt2: TPoint;
  Ev: TEvent;
  Cmds: TCommandSet;
  Min, Max: TPoint;
  G: TGroup;
  V1, V2, V3: TFill;
  Leg: TLeg;
  GS, GL: TGroup;
  SA, SB, SC: TFill;
  M: TMemoryStream;
  Count: Integer;

procedure CountViews(P: TView; Args: Pointer);
begin
  Inc(PInteger(Args)^);
end;

function IsV2(P: TView; Args: Pointer): Boolean;
begin
  Result := P = TView(Args);
end;

begin
  ScreenCreate(W, H);
  { the top group, set up as the application does }
  Desk := TGroup.Create(R(0, 0, W, H));
  Desk.Options := 0;
  Desk.Buffer := TScreen.ScreenBuffer;
  Desk.State := sfVisible or sfSelected or sfFocused or sfModal or sfExposed;

  { background and two overlapping views }
  Bg := TFill.Create(R(0, 0, W, H), '.', $07);
  Desk.Insert(Bg);
  Check(Row(0, 0, 5) = '......', 'inserting the background draws it');
  Check(Row(H - 1, W - 3, W - 1) = '...', 'background covers the whole screen');
  Check(AttrAt(0, 0) = $07, 'background attribute through the palette');

  A := TFill.Create(R(2, 1, 12, 4), 'A', $1F);
  Desk.Insert(A);
  Check(Row(1, 0, 13) = '..AAAAAAAAAA..', 'a view is drawn where it is');
  Check(Row(3, 0, 13) = '..AAAAAAAAAA..', 'a view is drawn on all its rows');
  Check(Row(4, 0, 13) = '..............', 'not below its bottom edge');
  Check(AttrAt(2, 1) = $1F, 'attribute of a view');

  B := TFill.Create(R(7, 2, 17, 6), 'B', $2E);
  Desk.Insert(B);
  Check(Row(2, 0, 18) = '..AAAAABBBBBBBBBB..', 'the newer view is in front');
  Check(Row(5, 5, 18) = '..BBBBBBBBBB..', 'rows below the older view');
  Check(Desk.First = TView(B), 'First is the top view');
  Check(Desk.Last = TView(Bg), 'Last is the bottom view');

  { z-order }
  A.MakeFirst;
  Check(Row(2, 0, 18) = '..AAAAAAAAAABBBBB..', 'MakeFirst brings a view to the front');
  Check(Desk.First = TView(A), 'it is now the first view');
  B.MakeFirst;
  Check(Row(2, 0, 18) = '..AAAAABBBBBBBBBB..', 'and back');

  { hiding and showing redraw what is below }
  B.Hide;
  Check(Row(2, 0, 18) = '..AAAAAAAAAA.......', 'Hide uncovers what was below');
  Check(Row(5, 5, 18) = '..............', 'the background shows where the hidden view was');
  B.Show;
  Check(Row(2, 0, 18) = '..AAAAABBBBBBBBBB..', 'Show draws the view again');

  { moving }
  B.MoveTo(20, 6);
  Check(Row(2, 0, 18) = '..AAAAAAAAAA.......', 'moved away: the old place is redrawn');
  Check(Row(6, 18, 31) = '..BBBBBBBBBB..', 'drawn at the new place');
  Check((B.Origin.X = 20) and (B.Origin.Y = 6) and (B.Size.X = 10), 'origin and size after MoveTo');
  B.GrowTo(4, 2);
  Check(Row(6, 18, 27) = '..BBBB....', 'GrowTo makes it smaller');
  Rc := B.GetBounds;
  Check((Rc.A.X = 20) and (Rc.B.X = 24) and (Rc.B.Y = 8), 'GetBounds after GrowTo');
  Rc := TRect.Create(7, 2, 17, 6);
  B.Locate(Rc);
  Check(Row(2, 0, 18) = '..AAAAABBBBBBBBBB..', 'Locate moves and resizes');
  Rc := TRect.Create(0, 0, 999, 999);
  B.Locate(Rc);
  Check((B.Size.X = W) and (B.Size.Y = H), 'Locate limits the size to the owner');
  Rc := TRect.Create(7, 2, 17, 6);
  B.Locate(Rc);

  { visibility }
  E := TFill.Create(R(20, 8, 24, 10), 'E', $4F);
  Desk.Insert(E);
  Check(E.Exposed, 'a view with nothing over it is exposed');
  F := TFill.Create(R(19, 7, 25, 11), 'F', $5F);
  Desk.Insert(F);
  Check(not E.Exposed, 'a view completely covered is not exposed');
  Check(F.Exposed, 'the covering view is exposed');
  Check(Row(8, 18, 26) = '.FFFFFF..', 'the covering view is what shows');
  C := TFill.Create(R(18, 8, 21, 9), 'C', $6F);
  Desk.Insert(C);
  F.Hide;
  Check(E.Exposed, 'exposed again once the cover is hidden');
  F.Show;
  Check(not E.Exposed, 'and covered again');
  Desk.Delete(C);
  C.Free;
  Desk.Delete(F);
  F.Free;
  Desk.Delete(E);
  E.Free;

  { shadows }
  B.SetState(sfShadow, True);
  Check(Shadowed(17, 3) and Shadowed(18, 3), 'the shadow is on the right of the view');
  Check(Shadowed(9, 6) and Shadowed(18, 6), 'and below it');
  Check(not Shadowed(19, 3), 'not further right');
  Check(not Shadowed(7, 6) and not Shadowed(8, 6), 'the first columns below are not shadowed');
  Check(not Shadowed(16, 3), 'the view itself is not shadowed');
  Check(Row(3, 15, 19) = 'BB...', 'the shadow keeps the text under it');
  B.SetState(sfShadow, False);
  Check(not Shadowed(17, 3) and not Shadowed(9, 6), 'removing the shadow redraws the area');

  { bounds of children when the owner changes size }
  G := TGroup.Create(R(0, 0, 20, 6));
  V1 := TFill.Create(R(0, 0, 10, 3), 'x', $07);
  V1.GrowMode := gfGrowHiX;
  G.Insert(V1);
  G.Size.X := 20;
  Rc := TRect.Create(0, 0, 0, 0);
  V1.CalcBounds(Rc, Point(10, 0));
  Check((Rc.A.X = 0) and (Rc.B.X = 20) and (Rc.B.Y = 3), 'CalcBounds with gfGrowHiX');
  V1.GrowMode := gfGrowLoX or gfGrowHiX;
  V1.CalcBounds(Rc, Point(4, 0));
  Check((Rc.A.X = 4) and (Rc.B.X = 14) and (Rc.B.Y = 3), 'CalcBounds with gfGrowLoX or gfGrowHiX moves the view');
  V1.GrowMode := 0;
  V1.CalcBounds(Rc, Point(7, 7));
  Check((Rc.A.X = 0) and (Rc.B.X = 10), 'CalcBounds without grow flags keeps the view');
  G.Free;
  Check(DoneCount = 4, 'Dispose of a group disposes its views');

  { selection and focus }
  Desk.SetCurrent(nil, normalSelect);
  V1 := TFill.Create(R(0, 0, 3, 1), '1', $07);
  V2 := TFill.Create(R(4, 0, 7, 1), '2', $07);
  V3 := TFill.Create(R(8, 0, 11, 1), '3', $07);
  V1.Options := ofSelectable;
  V2.Options := ofSelectable;
  V3.Options := ofSelectable;
  G := TGroup.Create(R(20, 0, 40, 2));
  G.State := G.State or sfExposed;
  G.Insert(V1);
  G.Insert(V2);
  G.Insert(V3);
  { ResetCurrent looks from Last, the bottom view: the first inserted one }
  Check(G.Current = TView(V1), 'the first inserted selectable view becomes current');
  Check((V1.State and sfSelected) <> 0, 'and selected');
  Check((V3.State and sfSelected) = 0, 'the others are not');
  V3.Select;
  Check((G.Current = TView(V3)) and ((V3.State and sfSelected) <> 0), 'Select works');
  V1.Select;
  Check((G.Current = TView(V1)) and ((V1.State and sfSelected) <> 0)
    and ((V3.State and sfSelected) = 0), 'Select moves the selection');
  G.SelectNext(True);
  Check(G.Current = TView(V3), 'SelectNext goes on (toward the back of the list)');
  G.SelectNext(False);
  Check(G.Current = TView(V1), 'SelectNext backwards');
  V2.Options := V2.Options and not ofSelectable;
  G.SelectNext(True);
  Check(G.Current <> TView(V2), 'a view that cannot be selected is skipped');
  V3.State := V3.State or sfDisabled;
  V1.Select;
  G.SelectNext(True);
  Check(G.Current = TView(V1), 'a disabled view is skipped too');
  V3.State := V3.State and not sfDisabled;

  { group access }
  Count := 0;
  G.ForEach(@CountViews, @Count);
  Check(Count = 3, 'ForEach visits all the views');
  Check(G.FirstThat(@IsV2, V2) = TView(V2), 'FirstThat');
  Check(G.FirstThat(@IsV2, B) = nil, 'FirstThat finds nothing');
  Check((G.IndexOf(V1) = 3) and (G.IndexOf(V3) = 1), 'IndexOf counts from Last (the bottom view is 3 here)');
  Check(G.At(0) = G.Last, 'At(0) is Last');
  Check(G.First = TView(V3), 'First is the view inserted last');
  G.Delete(V2);
  Check((V2.Owner = nil) and (V2.Next = nil), 'Delete detaches a view');
  Count := 0;
  G.ForEach(@CountViews, @Count);
  Check(Count = 2, 'Delete removes it from the list');
  V2.Free;
  G.Free;

  { the caret }
  V1 := TFill.Create(R(3, 2, 8, 3), 'q', $07);
  V1.Options := ofSelectable;
  Desk.Insert(V1);
  Check((V1.State and sfFocused) <> 0, 'a selectable view inserted into a focused group is focused');
  V1.SetCursor(2, 0);
  Check(CaretSize = 0, 'no caret before the cursor is shown');
  V1.ShowCursor;
  Check((CaretX = 5) and (CaretY = 2) and (CaretSize = TScreen.CursorLines), 'the caret is where the cursor is, in screen coordinates');
  V1.BlockCursor;
  Check(CaretSize = 100, 'a block cursor');
  V1.NormalCursor;
  V1.HideCursor;
  Check(CaretSize = 0, 'a hidden cursor hides the caret');
  V1.ShowCursor;
  F := TFill.Create(R(4, 1, 10, 4), 'F', $5F);
  Desk.Insert(F);
  V1.ResetCursor;
  Check(CaretSize = 0, 'no caret under a view that covers it');
  Desk.Delete(F);
  F.Free;
  V1.ResetCursor;
  Check(CaretSize = TScreen.CursorLines, 'the caret is back when uncovered');
  Desk.Delete(V1);
  V1.Free;

  { messages }
  V1 := TFill.Create(R(0, 0, 2, 1), 'm', $07);
  Check(Message(V1, evCommand, cmOK, nil) = Pointer(V1), 'a message that is handled returns the receiver');
  Check(Message(V1, evCommand, cmCancel, nil) = nil, 'a message that is not handled returns nil');
  Check(Message(nil, evCommand, cmOK, nil) = nil, 'a message to nil');
  Ev.KeyDown.KeyCode := $1C0D;
  V1.ClearEvent(Ev);
  Check((Ev.KeyDown.KeyCode = $1C0D) and (Ev.KeyDown.CharScan.CharCode = $0D) and (Ev.KeyDown.CharScan.ScanCode = $1C), 'ClearEvent keeps the key');
  V1.ClearEvent(Ev);
  Check((Ev.What = evNothing) and (Ev.Message.InfoPtr = Pointer(V1)), 'ClearEvent');
  V1.Free;

  { commands }
  Check(not TView.CommandEnabled(cmZoom), 'zoom is disabled at the start');
  Check(TView.CommandEnabled(cmQuit) and TView.CommandEnabled(cmOK), 'the others are enabled');
  Check(TView.CommandEnabled(1000) and TView.CommandEnabled(40000), 'commands above 255 are always enabled');
  TView.CommandSetChanged := False;
  TView.EnableCommand(cmZoom);
  Check(TView.CommandEnabled(cmZoom) and TView.CommandSetChanged, 'EnableCommand marks the set as changed');
  TView.CommandSetChanged := False;
  TView.EnableCommand(cmZoom);
  Check(not TView.CommandSetChanged, 'enabling an enabled command changes nothing');
  Cmds := CommandsOf([cmZoom, cmQuit]);
  TView.DisableCommands(Cmds);
  Check(not TView.CommandEnabled(cmZoom) and not TView.CommandEnabled(cmQuit), 'DisableCommands');
  TView.GetCommands(Cmds);
  TView.EnableCommands(CommandsOf([cmQuit, cmClose]));
  Check(TView.CommandEnabled(cmQuit) and TView.CommandEnabled(cmClose), 'EnableCommands');
  TView.SetCommands(Cmds);
  Check(not TView.CommandEnabled(cmClose) and not TView.CommandEnabled(cmQuit), 'SetCommands restores a saved set');
  TView.SetCmdState(CommandsOf([cmQuit]), True);
  Check(TView.CommandEnabled(cmQuit), 'SetCmdState enable');
  Cmds := Default(TCommandSet);
  Check(Cmds.IsEmpty and not Cmds.Has(cmQuit), 'a new TCommandSet is empty');
  Cmds := Cmds + cmQuit + 300;
  Check(Cmds.Has(cmQuit) and not Cmds.Has(300) and not Cmds.IsEmpty, 'TCommandSet: + adds a command below 256');
  Check(((Cmds or CommandsOf([cmZoom])) and CommandsOf([cmZoom])) = CommandsOf([cmZoom]), 'TCommandSet: or, and, =');
  Check((Cmds - cmQuit).IsEmpty and ((Cmds - Cmds) <> Cmds), 'TCommandSet: - and <>');

  { colors }
  V1 := TFill.Create(R(0, 0, 2, 1), 'c', $07);
  V1.Options := 0;
  Check(AttrAsBIOSByte(V1.MapColor(1)) = $07, 'color 1 through the palette of the view');
  Check(AttrEq(V1.MapColor(2), TView.ErrorAttr), 'a color beyond the palette is the error color');
  Check(AttrEq(V1.MapColor(0), TView.ErrorAttr), 'color 0 is the error color');
  Check(PaletteSize(MakePalette(#1#2#3)) = 3, 'palette size');
  Check(V1.GetColorW(1) = $0007, 'GetColorW: the BIOS attribute of the color');
  V1.Free;

  { streams: a group with views that point to each other }
  RFill.ObjType := 4100;
  RFill.VmtLink := PtrUInt(System.TClass(TFill));
  RFill.Load := @BuildFill;
  RFill.Store := @StoreFill;
  RegisterType(RFill);
  RegisterType(RGroup);
  GS := TGroup.Create(R(0, 0, 20, 8));
  SA := TFill.Create(R(0, 0, 5, 2), 'a', $17);
  SB := TFill.Create(R(5, 0, 10, 2), 'b', $27);
  SC := TFill.Create(R(10, 0, 15, 2), 'c', $37);
  GS.Insert(SA);
  GS.Insert(SB);
  GS.Insert(SC);
  SB.Peer := SC;
  SA.Peer := SB;
  GS.Current := SB;
  M := TMemoryStream.Create(0, 256);
  M.Put(TStreamable(Pointer(GS)));
  Check(M.Status = stOk, 'a group is stored');
  M.Seek(0);
  GL := TGroup(M.Get);
  Check((GL <> nil) and (M.Status = stOk), 'a group is loaded');
  Check((GL.IndexOf(GL.At(1)) = 1) and (GL.At(3) <> nil), 'three views in the group');
  { At(1) is the view that was inserted last (the top one) }
  Check((TFill(GL.At(1)).Ch = Ord('c')) and (TFill(GL.At(2)).Ch = Ord('b')) and
    (TFill(GL.At(3)).Ch = Ord('a')), 'the views are in the same order');
  Check(TFill(GL.At(3)).Peer = GL.At(2), 'a pointer to a sibling view is made again (a -> b)');
  Check(TFill(GL.At(2)).Peer = GL.At(1), 'a pointer to a sibling view is made again (b -> c)');
  Check(TFill(GL.At(1)).Peer = nil, 'a nil pointer stays nil');
  Check(GL.Current = GL.At(2), 'the current view is the same');
  Check(((GL.At(2).State and sfSelected) <> 0) and ((GL.At(2).State and (sfFocused or sfActive or sfExposed)) = 0),
    'the current view of a loaded group is selected (SetCurrent), but not focused, active or exposed');
  Check(GL.Size.X = 20, 'the size of the group');
  GL.Free;
  GS.Free;
  M.Free;
  { the bounds and the coordinates of a view }
  V1 := TFill.Create(R(3, 2, 9, 5), 'p', $07);
  Rc := V1.GetBounds;
  Check((Rc.A.X = 3) and (Rc.B.Y = 5), 'GetBounds');
  Rc := V1.GetExtent;
  Check((Rc.A.X = 0) and (Rc.B.X = 6) and (Rc.B.Y = 3), 'GetExtent');
  Pt.X := 1; Pt.Y := 1;
  Pt2 := V1.MakeGlobal(Pt);
  Check((Pt2.X = 4) and (Pt2.Y = 3), 'MakeGlobal');
  Pt := V1.MakeLocal(Pt2);
  Check((Pt.X = 1) and (Pt.Y = 1), 'MakeLocal');
  V1.Free;

  { the 16-bit interface of Borland Pascal: Word cells and BIOS attributes }
  Leg := TLeg.Create(R(0, 6, 4, 8));
  Desk.Insert(Leg);
  Check((Cell(0, 6)^.Character.Text[0] = Ord('A')) and (AttrAsBIOSByte(Cell(0, 6)^.Attribute) = $1E),
    'WriteLineW: the cell is a character and an attribute');
  Check((Cell(1, 7)^.Character.Text[0] = Ord('B')) and (AttrAsBIOSByte(Cell(1, 7)^.Attribute) = $1F),
    'WriteLineW writes the same cells to every row');
  Check((Cell(2, 6)^.Character.Text[0] = Ord('C')) and (Cell(3, 6)^.Character.Text[0] = Ord('D')),
    'WriteBufW: W cells of H rows');
  Desk.Delete(Leg);
  Leg.Free;

  Desk.State := Desk.State and not sfExposed;
  Bg.Free;
  A.Free;
  B.Free;
  Desk.Free;
  ScreenDestroy;
  Finish;
end.
