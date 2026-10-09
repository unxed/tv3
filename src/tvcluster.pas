{ TvCluster: groups of check boxes and radio buttons: TCluster, TRadioButtons, TCheckBoxes,
  TMultiCheckBoxes, TSItem (the list of the item texts).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/dialogs.h (class declarations)
    source/tvision/tcluster.cpp, tradiobu.cpp, tcheckbo.cpp, tmulchkb.cpp
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the texts are ShortStrings;
    - the data of TCluster is a Word, the one of TMultiCheckBoxes is a LongWord, as in the
      original (DataSize). }
unit TvCluster;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvDrawBuf, TvObjs, TvUtil, TvViews,
  TvDialog;
{$WARN 3018 OFF}  { "Constructor should be public": Create(streamableInit) is protected, as in tvision }

type
  TSItem = class
    Value: PStr;
    Next: TSItem;
    constructor Create(const AValue: ShortString; ANext: TSItem);
    destructor Destroy; override;
  end;

  { Palette: 1 = normal text, 2 = selected text, 3 = normal shortcut, 4 = selected
    shortcut, 5 = disabled text }
  TCluster = class;
  TRadioButtons = class;
  TCheckBoxes = class;
  TMultiCheckBoxes = class;

  TCluster = class(TView)
    Value: LongWord;
    EnableMask: LongWord;
    Sel: Integer;
    Strings: TStringCollection;
    constructor Create(const Bounds: TRect; AStrings: TSItem);
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    destructor Destroy; override;
    function DataSize: Integer; override;
    procedure DrawBox(const Icon: ShortString; Marker: Char);
    procedure DrawMultiBox(const Icon, Marker: ShortString);
    procedure GetData(var Rec); override;
    function GetHelpCtx: Word; override;
    function GetPalette: TPalette; override;
    function UxClusterKey(var Event: TEvent; S, N: Integer): Boolean;
    procedure HandleEvent(var Event: TEvent); override;
    function Mark(Item: Integer): Boolean; virtual;
    function MultiMark(Item: Integer): Byte; virtual;
    procedure Press(Item: Integer); virtual;
    procedure MovedTo(Item: Integer); virtual;
    procedure SetData(var Rec); override;
    procedure SetState(AState: Word; Enable: Boolean); override;
    procedure SetButtonState(AMask: LongWord; Enable: Boolean); virtual;
    function ButtonState(Item: Integer): Boolean;
    function Column(Item: Integer): Integer;
    function FindSel(P: TPoint): Integer;
    function Row(Item: Integer): Integer;
  private
    procedure MoveSel(I, S: Integer);
  end;

  TRadioButtons = class(TCluster)
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
  public
    procedure Draw; override;
    function Mark(Item: Integer): Boolean; override;
    procedure MovedTo(Item: Integer); override;
    procedure Press(Item: Integer); override;
    procedure SetData(var Rec); override;
  end;

  TCheckBoxes = class(TCluster)
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
  public
    procedure Draw; override;
    function Mark(Item: Integer): Boolean; override;
    procedure Press(Item: Integer); override;
  end;

  { States: the characters shown for the states 0..SelRange-1; Flags: low byte is the mask
    of the bits of one item, high byte is the number of bits per item. }
  TMultiCheckBoxes = class(TCluster)
    SelRange: Byte;
    Flags: Word;
    States: PStr;
    constructor Create(const Bounds: TRect; AStrings: TSItem; ASelRange: Byte; AFlags: Word;
      const AStates: ShortString);
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    destructor Destroy; override;
    function DataSize: Integer; override;
    procedure Draw; override;
    procedure GetData(var Rec); override;
    function MultiMark(Item: Integer): Byte; override;
    procedure Press(Item: Integer); override;
    procedure SetData(var Rec); override;
  end;

const
  ClusterPalette = #$10#$11#$12#$12#$1F;

var
  { stream records (see RView of TvViews) }
  RCluster, RRadioButtons, RCheckBoxes, RMultiCheckBoxes: TStreamableClass;

implementation

{ --- TSItem ------------------------------------------------------------------ }

constructor TSItem.Create(const AValue: ShortString; ANext: TSItem);
begin
  inherited Create;
  Value := NewStr(AValue);
  Next := ANext;
end;

destructor TSItem.Destroy;
begin
  DisposeStr(Value);
  inherited Destroy;
end;

{ The text of an item: an item with an empty text is nil in the collection (NewStr('') is nil), not a string of length 0 }
function ItemText(Strings: TStringCollection; I: Integer): ShortString;
var
  P: PStr;
begin
  P := PStr(Strings.At(I));
  if P = nil then
    Result := ''
  else
    Result := P^;
end;

{ --- TCluster ---------------------------------------------------------------- }

constructor TCluster.Create(const Bounds: TRect; AStrings: TSItem);
var
  N: Integer;
  P: TSItem;
begin
  inherited Create(Bounds);
  Options := Options or ofSelectable or ofFirstClick or ofPreProcess or ofPostProcess;
  Value := 0;
  Sel := 0;
  N := 0;
  P := AStrings;
  while P <> nil do
  begin
    Inc(N);
    P := P.Next;
  end;
  Strings := TStringCollection.Create(N, 0);
  while AStrings <> nil do
  begin
    P := AStrings;
    if AStrings.Value = nil then
      Strings.AtInsert(Strings.Count, nil)
    else
      Strings.AtInsert(Strings.Count, NewStr(AStrings.Value^));
    AStrings := AStrings.Next;
    P.Free;
  end;
  SetCursor(2, 0);
  ShowCursor;
  EnableMask := $FFFFFFFF;
end;

destructor TCluster.Destroy;
begin
  if Strings <> nil then
    Strings.Free;
  Strings := nil;
  inherited Destroy;
end;

function TCluster.DataSize: Integer;
begin
  { the value is a LongWord, but the data is a Word, as in the original;
    TMultiCheckBoxes gives the size of a LongWord }
  Result := SizeOf(Word);
end;

procedure TCluster.DrawBox(const Icon: ShortString; Marker: Char);
var
  S: ShortString;
begin
  S := ' ' + Marker;
  DrawMultiBox(Icon, S);
end;

procedure TCluster.DrawMultiBox(const Icon, Marker: ShortString);
var
  B: TDrawBuffer;
  CNorm, CSel, CDis, C: TAttrPair;
  N, Y, Col, Item, X: Integer;
  Lit: Boolean;
begin
  CNorm := GetColor($0301);
  CSel := GetColor($0402);
  CDis := GetColor($0505);
  N := Strings.Count;
  Lit := (State and sfSelected) <> 0;
  B := TDrawBuffer.Create(Size.X);
  Y := 0;
  while Y < Size.Y do
  begin
    { a row: the items Y, Y + Size.Y, ... side by side }
    B.MoveChar(0, 32, CNorm[0], Size.X);
    Col := 0;
    Item := Y;
    while Item < N do
    begin
      X := Column(Item);
      if X < Size.X then
      begin
        if not ButtonState(Item) then
          C := CDis
        else if Lit and (Item = Sel) then
          C := CSel
        else
          C := CNorm;
        B.MoveChar(X, Ord(' '), C[0], Size.X - X);
        B.MoveCStrS(X, Icon, C);
        B.PutChar(X + 2, Ord(Marker[MultiMark(Item) + 1]));
        B.MoveCStrS(X + 5, ItemText(Strings, Item), C);
        if ShowMarkers and Lit and (Item = Sel) then
        begin
          B.PutChar(X, SpecialChars[0]);
          B.PutChar(Column(Item + Size.Y) - 1, SpecialChars[1]);
        end;
      end;
      Inc(Col);
      Item := Col * Size.Y + Y;
    end;
    WriteBuf(0, Y, Size.X, 1, B);
    Inc(Y);
  end;
  B.Free;
  SetCursor(Column(Sel) + 2, Row(Sel));
end;

procedure TCluster.GetData(var Rec);
begin
  Word(Rec) := Word(Value);
  DrawView;
end;

function TCluster.GetHelpCtx: Word;
begin
  if HelpCtx = hcNoContext then
    Result := hcNoContext
  else
    Result := HelpCtx + Sel;
end;

function TCluster.GetPalette: TPalette;
begin
  Result := TPalette.Create(ClusterPalette, Length(ClusterPalette));
end;

procedure TCluster.MoveSel(I, S: Integer);
begin
  if I > Strings.Count then
    Exit;
  Sel := S;
  MovedTo(Sel);
  DrawView;
end;

{ The arrow keys by the guidelines: the items are in columns of Size.Y; Up and Down walk the items one by one (the bottom of a column goes to the top of the
  next one), Right and Left move by a column and at the end of a row go to the next or the previous row; past the first or the last item the focus leaves the group. }
function TCluster.UxClusterKey(var Event: TEvent; S, N: Integer): Boolean;
var
  Key: Word;
  Cur, R, C: Integer;
  Done: Boolean;

  function Enabled(I: Integer): Boolean;
  begin
    Result := (I >= 0) and (I < N) and ButtonState(I);
  end;

  { the item after I in the direction, or -1 }
  function Step(I: Integer): Integer;
  var
    Rw, Cl: Integer;
  begin
    Rw := I mod Size.Y;
    Cl := I div Size.Y;
    Result := -1;
    case Key of
      kbUp:
        if I > 0 then Result := I - 1;
      kbDown:
        if I < N - 1 then Result := I + 1;
      kbRight:
        if I + Size.Y < N then
          Result := I + Size.Y
        else if (Rw + 1 < Size.Y) and (Rw + 1 < N) then
          Result := Rw + 1;
      kbLeft:
        if Cl > 0 then
          Result := I - Size.Y
        else if Rw > 0 then
        begin
          R := Rw - 1;
          C := (N - 1 - R) div Size.Y;
          Result := C * Size.Y + R;
        end;
    end;
  end;

begin
  Result := False;
  Key := CtrlToArrow(Event.KeyDown.KeyCode);
  if ((Key <> kbUp) and (Key <> kbDown) and (Key <> kbLeft) and (Key <> kbRight)) or (N = 0) or (Size.Y < 1) then
    Exit;
  Cur := S;
  repeat
    Cur := Step(Cur);
    Done := (Cur < 0) or Enabled(Cur);
  until Done;
  Result := True;
  if Cur >= 0 then
    MoveSel(1, Cur)
  else if not UxPassFocus(Self, (Key = kbDown) or (Key = kbRight)) then
    Exit(False);
  ClearEvent(Event);
end;

procedure TCluster.HandleEvent(var Event: TEvent);
var
  N, I, S, Tries: Integer;
  Focused: Boolean;
  Key: Word;

  function Under: Integer;
  begin
    Result := FindSel(MakeLocal(Event.Mouse.Where));
  end;

  { the item after I for an arrow key, wrapping around the ends }
  function Neighbour(I: Integer): Integer;
  var
    Cells: Integer;
  begin
    case Key of
      kbUp:
        if I > 0 then Result := I - 1 else Result := N - 1;
      kbDown:
        if I < N - 1 then Result := I + 1 else Result := 0;
      kbRight:
        begin
          Result := I + Size.Y;
          if Result >= N then
            Result := 0;
        end;
    else
      if I <= 0 then
        Result := N - 1
      else if I >= Size.Y then
        Result := I - Size.Y
      else
      begin
        { from the first column to the last column of the row above }
        Cells := Size.Y * ((N + Size.Y - 1) div Size.Y);
        Result := Cells + I - Size.Y - 1;
        if Result >= N then
          Result := N - 1;
      end;
    end;
  end;

  { the item whose hot key the event is, or -1 }
  function HotItem: Integer;
  var
    J: Integer;
    Hot: Char;
    Plain: Boolean;
  begin
    Result := -1;
    if Event.KeyDown.KeyCode = 0 then
      Exit;
    { a plain letter counts when the cluster is focused or after the others }
    Plain := Focused or (Owner.Phase = phPostProcess);
    for J := 0 to N - 1 do
    begin
      Hot := HotKey(ItemText(Strings, J));
      if (Event.KeyDown.KeyCode = GetAltCode(Hot)) or HotKeyAlt(Hot, Event)
        or (Plain and (Hot <> #0) and (UpCaseCp(Chr(Event.KeyDown.CharScan.CharCode)) = Hot)) then
        Exit(J);
    end;
  end;

begin
  inherited HandleEvent(Event);
  if (Options and ofSelectable) = 0 then
    Exit;
  N := Strings.Count;
  Focused := (State and sfFocused) <> 0;
  if Event.What = evMouseDown then
  begin
    I := Under;
    if (I <> -1) and ButtonState(I) then
      Sel := I;
    DrawView;
    { the cursor shows whether a release would press the item }
    repeat
      if ButtonState(Sel) and (Under = Sel) then
        ShowCursor
      else
        HideCursor;
    until not MouseEvent(Event, evMouseMove);
    ShowCursor;
    if Under = Sel then
    begin
      Press(Sel);
      DrawView;
    end;
    ClearEvent(Event);
    Exit;
  end;
  if Event.What <> evKeyDown then
    Exit;
  if Focused and UxInDialog(Self) and UxClusterKey(Event, Sel, N) then
    Exit;
  Key := CtrlToArrow(Event.KeyDown.KeyCode);
  if (Key = kbUp) or (Key = kbDown) or (Key = kbLeft) or (Key = kbRight) then
  begin
    if not Focused then
      Exit;
    S := Sel;
    Tries := 0;
    repeat
      Inc(Tries);
      S := Neighbour(S);
    until ButtonState(S) or (Tries > N);
    MoveSel(Tries, S);
    ClearEvent(Event);
    Exit;
  end;
  I := HotItem;
  if I >= 0 then
  begin
    if ButtonState(I) then
    begin
      if Focus then
      begin
        Sel := I;
        MovedTo(I);
        Press(I);
        DrawView;
      end;
      ClearEvent(Event);
    end;
  end
  else if Focused and (Event.KeyDown.CharScan.CharCode = Ord(' ')) then
  begin
    Press(Sel);
    DrawView;
    ClearEvent(Event);
  end;
end;

procedure TCluster.SetButtonState(AMask: LongWord; Enable: Boolean);
var
  N: Integer;
  TestMask: LongWord;
begin
  if not Enable then
    EnableMask := EnableMask and not AMask
  else
    EnableMask := EnableMask or AMask;
  N := Strings.Count;
  if N < 32 then
  begin
    TestMask := (LongWord(1) shl N) - 1;
    if (EnableMask and TestMask) <> 0 then
      Options := Options or ofSelectable
    else
      Options := Options and not ofSelectable;
  end;
end;

procedure TCluster.SetData(var Rec);
begin
  Value := Word(Rec);
  DrawView;
end;

procedure TCluster.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if AState = sfSelected then
    DrawView;
end;

function TCluster.Mark(Item: Integer): Boolean;
begin
  Result := False;
end;

function TCluster.MultiMark(Item: Integer): Byte;
begin
  if Mark(Item) then
    Result := 1
  else
    Result := 0;
end;

procedure TCluster.MovedTo(Item: Integer);
begin
end;

procedure TCluster.Press(Item: Integer);
begin
end;

function TCluster.Column(Item: Integer): Integer;
var
  I, Width, L: Integer;
begin
  if Item < Size.Y then
    Exit(0);
  { each column is as wide as its longest text, plus the icon and a gap }
  Result := -6;
  Width := 0;
  L := 0;
  for I := 0 to Item do
  begin
    if I mod Size.Y = 0 then
    begin
      Inc(Result, Width + 6);
      Width := 0;
    end;
    if I < Strings.Count then
      L := CStrLen(ItemText(Strings, I));
    if L > Width then
      Width := L;
  end;
end;

function TCluster.FindSel(P: TPoint): Integer;
var
  First: Integer;
begin
  if not GetExtent.Contains(P) then
    Exit(-1);
  First := 0;
  while P.X >= Column(First + Size.Y) do
    Inc(First, Size.Y);
  Result := First + P.Y;
  if Result >= Strings.Count then
    Result := -1;
end;

function TCluster.Row(Item: Integer): Integer;
begin
  Result := Item mod Size.Y;
end;

function TCluster.ButtonState(Item: Integer): Boolean;
begin
  if (Item >= 0) and (Item < 32) then
    Result := (EnableMask and (LongWord(1) shl Item)) <> 0
  else
    Result := False;
end;

{ --- TRadioButtons ----------------------------------------------------------- }

procedure TRadioButtons.Draw;
begin
  DrawMultiBox(' ( ) ', ' ' + #7);
end;

function TRadioButtons.Mark(Item: Integer): Boolean;
begin
  Result := Item = Integer(Value);
end;

procedure TRadioButtons.Press(Item: Integer);
begin
  Value := Item;
end;

{ The guidelines separate the cursor from the selection: in a dialog an arrow key only moves the cursor, Space (or the hot key, or a click) selects.
  Outside a dialog, or with UxNavBoundary off, the classic Turbo Vision behaviour: the selection follows the cursor. }
procedure TRadioButtons.MovedTo(Item: Integer);
begin
  if not UxInDialog(Self) then
    Value := Item;
end;

procedure TRadioButtons.SetData(var Rec);
begin
  inherited SetData(Rec);
  Sel := Integer(Value);
end;

{ --- TCheckBoxes ------------------------------------------------------------- }

procedure TCheckBoxes.Draw;
begin
  DrawMultiBox(' [ ] ', ' X');
end;

function TCheckBoxes.Mark(Item: Integer): Boolean;
begin
  Result := (Item < 32) and ((Value and (LongWord(1) shl Item)) <> 0);
end;

procedure TCheckBoxes.Press(Item: Integer);
begin
  if Item < 32 then
    Value := Value xor (LongWord(1) shl Item);
end;

{ --- TMultiCheckBoxes -------------------------------------------------------- }

constructor TMultiCheckBoxes.Create(const Bounds: TRect; AStrings: TSItem; ASelRange: Byte;
  AFlags: Word; const AStates: ShortString);
begin
  inherited Create(Bounds, AStrings);
  SelRange := ASelRange;
  Flags := AFlags;
  States := NewStr(AStates);
end;

destructor TMultiCheckBoxes.Destroy;
begin
  DisposeStr(States);
  States := nil;
  inherited Destroy;
end;

procedure TMultiCheckBoxes.Draw;
begin
  DrawMultiBox(' [ ] ', States^);
end;

function TMultiCheckBoxes.DataSize: Integer;
begin
  Result := SizeOf(LongWord);
end;

function TMultiCheckBoxes.MultiMark(Item: Integer): Byte;
var
  Flo, Fhi: Integer;
begin
  Flo := Flags and $FF;
  Fhi := (Flags shr 8) * Item;
  if Fhi > 31 then
    Result := 0
  else
    Result := Byte((Value and (LongWord(Flo) shl Fhi)) shr Fhi);
end;

procedure TMultiCheckBoxes.GetData(var Rec);
begin
  LongWord(Rec) := Value;
  DrawView;
end;

procedure TMultiCheckBoxes.Press(Item: Integer);
var
  Flo, Fhi, Cur: Integer;
begin
  Flo := Flags and $FF;
  Fhi := (Flags shr 8) * Item;
  if Fhi > 31 then
    Exit;
  Cur := Integer((Value and (LongWord(Flo) shl Fhi)) shr Fhi);
  Inc(Cur);
  if Cur >= SelRange then
    Cur := 0;
  Value := (Value and not (LongWord(Flo) shl Fhi)) or (LongWord(Cur) shl Fhi);
end;

procedure TMultiCheckBoxes.SetData(var Rec);
begin
  Value := LongWord(Rec);
  DrawView;
end;

{ --- Streams ------------------------------------------------------------------ }

procedure TCluster.Write(Os: opstream);
begin
  inherited Write(Os);
  Os.WriteBytes(Value, SizeOf(LongWord));
  Os.WriteBytes(Sel, SizeOf(Integer));
  Os.WriteBytes(EnableMask, SizeOf(LongWord));
  Os.WritePointer(Strings);
end;

function TCluster.Read(Ip: ipstream): Pointer;
begin
  inherited Read(Ip);
  Ip.ReadBytes(Value, SizeOf(LongWord));
  Ip.ReadBytes(Sel, SizeOf(Integer));
  Ip.ReadBytes(EnableMask, SizeOf(LongWord));
  Strings := TStringCollection(Ip.ReadPointer);
  SetCursor(2, 0);
  ShowCursor;
  SetButtonState(0, True);
  Result := Self;
end;

class function TCluster.Build: TStreamable;
begin
  Result := TCluster.Create(streamableInit);
end;

constructor TCluster.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TCluster.StreamableName: ShortString;
begin
  Result := 'TCluster';
end;

class function TRadioButtons.Build: TStreamable;
begin
  Result := TRadioButtons.Create(streamableInit);
end;

constructor TRadioButtons.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TRadioButtons.StreamableName: ShortString;
begin
  Result := 'TRadioButtons';
end;

class function TCheckBoxes.Build: TStreamable;
begin
  Result := TCheckBoxes.Create(streamableInit);
end;

constructor TCheckBoxes.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TCheckBoxes.StreamableName: ShortString;
begin
  Result := 'TCheckBoxes';
end;

procedure TMultiCheckBoxes.Write(Os: opstream);
begin
  inherited Write(Os);
  Os.WriteByte(SelRange);
  Os.WriteWord(Flags);
  Os.WriteString(States);
end;

function TMultiCheckBoxes.Read(Ip: ipstream): Pointer;
begin
  inherited Read(Ip);
  SelRange := Ip.ReadByte;
  Flags := Ip.ReadWord;
  States := Ip.ReadString;
  Result := Self;
end;

class function TMultiCheckBoxes.Build: TStreamable;
begin
  Result := TMultiCheckBoxes.Create(streamableInit);
end;

constructor TMultiCheckBoxes.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TMultiCheckBoxes.StreamableName: ShortString;
begin
  Result := 'TMultiCheckBoxes';
end;

initialization
  RCluster := TStreamableClass.Create('TCluster', @TCluster.Build);
  RRadioButtons := TStreamableClass.Create('TRadioButtons', @TRadioButtons.Build);
  RCheckBoxes := TStreamableClass.Create('TCheckBoxes', @TCheckBoxes.Build);
  RMultiCheckBoxes := TStreamableClass.Create('TMultiCheckBoxes', @TMultiCheckBoxes.Build);

end.
