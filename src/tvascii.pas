{ TvAscii: a table of characters. A window (TAsciiChart) holds the table (TAsciiTable: 256 codes in 8 rows of 32,
  the cursor is the current code) and a report line under it (TAsciiReport: the character and its code in decimal and
  in hexadecimal, or as U+XXXX).

  MIT (see LICENSE).

  Two modes:
    code page (the default): the codes 0..255 are bytes and are shown through the code page of the screen;
    Unicode (Unicode = True): the table shows a block of 256 code points (Block * 256 .. Block * 256 + 255), the keys
      Ctrl+PgUp and Ctrl+PgDn go to the previous and the next block.
  CharText (a field of the table, AsciiCharText for the new tables) gives the text of a cell for a code, so that a
  program can show its own code page or its own glyphs; AsciiPalette is the palette of the table and of the report.

  Keys: the arrows, Home and End (the row), PgUp and PgDn (the column), Ctrl+Home and Ctrl+End (the first and the last
  code), Ctrl+Left and Ctrl+Right (5 columns); Enter, a double click or a typed character (TypePicks) picks the code.
  A subclass changes the keys by KeyAction and TypedCode.

  Messages (AsciiCommandBase + ...): acFocused is broadcast to the owner of the table when the cursor moves (InfoPtr =
  the table; the report follows it), acPicked is sent to the owner as a command when a code is picked (InfoPtr = the
  code). OnPick is called before. }
unit TvAscii;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvEvents, TvKeys, TvDrawBuf, TvObjs, TvViews, TvWindow;

const
  AsciiCols = 32;
  AsciiRows = 8;
  AsciiCells = AsciiCols * AsciiRows;
  AsciiMaxBlock = $10FFFF div AsciiCells;

  { offsets from AsciiCommandBase }
  acFocused = 0;
  acPicked = 1;

type
  TAsciiTable = class;

  { the text of the cell of a code: one byte (shown through the code page) or the UTF-8 of one character of one column }
  TAsciiCharText = function(Code: LongInt): AnsiString;
  TAsciiPickEvent = procedure(Sender: TAsciiTable; Code: LongInt) of object;

  TAsciiKey = (akNone, akLeft, akRight, akUp, akDown, akRowStart, akRowEnd, akColTop, akColBottom, akFirst, akLast,
    akUp2, akDown2, akLeft5, akRight5, akPrevBlock, akNextBlock, akPick);

  { Palette: 1 = the characters, 2 = the cell under the cursor (MarkCursor). Data (GetData, SetData): the code, a LongInt. }
  TAsciiTable = class(TView)
    Unicode: Boolean;
    Block: LongInt;
    { a typed character moves the cursor to its code and picks it }
    TypePicks: Boolean;
    { the cell under the cursor is drawn in color 2 (the hardware cursor is shown as well) }
    MarkCursor: Boolean;
    CharText: TAsciiCharText;
    OnPick: TAsciiPickEvent;
    constructor Create(const Bounds: TRect);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    function GetPalette: TPalette; override;
    procedure Draw; override;
    procedure HandleEvent(var Event: TEvent); override;
    function KeyAction(var Event: TEvent): TAsciiKey; virtual;
    { the code of a typed character, -1 when the key is not a character }
    function TypedCode(var Event: TEvent): LongInt; virtual;
    function Code: LongInt;
    { the cursor goes to Code (and to its block in the Unicode mode); the owner is told }
    procedure SetCode(ACode: LongInt);
    function CellText(ACode: LongInt): AnsiString;
    procedure Pick; virtual;
    procedure Focused; virtual;
    function DataSize: Integer; override;
    procedure GetData(var Rec); override;
    procedure SetData(var Rec); override;
  end;

  { Palette: 1 = the text, 2 = the character. }
  TAsciiReport = class(TView)
    Code: LongInt;
    Unicode: Boolean;
    CharStr: AnsiString;
    constructor Create(const Bounds: TRect);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    function GetPalette: TPalette; override;
    procedure Draw; override;
    procedure HandleEvent(var Event: TEvent); override;
    { the line without the character: Prefix + character + Rest }
    procedure ReportParts(out Prefix, Rest: AnsiString); virtual;
    procedure ShowCode(Table: TAsciiTable);
  end;

  TAsciiChart = class(TWindow)
    Table: TAsciiTable;
    Report: TAsciiReport;
    constructor Create(const ATitle: ShortString = 'ASCII Table'; AUnicode: Boolean = False);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    { the views; a subclass makes its own (e.g. with the key codes of its application) }
    function MakeTable(const Bounds: TRect): TAsciiTable; virtual;
    function MakeReport(const Bounds: TRect): TAsciiReport; virtual;
  end;

{ the text of a cell in the code page mode: the code as one byte }
function AsciiCodePageText(Code: LongInt): AnsiString;
{ the text of a cell in the Unicode mode: the UTF-8 of the code point; the control characters 0..31 and 127 as bytes
  (the screen shows the glyphs of the code page), a code point that has no glyph of one column as a space }
function AsciiUnicodeText(Code: LongInt): AnsiString;

var
  AsciiCommandBase: Word = 910;
  AsciiPalette: ShortString = #6#7;
  { the CharText of a new table; nil: AsciiCodePageText or AsciiUnicodeText by the mode }
  AsciiCharText: TAsciiCharText = nil;
  RAsciiTable, RAsciiReport, RAsciiChart: TStreamRec;

implementation

uses
  SysUtils, TvUtf8;

function AsciiCodePageText(Code: LongInt): AnsiString;
begin
  Result := Chr(Code and $FF);
end;

function AsciiUnicodeText(Code: LongInt): AnsiString;
begin
  if (Code < 32) or (Code = 127) then
    Exit(Chr(Code));
  if ((Code >= $80) and (Code < $A0)) or ((Code >= $D800) and (Code <= $DFFF)) or (Code > $10FFFF) or
    (CharWidth(Code) <> 1) then
    Exit(' ');
  SetLength(Result, 4);
  SetLength(Result, Utf8Encode(Code, PByte(PAnsiChar(Result))));
end;

function BlockOf(Code: LongInt): LongInt;
begin
  Result := Code div AsciiCells;
end;

{ --- TAsciiTable --- }

constructor TAsciiTable.Create(const Bounds: TRect);
begin
  inherited Create(Bounds);
  Options := Options or ofSelectable;
  EventMask := EventMask or evMouseMove;
  TypePicks := True;
  MarkCursor := True;
  CharText := AsciiCharText;
  BlockCursor;
  ShowCursor;
end;

constructor TAsciiTable.Load(S: TStream);
var
  B: Byte;
begin
  inherited Load(S);
  S.Read(Block, SizeOf(Block));
  S.Read(B, 1);
  Unicode := (B and 1) <> 0;
  TypePicks := (B and 2) <> 0;
  MarkCursor := (B and 4) <> 0;
  CharText := AsciiCharText;
end;

procedure TAsciiTable.Store(S: TStream);
var
  B: Byte;
begin
  inherited Store(S);
  S.Write(Block, SizeOf(Block));
  B := Ord(Unicode) or (Ord(TypePicks) shl 1) or (Ord(MarkCursor) shl 2);
  S.Write(B, 1);
end;

function TAsciiTable.GetPalette: TPalette;
begin
  Result := MakePalette(AsciiPalette);
end;

function TAsciiTable.CellText(ACode: LongInt): AnsiString;
begin
  if Assigned(CharText) then
    Result := CharText(ACode)
  else if Unicode then
    Result := AsciiUnicodeText(ACode)
  else
    Result := AsciiCodePageText(ACode);
end;

function TAsciiTable.Code: LongInt;
begin
  Result := Block * AsciiCells + Cursor.Y * AsciiCols + Cursor.X;
  if not Unicode then
    Result := Result and $FF;
end;

procedure TAsciiTable.Draw;
var
  B: TDrawBuffer;
  Normal, Marked, A: TColorAttr;
  X, Y: Integer;
  T: AnsiString;
begin
  Normal := GetColor(1)[0];
  Marked := GetColor(2)[0];
  B := TDrawBuffer.Create(Size.X);
  try
    for Y := 0 to Size.Y - 1 do
    begin
      B.MoveChar(0, Ord(' '), Normal, Size.X);
      if Y < AsciiRows then
        for X := 0 to AsciiCols - 1 do
        begin
          if X >= Size.X then
            Break;
          if MarkCursor and (X = Cursor.X) and (Y = Cursor.Y) then
            A := Marked
          else
            A := Normal;
          if Unicode then
            T := CellText(Block * AsciiCells + Y * AsciiCols + X)
          else
            T := CellText(Y * AsciiCols + X);
          if Length(T) = 1 then
            B.MoveChar(X, Ord(T[1]), A, 1)
          else
          begin
            B.MoveChar(X, Ord(' '), A, 1);
            if T <> '' then
              B.MoveStr(X, @T[1], Length(T), A, 1);
          end;
        end;
      WriteLine(0, Y, Size.X, 1, B);
    end;
  finally
    B.Free;
  end;
end;

procedure TAsciiTable.Focused;
begin
  if Owner <> nil then
    Message(Owner, evBroadcast, AsciiCommandBase + acFocused, Self);
end;

procedure TAsciiTable.Pick;
var
  C: LongInt;
begin
  C := Code;
  if Assigned(OnPick) then
    OnPick(Self, C);
  if Owner <> nil then
    Message(Owner, evCommand, AsciiCommandBase + acPicked, Pointer(PtrInt(C)));
end;

procedure TAsciiTable.SetCode(ACode: LongInt);
begin
  if ACode < 0 then
    ACode := 0;
  if Unicode then
  begin
    if ACode > $10FFFF then
      ACode := $10FFFF;
    Block := BlockOf(ACode);
  end
  else
    ACode := ACode and $FF;
  SetCursor((ACode mod AsciiCells) mod AsciiCols, (ACode mod AsciiCells) div AsciiCols);
  DrawView;
  Focused;
end;

function TAsciiTable.KeyAction(var Event: TEvent): TAsciiKey;
begin
  case Event.KeyDown.KeyCode of
    kbLeft: Result := akLeft;
    kbRight: Result := akRight;
    kbUp: Result := akUp;
    kbDown: Result := akDown;
    kbHome: Result := akRowStart;
    kbEnd: Result := akRowEnd;
    kbPgUp: Result := akColTop;
    kbPgDn: Result := akColBottom;
    kbCtrlHome: Result := akFirst;
    kbCtrlEnd: Result := akLast;
    kbCtrlLeft: Result := akLeft5;
    kbCtrlRight: Result := akRight5;
    kbCtrlPgUp: Result := akPrevBlock;
    kbCtrlPgDn: Result := akNextBlock;
    kbEnter: Result := akPick;
  else
    Result := akNone;
  end;
end;

function TAsciiTable.TypedCode(var Event: TEvent): LongInt;
var
  Cp: LongWord;
  Used: Integer;
begin
  Result := -1;
  if Unicode then
  begin
    if (Event.KeyDown.TextLength > 0) and Utf8Decode(@Event.KeyDown.Text[0], Event.KeyDown.TextLength, Cp, Used) and (Cp >= 32) then
      Result := Cp;
  end
  else if Event.KeyDown.CharScan.CharCode >= 32 then
    Result := Event.KeyDown.CharScan.CharCode;
end;

procedure TAsciiTable.HandleEvent(var Event: TEvent);

  procedure MoveTo(X, Y: Integer);
  begin
    if X < 0 then
      X := 0;
    if X > AsciiCols - 1 then
      X := AsciiCols - 1;
    if Y < 0 then
      Y := 0;
    if Y > AsciiRows - 1 then
      Y := AsciiRows - 1;
    if (X <> Cursor.X) or (Y <> Cursor.Y) then
    begin
      SetCursor(X, Y);
      if MarkCursor then
        DrawView;
    end;
    Focused;
  end;

  procedure ToBlock(NewBlock: LongInt);
  begin
    if not Unicode or (NewBlock < 0) or (NewBlock > AsciiMaxBlock) then
      Exit;
    Block := NewBlock;
    DrawView;
    Focused;
  end;

var
  P: TPoint;
  C: LongInt;
begin
  inherited HandleEvent(Event);
  case Event.What of
    evMouseDown:
      begin
        if (Event.Mouse.EventFlags and meDoubleClick) <> 0 then
        begin
          if MouseInView(Event.Mouse.Where) then
          begin
            P := MakeLocal(Event.Mouse.Where);
            MoveTo(P.X, P.Y);
          end;
          Pick;
          ClearEvent(Event);
          Exit;
        end;
        repeat
          if MouseInView(Event.Mouse.Where) then
          begin
            P := MakeLocal(Event.Mouse.Where);
            MoveTo(P.X, P.Y);
          end;
        until not MouseEvent(Event, evMouseMove);
        ClearEvent(Event);
      end;
    evKeyDown:
      begin
        case KeyAction(Event) of
          akLeft: MoveTo(Cursor.X - 1, Cursor.Y);
          akRight: MoveTo(Cursor.X + 1, Cursor.Y);
          akUp: MoveTo(Cursor.X, Cursor.Y - 1);
          akDown: MoveTo(Cursor.X, Cursor.Y + 1);
          akRowStart: MoveTo(0, Cursor.Y);
          akRowEnd: MoveTo(AsciiCols - 1, Cursor.Y);
          akColTop: MoveTo(Cursor.X, 0);
          akColBottom: MoveTo(Cursor.X, AsciiRows - 1);
          akFirst: MoveTo(0, 0);
          akLast: MoveTo(AsciiCols - 1, AsciiRows - 1);
          akUp2: MoveTo(Cursor.X, Cursor.Y - 2);
          akDown2: MoveTo(Cursor.X, Cursor.Y + 2);
          akLeft5: MoveTo(Cursor.X - 5, Cursor.Y);
          akRight5: MoveTo(Cursor.X + 5, Cursor.Y);
          akPrevBlock: ToBlock(Block - 1);
          akNextBlock: ToBlock(Block + 1);
          akPick: Pick;
        else
          begin
            if not TypePicks then
              Exit;
            C := TypedCode(Event);
            if (C < 0) or (Unicode and (C > $10FFFF)) or (not Unicode and (C > 255)) then
              Exit;
            SetCode(C);
            Pick;
          end;
        end;
        ClearEvent(Event);
      end;
  end;
end;

function TAsciiTable.DataSize: Integer;
begin
  Result := SizeOf(LongInt);
end;

procedure TAsciiTable.GetData(var Rec);
begin
  LongInt(Rec) := Code;
end;

procedure TAsciiTable.SetData(var Rec);
begin
  SetCode(LongInt(Rec));
end;

{ --- TAsciiReport --- }

constructor TAsciiReport.Create(const Bounds: TRect);
begin
  inherited Create(Bounds);
  EventMask := EventMask or evBroadcast;
end;

constructor TAsciiReport.Load(S: TStream);
var
  B: Byte;
begin
  inherited Load(S);
  S.Read(Code, SizeOf(Code));
  S.Read(B, 1);
  Unicode := B <> 0;
  if Assigned(AsciiCharText) then
    CharStr := AsciiCharText(Code)
  else if Unicode then
    CharStr := AsciiUnicodeText(Code)
  else
    CharStr := AsciiCodePageText(Code);
end;

procedure TAsciiReport.Store(S: TStream);
var
  B: Byte;
begin
  inherited Store(S);
  S.Write(Code, SizeOf(Code));
  B := Ord(Unicode);
  S.Write(B, 1);
end;

function TAsciiReport.GetPalette: TPalette;
begin
  Result := MakePalette(AsciiPalette);
end;

procedure TAsciiReport.ReportParts(out Prefix, Rest: AnsiString);
begin
  Prefix := ' Char: ';
  if Unicode then
    Rest := Format('  Dec: %d  U+%.4X', [Code, Code])
  else
    Rest := Format('  Dec: %3d  Hex: %.2X', [Code, Code]);
end;

procedure TAsciiReport.Draw;
var
  B: TDrawBuffer;
  Normal, Value: TColorAttr;
  Prefix, Rest: AnsiString;
  X: Integer;
begin
  Normal := GetColor(1)[0];
  Value := GetColor(2)[0];
  ReportParts(Prefix, Rest);
  B := TDrawBuffer.Create(Size.X);
  try
    B.MoveChar(0, Ord(' '), Normal, Size.X);
    X := B.MoveStr(0, @Prefix[1], Length(Prefix), Normal, Size.X);
    if X < Size.X then
    begin
      if Length(CharStr) = 1 then
      begin
        if CharStr[1] <> #0 then
          B.MoveChar(X, Ord(CharStr[1]), Value, 1)
        else
          B.MoveChar(X, Ord(' '), Value, 1);
      end
      else if CharStr <> '' then
        B.MoveStr(X, @CharStr[1], Length(CharStr), Value, 1);
      Inc(X);
      if (X < Size.X) and (Rest <> '') then
        B.MoveStr(X, @Rest[1], Length(Rest), Normal, Size.X - X);
    end;
    WriteLine(0, 0, Size.X, 1, B);
  finally
    B.Free;
  end;
end;

procedure TAsciiReport.ShowCode(Table: TAsciiTable);
begin
  Code := Table.Code;
  Unicode := Table.Unicode;
  CharStr := Table.CellText(Code);
  DrawView;
end;

procedure TAsciiReport.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Message.Command = AsciiCommandBase + acFocused) and
    (TObject(Event.Message.InfoPtr) is TAsciiTable) then
    ShowCode(TAsciiTable(Event.Message.InfoPtr));
end;

{ --- TAsciiChart --- }

constructor TAsciiChart.Create(const ATitle: ShortString; AUnicode: Boolean);
var
  R, T: TRect;
begin
  R := TRect.Create(0, 0, AsciiCols + 2, AsciiRows + 4);
  inherited Create(R, ATitle, wnNoNumber);
  Flags := Flags and not (wfGrow or wfZoom);
  R := GetExtent;
  R.Grow(-1, -1);
  T := TRect.Create(R.A.X, R.B.Y - 1, R.B.X, R.B.Y);
  Report := MakeReport(T);
  Report.Options := Report.Options or ofFramed;
  Insert(Report);
  T := TRect.Create(R.A.X, R.A.Y, R.B.X, R.B.Y - 2);
  Table := MakeTable(T);
  Table.Options := Table.Options or ofFramed;
  Table.Unicode := AUnicode;
  Insert(Table);
  Table.Select;
  Report.ShowCode(Table);
end;

function TAsciiChart.MakeTable(const Bounds: TRect): TAsciiTable;
begin
  Result := TAsciiTable.Create(Bounds);
end;

function TAsciiChart.MakeReport(const Bounds: TRect): TAsciiReport;
begin
  Result := TAsciiReport.Create(Bounds);
end;

constructor TAsciiChart.Load(S: TStream);
begin
  inherited Load(S);
  GetSubViewPtr(S, Table);
  GetSubViewPtr(S, Report);
end;

procedure TAsciiChart.Store(S: TStream);
begin
  inherited Store(S);
  PutSubViewPtr(S, Table);
  PutSubViewPtr(S, Report);
end;

function BuildAsciiTable(S: TStream): TStreamable;
begin
  Result := TStreamable(Pointer(TAsciiTable.Load(S)));
end;

procedure StoreAsciiTable(P: TStreamable; S: TStream);
begin
  TAsciiTable(Pointer(P)).Store(S);
end;

function BuildAsciiReport(S: TStream): TStreamable;
begin
  Result := TStreamable(Pointer(TAsciiReport.Load(S)));
end;

procedure StoreAsciiReport(P: TStreamable; S: TStream);
begin
  TAsciiReport(Pointer(P)).Store(S);
end;

function BuildAsciiChart(S: TStream): TStreamable;
begin
  Result := TStreamable(Pointer(TAsciiChart.Load(S)));
end;

procedure StoreAsciiChart(P: TStreamable; S: TStream);
begin
  TAsciiChart(Pointer(P)).Store(S);
end;

initialization
  RAsciiTable.ObjType := 10010;
  RAsciiTable.VmtLink := PtrUInt(System.TClass(TAsciiTable));
  RAsciiTable.Load := @BuildAsciiTable;
  RAsciiTable.Store := @StoreAsciiTable;
  RAsciiReport.ObjType := 10011;
  RAsciiReport.VmtLink := PtrUInt(System.TClass(TAsciiReport));
  RAsciiReport.Load := @BuildAsciiReport;
  RAsciiReport.Store := @StoreAsciiReport;
  RAsciiChart.ObjType := 10012;
  RAsciiChart.VmtLink := PtrUInt(System.TClass(TAsciiChart));
  RAsciiChart.Load := @BuildAsciiChart;
  RAsciiChart.Store := @StoreAsciiChart;
end.
