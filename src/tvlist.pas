{ TvList: TListViewer and TListBox.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/views.h, dialogs.h (class declarations, TListBoxRec)
    source/tvision/tlstview.cpp, tlistbox.cpp, tvtext2.cpp (emptyText)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - GetText is a function that returns a ShortString (255 characters at most);
    - Done replaces shutDown (it clears the pointers to the scroll bars);
    - the items of TListBox are PStr (as in TStringCollection);
    - streams are not translated yet. }
unit TvList;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvDrawBuf, TvObjs, TvUtil, TvViews, TvDialog,
  TvWindow, TvGlyphs;

const
  EmptyText = '<empty>';

type
  { Palette: 1 = active, 2 = inactive, 3 = focused, 4 = selected, 5 = divider }
  TListViewer = class;
  TListBox = class;
  TListViewer = class(TView)
    HScrollBar: TScrollBar;
    VScrollBar: TScrollBar;
    NumCols: Integer;
    TopItem: Integer;
    Focused: Integer;
    Range: Integer;
    constructor Create(const Bounds: TRect; ANumCols: Integer; AHScrollBar, AVScrollBar: TScrollBar);
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    destructor Destroy; override;
    procedure ChangeBounds(const Bounds: TRect); override;
    procedure Draw; override;
    procedure FocusItem(Item: Integer); virtual;
    procedure FocusItemNum(Item: Integer);
    function GetPalette: TPalette; override;
    function GetText(Item, MaxLen: Integer): ShortString; virtual;
    function IsSelected(Item: Integer): Boolean; virtual;
    procedure HandleEvent(var Event: TEvent); override;
    procedure SelectItem(Item: Integer); virtual;
    procedure SetRange(ARange: Integer);
    procedure SetState(AState: Word; Enable: Boolean); override;
  end;

  { the data record of a list box: the collection (owned by the list box after SetData)
    and the number of the selected item }
  PListBoxRec = ^TListBoxRec;
  TListBoxRec = record
    Items: TCollection;
    Selection: Word;
  end;

  TListBox = class(TListViewer)
    Items: TCollection;
    function List: TCollection;
    constructor Create(const Bounds: TRect; ANumCols: Integer; AScrollBar: TScrollBar);
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    destructor Destroy; override;
    function DataSize: Integer; override;
    procedure GetData(var Rec); override;
    function GetText(Item, MaxLen: Integer): ShortString; override;
    procedure NewList(AList: TCollection);
    procedure SetData(var Rec); override;
    { Free Vision extensions: the focused item itself, not its index. }
    function GetFocusedItem: Pointer;
    procedure SetFocusedItem(Item: Pointer);
  end;

const
  ListViewerPalette = #$1A#$1A#$1B#$1C#$1D;

var
  { UX guidelines L.2: Home and End go to the first and the last item of the list. False (the default, Turbo Vision): to the first and the last row shown;
    Ctrl+PgUp and Ctrl+PgDn go to the first and the last item. The default is not changed: lists of the applications built on tv3 rely on it. }
  UxListHomeEnd: Boolean = False;
  { stream records (see RView of TvViews) }
  RListViewer, RListBox: TStreamableClass;
  { TListBox.Done disposes the list (as in Turbo Vision); the fork of the application does not and its code disposes the list itself
    (TSysDialog.Done): the application sets False }
  ListBoxOwnsList: Boolean = True;

implementation

const
  MouseAutosToSkip = 4;

{ --- TListViewer ------------------------------------------------------------- }

constructor TListViewer.Create(const Bounds: TRect; ANumCols: Integer; AHScrollBar,
  AVScrollBar: TScrollBar);
begin
  inherited Create(Bounds);
  NumCols := ANumCols;
  TopItem := 0;
  Focused := 0;
  Range := 0;
  Options := Options or ofFirstClick or ofSelectable;
  EventMask := EventMask or evBroadcast;
  HScrollBar := AHScrollBar;
  VScrollBar := AVScrollBar;
  if VScrollBar <> nil then
  begin
    { one column scrolls by rows, several columns by whole columns }
    if NumCols = 1 then
      VScrollBar.SetStep(Size.Y - 1, 1)
    else
      VScrollBar.SetStep(Size.Y * NumCols, Size.Y);
  end;
  if HScrollBar <> nil then
    HScrollBar.SetStep(Size.X div NumCols, 1);
end;

destructor TListViewer.Destroy;
begin
  HScrollBar := nil;
  VScrollBar := nil;
  inherited Destroy;
end;

procedure TListViewer.ChangeBounds(const Bounds: TRect);
begin
  inherited ChangeBounds(Bounds);
  if HScrollBar <> nil then
    HScrollBar.SetStep(Size.X div NumCols, HScrollBar.ArStep);
  if VScrollBar <> nil then
    VScrollBar.SetStep(Size.Y, VScrollBar.ArStep);
end;

procedure TListViewer.Draw;
var
  B: TDrawBuffer;
  Active, CursorShown: Boolean;
  CNormal, CFocused, CSelected, C: TColorAttr;
  ColWidth, Indent, Row, Col, X, Item, Marker: Integer;
begin
  Active := (State and (sfSelected or sfActive)) = (sfSelected or sfActive);
  CSelected := GetColor(4)[0];
  if Active then
  begin
    CNormal := GetColor(1)[0];
    CFocused := GetColor(3)[0];
  end
  else
  begin
    CNormal := GetColor(2)[0];
    CFocused := CNormal;
  end;
  Indent := 0;
  if HScrollBar <> nil then
    Indent := HScrollBar.Value;
  ColWidth := Size.X div NumCols + 1;
  CursorShown := False;
  B := TDrawBuffer.Create(Size.X + ColWidth);
  for Row := 0 to Size.Y - 1 do
  begin
    for Col := 0 to NumCols - 1 do
    begin
      Item := TopItem + Col * Size.Y + Row;
      X := Col * ColWidth;
      if Active and (Item = Focused) and (Range > 0) then
      begin
        C := CFocused;
        Marker := 0;
        SetCursor(X + 1, Row);
        CursorShown := True;
      end
      else if (Item >= 0) and (Item < Range) and IsSelected(Item) then
      begin
        C := CSelected;
        Marker := 2;
      end
      else
      begin
        C := CNormal;
        Marker := 4;
      end;
      B.MoveChar(X, Ord(' '), C, ColWidth);
      if (Item >= 0) and (Item < Range) then
      begin
        if Indent < 255 then
          B.MoveStrS(X + 1, GetText(Item, 255), C, ColWidth, Indent);
        if ShowMarkers then
        begin
          B.PutChar(X, SpecialChars[Marker]);
          B.PutChar(X + ColWidth - 2, SpecialChars[Marker + 1]);
        end;
      end
      else if (Row = 0) and (Col = 0) then
        B.MoveStrS(X + 1, EmptyText, GetColor(1)[0]);
      B.MoveGlyph(X + ColWidth - 1, glLightV, GetColor(5)[0], 1);
    end;
    WriteLine(0, Row, Size.X, 1, B);
  end;
  B.Free;
  if not CursorShown then
    SetCursor(-1, -1);
end;

procedure TListViewer.FocusItem(Item: Integer);
var
  Page, ColTop: Integer;
begin
  Focused := Item;
  if VScrollBar <> nil then
    VScrollBar.SetValue(Item)
  else
    DrawView;
  if Size.Y <= 0 then
    Exit;
  Page := Size.Y * NumCols;
  { scroll so that the item is shown; with several columns the top item
    stays at the start of a column }
  if NumCols = 1 then
  begin
    if Item < TopItem then
      TopItem := Item
    else if Item >= TopItem + Size.Y then
      TopItem := Item - Size.Y + 1;
  end
  else
  begin
    ColTop := Item - Item mod Size.Y;
    if Item < TopItem then
      TopItem := ColTop
    else if Item >= TopItem + Page then
      TopItem := ColTop + Size.Y - Page;
  end;
end;

procedure TListViewer.FocusItemNum(Item: Integer);
begin
  if Range = 0 then
    Exit;
  if Item < 0 then
    Item := 0
  else if Item >= Range then
    Item := Range - 1;
  FocusItem(Item);
end;

function TListViewer.GetPalette: TPalette;
begin
  Result := TPalette.Create(ListViewerPalette, Length(ListViewerPalette));
end;

function TListViewer.GetText(Item, MaxLen: Integer): ShortString;
begin
  Result := '';
end;

function TListViewer.IsSelected(Item: Integer): Boolean;
begin
  Result := Item = Focused;
end;

procedure TListViewer.HandleEvent(var Event: TEvent);
var
  NewItem: Integer;
  Key: Word;

  procedure Jump(Item: Integer);
  begin
    FocusItemNum(Item);
    DrawView;
  end;

  { the item to go to when the mouse is outside the view (auto events) }
  function Outside(const M: TPoint; Item: Integer): Integer;
  var
    ColTop: Integer;
  begin
    Result := Item;
    ColTop := Focused - Focused mod Size.Y;
    if NumCols = 1 then
    begin
      if M.Y < 0 then
        Result := Focused - 1
      else if M.Y >= Size.Y then
        Result := Focused + 1;
    end
    else if (M.X < 0) or (M.X >= Size.X) then
    begin
      { beside the view: a column to the left or to the right }
      if M.X < 0 then
        Result := Focused - Size.Y
      else
        Result := Focused + Size.Y;
    end
    else if M.Y < 0 then
      Result := ColTop
    else if M.Y > Size.Y then
      Result := ColTop + Size.Y - 1;
  end;

  procedure TrackMouse;
  var
    M: TPoint;
    ColWidth, Shown, Autos: Integer;
    Double: Boolean;
  begin
    ColWidth := Size.X div NumCols + 1;
    Shown := Focused;
    NewItem := 0;
    Autos := 0;
    repeat
      M := MakeLocal(Event.Mouse.Where);
      if MouseInView(Event.Mouse.Where) then
        NewItem := TopItem + Size.Y * (M.X div ColWidth) + M.Y
      else
      begin
        { outside the view only every few auto events scroll }
        if Event.What = evMouseAuto then
          Inc(Autos);
        if Autos = MouseAutosToSkip then
        begin
          Autos := 0;
          NewItem := Outside(M, NewItem);
        end;
      end;
      if Shown <> NewItem then
      begin
        Shown := NewItem;
        Jump(NewItem);
      end;
      Double := (Event.Mouse.EventFlags and meDoubleClick) <> 0;
    until Double or not MouseEvent(Event, evMouseMove or evMouseAuto);
    Jump(NewItem);
    if Double and (NewItem < Range) then
      SelectItem(NewItem);
  end;

  { the item a key moves to; False when the key is not for the list }
  function KeyTarget(K: Word; out Item: Integer): Boolean;
  var
    Page: Integer;
  begin
    Result := True;
    Page := Size.Y * NumCols;
    if UxListHomeEnd and (K = kbHome) then
      K := kbCtrlPgUp
    else if UxListHomeEnd and (K = kbEnd) then
      K := kbCtrlPgDn;
    case K of
      kbUp: Item := Focused - 1;
      kbDown: Item := Focused + 1;
      kbLeft: Item := Focused - Size.Y;
      kbRight: Item := Focused + Size.Y;
      kbPgUp: Item := Focused - Page;
      kbPgDn: Item := Focused + Page;
      kbHome: Item := TopItem;
      kbEnd: Item := TopItem + Page - 1;
      kbCtrlPgUp: Item := 0;
      kbCtrlPgDn: Item := Range - 1;
    else
      Result := False;
    end;
    { Left and Right move between columns only }
    if ((K = kbLeft) or (K = kbRight)) and (NumCols <= 1) then
      Result := False;
  end;

  function FromBar(Bar: TScrollBar): Boolean;
  begin
    Result := (Bar <> nil) and (Event.Message.InfoPtr = Pointer(Bar));
  end;

begin
  inherited HandleEvent(Event);
  case Event.What of
    evMouseDown:
      begin
        TrackMouse;
        ClearEvent(Event);
      end;
    evKeyDown:
      begin
        if (Event.KeyDown.CharScan.CharCode = Ord(' ')) and (Focused < Range) then
        begin
          SelectItem(Focused);
          Jump(Focused);
          ClearEvent(Event);
          Exit;
        end;
        Key := CtrlToArrow(Event.KeyDown.KeyCode);
        if not KeyTarget(Key, NewItem) then
          Exit;
        { an arrow key that would leave the items passes the focus on (in a dialog) }
        if ((Key = kbUp) or (Key = kbDown) or (Key = kbLeft) or (Key = kbRight))
          and ((NewItem < 0) or (NewItem >= Range))
          and UxPassFocus(Self, (Key = kbDown) or (Key = kbRight)) then
        begin
          ClearEvent(Event);
          Exit;
        end;
        Jump(NewItem);
        ClearEvent(Event);
      end;
    evBroadcast:
      if (Options and ofSelectable) <> 0 then
      begin
        if FromBar(VScrollBar) then
        begin
          if Event.Message.Command = cmScrollBarClicked then
            Select
          else if Event.Message.Command = cmScrollBarChanged then
            Jump(VScrollBar.Value);
        end
        else if FromBar(HScrollBar) then
        begin
          if Event.Message.Command = cmScrollBarClicked then
            Select
          else if Event.Message.Command = cmScrollBarChanged then
            DrawView;
        end;
      end;
  end;
end;

procedure TListViewer.SelectItem(Item: Integer);
begin
  Message(Owner, evBroadcast, cmListItemSelected, Self);
end;

procedure TListViewer.SetRange(ARange: Integer);
begin
  Range := ARange;
  if Focused >= ARange then
    Focused := 0;
  if VScrollBar <> nil then
    VScrollBar.SetParams(Focused, 0, ARange - 1, VScrollBar.PgStep, VScrollBar.ArStep)
  else
    DrawView;
end;

procedure TListViewer.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if (AState and (sfSelected or sfActive or sfVisible)) <> 0 then
  begin
    if HScrollBar <> nil then
    begin
      if GetState(sfActive) and GetState(sfVisible) then
        HScrollBar.Show
      else
        HScrollBar.Hide;
    end;
    if VScrollBar <> nil then
    begin
      if GetState(sfActive) and GetState(sfVisible) then
        VScrollBar.Show
      else
        VScrollBar.Hide;
    end;
    DrawView;
  end;
end;

{ --- TListBox ---------------------------------------------------------------- }

constructor TListBox.Create(const Bounds: TRect; ANumCols: Integer; AScrollBar: TScrollBar);
begin
  inherited Create(Bounds, ANumCols, nil, AScrollBar);
  Items := nil;
  SetRange(0);
end;

destructor TListBox.Destroy;
begin
  if (Items <> nil) and ListBoxOwnsList then
    Items.Free;
  Items := nil;
  inherited Destroy;
end;

function TListBox.DataSize: Integer;
begin
  Result := SizeOf(TListBoxRec);
end;

procedure TListBox.GetData(var Rec);
begin
  TListBoxRec(Rec).Items := Items;
  TListBoxRec(Rec).Selection := Focused;
end;

function TListBox.GetText(Item, MaxLen: Integer): ShortString;
begin
  if Items <> nil then
  begin
    Result := PStr(Items.At(Item))^;
    if Length(Result) > MaxLen then
      SetLength(Result, MaxLen);
  end
  else
    Result := '';
end;

function TListBox.GetFocusedItem: Pointer;
begin
  if (Items <> nil) and (Focused >= 0) and (Focused < Items.Count) then
    Result := Items.At(Focused)
  else
    Result := nil;
end;

procedure TListBox.SetFocusedItem(Item: Pointer);
var
  I: Integer;
begin
  if (Items = nil) or (Item = nil) then Exit;
  I := Items.IndexOf(Item);
  if I >= 0 then
    FocusItem(I);
end;

function TListBox.List: TCollection;
begin
  Result := Items;
end;

procedure TListBox.NewList(AList: TCollection);
begin
  if Items <> nil then
    Items.Free;
  Items := AList;
  if AList <> nil then
    SetRange(AList.Count)
  else
    SetRange(0);
  if Range > 0 then
    FocusItem(0);
  DrawView;
end;

procedure TListBox.SetData(var Rec);
var
  D: PListBoxRec;
begin
  D := @Rec;
  NewList(D^.Items);
  FocusItem(D^.Selection);
  DrawView;
end;

{ --- Streams ------------------------------------------------------------------ }

procedure TListViewer.Write(Os: opstream);
var
  N: SmallInt;
begin
  inherited Write(Os);
  Os.WritePointer(HScrollBar);
  Os.WritePointer(VScrollBar);
  N := NumCols;
  Os.WriteBytes(N, SizeOf(SmallInt));
  N := TopItem;
  Os.WriteBytes(N, SizeOf(SmallInt));
  N := Focused;
  Os.WriteBytes(N, SizeOf(SmallInt));
  N := Range;
  Os.WriteBytes(N, SizeOf(SmallInt));
end;

function TListViewer.Read(Ip: ipstream): Pointer;
var
  N: SmallInt;
begin
  inherited Read(Ip);
  HScrollBar := TScrollBar(Ip.ReadPointer);
  VScrollBar := TScrollBar(Ip.ReadPointer);
  Ip.ReadBytes(N, SizeOf(SmallInt));
  NumCols := N;
  Ip.ReadBytes(N, SizeOf(SmallInt));
  TopItem := N;
  Ip.ReadBytes(N, SizeOf(SmallInt));
  Focused := N;
  Ip.ReadBytes(N, SizeOf(SmallInt));
  Range := N;
  Result := Self;
end;

class function TListViewer.Build: TStreamable;
begin
  Result := TListViewer.Create(streamableInit);
end;

constructor TListViewer.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TListViewer.StreamableName: ShortString;
begin
  Result := 'TListViewer';
end;

procedure TListBox.Write(Os: opstream);
begin
  inherited Write(Os);
  Os.WritePointer(Items);
end;

function TListBox.Read(Ip: ipstream): Pointer;
begin
  inherited Read(Ip);
  Items := TCollection(Ip.ReadPointer);
  Result := Self;
end;

class function TListBox.Build: TStreamable;
begin
  Result := TListBox.Create(streamableInit);
end;

constructor TListBox.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TListBox.StreamableName: ShortString;
begin
  Result := 'TListBox';
end;

initialization
  RListViewer := TStreamableClass.Create('TListViewer', @TListViewer.Build);
  RListBox := TStreamableClass.Create('TListBox', @TListBox.Build);

end.
