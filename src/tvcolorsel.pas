{ TvColorSel: the dialog that edits a palette: TColorDialog with TColorSelector, TMonoSelector,
  TColorDisplay, TColorGroupList, TColorItemList, and the lists of groups and items
  (ColorItem, ColorGroup).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/colorsel.h (class declarations, commands)
    source/tvision/colorsel.cpp, tvtext1.cpp (texts)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the lists are built with ColorItem and ColorGroup (instead of operator+);
      the dialog takes them over and frees them;
    - the palette is a TPalette (a dynamic array, element 0 is the size); the data of the
      dialog is a TPalette: GetData gives a copy, SetData takes a copy;
    - the colors of the palette are TColorAttr, they are edited as BIOS colors (16 colors);
    - the remembered indexes of the groups are in ColorIndexes (FreeColorIndexes frees them);
    - streams: group/item lists and peer fields follow magiblot/Borland ColorSel
      (count + names + indexes; TColorDialog stores Display/Groups/selectors as peer views). }
unit TvColorSel;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvText, TvDrawBuf, TvObjs, TvUtil, TvViews,
  TvGlyphs, TvWindow, TvDialog, TvCluster, TvList;

const
  { broadcasts between the views of the dialog }
  cmSaveColorIndex = 76; cmNewColorIndex = 75; cmNewColorItem = 74;
  cmColorSet = 73;          { InfoByte: the BIOS attribute to show }
  cmColorBackgroundChanged = 72; cmColorForegroundChanged = 71;

  ColorsTitle = 'Colors';
  GroupText = '~G~roup';
  ItemText = '~I~tem';
  ForText = '~F~oreground';
  BakText = '~B~ackground';
  TextText = 'Text ';
  ColorText = 'Color';
  NormalText = 'Normal';
  HighlightText = 'Highlight';
  UnderlineText = 'Underline';
  InverseText = 'Inverse';
  ColorOKText = 'O~K~';
  ColorCancelText = 'Cancel';

type
  TColorSel = (csBackground, csForeground);

  { an entry of the palette by name (Index into the palette); a group lists its items }
  PColorItem = ^TColorItem;
  PColorGroup = ^TColorGroup;
  PColorIndex = ^TColorIndex;
  TColorItem = record
    Next: PColorItem;
    Name: PStr;
    Index: Byte;
  end;
  TColorGroup = record
    Next: PColorGroup;
    Name: PStr;
    Items: PColorItem;
    Index: Byte;          { the item last chosen in the group }
  end;

  { what the dialog remembers of the last choice: the group, the number of groups and the item of every group }
  TColorIndex = record
    GroupIndex, ColorSize: Byte;
    ColorIndex: array[Byte] of Byte;
  end;
  TMonoColorList = array[0..4] of Byte;

  TColorSelector = class;
  TMonoSelector = class;
  TColorDisplay = class;
  TColorGroupList = class;
  TColorItemList = class;
  TColorDialog = class;

  TColorSelector = class(TView)
    Color: Byte;
    SelType: TColorSel;
    constructor Create(const Bounds: TRect; ASelType: TColorSel);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    procedure Draw; override;
    procedure HandleEvent(var Event: TEvent); override;
  private
    procedure ColorChanged;
  end;

  TMonoSelector = class(TCluster)
    constructor Create(const Bounds: TRect);
    constructor Load(S: TStream);
    procedure Draw; override;
    procedure HandleEvent(var Event: TEvent); override;
    function Mark(Item: Integer): Boolean; override;
    procedure MovedTo(Item: Integer); override;
    procedure Press(Item: Integer); override;
  private
    procedure NewColor;
  end;

  TColorDisplay = class(TView)
    Color: PColorAttr;
    Text: PStr;
    constructor Create(const Bounds: TRect; const AText: ShortString);
    constructor Load(S: TStream);
    destructor Destroy; override;
    procedure Store(S: TStream); override;
    procedure Draw; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure SetColor(AColor: PColorAttr);
  end;

  TColorGroupList = class(TListViewer)
    Groups: PColorGroup;
    constructor Create(const Bounds: TRect; AScrollBar: TScrollBar; AGroups: PColorGroup);
    constructor Load(S: TStream);
    destructor Destroy; override;
    procedure Store(S: TStream); override;
    procedure FocusItem(Item: Integer); override;
    function GetText(Item, MaxLen: Integer): ShortString; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure SetGroupIndex(GroupNum, ItemNum: Byte);
    function GetGroupIndex(GroupNum: Byte): Byte;
    function GetGroup(GroupNum: Byte): PColorGroup;
    function GetNumGroups: Byte;
  end;

  TColorItemList = class(TListViewer)
    Items: PColorItem;
    constructor Create(const Bounds: TRect; AScrollBar: TScrollBar; AItems: PColorItem);
    constructor Load(S: TStream);
    procedure FocusItem(Item: Integer); override;
    function GetText(Item, MaxLen: Integer): ShortString; override;
    procedure HandleEvent(var Event: TEvent); override;
  end;

  TColorDialog = class(TDialog)
    Pal: TPalette;
    Display: TColorDisplay;
    Groups: TColorGroupList;
    ForLabel: TLabel;
    ForSel: TColorSelector;
    BakLabel: TLabel;
    BakSel: TColorSelector;
    MonoLabel: TLabel;
    MonoSel: TMonoSelector;
    GroupIndex: Byte;
    constructor Create(const APalette: TPalette; AGroups: PColorGroup);
    constructor Load(S: TStream);
    destructor Destroy; override;
    procedure Store(S: TStream); override;
    function DataSize: Integer; override;
    procedure GetData(var Rec); override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure SetData(var Rec); override;
  private
    procedure SetIndexes;
    procedure GetIndexes;
  end;

var
  { the indexes remembered between the uses of the dialog }
  ColorIndexes: PColorIndex = nil;

function ColorItem(const Name: ShortString; Index: Byte; Next: PColorItem): PColorItem;
function ColorGroup(const Name: ShortString; Items: PColorItem; Next: PColorGroup): PColorGroup;
{ appends the items to the last group of the list }
function ColorGroupItems(Group: PColorGroup; Items: PColorItem): PColorGroup;
procedure FreeColorIndexes;

const
  { the attributes that the monochrome selector offers, by item (DN's T_BWSelector takes them too) }
  MonoColors: TMonoColorList = (7, 15, 1, 112, 9);

implementation

{ --- ColorItem, ColorGroup ----------------------------------------------------- }

function ColorItem(const Name: ShortString; Index: Byte; Next: PColorItem): PColorItem;
begin
  New(Result);
  Result^.Name := NewStr(Name);
  Result^.Index := Index;
  Result^.Next := Next;
end;

function ColorGroup(const Name: ShortString; Items: PColorItem; Next: PColorGroup): PColorGroup;
begin
  New(Result);
  Result^.Name := NewStr(Name);
  Result^.Index := 0;
  Result^.Items := Items;
  Result^.Next := Next;
end;

function ColorGroupItems(Group: PColorGroup; Items: PColorItem): PColorGroup;
var
  G: PColorGroup;
  I: PColorItem;
begin
  Result := Group;
  G := Group;
  while G^.Next <> nil do
    G := G^.Next;
  if G^.Items = nil then
    G^.Items := Items
  else
  begin
    I := G^.Items;
    while I^.Next <> nil do
      I := I^.Next;
    I^.Next := Items;
  end;
end;

procedure FreeItems(Cur: PColorItem);
var
  P: PColorItem;
begin
  while Cur <> nil do
  begin
    P := Cur;
    Cur := Cur^.Next;
    DisposeStr(P^.Name);
    Dispose(P);
  end;
end;

procedure FreeGroups(Cur: PColorGroup);
var
  P: PColorGroup;
begin
  while Cur <> nil do
  begin
    P := Cur;
    FreeItems(Cur^.Items);
    Cur := Cur^.Next;
    DisposeStr(P^.Name);
    Dispose(P);
  end;
end;

procedure FreeColorIndexes;
begin
  if ColorIndexes <> nil then
    Dispose(ColorIndexes);
  ColorIndexes := nil;
end;

{ --- TColorSelector ------------------------------------------------------------ }

constructor TColorSelector.Create(const Bounds: TRect; ASelType: TColorSel);
begin
  inherited Create(Bounds);
  Options := Options or (ofSelectable or ofFirstClick or ofFramed);
  EventMask := EventMask or evBroadcast;
  SelType := ASelType;
  Color := 0;
end;

constructor TColorSelector.Load(S: TStream);
var
  Temp: Integer;
begin
  inherited Load(S);
  S.Read(Color, SizeOf(Color));
  S.Read(Temp, SizeOf(Temp));
  SelType := TColorSel(Temp);
end;

procedure TColorSelector.Store(S: TStream);
var
  Temp: Integer;
begin
  inherited Store(S);
  S.Write(Color, SizeOf(Color));
  Temp := Ord(SelType);
  S.Write(Temp, SizeOf(Temp));
end;

procedure TColorSelector.Draw;
var
  B: TDrawBuffer;
  I, J, C: Integer;
begin
  B := TDrawBuffer.Create(Size.X);
  B.MoveChar(0, Ord(' '), AttrFromBIOS($70), Size.X);
  for I := 0 to Size.Y do
  begin
    if I < 4 then
    begin
      for J := 0 to 3 do
      begin
        C := I * 4 + J;
        B.MoveGlyph(J * 3, glBlockFull, AttrFromBIOS(C), 3);
        if C = Color then
        begin
          B.PutChar(J * 3 + 1, 8);
          if C = 0 then
            B.PutAttribute(J * 3 + 1, AttrFromBIOS($70));
        end;
      end;
    end;
    WriteLine(0, I, Size.X, 1, B);
  end;
  B.Free;
end;

procedure TColorSelector.ColorChanged;
var
  Cmd: Word;
begin
  if SelType = csForeground then
    Cmd := cmColorForegroundChanged
  else
    Cmd := cmColorBackgroundChanged;
  Message(Owner, evBroadcast, Cmd, Pointer(PtrUInt(Color)));
end;

procedure TColorSelector.HandleEvent(var Event: TEvent);
const
  Cols = 4;               { colors in a row of the selector }
var
  Before, Last: Integer;
  Attr: Byte;
  Mouse: TPoint;
begin
  inherited HandleEvent(Event);
  if Event.What = evBroadcast then
  begin
    { the dialog shows another attribute: take its half }
    if Event.Message.Command = cmColorSet then
    begin
      Attr := Event.Message.InfoByte;
      if SelType = csForeground then
        Color := Attr and $0F
      else
        Color := Attr shr 4;
      DrawView;
    end;
    Exit;
  end;
  Before := Color;
  if SelType = csBackground then
    Last := 7
  else
    Last := 15;
  case Event.What of
    evMouseDown:
      begin
        repeat
          if MouseInView(Event.Mouse.Where) then
          begin
            Mouse := MakeLocal(Event.Mouse.Where);
            Color := Mouse.Y * Cols + Mouse.X div 3;
          end
          else
            Color := Before;
          ColorChanged;
          DrawView;
        until not MouseEvent(Event, evMouseMove);
      end;
    evKeyDown:
      case CtrlToArrow(Event.KeyDown.KeyCode) of
        kbLeft:
          if Color = 0 then
            Color := Last
          else
            Dec(Color);
        kbRight:
          if Color >= Last then
            Color := 0
          else
            Inc(Color);
        kbUp:
          if Color >= Cols then
            Dec(Color, Cols)
          else if Color = 0 then
            Color := Last
          else
            Color := Color + Last - Cols;
        kbDown:
          if Color + Cols <= Last then
            Inc(Color, Cols)
          else if Color = Last then
            Color := 0
          else
            Color := Color - (Last - Cols);
      else
        Exit;
      end;
  else
    Exit;
  end;
  DrawView;
  ColorChanged;
  ClearEvent(Event);
end;

{ --- TMonoSelector ------------------------------------------------------------- }

constructor TMonoSelector.Create(const Bounds: TRect);
begin
  inherited Create(Bounds, NewSItem(NormalText, NewSItem(HighlightText,
    NewSItem(UnderlineText, NewSItem(InverseText, nil)))));
  EventMask := EventMask or evBroadcast;
end;

constructor TMonoSelector.Load(S: TStream);
begin
  inherited Load(S);
end;

procedure TMonoSelector.Draw;
begin
  DrawBox(' ( ) ', #$07);
end;

procedure TMonoSelector.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What <> evBroadcast then
    Exit;
  if Event.Message.Command <> cmColorSet then
    Exit;
  { the attribute of the dialog is one of MonoColors: the cluster marks it }
  Value := Event.Message.InfoByte;
  DrawView;
end;

function TMonoSelector.Mark(Item: Integer): Boolean;
begin
  Result := MonoColors[Item] = Value;
end;

procedure TMonoSelector.NewColor;
begin
  Message(Owner, evBroadcast, cmColorForegroundChanged, Pointer(PtrUInt(Value and $0F)));
  Message(Owner, evBroadcast, cmColorBackgroundChanged, Pointer(PtrUInt((Value shr 4) and $0F)));
end;

procedure TMonoSelector.Press(Item: Integer);
begin
  Value := MonoColors[Item];
  NewColor;
end;

procedure TMonoSelector.MovedTo(Item: Integer);
begin
  Value := MonoColors[Item];
  NewColor;
end;

{ --- TColorDisplay ------------------------------------------------------------- }

constructor TColorDisplay.Create(const Bounds: TRect; const AText: ShortString);
begin
  inherited Create(Bounds);
  Color := nil;
  Text := NewStr(AText);
  EventMask := EventMask or evBroadcast;
end;

constructor TColorDisplay.Load(S: TStream);
begin
  inherited Load(S);
  Text := S.ReadStr;
  Color := nil;
end;

procedure TColorDisplay.Store(S: TStream);
begin
  inherited Store(S);
  S.WriteStr(Text);
end;

destructor TColorDisplay.Destroy;
begin
  DisposeStr(Text);
  Text := nil;
  inherited Destroy;
end;

procedure TColorDisplay.Draw;
var
  C: TColorAttr;
  B: TDrawBuffer;
  Len, I: Integer;
begin
  if Color = nil then
    Exit;
  C := Color^;
  { BIOS color 0 has a special meaning in TDrawBuffer functions, so it is shown as an
    invalid color }
  if AttrToBIOS(C) = 0 then
    C := ErrorAttr;
  Len := TText.Width(Text^);
  if Len < 1 then
    Len := 1;
  B := TDrawBuffer.Create(Size.X);
  I := 0;
  while I * Len <= Size.X do
  begin
    B.MoveStrS(I * Len, Text^, C);
    Inc(I);
  end;
  WriteLine(0, 0, Size.X, Size.Y, B);
  B.Free;
end;

procedure TColorDisplay.HandleEvent(var Event: TEvent);
var
  Bios: Byte;
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Color <> nil) then
    case Event.Message.Command of
      cmColorBackgroundChanged:
        begin
          Bios := (AttrToBIOS(Color^) and $0F) or ((Event.Message.InfoByte shl 4) and $F0);
          Color^ := AttrFromBIOS(Bios);
          DrawView;
        end;
      cmColorForegroundChanged:
        begin
          Bios := (AttrToBIOS(Color^) and $F0) or (Event.Message.InfoByte and $0F);
          Color^ := AttrFromBIOS(Bios);
          DrawView;
        end;
    end;
end;

procedure TColorDisplay.SetColor(AColor: PColorAttr);
begin
  Color := AColor;
  Message(Owner, evBroadcast, cmColorSet, Pointer(PtrUInt(AttrToBIOS(Color^))));
  DrawView;
end;

{ --- TColorGroupList ----------------------------------------------------------- }

constructor TColorGroupList.Create(const Bounds: TRect; AScrollBar: TScrollBar;
  AGroups: PColorGroup);
var
  I: Integer;
  G: PColorGroup;
begin
  inherited Create(Bounds, 1, nil, AScrollBar);
  Groups := AGroups;
  I := 0;
  G := AGroups;
  while G <> nil do
  begin
    G := G^.Next;
    Inc(I);
  end;
  SetRange(I);
end;

procedure WriteColorItems(S: TStream; Items: PColorItem);
var
  Count: Integer;
  Cur: PColorItem;
begin
  Count := 0;
  Cur := Items;
  while Cur <> nil do
  begin
    Inc(Count);
    Cur := Cur^.Next;
  end;
  S.Write(Count, SizeOf(Count));
  Cur := Items;
  while Cur <> nil do
  begin
    S.WriteStr(Cur^.Name);
    S.Write(Cur^.Index, SizeOf(Cur^.Index));
    Cur := Cur^.Next;
  end;
end;

procedure WriteColorGroups(S: TStream; AGroups: PColorGroup);
var
  Count: Integer;
  Cur: PColorGroup;
begin
  Count := 0;
  Cur := AGroups;
  while Cur <> nil do
  begin
    Inc(Count);
    Cur := Cur^.Next;
  end;
  S.Write(Count, SizeOf(Count));
  Cur := AGroups;
  while Cur <> nil do
  begin
    S.WriteStr(Cur^.Name);
    WriteColorItems(S, Cur^.Items);
    Cur := Cur^.Next;
  end;
end;

function ReadColorItems(S: TStream): PColorItem;
var
  Count: Integer;
  Items, Last, Cur: PColorItem;
  Nm: PStr;
  Idx: Byte;
begin
  S.Read(Count, SizeOf(Count));
  Items := nil;
  Last := nil;
  while Count > 0 do
  begin
    Dec(Count);
    Nm := S.ReadStr;
    S.Read(Idx, SizeOf(Idx));
    New(Cur);
    Cur^.Name := Nm;
    Cur^.Index := Idx;
    Cur^.Next := nil;
    if Items = nil then
      Items := Cur
    else
      Last^.Next := Cur;
    Last := Cur;
  end;
  Result := Items;
end;

function ReadColorGroups(S: TStream): PColorGroup;
var
  Count: Integer;
  Groups, Last, Cur: PColorGroup;
  Nm: PStr;
begin
  S.Read(Count, SizeOf(Count));
  Groups := nil;
  Last := nil;
  while Count > 0 do
  begin
    Dec(Count);
    Nm := S.ReadStr;
    New(Cur);
    Cur^.Name := Nm;
    Cur^.Index := 0;
    Cur^.Items := ReadColorItems(S);
    Cur^.Next := nil;
    if Groups = nil then
      Groups := Cur
    else
      Last^.Next := Cur;
    Last := Cur;
  end;
  Result := Groups;
end;

constructor TColorGroupList.Load(S: TStream);
begin
  inherited Load(S);
  Groups := ReadColorGroups(S);
end;

procedure TColorGroupList.Store(S: TStream);
begin
  inherited Store(S);
  WriteColorGroups(S, Groups);
end;

destructor TColorGroupList.Destroy;
begin
  FreeGroups(Groups);
  Groups := nil;
  inherited Destroy;
end;

function TColorGroupList.GetGroup(GroupNum: Byte): PColorGroup;
begin
  Result := Groups;
  while (Result <> nil) and (GroupNum > 0) do
  begin
    Result := Result^.Next;
    Dec(GroupNum);
  end;
end;

procedure TColorGroupList.FocusItem(Item: Integer);
var
  G: PColorGroup;
begin
  inherited FocusItem(Item);
  G := Groups;
  while (G <> nil) and (Item > 0) do
  begin
    G := G^.Next;
    Dec(Item);
  end;
  if G <> nil then
    Message(Owner, evBroadcast, cmNewColorItem, G);
end;

function TColorGroupList.GetText(Item, MaxLen: Integer): ShortString;
var
  G: PColorGroup;
begin
  G := GetGroup(Item);
  if G <> nil then
  begin
    Result := G^.Name^;
    if Length(Result) > MaxLen then
      SetLength(Result, MaxLen);
  end
  else
    Result := '';
end;

procedure TColorGroupList.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Message.Command = cmSaveColorIndex) then
    SetGroupIndex(Focused, Event.Message.InfoByte);
end;

procedure TColorGroupList.SetGroupIndex(GroupNum, ItemNum: Byte);
var
  G: PColorGroup;
  Index: Byte;
  Cur: PColorItem;
begin
  G := GetGroup(GroupNum);
  if G <> nil then
  begin
    Index := 0;
    Cur := G^.Items;
    if Cur <> nil then
      while Index < ItemNum do
      begin
        Cur := Cur^.Next;
        if Cur = nil then
          Break;
        Inc(Index);
      end;
    G^.Index := Index;
  end;
end;

function TColorGroupList.GetGroupIndex(GroupNum: Byte): Byte;
var
  G: PColorGroup;
begin
  G := GetGroup(GroupNum);
  if G <> nil then
    Result := G^.Index
  else
    Result := 0;
end;

function TColorGroupList.GetNumGroups: Byte;
var
  G: PColorGroup;
begin
  Result := 0;
  G := Groups;
  while G <> nil do
  begin
    Inc(Result);
    G := G^.Next;
  end;
end;

{ --- TColorItemList ------------------------------------------------------------ }

constructor TColorItemList.Create(const Bounds: TRect; AScrollBar: TScrollBar;
  AItems: PColorItem);
var
  I: Integer;
  P: PColorItem;
begin
  inherited Create(Bounds, 1, nil, AScrollBar);
  Items := AItems;
  EventMask := EventMask or evBroadcast;
  I := 0;
  P := AItems;
  while P <> nil do
  begin
    P := P^.Next;
    Inc(I);
  end;
  SetRange(I);
end;

constructor TColorItemList.Load(S: TStream);
begin
  inherited Load(S);
  { Items point into TColorGroupList.Groups; wired by cmNewColorItem. }
  Items := nil;
end;

procedure TColorItemList.FocusItem(Item: Integer);
var
  Cur: PColorItem;
  N: Integer;
begin
  inherited FocusItem(Item);
  Message(Owner, evBroadcast, cmSaveColorIndex, Pointer(PtrUInt(Item)));
  Cur := Items;
  N := Item;
  while (Cur <> nil) and (N > 0) do
  begin
    Cur := Cur^.Next;
    Dec(N);
  end;
  if Cur <> nil then
    Message(Owner, evBroadcast, cmNewColorIndex, Pointer(PtrUInt(Cur^.Index)));
end;

function TColorItemList.GetText(Item, MaxLen: Integer): ShortString;
var
  Cur: PColorItem;
begin
  Cur := Items;
  while (Cur <> nil) and (Item > 0) do
  begin
    Cur := Cur^.Next;
    Dec(Item);
  end;
  if Cur <> nil then
  begin
    Result := Cur^.Name^;
    if Length(Result) > MaxLen then
      SetLength(Result, MaxLen);
  end
  else
    Result := '';
end;

procedure TColorItemList.HandleEvent(var Event: TEvent);
var
  G: PColorGroup;
  Cur: PColorItem;
  I: Integer;
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Message.Command = cmNewColorItem) then
  begin
    G := PColorGroup(Event.Message.InfoPtr);
    Items := G^.Items;
    Cur := Items;
    I := 0;
    while Cur <> nil do
    begin
      Cur := Cur^.Next;
      Inc(I);
    end;
    SetRange(I);
    FocusItem(G^.Index);
    DrawView;
  end;
end;

{ --- TColorDialog -------------------------------------------------------------- }

constructor TColorDialog.Create(const APalette: TPalette; AGroups: PColorGroup);
var
  R: TRect;
  SB: TScrollBar;
  Lbl: TLabel;
  P: TView;
  Btn: TButton;
begin
  R := TRect.Create(0, 0, 61, 18);
  inherited Create(R, ColorsTitle);
  Options := Options or ofCentered;
  if Length(APalette) > 0 then
    Pal := Copy(APalette)
  else
    Pal := nil;

  R := TRect.Create(18, 3, 19, 14);
  SB := TScrollBar.Create(R);
  Insert(SB);
  R := TRect.Create(3, 3, 18, 14);
  Groups := TColorGroupList.Create(R, SB, AGroups);
  Insert(Groups);
  R := TRect.Create(2, 2, 8, 3);
  Lbl := TLabel.Create(R, GroupText, Groups);
  Insert(Lbl);

  R := TRect.Create(41, 3, 42, 14);
  SB := TScrollBar.Create(R);
  Insert(SB);
  R := TRect.Create(21, 3, 41, 14);
  P := TColorItemList.Create(R, SB, AGroups^.Items);
  Insert(P);
  R := TRect.Create(20, 2, 25, 3);
  Lbl := TLabel.Create(R, ItemText, P);
  Insert(Lbl);

  R := TRect.Create(45, 3, 57, 7);
  ForSel := TColorSelector.Create(R, csForeground);
  Insert(ForSel);
  R := TRect.Create(45, 2, 57, 3);
  ForLabel := TLabel.Create(R, ForText, ForSel);
  Insert(ForLabel);

  R := TRect.Create(45, 9, 57, 11);
  BakSel := TColorSelector.Create(R, csBackground);
  Insert(BakSel);
  R := TRect.Create(45, 8, 57, 9);
  BakLabel := TLabel.Create(R, BakText, BakSel);
  Insert(BakLabel);

  R := TRect.Create(44, 12, 58, 14);
  Display := TColorDisplay.Create(R, TextText);
  Insert(Display);

  R := TRect.Create(44, 3, 59, 7);
  MonoSel := TMonoSelector.Create(R);
  MonoSel.Hide;
  Insert(MonoSel);
  R := TRect.Create(43, 2, 49, 3);
  MonoLabel := TLabel.Create(R, ColorText, MonoSel);
  MonoLabel.Hide;
  Insert(MonoLabel);

  R := TRect.Create(36, 15, 46, 17);
  Btn := TButton.Create(R, ColorOKText, cmOK, bfDefault);
  Insert(Btn);
  R := TRect.Create(48, 15, 58, 17);
  Btn := TButton.Create(R, ColorCancelText, cmCancel, bfNormal);
  Insert(Btn);
  SelectNext(False);

  GroupIndex := 0;
  if Length(Pal) > 0 then
    SetData(Pal);
end;

constructor TColorDialog.Load(S: TStream);
begin
  inherited Load(S);
  { Children are already loaded; resolve peer indexes now (TView.GetPeerViewPtr
    would only queue fixups on an enclosing owner and leave these fields nil). }
  Display := TColorDisplay(ReadChildPtr(S));
  Groups := TColorGroupList(ReadChildPtr(S));
  ForLabel := TLabel(ReadChildPtr(S));
  ForSel := TColorSelector(ReadChildPtr(S));
  BakLabel := TLabel(ReadChildPtr(S));
  BakSel := TColorSelector(ReadChildPtr(S));
  MonoLabel := TLabel(ReadChildPtr(S));
  MonoSel := TMonoSelector(ReadChildPtr(S));
  Pal := nil;
  GroupIndex := 0;
end;

procedure TColorDialog.Store(S: TStream);
begin
  inherited Store(S);
  PutPeerViewPtr(S, Display);
  PutPeerViewPtr(S, Groups);
  PutPeerViewPtr(S, ForLabel);
  PutPeerViewPtr(S, ForSel);
  PutPeerViewPtr(S, BakLabel);
  PutPeerViewPtr(S, BakSel);
  PutPeerViewPtr(S, MonoLabel);
  PutPeerViewPtr(S, MonoSel);
end;

destructor TColorDialog.Destroy;
begin
  Pal := nil;
  inherited Destroy;
end;

procedure TColorDialog.HandleEvent(var Event: TEvent);
begin
  if (Event.What = evBroadcast) and (Event.Message.Command = cmNewColorItem) then
    GroupIndex := Groups.Focused;
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Message.Command = cmNewColorIndex) and
    (Event.Message.InfoByte < Length(Pal)) then
    Display.SetColor(@Pal[Event.Message.InfoByte]);
end;

function TColorDialog.DataSize: Integer;
begin
  Result := SizeOf(TPalette);
end;

procedure TColorDialog.GetData(var Rec);
begin
  GetIndexes;
  TPalette(Rec) := Copy(Pal);
end;

procedure TColorDialog.SetData(var Rec);
begin
  Pal := Copy(TPalette(Rec));
  SetIndexes;
  { the original takes the index of the item in the group as the index of the palette }
  if Groups.GetGroupIndex(GroupIndex) < Length(Pal) then
    Display.SetColor(@Pal[Groups.GetGroupIndex(GroupIndex)]);
  Groups.FocusItem(GroupIndex);
  if ShowMarkers then
  begin
    ForLabel.Hide;
    ForSel.Hide;
    BakLabel.Hide;
    BakSel.Hide;
    MonoLabel.Show;
    MonoSel.Show;
  end;
  Groups.Select;
end;

procedure TColorDialog.SetIndexes;
var
  NumGroups, Index: Byte;
begin
  NumGroups := Groups.GetNumGroups;
  if (ColorIndexes <> nil) and (ColorIndexes^.ColorSize <> NumGroups) then
    FreeColorIndexes;
  if ColorIndexes = nil then
  begin
    New(ColorIndexes);
    FillChar(ColorIndexes^, SizeOf(TColorIndex), 0);
    ColorIndexes^.ColorSize := NumGroups;
  end;
  for Index := 0 to NumGroups - 1 do
    Groups.SetGroupIndex(Index, ColorIndexes^.ColorIndex[Index]);
  GroupIndex := ColorIndexes^.GroupIndex;
end;

procedure TColorDialog.GetIndexes;
var
  N, Index: Byte;
begin
  N := Groups.GetNumGroups;
  if ColorIndexes = nil then
  begin
    New(ColorIndexes);
    FillChar(ColorIndexes^, SizeOf(TColorIndex), 0);
    ColorIndexes^.ColorSize := N;
  end;
  ColorIndexes^.GroupIndex := GroupIndex;
  for Index := 0 to N - 1 do
    ColorIndexes^.ColorIndex[Index] := Groups.GetGroupIndex(Index);
end;

end.
