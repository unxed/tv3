{ TvHist: the history of input lines: the list of strings (HistoryAdd...), THistory (the arrow
  next to an input line), THistoryWindow, THistoryViewer.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/dialogs.h, util.h (class declarations, history functions)
    source/tvision/histlist.cpp, thistory.cpp, thistwin.cpp, thstview.cpp, tvtext1.cpp (icon)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the history is an array of records instead of a block of bytes; the behavior is the
      same: HistorySize bytes are counted as in the original (3 bytes + the length of the
      string per record) and the oldest records are dropped when the strings do not fit;
      the empty first record of the original is not needed (after it is dropped, the
      original skips the first string of its list);
    - the history is initialized and freed by the unit itself;
    - HistoryStr is a function that returns '' if there is no such string;
    - THistoryWindow gets its viewer from the virtual InitViewer;
    - streams are not translated yet. }
unit TvHist;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvText, TvDrawBuf, TvObjs, TvUtil, TvViews,
  TvDialog, TvWindow, TvList, TvInput, TvGlyphs;

var
  { the size of the history block in bytes; set it before the first HistoryAdd }
  HistorySize: Word = 1024;

procedure ClearHistory;
{ frees the memory of the history (it is empty afterwards) }
procedure DoneHistory;
function HistoryCount(Id: Byte): Integer;
procedure HistoryAdd(Id: Byte; const Str: ShortString);
function HistoryStr(Id: Byte; Index: Integer): ShortString;
{ the history in a stream (used by DN to keep it between the runs; the format is ours: the count, then the id and the
  string of every record). Load replaces the history and makes HistorySize big enough for it. }
{ drops the strings that end with the character (DN: the strings that end with a blank are not kept) }
procedure HistoryRemoveEndingWith(C: Char);
procedure HistoryStore(S: TStream);
procedure HistoryLoad(S: TStream);

const
  HistoryPalette = #$16#$17;
  HistoryWindowPalette = #$13#$13#$15#$18#$17#$13#$14;
  HistoryViewerPalette = #$06#$06#$07#$06#$06;

type
  THistoryViewer = class;
  THistoryWindow = class;
  THistory = class;

  THistoryViewer = class(TListViewer)
    HistoryId: Word;
    constructor Create(const Bounds: TRect; AHScrollBar, AVScrollBar: TScrollBar; AHistoryId: Word);
    function GetPalette: TPalette; override;
    function GetText(Item, MaxLen: Integer): ShortString; override;
    procedure HandleEvent(var Event: TEvent); override;
    function HistoryWidth: Integer;
  end;

  THistoryWindow = class(TWindow)
    Viewer: TListViewer;
    constructor Create(const Bounds: TRect; AHistoryId: Word);
    function GetPalette: TPalette; override;
    function GetSelection: ShortString;
    procedure HandleEvent(var Event: TEvent); override;
    function InitViewer(R: TRect; AHistoryId: Word): TListViewer; virtual;
  end;

  { Palette: 1 = arrow, 2 = sides }
  THistory = class(TView)
    Link: TInputLine;
    HistoryId: Word;
    constructor Create(const Bounds: TRect; ALink: TInputLine; AHistoryId: Word);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    destructor Destroy; override;
    procedure Draw; override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    function InitHistoryWindow(const Bounds: TRect): THistoryWindow; virtual;
    procedure RecordHistory(const S: ShortString); virtual;
  end;

var
  { stream records (see RView of TvViews) }
  RHistory: TStreamRec;

implementation

{ --- the history list -------------------------------------------------------- }

type
  THistRec = record
    Id: Byte;
    Str: ShortString;
  end;

var
  Recs: array of THistRec;
  RecCount: Integer = 0;
  Used: Integer = 0;          { the bytes taken by the records }
  CurId: Byte = 0;
  CurRec: Integer = -1;       { the index of the current record, -1 if none }

function RecLen(Index: Integer): Integer;
begin
  Result := Length(Recs[Index].Str) + 3;
end;

procedure ClearHistory;
begin
  SetLength(Recs, 16);
  RecCount := 0;
  Used := 0;
end;

procedure DoneHistory;
begin
  SetLength(Recs, 0);
  RecCount := 0;
  Used := 0;
end;

procedure HistoryStore(S: TStream);
var
  I: Integer;
begin
  S.Write(RecCount, SizeOf(RecCount));
  for I := 0 to RecCount - 1 do
  begin
    S.Write(Recs[I].Id, 1);
    S.WriteStr(@Recs[I].Str);
  end;
end;

procedure HistoryLoad(S: TStream);
var
  I, N: Integer;
  Id: Byte;
  T: ShortString;
begin
  S.Read(N, SizeOf(N));
  if (S.Status <> stOK) or (N < 0) or (N > 65535) then
    Exit;
  ClearHistory;
  for I := 1 to N do
  begin
    S.Read(Id, 1);
    S.ReadStrV(T);
    if S.Status <> stOK then
      Break;
    if RecCount >= Length(Recs) then
      SetLength(Recs, Length(Recs) * 2 + 16);
    Recs[RecCount].Id := Id;
    Recs[RecCount].Str := T;
    Inc(RecCount);
    Inc(Used, Length(T) + 3);
  end;
  if Used + 256 > HistorySize then
    HistorySize := Used + 256;
end;

procedure AdvanceStringPointer;
begin
  Inc(CurRec);
  while (CurRec < RecCount) and (Recs[CurRec].Id <> CurId) do
    Inc(CurRec);
  if CurRec >= RecCount then
    CurRec := -1;
end;

procedure DeleteRec(Index: Integer);
var
  I: Integer;
begin
  Dec(Used, RecLen(Index));
  for I := Index to RecCount - 2 do
    Recs[I] := Recs[I + 1];
  Dec(RecCount);
end;

procedure HistoryRemoveEndingWith(C: Char);
var
  I: Integer;
begin
  I := 0;
  while I < RecCount do
    if (Length(Recs[I].Str) > 0) and (Recs[I].Str[Length(Recs[I].Str)] = C) then
      DeleteRec(I)
    else
      Inc(I);
  CurRec := -1;
end;

procedure InsertString(Id: Byte; const Str: ShortString);
var
  Len: Integer;
begin
  Len := Length(Str) + 3;
  while (Len > HistorySize - Used) and (RecCount > 0) do
    DeleteRec(0);
  if RecCount >= Length(Recs) then
    SetLength(Recs, Length(Recs) * 2 + 16);
  Recs[RecCount].Id := Id;
  Recs[RecCount].Str := Str;
  Inc(RecCount);
  Inc(Used, Len);
end;

procedure StartId(Id: Byte);
begin
  CurId := Id;
  CurRec := -1;       { the original starts at its empty first record instead }
end;

function HistoryCount(Id: Byte): Integer;
begin
  StartId(Id);
  Result := 0;
  AdvanceStringPointer;
  while CurRec <> -1 do
  begin
    Inc(Result);
    AdvanceStringPointer;
  end;
end;

procedure HistoryAdd(Id: Byte; const Str: ShortString);
begin
  if Str = '' then
    Exit;
  StartId(Id);
  AdvanceStringPointer;
  while CurRec <> -1 do
  begin
    if Str = Recs[CurRec].Str then
      DeleteRec(CurRec);
    AdvanceStringPointer;
  end;
  InsertString(Id, Str);
end;

function HistoryStr(Id: Byte; Index: Integer): ShortString;
var
  I: Integer;
begin
  StartId(Id);
  for I := 0 to Index do
    AdvanceStringPointer;
  if CurRec <> -1 then
    Result := Recs[CurRec].Str
  else
    Result := '';
end;

{ --- THistoryViewer ---------------------------------------------------------- }

constructor THistoryViewer.Create(const Bounds: TRect; AHScrollBar, AVScrollBar: TScrollBar;
  AHistoryId: Word);
begin
  inherited Create(Bounds, 1, AHScrollBar, AVScrollBar);
  HistoryId := AHistoryId;
  SetRange(HistoryCount(HistoryId));
  { the newest string is the text of the line itself: start at the one before }
  if Range > 1 then
    FocusItem(1);
  if HScrollBar <> nil then
    HScrollBar.SetRange(0, HistoryWidth - Size.X + 3);
end;

function THistoryViewer.GetPalette: TPalette;
begin
  Result := MakePalette(HistoryViewerPalette);
end;

function THistoryViewer.GetText(Item, MaxLen: Integer): ShortString;
begin
  Result := HistoryStr(HistoryId, Item);
  if Length(Result) > MaxLen then
    SetLength(Result, MaxLen);
end;

procedure THistoryViewer.HandleEvent(var Event: TEvent);
var
  Res: Word;
begin
  Res := cmValid;
  case Event.What of
    evMouseDown:
      if (Event.Mouse.EventFlags and meDoubleClick) <> 0 then
        Res := cmOK;
    evKeyDown:
      if Event.KeyDown.KeyCode = kbEnter then
        Res := cmOK
      else if Event.KeyDown.KeyCode = kbEsc then
        Res := cmCancel;
    evCommand:
      if Event.Message.Command = cmCancel then
        Res := cmCancel;
  end;
  if Res = cmValid then
    inherited HandleEvent(Event)
  else
  begin
    EndModal(Res);
    ClearEvent(Event);
  end;
end;

function THistoryViewer.HistoryWidth: Integer;
var
  I, W: Integer;
begin
  Result := 0;
  for I := 0 to HistoryCount(HistoryId) - 1 do
  begin
    W := TText.Width(HistoryStr(HistoryId, I));
    if W > Result then
      Result := W;
  end;
end;

{ --- THistoryWindow ---------------------------------------------------------- }

constructor THistoryWindow.Create(const Bounds: TRect; AHistoryId: Word);
begin
  inherited Create(Bounds, '', wnNoNumber);
  Flags := wfClose;
  Viewer := InitViewer(GetExtent, AHistoryId);
  if Viewer <> nil then
    Insert(Viewer);
end;

function THistoryWindow.GetPalette: TPalette;
begin
  Result := MakePalette(HistoryWindowPalette);
end;

function THistoryWindow.GetSelection: ShortString;
begin
  Result := Viewer.GetText(Viewer.Focused, 255);
end;

procedure THistoryWindow.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evMouseDown) and not MouseInView(Event.Mouse.Where) then
  begin
    EndModal(cmCancel);
    ClearEvent(Event);
  end;
end;

function THistoryWindow.InitViewer(R: TRect; AHistoryId: Word): TListViewer;
begin
  R.Grow(-1, -1);
  Result := THistoryViewer.Create(R, StandardScrollBar(sbHorizontal or sbHandleKeyboard),
    StandardScrollBar(sbVertical or sbHandleKeyboard), AHistoryId);
end;

{ --- THistory ---------------------------------------------------------------- }

constructor THistory.Create(const Bounds: TRect; ALink: TInputLine; AHistoryId: Word);
begin
  inherited Create(Bounds);
  Link := ALink;
  if Link <> nil then
    Link.KeepVertical := True;   { Down opens the list }
  HistoryId := AHistoryId;
  Options := Options or ofPostProcess;
  EventMask := EventMask or evBroadcast;
end;

destructor THistory.Destroy;
begin
  Link := nil;
  inherited Destroy;
end;

procedure THistory.Draw;
var
  B: TDrawBuffer;
  Colors: TAttrPair;
begin
  Colors := GetColor($0102);
  B := TDrawBuffer.Create(Size.X);
  B.MoveCStrS(0, GlyphStr(glBlockRight) + '~' + GlyphStr(glArrowDown) + '~' + GlyphStr(glBlockLeft), Colors);
  WriteLine(0, 0, Size.X, Size.Y, B);
  B.Free;
end;

function THistory.GetPalette: TPalette;
begin
  Result := MakePalette(HistoryPalette);
end;

procedure THistory.HandleEvent(var Event: TEvent);
var
  Opens: Boolean;
  Key: Word;
  R: TRect;
  Win: THistoryWindow;
begin
  inherited HandleEvent(Event);
  Opens := Event.What = evMouseDown;
  if (Event.What = evKeyDown) and ((Link.State and sfFocused) <> 0) then
  begin
    Key := CtrlToArrow(Event.KeyDown.KeyCode);
    Opens := (Key = kbDown) or (Key = kbCtrlDown);
  end;
  if Opens then
  begin
    if Link.Focus then
    begin
      RecordHistory(Link.Data^);
      { the window covers the line and a few rows below it, inside the owner }
      R := Link.GetBounds;
      R.Grow(1, 0);
      R.A.Y := R.A.Y - 1;
      R.B.Y := R.B.Y + 7;
      R.Intersect(Owner.GetExtent);
      R.B.Y := R.B.Y - 1;
      Win := InitHistoryWindow(R);
      if Win <> nil then
      begin
        if Owner.ExecView(Win) = cmOK then
        begin
          Link.Data^ := Copy(Win.GetSelection, 1, Link.MaxLen);
          Link.SelectAll(True);
          Link.DrawView;
        end;
        Win.Free;
      end;
    end;
    ClearEvent(Event);
  end
  else if Event.What = evBroadcast then
    if (Event.Message.Command = cmRecordHistory)
      or ((Event.Message.Command = cmReleasedFocus) and (Event.Message.InfoPtr = Pointer(Link))) then
      RecordHistory(Link.Data^);
end;

function THistory.InitHistoryWindow(const Bounds: TRect): THistoryWindow;
begin
  Result := THistoryWindow.Create(Bounds, HistoryId);
  Result.HelpCtx := Link.HelpCtx;
end;

procedure THistory.RecordHistory(const S: ShortString);
begin
  HistoryAdd(Byte(HistoryId), S);
end;

{ --- Streams ------------------------------------------------------------------ }

constructor THistory.Load(S: TStream);
var
  Id: Word;
begin
  inherited Load(S);
  S.Read(Id, 2);
  HistoryId := Id;
  { the input line is a view of the same owner }
  GetPeerViewPtr(S, Link);
end;

procedure THistory.Store(S: TStream);
var
  Id: Word;
begin
  inherited Store(S);
  Id := HistoryId;
  S.Write(Id, 2);
  PutPeerViewPtr(S, Link);
end;

function BuildHistory(S: TStream): TStreamable;
begin
  Result := TStreamable(Pointer(THistory.Load(S)));
end;

procedure StoreHistory(P: TStreamable; S: TStream);
begin
  THistory(Pointer(P)).Store(S);
end;


initialization
  RHistory.ObjType := 22;
  RHistory.VmtLink := PtrUInt(System.TClass(THistory));
  RHistory.Load := @BuildHistory;
  RHistory.Store := @StoreHistory;
  ClearHistory;
finalization
  DoneHistory;
end.
