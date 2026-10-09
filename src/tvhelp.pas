{ TvHelp: the help system of Turbo Vision: topics with paragraphs and cross references (THelpTopic), the index of
  their positions (THelpIndex), the help file (THelpFile), the viewer (THelpViewer) and its window (THelpWindow).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/helpbase.h, help.h (class declarations)
    source/tvision/helpbase.cpp, help.cpp
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the streams are the object streams of TvObjs (ipstream, opstream, iopstream); THelpTopic and THelpIndex register
      themselves by name (RHelpTopic, RHelpIndex);
    - a line of a topic is a ShortString (longer lines are cut to 255 bytes);
    - the help files are made by tvhc (tv/tools/tvhc.pas) from the text of a help (.htx). }
unit TvHelp;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvText, TvDrawBuf, TvObjs, TvUtil, TvViews, TvWindow;
{$WARN 3018 OFF}  { "Constructor should be public": Create(streamableInit) is protected, as in tvision }

const
  MagicHeader = $46484246;          { 'FBHF' }
  CHelpViewer = #$06#$07#$08;
  CHelpWindow = #$80#$81#$82#$83#$84#$85#$86#$87;
  { the title of the help window and the text of a topic that is not in the file }
  HelpWinTitle = 'Help';
  InvalidContext =
    #10 + ' No help available in this context.';

type
  { one paragraph of a topic; the paragraphs of a topic form a list }
  PParagraph = ^TParagraph;
  TParagraph = record
    Text: PByte;                    { Size bytes followed by a zero }
    Size: Word;
    Wrap: Boolean;                  { False: the lines end only at #10 }
    Next: PParagraph;
  end;

  PCrossRef = ^TCrossRef;
  TCrossRef = record
    Ref: LongInt;                   { the number of the topic that the reference leads to }
    Offset: LongInt;                { in the text of the topic, counted from 1 over the paragraphs }
    Length: Byte;
  end;

  TCrossRefHandler = procedure(Os: opstream; Value: Integer);

  THelpTopic = class(TStreamable)
    Paragraphs: PParagraph;
    NumRefs: Integer;
    CrossRefs: PCrossRef;
    constructor Create; overload;
    destructor Destroy; override;
    procedure AddCrossRef(Ref: TCrossRef);
    procedure AddParagraph(P: PParagraph);
    { the place of a cross reference in the wrapped text: X, Y (Y from 1) and the width on the screen }
    procedure GetCrossRef(I: Integer; var Loc: TPoint; var Length: Byte; var Ref: Integer);
    function GetLine(Line: Integer): ShortString;
    function GetNumCrossRefs: Integer;
    function LongestLineWidth: Integer;
    function NumLines: Integer;
    procedure SetCrossRef(I: Integer; const Ref: TCrossRef);
    procedure SetNumCrossRefs(I: Integer);
    procedure SetWidth(AWidth: Integer);
  private
    Width: Integer;
    LastOffset: Integer;
    LastLine: Integer;
    LastParagraph: PParagraph;
    procedure WrapText(Text: PByte; Size: Integer; var Offset: Integer; Wrap: Boolean; out LineStart, LineLen: Integer);
    procedure DisposeParagraphs;
    procedure ReadParagraphs(Ip: ipstream);
    procedure ReadCrossRefs(Ip: ipstream);
    procedure WriteParagraphs(Os: opstream);
    procedure WriteCrossRefs(Os: opstream);
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    procedure Write(Os: opstream); override;
    function Read(Ip: ipstream): Pointer; override;
  public
    class function Build: TStreamable; static;
  end;


  THelpIndex = class(TStreamable)
    Size: LongInt;
    Index: PLongInt;
    constructor Create; overload;
    destructor Destroy; override;
    function Position(I: Integer): LongInt;
    procedure Add(I: Integer; Val: LongInt);
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    procedure Write(Os: opstream); override;
    function Read(Ip: ipstream): Pointer; override;
  public
    class function Build: TStreamable; static;
  end;


  THelpFile = class
    Stream: iopstream;
    Modified: Boolean;
    Index: THelpIndex;
    IndexPos: LongInt;
    { the file takes the stream and disposes it }
    constructor Create(S: iopstream);
    destructor Destroy; override;
    function GetTopic(I: Integer): THelpTopic;
    function InvalidTopic: THelpTopic;
    procedure RecordPositionInIndex(I: Integer);
    procedure PutTopic(Topic: THelpTopic);
  private
    class procedure EnsureStreamSize(S: iopstream; DesiredSize: Integer); static;
  end;


  { Palette: 1 = normal, 2 = keyword, 3 = selected keyword }
  THelpViewer = class;
  THelpViewer = class(TScroller)
    HFile: THelpFile;
    Topic: THelpTopic;
    Selected: Integer;
    constructor Create(const Bounds: TRect; AHScrollBar, AVScrollBar: TScrollBar; AHelpFile: THelpFile; Context: Word);
    destructor Destroy; override;
    procedure ChangeBounds(const Bounds: TRect); override;
    procedure Draw; override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure MakeSelectVisible(ASelected: Integer; var KeyPoint: TPoint; var KeyLength: Byte; var KeyRef: Integer);
    procedure SwitchToTopic(KeyRef: Integer);
  end;

  { Palette: 1 = frame passive, 2 = frame active, 3 = frame icon, 4 = scroll bar page area, 5 = scroll bar controls,
    6 = help viewer normal, 7 = help viewer keyword, 8 = help viewer selected keyword }
  THelpWindow = class;
  THelpWindow = class(TWindow)
    Viewer: THelpViewer;
    constructor Create(AHelpFile: THelpFile; Context: Word);
    procedure GotoContext(Context: Word);    { shows the topic of the context (DN reuses a window of the help) }
    function GetPalette: TPalette; override;
  end;

procedure NotAssigned(Os: opstream; Value: Integer);

var
  CrossRefHandler: TCrossRefHandler = @NotAssigned;
  RHelpTopic, RHelpIndex: TStreamableClass;

implementation

uses
  SysUtils;

procedure NotAssigned(Os: opstream; Value: Integer);
begin
end;

{ --- THelpTopic -------------------------------------------------------------- }

constructor THelpTopic.Create;
begin
  inherited Create;
  Paragraphs := nil;
  NumRefs := 0;
  CrossRefs := nil;
  Width := 0;
  LastOffset := 0;
  LastLine := MaxInt;
  LastParagraph := nil;
end;

constructor THelpTopic.Create(AInit: TStreamableInit);
begin
  inherited Create;
end;

class function THelpTopic.Build: TStreamable;
begin
  Result := THelpTopic.Create(streamableInit);
end;

function THelpTopic.StreamableName: ShortString;
begin
  Result := 'THelpTopic';
end;

procedure THelpTopic.Write(Os: opstream);
begin
  WriteParagraphs(Os);
  WriteCrossRefs(Os);
end;

function THelpTopic.Read(Ip: ipstream): Pointer;
begin
  ReadParagraphs(Ip);
  ReadCrossRefs(Ip);
  Width := 0;
  LastLine := MaxInt;
  Result := Self;
end;

{ a paragraph: its length (a Word), the wrap flag (an Integer), then the text }
procedure THelpTopic.ReadParagraphs(Ip: ipstream);
var
  Total, K, Flag: Integer;
  Len: Word;
  Tail: ^PParagraph;
  Fresh: PParagraph;
begin
  Total := 0;
  Ip.ReadBytes(Total, SizeOf(Integer));
  Tail := @Paragraphs;
  for K := 1 to Total do
  begin
    Len := Ip.ReadWord;
    Fresh := AllocMem(SizeOf(TParagraph));
    Fresh^.Size := Len;
    Fresh^.Text := AllocMem(Len + 1);
    Flag := 0;
    Ip.ReadBytes(Flag, SizeOf(Integer));
    Fresh^.Wrap := Flag <> 0;
    Ip.ReadBytes(Fresh^.Text^, Len);
    Tail^ := Fresh;
    Tail := @Fresh^.Next;
  end;
  Tail^ := nil;
end;

{ a cross reference: Ref and Offset (Integers), Length (a byte) }
procedure THelpTopic.ReadCrossRefs(Ip: ipstream);
var
  K: Integer;
  X: PCrossRef;
begin
  NumRefs := 0;
  Ip.ReadBytes(NumRefs, SizeOf(Integer));
  CrossRefs := nil;
  if NumRefs > 0 then
    CrossRefs := AllocMem(NumRefs * SizeOf(TCrossRef));
  for K := 0 to NumRefs - 1 do
  begin
    X := CrossRefs + K;
    Ip.ReadBytes(X^.Ref, SizeOf(Integer));
    Ip.ReadBytes(X^.Offset, SizeOf(Integer));
    X^.Length := Ip.ReadByte;
  end;
end;

procedure THelpTopic.WriteParagraphs(Os: opstream);
var
  Total, Flag: Integer;
  Para: PParagraph;
begin
  Total := 0;
  Para := Paragraphs;
  while Para <> nil do
  begin
    Para := Para^.Next;
    Inc(Total);
  end;
  Os.WriteBytes(Total, SizeOf(Integer));
  Para := Paragraphs;
  while Para <> nil do
  begin
    Os.WriteWord(Para^.Size);
    Flag := Ord(Para^.Wrap);
    Os.WriteBytes(Flag, SizeOf(Integer));
    Os.WriteBytes(Para^.Text^, Para^.Size);
    Para := Para^.Next;
  end;
end;

{ a handler, when set, writes the target of each reference itself }
procedure THelpTopic.WriteCrossRefs(Os: opstream);
var
  K: Integer;
  X: PCrossRef;
  ByHandler: Boolean;
begin
  Os.WriteBytes(NumRefs, SizeOf(Integer));
  ByHandler := Pointer(CrossRefHandler) <> Pointer(@NotAssigned);
  for K := 0 to NumRefs - 1 do
  begin
    X := CrossRefs + K;
    if ByHandler then
      CrossRefHandler(Os, X^.Ref)
    else
      Os.WriteBytes(X^.Ref, SizeOf(Integer));
    Os.WriteBytes(X^.Offset, SizeOf(Integer));
    Os.WriteByte(X^.Length);
  end;
end;

procedure THelpTopic.DisposeParagraphs;
var
  Cur: PParagraph;
begin
  while Paragraphs <> nil do
  begin
    Cur := Paragraphs;
    Paragraphs := Cur^.Next;
    FreeMem(Cur^.Text);
    Dispose(Cur);
  end;
  LastParagraph := nil;
end;

destructor THelpTopic.Destroy;
begin
  DisposeParagraphs;
  if CrossRefs <> nil then
    FreeMem(CrossRefs, NumRefs * SizeOf(TCrossRef));
  CrossRefs := nil;
  NumRefs := 0;
  inherited Destroy;
end;

procedure THelpTopic.AddCrossRef(Ref: TCrossRef);
begin
  SetNumCrossRefs(NumRefs + 1);
  (CrossRefs + NumRefs - 1)^ := Ref;
end;

procedure THelpTopic.AddParagraph(P: PParagraph);
var
  PP, Back: PParagraph;
begin
  if Paragraphs = nil then
    Paragraphs := P
  else
  begin
    PP := Paragraphs;
    Back := PP;
    while PP <> nil do
    begin
      Back := PP;
      PP := PP^.Next;
    end;
    Back^.Next := P;
  end;
  P^.Next := nil;
end;

{ Takes one line of the paragraph from Offset: the line is wrapped to the width of the topic, a word that is cut by the wrapping
  goes to the next line. LineStart and LineLen tell the line without the white space at its end, Offset moves past it. }
procedure THelpTopic.WrapText(Text: PByte; Size: Integer; var Offset: Integer; Wrap: Boolean; out LineStart, LineLen: Integer);
var
  LineEnd, Wrapped, NewSize, Dummy: Integer;
begin
  LineStart := Offset;
  LineEnd := Offset;
  while (LineEnd < Size) and (Text[LineEnd] <> 10) do
    Inc(LineEnd);
  if LineEnd < Size then
    Inc(LineEnd);                  { past the #10 }
  LineLen := LineEnd - LineStart;
  if Wrap and (Width > 0) then
  begin
    TText.Scroll(Text + LineStart, LineLen, Width, False, Wrapped, Dummy);
    if (Wrapped > 0) and (Wrapped < LineLen) then
    begin
      NewSize := Wrapped;
      { the last word is omitted if the wrapping cut it off }
      while (NewSize > 0) and not (Text[LineStart + NewSize] in [9, 10, 11, 12, 13, 32]) do
        Dec(NewSize);
      { unless it fills the whole line }
      if NewSize = 0 then
        NewSize := Wrapped;
      { if a blank follows, it is kept so that Offset moves past it }
      if (NewSize < LineLen) and (Text[LineStart + NewSize] in [9, 10, 11, 12, 13, 32]) then
        Inc(NewSize);
      LineLen := NewSize;
    end;
  end;
  Inc(Offset, LineLen);
  while (LineLen > 0) and (Text[LineStart + LineLen - 1] in [9, 10, 11, 12, 13, 32]) do
    Dec(LineLen);
end;

procedure THelpTopic.GetCrossRef(I: Integer; var Loc: TPoint; var Length: Byte; var Ref: Integer);
var
  Para: PParagraph;
  X: PCrossRef;
  Target, Before, InPara, Row, Start, LStart, LLen: Integer;
begin
  X := CrossRefs + I;
  Target := X^.Offset;
  Para := Paragraphs;
  Before := 0;           { bytes of the paragraphs already passed }
  InPara := 0;
  Row := 0;
  while Para <> nil do
  begin
    Start := InPara;
    WrapText(Para^.Text, Para^.Size, InPara, Para^.Wrap, LStart, LLen);
    Inc(Row);
    if Target <= Before + InPara then
    begin
      LStart := Target - (Before + Start) - 1;     { bytes of the line before the reference }
      Loc.X := TText.Width(Para^.Text + Start, LStart);
      Loc.Y := Row;
      Length := TText.Width(Para^.Text + Start + LStart, X^.Length);
      Ref := X^.Ref;
      Exit;
    end;
    if InPara >= Para^.Size then
    begin
      Inc(Before, Para^.Size);
      InPara := 0;
      Para := Para^.Next;
    end;
  end;
  Loc.X := 0;
  Loc.Y := 0;
  Length := 0;
  Ref := X^.Ref;
end;

function THelpTopic.GetLine(Line: Integer): ShortString;
var
  Para: PParagraph;
  Ofs, LStart, LLen, Wanted: Integer;
begin
  Result := '';
  Wanted := Line;
  if LastLine < Line then
  begin
    { go on from the line found the last time }
    Dec(Line, LastLine);
    Para := LastParagraph;
    Ofs := LastOffset;
  end
  else
  begin
    Para := Paragraphs;
    Ofs := 0;
  end;
  LastLine := Wanted;
  while Para <> nil do
  begin
    while Ofs < Para^.Size do
    begin
      WrapText(Para^.Text, Para^.Size, Ofs, Para^.Wrap, LStart, LLen);
      Dec(Line);
      if Line = 0 then
      begin
        LastParagraph := Para;
        LastOffset := Ofs;
        if LLen > 255 then
          LLen := 255;
        SetLength(Result, LLen);
        if LLen > 0 then
          Move(Para^.Text[LStart], Result[1], LLen);
        { tvhc writes the blanks inside a reference as #$FF so that they do not wrap }
        for Ofs := 1 to LLen do
          if Result[Ofs] = #$FF then
            Result[Ofs] := ' ';
        Exit;
      end;
    end;
    Para := Para^.Next;
    Ofs := 0;
  end;
end;

function THelpTopic.GetNumCrossRefs: Integer;
begin
  Result := NumRefs;
end;

function THelpTopic.LongestLineWidth: Integer;
var
  I, W: Integer;
  S: ShortString;
begin
  Result := 0;
  for I := 1 to NumLines do
  begin
    S := GetLine(I);
    W := TText.Width(S);
    if W > Result then
      Result := W;
  end;
end;

function THelpTopic.NumLines: Integer;
var
  Para: PParagraph;
  Ofs, LStart, LLen: Integer;
begin
  Result := 0;
  Para := Paragraphs;
  while Para <> nil do
  begin
    Ofs := 0;
    while Ofs < Para^.Size do
    begin
      WrapText(Para^.Text, Para^.Size, Ofs, Para^.Wrap, LStart, LLen);
      Inc(Result);
    end;
    Para := Para^.Next;
  end;
end;

procedure THelpTopic.SetCrossRef(I: Integer; const Ref: TCrossRef);
begin
  if (I >= 0) and (I < NumRefs) then
    (CrossRefs + I)^ := Ref;
end;

procedure THelpTopic.SetNumCrossRefs(I: Integer);
var
  Fresh: PCrossRef;
  Keep: Integer;
begin
  if I = NumRefs then
    Exit;
  Fresh := nil;
  if I > 0 then
    GetMem(Fresh, I * SizeOf(TCrossRef));
  Keep := NumRefs;
  if Keep > I then
    Keep := I;
  if (Keep > 0) and (CrossRefs <> nil) then
    Move(CrossRefs^, Fresh^, Keep * SizeOf(TCrossRef));
  if CrossRefs <> nil then
    FreeMem(CrossRefs);
  CrossRefs := Fresh;
  NumRefs := I;
end;

procedure THelpTopic.SetWidth(AWidth: Integer);
begin
  Width := AWidth;
  LastLine := MaxInt;              { the cached place of the last line was found with the old width }
end;

{ --- THelpIndex -------------------------------------------------------------- }

constructor THelpIndex.Create;
begin
  inherited Create;
  Size := 0;
  Index := nil;
end;

constructor THelpIndex.Create(AInit: TStreamableInit);
begin
  inherited Create;
end;

class function THelpIndex.Build: TStreamable;
begin
  Result := THelpIndex.Create(streamableInit);
end;

function THelpIndex.StreamableName: ShortString;
begin
  Result := 'THelpIndex';
end;

{ the size (an Integer), then Size positions (Integers) }
procedure THelpIndex.Write(Os: opstream);
begin
  Os.WriteBytes(Size, SizeOf(Integer));
  if Size > 0 then
    Os.WriteBytes(Index^, Size * SizeOf(LongInt));
end;

function THelpIndex.Read(Ip: ipstream): Pointer;
begin
  Size := 0;
  Ip.ReadBytes(Size, SizeOf(Integer));
  Index := nil;
  if Size > 0 then
  begin
    Index := AllocMem(Size * SizeOf(LongInt));
    Ip.ReadBytes(Index^, Size * SizeOf(LongInt));
  end;
  Result := Self;
end;

destructor THelpIndex.Destroy;
begin
  if Index <> nil then
    FreeMem(Index, Size * SizeOf(LongInt));
  Index := nil;
  inherited Destroy;
end;

function THelpIndex.Position(I: Integer): LongInt;
begin
  if (I >= 0) and (I < Size) then
    Result := (Index + I)^
  else
    Result := -1;
end;

procedure THelpIndex.Add(I: Integer; Val: LongInt);
const
  Delta = 10;
var
  P: PLongInt;
  NewSize: Integer;
begin
  if I >= Size then
  begin
    NewSize := (I + Delta) div Delta * Delta;
    GetMem(P, NewSize * SizeOf(LongInt));
    if Index <> nil then
    begin
      Move(Index^, P^, Size * SizeOf(LongInt));
      FreeMem(Index, Size * SizeOf(LongInt));
    end;
    FillChar((P + Size)^, (NewSize - Size) * SizeOf(LongInt), $FF);
    Index := P;
    Size := NewSize;
  end;
  (Index + I)^ := Val;
end;

{ --- THelpFile --------------------------------------------------------------- }

constructor THelpFile.Create(S: iopstream);
var
  Magic, Size: LongInt;
begin
  inherited Create;
  Magic := 0;
  S.SeekG(0, fsFromEnd);
  Size := S.TellG;
  S.SeekG(0);
  if Size > SizeOf(Magic) then
    S.ReadBytes(Magic, SizeOf(Magic));
  if (Magic = MagicHeader) and (Size >= 12) then
  begin
    S.SeekG(8);
    S.ReadBytes(IndexPos, SizeOf(IndexPos));
    S.SeekG(IndexPos);
    Index := THelpIndex(S.ReadPointer);
    if Index = nil then
      Index := THelpIndex.Create;
    Modified := False;
  end
  else
  begin
    IndexPos := 12;
    Index := THelpIndex.Create;
    Modified := True;
  end;
  Stream := S;
end;

destructor THelpFile.Destroy;
var
  Magic, Size: LongInt;
begin
  if Modified and (Stream <> nil) then
  begin
    EnsureStreamSize(Stream, IndexPos);
    Stream.SeekP(IndexPos);
    Stream.WritePointer(Index);
    Magic := MagicHeader;
    Stream.SeekP(0, fsFromEnd);
    Size := Stream.TellP - 8;
    Stream.SeekP(0);
    Stream.WriteBytes(Magic, SizeOf(Magic));
    Stream.WriteBytes(Size, SizeOf(Size));
    Stream.WriteBytes(IndexPos, SizeOf(IndexPos));
  end;
  FreeAndNil(Stream);
  FreeAndNil(Index);
  inherited Destroy;
end;

function THelpFile.GetTopic(I: Integer): THelpTopic;
var
  Pos: LongInt;
begin
  Result := nil;
  Pos := Index.Position(I);
  if Pos > 0 then
  begin
    Stream.SeekG(Pos);
    Result := THelpTopic(Stream.ReadPointer);
  end;
  if Result = nil then
    Result := InvalidTopic;
end;

function THelpFile.InvalidTopic: THelpTopic;
var
  Para: PParagraph;
begin
  Result := THelpTopic.Create;
  New(Para);
  Para^.Size := Length(InvalidContext);
  GetMem(Para^.Text, Para^.Size + 1);
  Move(InvalidContext[1], Para^.Text^, Para^.Size);
  Para^.Text[Para^.Size] := 0;
  Para^.Wrap := False;
  Para^.Next := nil;
  Result.AddParagraph(Para);
end;

procedure THelpFile.RecordPositionInIndex(I: Integer);
begin
  Index.Add(I, IndexPos);
  Modified := True;
end;

procedure THelpFile.PutTopic(Topic: THelpTopic);
begin
  EnsureStreamSize(Stream, IndexPos);
  Stream.SeekP(IndexPos);
  Stream.WritePointer(Topic);
  IndexPos := Stream.TellP;
  Modified := True;
end;

{ a stream that is shorter than DesiredSize is filled up to it with zero bytes }
class procedure THelpFile.EnsureStreamSize(S: iopstream; DesiredSize: Integer);
var
  CurrentSize: Int64;
begin
  S.SeekG(0, fsFromEnd);
  CurrentSize := S.TellG;
  if CurrentSize < DesiredSize then
  begin
    S.SeekP(0, fsFromEnd);
    while CurrentSize < DesiredSize do
    begin
      S.WriteByte(0);
      Inc(CurrentSize);
    end;
  end;
end;

{ --- THelpViewer ------------------------------------------------------------- }

constructor THelpViewer.Create(const Bounds: TRect; AHScrollBar, AVScrollBar: TScrollBar; AHelpFile: THelpFile; Context: Word);
begin
  inherited Create(Bounds, AHScrollBar, AVScrollBar);
  Options := Options or ofSelectable;
  GrowMode := gfGrowHiX or gfGrowHiY;
  HFile := AHelpFile;
  Topic := AHelpFile.GetTopic(Context);
  Topic.SetWidth(Size.X);        { the width for the wrapping of the lines }
  SetLimit(Topic.LongestLineWidth, Topic.NumLines);
  Selected := 1;
end;

destructor THelpViewer.Destroy;
begin
  if HFile <> nil then
    HFile.Free;
  HFile := nil;
  if Topic <> nil then
    Topic.Free;
  Topic := nil;
  inherited Destroy;
end;

procedure THelpViewer.ChangeBounds(const Bounds: TRect);
begin
  inherited ChangeBounds(Bounds);
  Topic.SetWidth(Size.X);
  SetLimit(Topic.LongestLineWidth, Topic.NumLines);
end;

procedure THelpViewer.Draw;
var
  B: TDrawBuffer;
  Normal, Keyword, SelKeyword, Attr: TColorAttr;
  Row, K, Len, Shown, Refs: Integer;
  KeyPoint: TPoint;
  KeyLength: Byte;
  KeyRef: Integer;
  Line: ShortString;
begin
  Normal := GetColor(1)[0];
  Keyword := GetColor(2)[0];
  SelKeyword := GetColor(3)[0];
  Topic.SetWidth(Size.X);
  Refs := Topic.GetNumCrossRefs;
  Shown := 0;
  KeyPoint.X := 0;
  KeyPoint.Y := 0;
  KeyLength := 0;
  KeyRef := 0;
  { skip the references above the visible part }
  while (Shown < Refs) and ((Shown = 0) or (KeyPoint.Y <= Delta.Y)) do
  begin
    Topic.GetCrossRef(Shown, KeyPoint, KeyLength, KeyRef);
    Inc(Shown);
  end;
  B := TDrawBuffer.Create(Size.X);
  try
    for Row := 1 to Size.Y do
    begin
      B.MoveChar(0, Ord(' '), Normal, Size.X);
      Line := Topic.GetLine(Row + Delta.Y);
      if TText.Width(Line) > Delta.X then
        B.MoveStrS(0, Line, Normal, Size.X, Delta.X);
      while KeyPoint.Y = Row + Delta.Y do
      begin
        Len := KeyLength;
        if KeyPoint.X < Delta.X then
        begin
          Dec(Len, Delta.X - KeyPoint.X);
          KeyPoint.X := Delta.X;
        end;
        if Shown = Selected then
          Attr := SelKeyword
        else
          Attr := Keyword;
        for K := 0 to Len - 1 do
          B.PutAttribute(KeyPoint.X - Delta.X + K, Attr);
        if Shown < Refs then
        begin
          Topic.GetCrossRef(Shown, KeyPoint, KeyLength, KeyRef);
          Inc(Shown);
        end
        else
          KeyPoint.Y := 0;
      end;
      WriteLine(0, Row - 1, Size.X, 1, B);
    end;
  finally
    B.Free;
  end;
end;

function THelpViewer.GetPalette: TPalette;
begin
  Result := TPalette.Create(CHelpViewer, Length(CHelpViewer));
end;

procedure THelpViewer.MakeSelectVisible(ASelected: Integer; var KeyPoint: TPoint; var KeyLength: Byte; var KeyRef: Integer);
var
  NewX, NewY: Integer;
begin
  Topic.GetCrossRef(ASelected, KeyPoint, KeyLength, KeyRef);
  NewX := Delta.X;
  NewY := Delta.Y;
  if KeyPoint.X < NewX then
    NewX := KeyPoint.X
  else if KeyPoint.X > NewX + Size.X then
    NewX := KeyPoint.X - Size.X;
  if KeyPoint.Y <= NewY then
    NewY := KeyPoint.Y - 1;
  if KeyPoint.Y > NewY + Size.Y then
    NewY := KeyPoint.Y - Size.Y;
  if (NewX <> Delta.X) or (NewY <> Delta.Y) then
    ScrollTo(NewX, NewY);
end;

procedure THelpViewer.SwitchToTopic(KeyRef: Integer);
begin
  if Topic <> nil then
    Topic.Free;
  Topic := HFile.GetTopic(KeyRef);
  Topic.SetWidth(Size.X);
  ScrollTo(0, 0);
  SetLimit(Topic.LongestLineWidth, Topic.NumLines);
  Selected := 1;
  DrawView;
end;

procedure THelpViewer.HandleEvent(var Event: TEvent);
var
  KeyPoint, Mouse: TPoint;
  KeyLength: Byte;
  KeyRef, Refs, Hit, K: Integer;
  InModal: Boolean;
begin
  inherited HandleEvent(Event);
  Refs := Topic.GetNumCrossRefs;
  case Event.What of
    evKeyDown:
      begin
        if Event.KeyDown.KeyCode = kbTab then
        begin
          Inc(Selected);
          if Selected > Refs then
            Selected := 1;
          if Refs > 0 then
            MakeSelectVisible(Selected - 1, KeyPoint, KeyLength, KeyRef);
        end
        else if Event.KeyDown.KeyCode = kbShiftTab then
        begin
          Dec(Selected);
          if Selected <= 0 then
            Selected := Refs;
          if Refs > 0 then
            MakeSelectVisible(Selected - 1, KeyPoint, KeyLength, KeyRef);
        end
        else if Event.KeyDown.KeyCode = kbEnter then
        begin
          if (Selected >= 1) and (Selected <= Refs) then
          begin
            Topic.GetCrossRef(Selected - 1, KeyPoint, KeyLength, KeyRef);
            SwitchToTopic(KeyRef);
          end;
        end
        else if Event.KeyDown.KeyCode = kbEsc then
        begin
          Event.What := evCommand;
          Event.Message.Command := cmClose;
          PutEvent(Event);
        end
        else
          Exit;
        DrawView;
        ClearEvent(Event);
      end;
    evMouseDown:
      begin
        { the place in the topic: columns from 0, lines from 1 }
        Mouse := MakeLocal(Event.Mouse.Where);
        Mouse.X := Mouse.X + Delta.X;
        Mouse.Y := Mouse.Y + Delta.Y + 1;
        Hit := -1;
        for K := 0 to Refs - 1 do
        begin
          Topic.GetCrossRef(K, KeyPoint, KeyLength, KeyRef);
          if (KeyPoint.Y = Mouse.Y) and (Mouse.X >= KeyPoint.X) and (Mouse.X - KeyPoint.X < KeyLength) then
          begin
            Hit := K;
            Break;
          end;
        end;
        if Hit < 0 then
          Exit;               { not on a reference }
        ClearEvent(Event);
        Selected := Hit + 1;
        DrawView;
        SwitchToTopic(KeyRef);
      end;
    evCommand:
      begin
        InModal := (Owner <> nil) and ((Owner.State and sfModal) <> 0);
        if InModal and (Event.Message.Command = cmClose) then
        begin
          ClearEvent(Event);
          EndModal(cmClose);
        end;
      end;
  end;
end;

{ --- THelpWindow ------------------------------------------------------------- }

constructor THelpWindow.Create(AHelpFile: THelpFile; Context: Word);
var
  R: TRect;
begin
  R := TRect.Create(0, 0, 50, 18);
  inherited Create(R, HelpWinTitle, wnNoNumber);
  Options := Options or ofCentered;
  R.Grow(-2, -1);
  Viewer := THelpViewer.Create(R, StandardScrollBar(sbHorizontal or sbHandleKeyboard),
    StandardScrollBar(sbVertical or sbHandleKeyboard), AHelpFile, Context);
  Insert(Viewer);
end;

procedure THelpWindow.GotoContext(Context: Word);
begin
  if Viewer <> nil then
    Viewer.SwitchToTopic(Context);
end;

function THelpWindow.GetPalette: TPalette;
begin
  Result := TPalette.Create(CHelpWindow, Length(CHelpWindow));
end;

initialization
  RHelpTopic := TStreamableClass.Create('THelpTopic', @THelpTopic.Build);
  RHelpIndex := TStreamableClass.Create('THelpIndex', @THelpIndex.Build);

end.
