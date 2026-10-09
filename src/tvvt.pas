{ TvVt: a terminal emulator without input and output (the core of the terminal view, PLAN.md item 8.1). It takes the bytes that a program writes to its
  terminal (Feed) and keeps the screen: a grid of TScreenCell (UTF-8, wide and zero-width characters, 16/256/24-bit colors, styles), the cursor, the
  scrolling region, the alternate screen, the history (scrollback), the modes that the program sets (application cursor keys, bracketed paste, mouse
  reporting) and the answers it must send back (device attributes, cursor position): TakeReply. The APC strings of the far2l terminal extensions go to
  Ext (TvVtExt), whose answers join the others in TakeReply.

  The control sequences are those of xterm (XTerm Control Sequences, ECMA-48, DEC STD 070 for the line drawing set). Not done: sixel and other graphics, DECRQM,
  rectangular operations, double width and height lines, text reflow on resize (the list is kept in the notes of the project, TODO-later.md). }
unit TvVt;

{$I tvdefs.inc}

interface

uses
  TvColors, TvCell, TvUtf8, TvClip, TvVtExt;

const
  MaxVtParams = 24;

type
  TVtRow = array of TScreenCell;

  TVtTitleProc = procedure(Data: Pointer; const Title: AnsiString);
  TVtBellProc = procedure(Data: Pointer);
  { OSC 52: the program sets the clipboard (Text is the decoded text, UTF-8) }
  TVtClipProc = procedure(Data: Pointer; const Text: AnsiString);
  { OSC 52 with "?": the program asks for the clipboard; False if there is none (then the answer is an empty text) }
  TVtClipGetFunc = function(Data: Pointer; out Text: AnsiString): Boolean;

  TVtEmu = class
  private
    FCols, FRows: Integer;
    Scr, Other: array of TVtRow;         { the screen in use and the other one (main/alternate) }
    Dirty: array of Boolean;
    AltOn: Boolean;
    Back: array of TVtRow;               { the history: a ring }
    BackStart, BackCount, BackMax: Integer;
    Tabs: array of Boolean;
    { the cursor }
    CX, CY: Integer;
    Pending: Boolean;                    { the cursor is after the last column: the next character wraps }
    Pen: TColorAttr;
    SvX, SvY: Integer;
    SvPen: TColorAttr;
    SvPending, SvOrigin: Boolean;
    SvG0, SvG1, SvShift: Integer;
    Top, Bot: Integer;                   { the scrolling region (rows, inclusive) }
    G0, G1, Shift: Integer;              { 0: ASCII, 1: DEC line drawing; Shift: which one is in use }
    LastCp: LongWord;
    { the parser }
    State: Integer;
    Params: array[0..MaxVtParams - 1] of LongInt;
    Colon: array[0..MaxVtParams - 1] of Boolean;   { the parameter I is followed by ':' (a sub-parameter) }
    NParams: Integer;
    HaveParam, LastSep: Boolean;
    Marker, Inter: Char;
    Osc: AnsiString;
    Utf8Need: Integer;
    Utf8Acc: LongWord;
    Utf8Min: LongWord;
    Reply: AnsiString;
    Apc: AnsiString;                     { the body of an APC string, Length(Apc) is the capacity, ApcLen the bytes }
    ApcLen: Integer;
    procedure ApcByte(B: Byte);
    procedure ApcDone;
    procedure Reset;
    procedure FreshRow(var R: TVtRow);
    procedure PutCp(Cp: LongWord);
    procedure Control(B: Byte);
    procedure Escape(B: Byte);
    procedure Csi(Final: Byte);
    procedure OscDone;
    procedure ScrollUp(N, FromTop: Integer; ToHistory: Boolean);
    procedure ScrollDown(N, FromTop: Integer);
    procedure LineFeed;
    procedure ReverseIndex;
    procedure MoveTo(X, Y: Integer);
    procedure EraseCells(Y, X1, X2: Integer);
    procedure EraseRows(Y1, Y2: Integer);
    procedure InsertChars(N: Integer);
    procedure DeleteChars(N: Integer);
    procedure SetMode(Priv: Boolean; Mode: LongInt; On: Boolean);
    procedure Sgr;
    procedure SaveCursor;
    procedure RestoreCursor;
    procedure SwitchAlt(ToAlt, Clear: Boolean);
    function Param(I, Def: Integer): Integer;
    procedure Answer(const S: AnsiString);
    procedure FixWide(Y, X1, X2: Integer);
    procedure PushBack(const R: TVtRow);
    procedure NextByte(B: Byte);
    procedure SoftReset;
    function Blank: TScreenCell;
  public
    { modes that the program sets }
    Autowrap, Origin, Insert, NewLine: Boolean;
    CursorVisible: Boolean;
    CursorShape: Integer;                { DECSCUSR: 0/1 blinking block, 2 block, 3/4 underline, 5/6 bar }
    AppCursor, AppKeypad, BracketedPaste, FocusEvents, ReverseScreen: Boolean;
    KittyFlags: Integer;                 { the keyboard protocol of Kitty that the program asked for: 1 disambiguate, 2 the types of events, 8 every key as an escape code (4, 16 are not used) }
    KittyStack: array[0..31] of Integer;
    KittyDepth: Integer;
    Win32Input: Boolean;                 { ESC [ ? 9001 h: the program wants the keys as KEY_EVENT_RECORDs (TvVtKeys) and their releases }
    MouseMode: Integer;                  { 0: none, 9, 1000 (press and release), 1002 (and drag), 1003 (all moves) }
    MouseEnc: Integer;                   { 0: X10 bytes, 1005 (UTF-8), 1006 (SGR), 1015 (urxvt) }
    Title: AnsiString;
    Ext: TVtExtServer;                   { the far2l terminal extensions of the program }
    OnTitle: TVtTitleProc;
    OnBell: TVtBellProc;
    OnClip: TVtClipProc;
    OnClipGet: TVtClipGetFunc;
    Data: Pointer;
    constructor Create(ACols, ARows: Integer; AHistory: Integer = 1000);
    destructor Destroy; override;
    procedure Resize(ACols, ARows: Integer);
    { the bytes of the program (UTF-8 text and control sequences) }
    procedure Feed(P: PByte; Len: Integer); overload;
    procedure Feed(const S: AnsiString); overload;
    { the bytes that must go back to the program (answers to the queries); empty when there are none }
    function TakeReply: AnsiString;
    function Cols: Integer;
    function RowCount: Integer;
    function CursorX: Integer;
    function CursorY: Integer;
    function IsAlt: Boolean;
    { the cell of the screen (the main or the alternate one); outside of it a blank cell }
    function CellAt(X, Y: Integer): TScreenCell;
    { the history: the oldest line is 0; a line can be shorter or longer than the screen, a cell outside of it is blank }
    function HistoryCount: Integer;
    function HistoryCell(Line, X: Integer): TScreenCell;
    function HistoryLength(Line: Integer): Integer;
    procedure SetHistoryLimit(N: Integer);
    { which rows changed since ClearDirty }
    function RowDirty(Y: Integer): Boolean;
    procedure ClearDirty;
    { the text of a row (UTF-8, without the trailing blanks) }
    function RowText(Y: Integer): AnsiString;
    function HistoryText(Line: Integer): AnsiString;
  end;

implementation

const
  stGround = 0;
  stEsc = 1;
  stCsi = 2;
  stOsc = 3;
  stOscEsc = 4;          { ESC inside OSC (maybe the string terminator) }
  stIgnore = 5;          { DCS, SOS, PM, APC: skipped up to the terminator }
  stIgnoreEsc = 6;
  stEscInter = 7;        { ESC and an intermediate byte: ( ) * + # % ... }
  stApc = 8;             { APC: collected for the far2l extensions }
  stApcEsc = 9;
  MaxApc = 64 * 1048576;

  MaxOsc = 8192;

  { DEC special graphics (ESC ( 0): the characters 0x60..0x7E }
  DecGraphics: array[$60..$7E] of LongWord = (
    $25C6, $2592, $2409, $240C, $240D, $240A, $00B0, $00B1, $2424, $240B, $2518, $2510, $250C, $2514, $253C, $23BA,
    $23BB, $2500, $23BC, $23BD, $251C, $2524, $2534, $252C, $2502, $2264, $2265, $03C0, $2260, $00A3, $00B7);

{ --- helpers ---------------------------------------------------------------- }

function Min2(A, B: Integer): Integer; inline;
begin
  if A < B then Result := A else Result := B;
end;

function Max2(A, B: Integer): Integer; inline;
begin
  if A > B then Result := A else Result := B;
end;

function Clamp(V, Lo, Hi: Integer): Integer; inline;
begin
  if V < Lo then V := Lo;
  if V > Hi then V := Hi;
  Result := V;
end;

function IntStr(V: LongInt): AnsiString;
var
  S: string[16];
begin
  Str(V, S);
  Result := S;
end;

function IStr(V: LongInt): AnsiString;
var
  S: string[16];
begin
  Str(V, S);
  Result := S;
end;

function CellText(const C: TScreenCell): AnsiString;
begin
  if C.Character.IsWideCharTrail then
    Exit('');
  Result := C.Character.GetText;
  if (Length(Result) = 1) and (Result[1] = #0) then
    Result := ' ';
end;

function RowToText(const R: TVtRow; Cols: Integer): AnsiString;
var
  X, E: Integer;
begin
  Result := '';
  E := Min2(Cols, Length(R)) - 1;
  while (E >= 0) and (R[E].Character.GetText = ' ') and not R[E].Character.IsWideCharTrail do
    Dec(E);
  for X := 0 to E do
    Result := Result + CellText(R[X]);
end;

{ --- the storage ------------------------------------------------------------ }

constructor TVtEmu.Create(ACols, ARows: Integer; AHistory: Integer);
begin
  FCols := Max2(ACols, 1);
  FRows := Max2(ARows, 1);
  BackMax := Max2(AHistory, 0);
  OnTitle := nil;
  OnBell := nil;
  OnClip := nil;
  OnClipGet := nil;
  Data := nil;
  Ext := TVtExtServer.Create(FCols, FRows);
  Reset;
end;

destructor TVtEmu.Destroy;
begin
  Ext.Free;
  Ext := nil;
  Scr := nil;
  Other := nil;
  Back := nil;
end;

function TVtEmu.Blank: TScreenCell;
var
  Ch: TScreenCharacter;
begin
  Ch.InitWithChar(Ord(' '));
  { the erased cells have the background of the pen and nothing else (xterm: back color erase) }
  Result := TScreenCell.Create(Ch, TColorAttr.Create(Default(TColor), Pen.GetBackground, 0));
end;

procedure TVtEmu.FreshRow(var R: TVtRow);
var
  X: Integer;
  B: TScreenCell;
begin
  B := Blank;
  R := nil;
  SetLength(R, FCols);
  for X := 0 to FCols - 1 do
    R[X] := B;
end;

procedure TVtEmu.Reset;
var
  I: Integer;
begin
  Pen := TColorAttr.Create(Default(TColor), Default(TColor), 0);
  SetLength(Scr, FRows);
  SetLength(Other, FRows);
  SetLength(Dirty, FRows);
  for I := 0 to FRows - 1 do
  begin
    FreshRow(Scr[I]);
    FreshRow(Other[I]);
    Dirty[I] := True;
  end;
  SetLength(Back, BackMax);
  BackStart := 0;
  BackCount := 0;
  AltOn := False;
  CX := 0; CY := 0; Pending := False;
  SvX := 0; SvY := 0; SvPen := Pen; SvPending := False; SvOrigin := False; SvG0 := 0; SvG1 := 0; SvShift := 0;
  Top := 0; Bot := FRows - 1;
  G0 := 0; G1 := 0; Shift := 0;
  LastCp := 0;
  State := stGround; NParams := 0; HaveParam := False; LastSep := False; Marker := #0; Inter := #0; Osc := '';
  Utf8Need := 0; Utf8Acc := 0; Utf8Min := 0;
  Reply := '';
  Autowrap := True; Origin := False; Insert := False; NewLine := False;
  CursorVisible := True; CursorShape := 0;
  AppCursor := False; AppKeypad := False; BracketedPaste := False; FocusEvents := False; ReverseScreen := False;
  Win32Input := False;
  KittyFlags := 0;
  KittyDepth := 0;
  MouseMode := 0; MouseEnc := 0;
  Title := '';
  SetLength(Tabs, FCols);
  for I := 0 to FCols - 1 do
    Tabs[I] := (I mod 8) = 0;
end;

procedure TVtEmu.SoftReset;
begin
  { DECSTR: the modes and the pen, not the contents }
  Pen := TColorAttr.Create(Default(TColor), Default(TColor), 0);
  Insert := False; Origin := False; Autowrap := True; NewLine := False;
  CursorVisible := True; AppCursor := False; AppKeypad := False;
  Top := 0; Bot := FRows - 1;
  G0 := 0; G1 := 0; Shift := 0;
  SvX := 0; SvY := 0; SvPen := Pen; SvPending := False; SvOrigin := False;
  Pending := False;
end;

function TVtEmu.Cols: Integer;
begin
  Result := FCols;
end;

function TVtEmu.RowCount: Integer;
begin
  Result := FRows;
end;

function TVtEmu.CursorX: Integer;
begin
  Result := CX;
end;

function TVtEmu.CursorY: Integer;
begin
  Result := CY;
end;

function TVtEmu.IsAlt: Boolean;
begin
  Result := AltOn;
end;

function TVtEmu.CellAt(X, Y: Integer): TScreenCell;
begin
  if (X < 0) or (X >= FCols) or (Y < 0) or (Y >= FRows) then
    Exit(Blank);
  Result := Scr[Y][X];
end;

function TVtEmu.HistoryCount: Integer;
begin
  Result := BackCount;
end;

function TVtEmu.HistoryLength(Line: Integer): Integer;
begin
  if (Line < 0) or (Line >= BackCount) then
    Exit(0);
  Result := Length(Back[(BackStart + Line) mod BackMax]);
end;

function TVtEmu.HistoryCell(Line, X: Integer): TScreenCell;
var
  Idx: Integer;
begin
  if (Line < 0) or (Line >= BackCount) then
    Exit(Blank);
  Idx := (BackStart + Line) mod BackMax;
  if (X < 0) or (X >= Length(Back[Idx])) then
    Exit(Blank);
  Result := Back[Idx][X];
end;

function TVtEmu.RowDirty(Y: Integer): Boolean;
begin
  Result := (Y >= 0) and (Y < FRows) and Dirty[Y];
end;

procedure TVtEmu.ClearDirty;
var
  I: Integer;
begin
  for I := 0 to FRows - 1 do
    Dirty[I] := False;
end;

procedure TVtEmu.SetHistoryLimit(N: Integer);
var
  Old: array of TVtRow;
  I, Keep: Integer;
begin
  N := Max2(N, 0);
  SetLength(Old, BackCount);
  for I := 0 to BackCount - 1 do
    Old[I] := Back[(BackStart + I) mod BackMax];
  Keep := Min2(BackCount, N);
  BackMax := N;
  Back := nil;
  SetLength(Back, N);
  BackStart := 0;
  for I := 0 to Keep - 1 do
    Back[I] := Old[BackCount - Keep + I];
  BackCount := Keep;
end;

procedure TVtEmu.PushBack(const R: TVtRow);
var
  Idx: Integer;
begin
  if BackMax = 0 then
    Exit;
  if BackCount < BackMax then
  begin
    Idx := (BackStart + BackCount) mod BackMax;
    Inc(BackCount);
  end
  else
  begin
    Idx := BackStart;
    BackStart := (BackStart + 1) mod BackMax;
  end;
  Back[Idx] := R;
end;

function TVtEmu.RowText(Y: Integer): AnsiString;
begin
  if (Y < 0) or (Y >= FRows) then
    Exit('');
  Result := RowToText(Scr[Y], FCols);
end;

function TVtEmu.HistoryText(Line: Integer): AnsiString;
begin
  if (Line < 0) or (Line >= BackCount) then
    Exit('');
  Result := RowToText(Back[(BackStart + Line) mod BackMax], MaxInt);
end;

procedure TVtEmu.Resize(ACols, ARows: Integer);
var
  I, Drop: Integer;
  B: TScreenCell;

  procedure Fit(var S: array of TVtRow; var D: array of TVtRow);
  var
    Y, K, X: Integer;
  begin
    for Y := 0 to ARows - 1 do
    begin
      K := Y + Drop;
      D[Y] := nil;
      SetLength(D[Y], ACols);
      for X := 0 to ACols - 1 do
        if (K >= 0) and (K < Length(S)) and (X < Length(S[K])) then
          D[Y][X] := S[K][X]
        else
          D[Y][X] := B;
    end;
  end;

var
  NS, NO: array of TVtRow;
begin
  ACols := Max2(ACols, 1);
  ARows := Max2(ARows, 1);
  if (ACols = FCols) and (ARows = FRows) then
    Exit;
  B := Blank;
  { the rows that do not fit above the cursor go to the history (the main screen) }
  Drop := 0;
  if CY >= ARows then
    Drop := CY - ARows + 1;
  if not AltOn then
    for I := 0 to Drop - 1 do
      PushBack(Scr[I]);
  SetLength(NS, ARows);
  SetLength(NO, ARows);
  Fit(Scr, NS);
  Drop := 0;
  Fit(Other, NO);
  Scr := NS;
  Other := NO;
  FCols := ACols;
  FRows := ARows;
  SetLength(Dirty, FRows);
  for I := 0 to FRows - 1 do
    Dirty[I] := True;
  Dec(CY, Max2(CY - ARows + 1, 0));
  CX := Min2(CX, FCols - 1);
  CY := Clamp(CY, 0, FRows - 1);
  Pending := False;
  Top := 0;
  Bot := FRows - 1;
  SetLength(Tabs, FCols);
  for I := 0 to FCols - 1 do
    Tabs[I] := (I mod 8) = 0;
  Answer(Ext.Resized(FCols, FRows));
end;

{ --- the screen operations --------------------------------------------------- }

function TVtEmu.Param(I, Def: Integer): Integer;
begin
  if (I < NParams) and (Params[I] > 0) then
    Result := Params[I]
  else
    Result := Def;
end;

procedure TVtEmu.Answer(const S: AnsiString);
begin
  Reply := Reply + S;
end;

function TVtEmu.TakeReply: AnsiString;
begin
  Result := Reply;
  Reply := '';
end;

procedure TVtEmu.MoveTo(X, Y: Integer);
begin
  CX := Clamp(X, 0, FCols - 1);
  if Origin then
    CY := Clamp(Y + Top, Top, Bot)
  else
    CY := Clamp(Y, 0, FRows - 1);
  Pending := False;
end;

procedure TVtEmu.ScrollUp(N, FromTop: Integer; ToHistory: Boolean);
var
  K, I: Integer;
  R: TVtRow;
begin
  N := Min2(N, Bot - FromTop + 1);
  for K := 1 to N do
  begin
    R := Scr[FromTop];
    if ToHistory and not AltOn and (FromTop = 0) then
      PushBack(R);                      { only what leaves the top of the main screen is history }
    for I := FromTop to Bot - 1 do
      Scr[I] := Scr[I + 1];
    Scr[Bot] := nil;
    FreshRow(Scr[Bot]);
  end;
  if N > 0 then
    for I := FromTop to Bot do
      Dirty[I] := True;
end;

procedure TVtEmu.ScrollDown(N, FromTop: Integer);
var
  K, I: Integer;
begin
  N := Min2(N, Bot - FromTop + 1);
  for K := 1 to N do
  begin
    for I := Bot downto FromTop + 1 do
      Scr[I] := Scr[I - 1];
    Scr[FromTop] := nil;
    FreshRow(Scr[FromTop]);
  end;
  if N > 0 then
    for I := FromTop to Bot do
      Dirty[I] := True;
end;

procedure TVtEmu.LineFeed;
begin
  if CY = Bot then
    ScrollUp(1, Top, True)
  else if CY < FRows - 1 then
    Inc(CY);
  Pending := False;
end;

procedure TVtEmu.ReverseIndex;
begin
  if CY = Top then
    ScrollDown(1, Top)
  else if CY > 0 then
    Dec(CY);
  Pending := False;
end;

{ a wide character that is partly overwritten leaves a blank in place of its other half }
procedure TVtEmu.FixWide(Y, X1, X2: Integer);
var
  B: TScreenCell;
begin
  B := Blank;
  if (X1 > 0) and (Scr[Y][X1].Character).IsWideCharTrail then
    Scr[Y][X1 - 1] := B;
  if (X2 < FCols - 1) and (Scr[Y][X2 + 1].Character).IsWideCharTrail then
    Scr[Y][X2 + 1] := B;
end;

procedure TVtEmu.EraseCells(Y, X1, X2: Integer);
var
  X: Integer;
  B: TScreenCell;
begin
  X1 := Max2(X1, 0);
  X2 := Min2(X2, FCols - 1);
  if X1 > X2 then
    Exit;
  FixWide(Y, X1, X2);
  B := Blank;
  for X := X1 to X2 do
    Scr[Y][X] := B;
  Dirty[Y] := True;
end;

procedure TVtEmu.EraseRows(Y1, Y2: Integer);
var
  Y: Integer;
begin
  for Y := Max2(Y1, 0) to Min2(Y2, FRows - 1) do
    EraseCells(Y, 0, FCols - 1);
end;

procedure TVtEmu.InsertChars(N: Integer);
var
  X: Integer;
begin
  N := Min2(N, FCols - CX);
  if N <= 0 then
    Exit;
  FixWide(CY, CX, CX);
  for X := FCols - 1 downto CX + N do
    Scr[CY][X] := Scr[CY][X - N];
  for X := CX to CX + N - 1 do
    Scr[CY][X] := Blank;
  if (Scr[CY][FCols - 1].Character).IsWideCharTrail or ((Scr[CY][FCols - 1].Character).IsWide) then
    Scr[CY][FCols - 1] := Blank;
  Dirty[CY] := True;
end;

procedure TVtEmu.DeleteChars(N: Integer);
var
  X: Integer;
begin
  N := Min2(N, FCols - CX);
  if N <= 0 then
    Exit;
  FixWide(CY, CX, CX + N - 1);
  for X := CX to FCols - N - 1 do
    Scr[CY][X] := Scr[CY][X + N];
  for X := FCols - N to FCols - 1 do
    Scr[CY][X] := Blank;
  Dirty[CY] := True;
end;

procedure TVtEmu.PutCp(Cp: LongWord);
var
  W, I, N, PX: Integer;
  Buf: array[0..4] of Byte;
  Ch: TScreenCharacter;
begin
  { the line drawing set }
  if ((Shift = 0) and (G0 = 1)) or ((Shift = 1) and (G1 = 1)) then
    if (Cp >= $60) and (Cp <= $7E) then
      Cp := DecGraphics[Cp];
  if Cp < $20 then
    Exit;
  LastCp := Cp;
  W := CharWidth(Cp);
  if W < 0 then
    Exit;                                { a control character of C1 }
  N := Utf8Encode(Cp, @Buf[0]);
  if W = 0 then
  begin
    { a combining mark goes into the cell of the character before it }
    PX := CX;
    if not Pending then
      Dec(PX);
    if PX >= 0 then
    begin
      if (Scr[CY][PX].Character).IsWideCharTrail and (PX > 0) then
        Dec(PX);
      (Scr[CY][PX].Character).AppendZeroWidthChar(@Buf[0], N);
      Dirty[CY] := True;
    end;
    Exit;
  end;
  if Pending or (CX + W > FCols) then
  begin
    if Autowrap then
    begin
      CX := 0;
      LineFeed;
    end
    else
      CX := FCols - W;
    Pending := False;
  end;
  if Insert then
    InsertChars(W);
  FixWide(CY, CX, CX + W - 1);
  Ch.InitWithMultiByteChar(@Buf[0], N, W = 2);
  Scr[CY][CX] := TScreenCell.Create(Ch, Pen);
  if W = 2 then
  begin
    Ch.InitAsWideCharTrail;
    Scr[CY][CX + 1] := TScreenCell.Create(Ch, Pen);
  end;
  Dirty[CY] := True;
  Inc(CX, W);
  if CX >= FCols then
  begin
    CX := FCols - 1;
    Pending := True;
  end;
end;

procedure TVtEmu.Control(B: Byte);
var
  X: Integer;
begin
  case B of
    7: if Assigned(OnBell) then OnBell(Data);
    8: begin
         if CX > 0 then
           Dec(CX);
         Pending := False;
       end;
    9: begin
         X := CX + 1;
         while (X < FCols - 1) and not Tabs[X] do
           Inc(X);
         CX := Min2(X, FCols - 1);
       end;
    10, 11, 12: begin
         LineFeed;
         if NewLine then
           CX := 0;
       end;
    13: begin
         CX := 0;
         Pending := False;
       end;
    14: Shift := 1;
    15: Shift := 0;
  end;
end;

procedure TVtEmu.SaveCursor;
begin
  SvX := CX; SvY := CY; SvPen := Pen; SvPending := Pending; SvOrigin := Origin;
  SvG0 := G0; SvG1 := G1; SvShift := Shift;
end;

procedure TVtEmu.RestoreCursor;
begin
  CX := Clamp(SvX, 0, FCols - 1);
  CY := Clamp(SvY, 0, FRows - 1);
  Pen := SvPen;
  Pending := SvPending;
  Origin := SvOrigin;
  G0 := SvG0; G1 := SvG1; Shift := SvShift;
end;

procedure TVtEmu.SwitchAlt(ToAlt, Clear: Boolean);
var
  T: array of TVtRow;
  I: Integer;
begin
  if ToAlt <> AltOn then
  begin
    T := Scr;
    Scr := Other;
    Other := T;
    AltOn := ToAlt;
    for I := 0 to FRows - 1 do
      Dirty[I] := True;
  end;
  if Clear and ToAlt then
    EraseRows(0, FRows - 1);
end;

procedure TVtEmu.SetMode(Priv: Boolean; Mode: LongInt; On: Boolean);
var
  I: Integer;
begin
  if not Priv then
  begin
    case Mode of
      4: Insert := On;
      20: NewLine := On;
    end;
    Exit;
  end;
  case Mode of
    1: AppCursor := On;
    5: begin
         ReverseScreen := On;
         for I := 0 to FRows - 1 do
           Dirty[I] := True;
       end;
    6: begin
         Origin := On;
         MoveTo(0, 0);
       end;
    7: Autowrap := On;
    25: CursorVisible := On;
    47, 1047: SwitchAlt(On, On);
    1048: if On then SaveCursor else RestoreCursor;
    1049: if On then
          begin
            SaveCursor;
            SwitchAlt(True, True);
          end
          else
          begin
            SwitchAlt(False, False);
            RestoreCursor;
          end;
    66: AppKeypad := On;
    9, 1000, 1002, 1003:
      if On then
        MouseMode := Mode
      else if MouseMode = Mode then
        MouseMode := 0;
    1005, 1006, 1015:
      if On then
        MouseEnc := Mode
      else if MouseEnc = Mode then
        MouseEnc := 0;
    1004: FocusEvents := On;
    9001: Win32Input := On;
    2004: BracketedPaste := On;
  end;
end;

procedure TVtEmu.Sgr;
var
  I, K, J, Idx, Cnt: Integer;
  C: TColor;
  St: Word;
  IsBg: Boolean;

  function Byte255(V: LongInt): Byte;
  begin
    Result := Byte(Clamp(V, 0, 255));
  end;

begin
  if NParams = 0 then
  begin
    Pen := TColorAttr.Create(Default(TColor), Default(TColor), 0);
    Exit;
  end;
  I := 0;
  while I < NParams do
  begin
    K := Params[I];
    St := Pen.GetStyle;
    case K of
      0: Pen := TColorAttr.Create(Default(TColor), Default(TColor), 0);
      1: Pen.SetStyle(St or slBold);
      3: Pen.SetStyle(St or slItalic);
      4: if Colon[I] and (I + 1 < NParams) and (Params[I + 1] = 0) then
         begin
           Pen.SetStyle(St and not slUnderline);
           Inc(I);
         end
         else
         begin
           Pen.SetStyle(St or slUnderline);
           while Colon[I] and (I + 1 < NParams) do Inc(I);
         end;
      5, 6: Pen.SetStyle(St or slBlink);
      7: Pen.SetStyle(St or slReverse);
      9: Pen.SetStyle(St or slStrike);
      21: Pen.SetStyle(St or slUnderline);
      22: Pen.SetStyle(St and not slBold);
      23: Pen.SetStyle(St and not slItalic);
      24: Pen.SetStyle(St and not slUnderline);
      25: Pen.SetStyle(St and not slBlink);
      27: Pen.SetStyle(St and not slReverse);
      29: Pen.SetStyle(St and not slStrike);
      30..37: Pen.SetForeground(TColor(TColorXTerm(K - 30)));
      39: Pen.SetForeground(Default(TColor));
      40..47: Pen.SetBackground(TColor(TColorXTerm(K - 40)));
      49: Pen.SetBackground(Default(TColor));
      90..97: Pen.SetForeground(TColor(TColorXTerm(K - 90 + 8)));
      100..107: Pen.SetBackground(TColor(TColorXTerm(K - 100 + 8)));
      38, 48, 58:
        begin
          IsBg := K = 48;
          { the number of parameters that go with this one: after ':' the sub-parameters, else the next ones by ';' }
          if Colon[I] then
          begin
            J := I + 1;
            Cnt := 0;
            while (J < NParams) do
            begin
              Inc(Cnt);
              if not Colon[J] then
                Break;
              Inc(J);
            end;
            { the sub-parameters are I+1 .. I+Cnt }
            if (Cnt >= 2) and (Params[I + 1] = 5) then
              C := TColor(TColorXTerm(Byte255(Params[I + 2])))
            else if (Cnt >= 4) and (Params[I + 1] = 2) then
              C := TColor(TColorRGB(TColorRGB.Create(Byte255(Params[I + Cnt - 2]), Byte255(Params[I + Cnt - 1]), Byte255(Params[I + Cnt]))))
            else
              C := Default(TColor);
            Idx := I + Cnt;
          end
          else
          begin
            if (I + 2 < NParams) and (Params[I + 1] = 5) then
            begin
              C := TColor(TColorXTerm(Byte255(Params[I + 2])));
              Idx := I + 2;
            end
            else if (I + 4 < NParams) and (Params[I + 1] = 2) then
            begin
              C := TColor(TColorRGB(TColorRGB.Create(Byte255(Params[I + 2]), Byte255(Params[I + 3]), Byte255(Params[I + 4]))));
              Idx := I + 4;
            end
            else
            begin
              C := Default(TColor);
              Idx := NParams - 1;
            end;
          end;
          if K <> 58 then
            if IsBg then
              Pen.SetBackground(C)
            else
              Pen.SetForeground(C);
          I := Idx;
        end;
    end;
    Inc(I);
  end;
end;

procedure TVtEmu.OscDone;
var
  P, Code: Integer;
  Text, Arg, Sel, Clip: AnsiString;
  Err: Integer;
begin
  P := Pos(';', Osc);
  if P = 0 then
    Exit;
  Val(Copy(Osc, 1, P - 1), Code, Err);
  if Err <> 0 then
    Exit;
  Text := Copy(Osc, P + 1, MaxInt);
  case Code of
    0, 2:
      begin
        Title := Text;
        if Assigned(OnTitle) then
          OnTitle(Data, Title);
      end;
    52:
      begin
        P := Pos(';', Text);
        if P > 0 then
        begin
          Arg := Copy(Text, P + 1, MaxInt);
          if Arg = '?' then
          begin
            { the program reads the clipboard: the answer is the same string with the text in base64 (the selection is as asked, c by default) }
            Sel := Copy(Text, 1, P - 1);
            if Sel = '' then
              Sel := 'c';
            Clip := '';
            if Assigned(OnClipGet) then
              if not OnClipGet(Data, Clip) then
                Clip := '';
            Answer(#27']52;' + Sel + ';' + Base64Encode(Clip) + #27'\');
          end
          else if Assigned(OnClip) then
            OnClip(Data, Base64Decode(Arg));
        end;
      end;
  end;
end;

procedure TVtEmu.Escape(B: Byte);
begin
  case Chr(B) of
    '7': SaveCursor;
    '8': RestoreCursor;
    'D': LineFeed;
    'E': begin
           CX := 0;
           LineFeed;
         end;
    'H': Tabs[CX] := True;
    'M': ReverseIndex;
    'c': begin
           Reset;
         end;
    '=': AppKeypad := True;
    '>': AppKeypad := False;
  end;
end;

procedure TVtEmu.Csi(Final: Byte);
var
  N, I, X: Integer;
  F: Char;
  Priv: Boolean;
begin
  F := Chr(Final);
  if NParams = 0 then
    Params[0] := 0;
  if LastSep and not HaveParam and (NParams < MaxVtParams) then
  begin
    Params[NParams] := 0;
    Colon[NParams] := False;
    Inc(NParams);
  end;
  Priv := Marker = '?';
  if Inter = '!' then
  begin
    if F = 'p' then
      SoftReset;
    Exit;
  end;
  if Inter = ' ' then
  begin
    if F = 'q' then
      CursorShape := Param(0, 0);
    Exit;
  end;
  if Inter <> #0 then
    Exit;
  if (F = 'u') and ((Marker = '>') or (Marker = '<') or (Marker = '=') or (Marker = '?')) then
  begin
    { the keyboard protocol of Kitty: > flags pushes, < n pops, = flags ; mode sets (1 the flags, 2 adds, 3 removes), ? asks }
    case Marker of
      '>': begin
             if KittyDepth < 32 then
             begin
               KittyStack[KittyDepth] := KittyFlags;
               Inc(KittyDepth);
             end;
             KittyFlags := Param(0, 0) and 31;
           end;
      '<': begin
             N := Param(0, 1);
             while (N > 0) and (KittyDepth > 0) do
             begin
               Dec(KittyDepth);
               KittyFlags := KittyStack[KittyDepth];
               Dec(N);
             end;
           end;
      '=': case Param(1, 1) of
             2: KittyFlags := KittyFlags or (Param(0, 0) and 31);
             3: KittyFlags := KittyFlags and not (Param(0, 0) and 31);
           else
             KittyFlags := Param(0, 0) and 31;
           end;
      '?': Answer(#27'[?' + IStr(KittyFlags) + 'u');
    end;
    Exit;
  end;
  if (Marker = '>') or (Marker = '=') then
  begin
    if F = 'c' then
      Answer(#27'[>0;0;0c');
    Exit;
  end;
  if Marker = '<' then
    Exit;
  case F of
    '@': InsertChars(Param(0, 1));
    'A': begin
           N := Param(0, 1);
           if CY >= Top then CY := Max2(CY - N, Top) else CY := Max2(CY - N, 0);
           Pending := False;
         end;
    'B', 'e': begin
           N := Param(0, 1);
           if CY <= Bot then CY := Min2(CY + N, Bot) else CY := Min2(CY + N, FRows - 1);
           Pending := False;
         end;
    'C', 'a': begin
           CX := Min2(CX + Param(0, 1), FCols - 1);
           Pending := False;
         end;
    'D': begin
           CX := Max2(CX - Param(0, 1), 0);
           Pending := False;
         end;
    'E': begin
           CY := Min2(CY + Param(0, 1), Bot);
           CX := 0;
           Pending := False;
         end;
    'F': begin
           CY := Max2(CY - Param(0, 1), Top);
           CX := 0;
           Pending := False;
         end;
    'G', '`': begin
           CX := Clamp(Param(0, 1) - 1, 0, FCols - 1);
           Pending := False;
         end;
    'H', 'f': MoveTo(Param(1, 1) - 1, Param(0, 1) - 1);
    'I': for I := 1 to Param(0, 1) do Control(9);
    'J': case Param(0, 0) of
           0: begin
                EraseCells(CY, CX, FCols - 1);
                EraseRows(CY + 1, FRows - 1);
              end;
           1: begin
                EraseRows(0, CY - 1);
                EraseCells(CY, 0, CX);
              end;
           2: EraseRows(0, FRows - 1);
           3: begin
                BackCount := 0;
                BackStart := 0;
              end;
         end;
    'K': case Param(0, 0) of
           0: EraseCells(CY, CX, FCols - 1);
           1: EraseCells(CY, 0, CX);
           2: EraseCells(CY, 0, FCols - 1);
         end;
    'L': if (CY >= Top) and (CY <= Bot) then
         begin
           ScrollDown(Param(0, 1), CY);
           CX := 0;
           Pending := False;
         end;
    'M': if (CY >= Top) and (CY <= Bot) then
         begin
           ScrollUp(Param(0, 1), CY, False);
           CX := 0;
           Pending := False;
         end;
    'P': DeleteChars(Param(0, 1));
    'S': ScrollUp(Param(0, 1), Top, True);
    'T': if NParams <= 1 then ScrollDown(Param(0, 1), Top);
    'X': EraseCells(CY, CX, CX + Param(0, 1) - 1);
    'Z': begin
           for I := 1 to Param(0, 1) do
           begin
             X := CX - 1;
             while (X > 0) and not Tabs[X] do
               Dec(X);
             CX := Max2(X, 0);
           end;
           Pending := False;
         end;
    'b': for I := 1 to Min2(Param(0, 1), 65535) do
           if LastCp <> 0 then PutCp(LastCp);
    'c': if NParams = 0 then Answer(#27'[?62;22c') else if Params[0] = 0 then Answer(#27'[?62;22c');
    'd': begin
           MoveTo(CX, Param(0, 1) - 1);
         end;
    'g': case Param(0, 0) of
           0: Tabs[CX] := False;
           3: for I := 0 to FCols - 1 do Tabs[I] := False;
         end;
    'h': for I := 0 to Max2(NParams, 1) - 1 do SetMode(Priv, Params[I], True);
    'l': for I := 0 to Max2(NParams, 1) - 1 do SetMode(Priv, Params[I], False);
    'm': if not Priv then Sgr;
    'n': case Param(0, 0) of
           5: Answer(#27'[0n');
           6: begin
                if Origin then N := CY - Top + 1 else N := CY + 1;
                if Priv then
                  Answer(#27'[?' + IntStr(N) + ';' + IntStr(CX + 1) + 'R')
                else
                  Answer(#27'[' + IntStr(N) + ';' + IntStr(CX + 1) + 'R');
              end;
         end;
    'r': if not Priv then
         begin
           I := Param(0, 1) - 1;
           N := Param(1, FRows) - 1;
           if N > FRows - 1 then N := FRows - 1;
           if (I >= 0) and (I < N) then
           begin
             Top := I;
             Bot := N;
             MoveTo(0, 0);
           end;
         end;
    's': if not Priv and (NParams = 0) then SaveCursor;
    'u': if not Priv then RestoreCursor;
    't': if Param(0, 0) = 18 then Answer(#27'[8;' + IntStr(FRows) + ';' + IntStr(FCols) + 't');
  end;
end;

{ --- the parser ------------------------------------------------------------- }

procedure TVtEmu.NextByte(B: Byte);
var
  D, X: Integer;
  Ch: TScreenCharacter;
  Ch0: TScreenCell;
begin
  case State of
    stGround:
      begin
        if Utf8Need > 0 then
        begin
          if (B and $C0) = $80 then
          begin
            Utf8Acc := (Utf8Acc shl 6) or (B and $3F);
            Dec(Utf8Need);
            if Utf8Need = 0 then
            begin
              if (Utf8Acc < Utf8Min) or (Utf8Acc > $10FFFF) or ((Utf8Acc >= $D800) and (Utf8Acc <= $DFFF)) then
                PutCp($FFFD)
              else
                PutCp(Utf8Acc);
            end;
            Exit;
          end;
          Utf8Need := 0;
          PutCp($FFFD);                  { a broken sequence; the byte is read again }
        end;
        if B >= $80 then
        begin
          if (B >= $C2) and (B <= $DF) then
          begin Utf8Need := 1; Utf8Acc := B and $1F; Utf8Min := $80; end
          else if (B >= $E0) and (B <= $EF) then
          begin Utf8Need := 2; Utf8Acc := B and $0F; Utf8Min := $800; end
          else if (B >= $F0) and (B <= $F4) then
          begin Utf8Need := 3; Utf8Acc := B and $07; Utf8Min := $10000; end
          else
            PutCp($FFFD);
        end
        else if B = 27 then
          State := stEsc
        else if B < $20 then
          Control(B)
        else if B <> $7F then
          PutCp(B);
      end;
    stEsc:
      begin
        case Chr(B) of
          '[': begin
                 State := stCsi;
                 NParams := 0;
                 HaveParam := False;
                 LastSep := False;
                 Marker := #0;
                 Inter := #0;
               end;
          ']': begin
                 State := stOsc;
                 Osc := '';
               end;
          'P', 'X', '^': State := stIgnore;
          '_': begin
                 State := stApc;
                 ApcLen := 0;
               end;
          '(', ')', '*', '+', '#', '%', ' ':
               begin
                 Inter := Chr(B);
                 State := stEscInter;
               end;
          #27: ;                          { ESC ESC: still in the escape }
          #24, #26: State := stGround;
        else
          State := stGround;
          if B >= $20 then
            Escape(B);
        end;
      end;
    stEscInter:
      begin
        if (B >= $20) and (B <= $2F) then
          Exit;
        State := stGround;
        case Inter of
          '(': if B = Ord('0') then G0 := 1 else G0 := 0;
          ')': if B = Ord('0') then G1 := 1 else G1 := 0;
          '#': if B = Ord('8') then
               begin
                 { DECALN: the screen of E }
                 Ch0 := Blank;
                 Ch.InitWithChar(Ord('E'));
                 Ch0.Character := Ch;
                 for D := 0 to FRows - 1 do
                 begin
                   for X := 0 to FCols - 1 do
                     Scr[D][X] := Ch0;
                   Dirty[D] := True;
                 end;
                 CX := 0;
                 CY := 0;
                 Pending := False;
               end;
        end;
        Inter := #0;
      end;
    stCsi:
      begin
        if B = 27 then
        begin
          State := stEsc;
          Exit;
        end;
        if (B = 24) or (B = 26) then
        begin
          State := stGround;
          Exit;
        end;
        if B < $20 then
        begin
          Control(B);
          Exit;
        end;
        if (B >= Ord('0')) and (B <= Ord('9')) then
        begin
          if not HaveParam then
          begin
            if NParams < MaxVtParams then
            begin
              Params[NParams] := 0;
              Colon[NParams] := False;
              Inc(NParams);
            end;
            HaveParam := True;
          end;
          if NParams > 0 then
            if Params[NParams - 1] < 100000 then
              Params[NParams - 1] := Params[NParams - 1] * 10 + (B - Ord('0'));
          LastSep := False;
        end
        else if (B = Ord(';')) or (B = Ord(':')) then
        begin
          if not HaveParam then
          begin
            if NParams < MaxVtParams then
            begin
              Params[NParams] := 0;
              Colon[NParams] := False;
              Inc(NParams);
            end;
          end;
          if (B = Ord(':')) and (NParams > 0) then
            Colon[NParams - 1] := True;
          HaveParam := False;
          LastSep := True;
        end
        else if (B >= $3C) and (B <= $3F) then
          Marker := Chr(B)
        else if (B >= $20) and (B <= $2F) then
          Inter := Chr(B)
        else if (B >= $40) and (B <= $7E) then
        begin
          State := stGround;
          Csi(B);
        end
        else
          State := stGround;
      end;
    stOsc:
      begin
        if B = 7 then
        begin
          State := stGround;
          OscDone;
        end
        else if B = 27 then
          State := stOscEsc
        else if (B = 24) or (B = 26) then
          State := stGround
        else if Length(Osc) < MaxOsc then
          Osc := Osc + Chr(B);
      end;
    stOscEsc:
      begin
        if B = Ord('\') then
        begin
          State := stGround;
          OscDone;
        end
        else
        begin
          State := stEsc;                { not the terminator: the escape starts something else }
          NextByte(B);
        end;
      end;
    stIgnore:
      begin
        if B = 27 then
          State := stIgnoreEsc
        else if (B = 7) or (B = 24) or (B = 26) then
          State := stGround;
      end;
    stApc:
      case B of
        7: begin
             State := stGround;
             ApcDone;
           end;
        27: State := stApcEsc;
        24, 26: State := stGround;
      else
        ApcByte(B);
      end;
    stApcEsc:
      if B = Ord('\') then
      begin
        State := stGround;
        ApcDone;
      end
      else
      begin
        State := stEsc;
        NextByte(B);
      end;
    stIgnoreEsc:
      begin
        if B = Ord('\') then
          State := stGround
        else
        begin
          State := stEsc;
          NextByte(B);
        end;
      end;
  end;
end;

procedure TVtEmu.ApcByte(B: Byte);
begin
  if ApcLen >= MaxApc then
    Exit;
  if ApcLen >= Length(Apc) then
    SetLength(Apc, 2 * ApcLen + 256);
  Inc(ApcLen);
  Apc[ApcLen] := Chr(B);
end;

{ only the strings of the far2l extensions are used; the others are dropped }
procedure TVtEmu.ApcDone;
var
  Body: AnsiString;
begin
  if (ApcLen >= 6) and (ApcLen < MaxApc) and (Copy(Apc, 1, 5) = 'far2l') then
  begin
    Body := Copy(Apc, 1, ApcLen);
    Answer(Ext.Body(Body));
  end;
  ApcLen := 0;
  if Length(Apc) > 65536 then
    Apc := '';
end;

procedure TVtEmu.Feed(P: PByte; Len: Integer);
var
  I: Integer;
begin
  for I := 0 to Len - 1 do
    NextByte(P[I]);
end;

procedure TVtEmu.Feed(const S: AnsiString);
begin
  if Length(S) > 0 then
    Feed(PByte(@S[1]), Length(S));
end;

end.
