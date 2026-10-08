{ TvIni: INI files that keep what the user wrote.

  MIT as the one INI reader/writer of dn and fpide (the feature list comes from what both of them need).

  Format
    [Section]                       a section; the lines before the first one belong to the section MainSectionName
    Tag=Value ;Comment              an entry; the part after the first ';' that is outside quotes is the comment
    Tag='a ; b'  Tag="it's"         a value in quotes: the quote of the same kind inside is doubled ('it''s')
    ; text                          a line that is no entry (a comment, an empty line, any text) is kept as it is
  Tags and sections are compared without regard to case. The values are text: UTF-8 bytes go through unchanged (a byte order mark
  at the start of the file is dropped and written back). The line ends of the file (CR LF or LF) are kept.

  What the user did not change is written back as it was read (spaces, comments, order). SetEntry quotes the value by itself when it
  has to (a ';', a quote, spaces at the ends); GetEntry gives the value without the quotes.

  Update writes through a temporary file and renames it, so a crash does not leave half of an INI file. }
unit TvIni;

{$I tvdefs.inc}

interface

type
  TIniEntry = class
  private
    FTag, FValue, FComment: AnsiString;
    FText: AnsiString;                  { the line as it was read; empty after a change }
    FHasText: Boolean;
    FIsEntry: Boolean;                  { False: a line that is no entry (kept as FText) }
    FRaw: Boolean;                      { no comments after a value, no quoting on writing (the Windows profile way) }
    procedure Parse(const ALine: AnsiString);
  public
    constructor Create(const ALine: AnsiString); overload;
    constructor Create(const ALine: AnsiString; ARaw: Boolean); overload;
    constructor Create(const ATag, AValue, AComment: AnsiString; ARaw: Boolean = False); overload;
    function GetText: AnsiString;
    function GetTag: AnsiString;
    function GetValue: AnsiString;
    function GetComment: AnsiString;
    procedure SetValue(const S: AnsiString);
    procedure SetComment(const S: AnsiString);
    { False for an empty line or a comment line }
    function IsEntry: Boolean;
  end;

  TIniSection = class;

  { the P names are kept for programs that used pointers to these }
  PIniEntry = TIniEntry;
  PIniSection = TIniSection;

  { callbacks of the enumerations; nested routines are accepted }
  TIniEntryEnumProc = procedure(P: PIniEntry) is nested;
  TIniSectionEnumProc = procedure(P: PIniSection) is nested;

  TIniSection = class
  private
    FName: AnsiString;
    FEntries: array of TIniEntry;
    FCount: Integer;
    FRaw: Boolean;
    function IndexOf(const Tag: AnsiString): Integer;
  public
    constructor Create(const AName: AnsiString; ARaw: Boolean = False);
    destructor Destroy; override;
    function GetName: AnsiString;
    function AddEntry(const S: AnsiString): PIniEntry; overload;
    function AddEntry(const Tag, Value, Comment: AnsiString): PIniEntry; overload;
    function SearchEntry(const Tag: AnsiString): PIniEntry;
    procedure DeleteEntry(const Tag: AnsiString);
    procedure ForEachEntry(EnumProc: TIniEntryEnumProc);
    { Entries, including the lines that are no entries; the first is 0 }
    function Count: Integer;
    function Entry(I: Integer): PIniEntry;
  end;

  TIniFile = class
  private
    FFileName: AnsiString;
    FSections: array of TIniSection;
    FCount: Integer;
    FModified: Boolean;
    FBom: Boolean;
    FCrLf: Boolean;
    function IndexOf(const Name: AnsiString): Integer;
    function AddSection(const Name: AnsiString): TIniSection;
  public
    { True: reading a missing tag adds it (with the default) to the file, so that the file lists all the settings that the program knows }
    MakeNullEntries: Boolean;
    { False (set it before Read): the Windows profile way: the value is everything after '=', a ';' in it is no comment, SetEntry does not quote }
    InlineComments: Boolean;
    constructor Create(const AFileName: AnsiString);
    destructor Destroy; override;
    function GetFileName: AnsiString;
    { Read: loads the file (False when it cannot be read; the INI is empty then). Update: writes it if something changed. }
    function Read: Boolean;
    function Update: Boolean;
    function IsModified: Boolean;
    { The text of an INI file instead of the file: for tests and for INI texts inside a program }
    procedure LoadFromText(const Text: AnsiString);
    function SaveToText: AnsiString;

    function SearchSection(const Section: AnsiString): PIniSection;
    function SearchEntry(const Section, Tag: AnsiString): PIniEntry;
    procedure ForEachSection(EnumProc: TIniSectionEnumProc);
    procedure ForEachEntry(const Section: AnsiString; EnumProc: TIniEntryEnumProc);

    function GetEntry(const Section, Tag, Default: AnsiString): AnsiString;
    procedure SetEntry(const Section, Tag, Value: AnsiString); overload;
    procedure SetEntry(const Section, Tag, Value, Comment: AnsiString); overload;
    function GetIntEntry(const Section, Tag: AnsiString; Default: LongInt): LongInt;
    procedure SetIntEntry(const Section, Tag: AnsiString; Value: LongInt);
    function GetBoolEntry(const Section, Tag: AnsiString; Default: Boolean): Boolean;
    procedure SetBoolEntry(const Section, Tag: AnsiString; Value: Boolean);
    function EntryExists(const Section, Tag: AnsiString): Boolean;
    procedure DeleteSection(const Section: AnsiString);
    procedure DeleteEntry(const Section, Tag: AnsiString);
    function SectionCount: Integer;
    function SectionAt(I: Integer): PIniSection;
  end;
  PIniFile = TIniFile;

const
  MainSectionName = 'MainSection';
  CommentChar = ';';

{ The value as it is written in a file: in quotes when it needs them. }
function IniQuote(const S: AnsiString): AnsiString;

implementation

uses
  SysUtils, TvUStr;

function Lower(const S: AnsiString): AnsiString;
begin
  Result := U8Lower(S);
end;

function IsDelimiter(C: Char): Boolean;
begin
  Result := (C = '''') or (C = '"');
end;

function IniQuote(const S: AnsiString): AnsiString;
var
  Need: Boolean;
  I: Integer;
  D: Char;
begin
  Need := (S <> '') and ((S[1] <= ' ') or (S[Length(S)] <= ' ') or IsDelimiter(S[1]));
  if not Need then
    for I := 1 to Length(S) do
      if (S[I] = CommentChar) or (S[I] < ' ') then
        Need := True;
  if not Need then
    Exit(S);
  D := '''';
  if Pos(D, S) > 0 then
    D := '"';
  Result := D;
  for I := 1 to Length(S) do
  begin
    if S[I] = D then
      Result := Result + D;
    Result := Result + S[I];
  end;
  Result := Result + D;
end;

{ --- TIniEntry --- }

constructor TIniEntry.Create(const ALine: AnsiString);
begin
  Create(ALine, False);
end;

constructor TIniEntry.Create(const ALine: AnsiString; ARaw: Boolean);
begin
  inherited Create;
  FRaw := ARaw;
  Parse(ALine);
end;

constructor TIniEntry.Create(const ATag, AValue, AComment: AnsiString; ARaw: Boolean);
begin
  inherited Create;
  FRaw := ARaw;
  FTag := ATag;
  FValue := AValue;
  FComment := AComment;
  FIsEntry := True;
  FHasText := False;
end;

procedure TIniEntry.Parse(const ALine: AnsiString);
var
  P, I: Integer;
  C, Delim: Char;
  InStr: Boolean;
  V: AnsiString;
begin
  FText := ALine;
  FHasText := True;
  FIsEntry := False;
  FTag := '';
  FValue := '';
  FComment := '';
  P := Pos('=', ALine);
  I := Pos(CommentChar, ALine);
  if (P = 0) or ((I <> 0) and (I < P)) or (Trim(Copy(ALine, 1, P - 1)) = '') then
    Exit;                                       { no entry: kept as the line }
  FIsEntry := True;
  FTag := Trim(Copy(ALine, 1, P - 1));
  if FRaw then
  begin
    V := Copy(ALine, P + 1, MaxInt);
    if (Length(V) >= 2) and IsDelimiter(V[1]) and (V[Length(V)] = V[1]) then
      V := Copy(V, 2, Length(V) - 2);          { the quotes of the ends are not a part of the value }
    FValue := V;
    Exit;
  end;
  V := '';
  Delim := #0;
  InStr := False;
  I := P + 1;
  while (I <= Length(ALine)) and (ALine[I] <= ' ') do
    Inc(I);                                     { the spaces before the value }
  if (I <= Length(ALine)) and IsDelimiter(ALine[I]) then
  begin
    Delim := ALine[I];
    InStr := True;
    Inc(I);
  end;
  while I <= Length(ALine) do
  begin
    C := ALine[I];
    if InStr then
    begin
      if C = Delim then
      begin
        if (I < Length(ALine)) and (ALine[I + 1] = Delim) then
        begin
          V := V + Delim;                       { a doubled quote is one quote }
          Inc(I);
        end
        else
          InStr := False;
      end
      else
        V := V + C;
    end
    else if C = CommentChar then
      Break
    else if Delim = #0 then
      V := V + C;                               { after the closing quote only the comment may follow: the rest is dropped }
    Inc(I);
  end;
  if Delim = #0 then
    FValue := Trim(V)
  else
    FValue := V;
  if (I <= Length(ALine)) and (ALine[I] = CommentChar) then
    FComment := Copy(ALine, I + 1, MaxInt)
  else
    FComment := '';
end;

function TIniEntry.GetText: AnsiString;
begin
  if FHasText then
    Exit(FText);
  if not FIsEntry then
    Exit('');
  if FRaw then
    Exit(FTag + '=' + FValue);
  Result := FTag + '=' + IniQuote(FValue);
  if FComment <> '' then
    Result := Result + ' ' + CommentChar + FComment;
end;

function TIniEntry.GetTag: AnsiString;
begin
  Result := FTag;
end;

function TIniEntry.GetValue: AnsiString;
begin
  Result := FValue;
end;

function TIniEntry.GetComment: AnsiString;
begin
  Result := FComment;
end;

procedure TIniEntry.SetValue(const S: AnsiString);
begin
  if FIsEntry and (FValue = S) then
    Exit;
  FValue := S;
  FIsEntry := True;
  FHasText := False;
end;

procedure TIniEntry.SetComment(const S: AnsiString);
begin
  if FIsEntry and (FComment = S) then
    Exit;
  FComment := S;
  FHasText := False;
end;

function TIniEntry.IsEntry: Boolean;
begin
  Result := FIsEntry;
end;

{ --- TIniSection --- }

constructor TIniSection.Create(const AName: AnsiString; ARaw: Boolean);
begin
  inherited Create;
  FName := AName;
  FRaw := ARaw;
end;

destructor TIniSection.Destroy;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    FEntries[I].Free;
  inherited Destroy;
end;

function TIniSection.GetName: AnsiString;
begin
  Result := FName;
end;

function TIniSection.IndexOf(const Tag: AnsiString): Integer;
var
  I: Integer;
  L: AnsiString;
begin
  L := Lower(Tag);
  for I := 0 to FCount - 1 do
    if FEntries[I].FIsEntry and (Lower(FEntries[I].FTag) = L) then
      Exit(I);
  Result := -1;
end;

function TIniSection.AddEntry(const S: AnsiString): PIniEntry;
begin
  if FCount = Length(FEntries) then
    SetLength(FEntries, FCount * 2 + 8);
  Result := TIniEntry.Create(S, FRaw);
  FEntries[FCount] := Result;
  Inc(FCount);
end;

function TIniSection.AddEntry(const Tag, Value, Comment: AnsiString): PIniEntry;
begin
  if FCount = Length(FEntries) then
    SetLength(FEntries, FCount * 2 + 8);
  Result := TIniEntry.Create(Tag, Value, Comment, FRaw);
  FEntries[FCount] := Result;
  Inc(FCount);
end;

function TIniSection.SearchEntry(const Tag: AnsiString): PIniEntry;
var
  I: Integer;
begin
  I := IndexOf(Tag);
  if I < 0 then
    Result := nil
  else
    Result := FEntries[I];
end;

procedure TIniSection.DeleteEntry(const Tag: AnsiString);
var
  I: Integer;
begin
  I := IndexOf(Tag);
  if I < 0 then
    Exit;
  FEntries[I].Free;
  Move(FEntries[I + 1], FEntries[I], (FCount - I - 1) * SizeOf(TIniEntry));
  Dec(FCount);
end;

procedure TIniSection.ForEachEntry(EnumProc: TIniEntryEnumProc);
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FEntries[I].FIsEntry then
      EnumProc(FEntries[I]);
end;

function TIniSection.Count: Integer;
begin
  Result := FCount;
end;

function TIniSection.Entry(I: Integer): PIniEntry;
begin
  Result := FEntries[I];
end;

{ --- TIniFile --- }

constructor TIniFile.Create(const AFileName: AnsiString);
begin
  inherited Create;
  FFileName := AFileName;
  InlineComments := True;
  FCrLf := {$ifdef unix}False{$else}True{$endif};
end;

destructor TIniFile.Destroy;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    FSections[I].Free;
  inherited Destroy;
end;

function TIniFile.GetFileName: AnsiString;
begin
  Result := FFileName;
end;

function TIniFile.IndexOf(const Name: AnsiString): Integer;
var
  I: Integer;
  L: AnsiString;
begin
  L := Lower(Name);
  for I := 0 to FCount - 1 do
    if Lower(FSections[I].FName) = L then
      Exit(I);
  Result := -1;
end;

function TIniFile.AddSection(const Name: AnsiString): TIniSection;
begin
  if FCount = Length(FSections) then
    SetLength(FSections, FCount * 2 + 8);
  Result := TIniSection.Create(Name, not InlineComments);
  FSections[FCount] := Result;
  Inc(FCount);
end;

procedure TIniFile.LoadFromText(const Text: AnsiString);
var
  I, Start, N: Integer;
  Line, T: AnsiString;
  Cur: TIniSection;
begin
  for I := 0 to FCount - 1 do
    FSections[I].Free;
  FSections := nil;
  FCount := 0;
  FBom := (Length(Text) >= 3) and (Byte(Text[1]) = $EF) and (Byte(Text[2]) = $BB) and (Byte(Text[3]) = $BF);
  Start := 1;
  if FBom then
    Inc(Start, 3);
  N := Length(Text);
  I := Start;
  Cur := nil;
  FCrLf := {$ifdef unix}False{$else}True{$endif};
  while Start <= N do
  begin
    I := Start;
    while (I <= N) and (Text[I] <> #10) do
      Inc(I);
    Line := Copy(Text, Start, I - Start);
    if (Line <> '') and (Line[Length(Line)] = #13) then
    begin
      SetLength(Line, Length(Line) - 1);
      FCrLf := True;
    end
    else if I <= N then
      FCrLf := False;
    Start := I + 1;
    T := Trim(Line);
    if (Length(T) >= 2) and (T[1] = '[') and (T[Length(T)] = ']') then
      Cur := AddSection(Trim(Copy(T, 2, Length(T) - 2)))
    else
    begin
      if Cur = nil then
        Cur := AddSection(MainSectionName);
      Cur.AddEntry(Line);
    end;
  end;
  FModified := False;
end;

function TIniFile.SaveToText: AnsiString;
var
  I, J: Integer;
  Eol: AnsiString;
  S: AnsiString;
begin
  if FCrLf then
    Eol := #13#10
  else
    Eol := #10;
  S := '';
  if FBom then
    S := Chr($EF) + Chr($BB) + Chr($BF);
  for I := 0 to FCount - 1 do
  begin
    if not ((I = 0) and (FSections[I].FName = MainSectionName)) then
      S := S + '[' + FSections[I].FName + ']' + Eol;
    for J := 0 to FSections[I].FCount - 1 do
      S := S + FSections[I].FEntries[J].GetText + Eol;
  end;
  Result := S;
end;

function TIniFile.Read: Boolean;
var
  F: file;
  Buf: AnsiString;
  Got: LongInt;
begin
  Result := False;
  if FFileName = '' then
    Exit;
  Assign(F, FFileName);
  {$push}{$I-}
  FileMode := 0;
  Reset(F, 1);
  {$pop}
  if IOResult <> 0 then
  begin
    LoadFromText('');
    Exit;
  end;
  SetLength(Buf, FileSize(F));
  if Length(Buf) > 0 then
    BlockRead(F, Buf[1], Length(Buf), Got);
  Close(F);
  LoadFromText(Buf);
  Result := True;
end;

function TIniFile.Update: Boolean;
var
  F: file;
  Buf, Tmp: AnsiString;
begin
  Result := True;
  if (not FModified) or (FFileName = '') then
    Exit;
  Buf := SaveToText;
  Tmp := FFileName + '.tmp';
  Assign(F, Tmp);
  {$push}{$I-}
  Rewrite(F, 1);
  if IOResult <> 0 then
    Exit(False);
  if Length(Buf) > 0 then
    BlockWrite(F, Buf[1], Length(Buf));
  Close(F);
  {$pop}
  if IOResult <> 0 then
    Exit(False);
  if FileExists(FFileName) then
    DeleteFile(FFileName);
  if not RenameFile(Tmp, FFileName) then
    Exit(False);
  FModified := False;
end;

function TIniFile.IsModified: Boolean;
begin
  Result := FModified;
end;

function TIniFile.SearchSection(const Section: AnsiString): PIniSection;
var
  I: Integer;
begin
  I := IndexOf(Section);
  if I < 0 then
    Result := nil
  else
    Result := FSections[I];
end;

function TIniFile.SearchEntry(const Section, Tag: AnsiString): PIniEntry;
var
  S: PIniSection;
begin
  S := SearchSection(Section);
  if S = nil then
    Result := nil
  else
    Result := S.SearchEntry(Tag);
end;

procedure TIniFile.ForEachSection(EnumProc: TIniSectionEnumProc);
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    EnumProc(FSections[I]);
end;

procedure TIniFile.ForEachEntry(const Section: AnsiString; EnumProc: TIniEntryEnumProc);
var
  S: PIniSection;
begin
  S := SearchSection(Section);
  if S <> nil then
    S.ForEachEntry(EnumProc);
end;

function TIniFile.GetEntry(const Section, Tag, Default: AnsiString): AnsiString;
var
  E: PIniEntry;
begin
  E := SearchEntry(Section, Tag);
  if E <> nil then
    Exit(E.GetValue);
  Result := Default;
  if MakeNullEntries then
    SetEntry(Section, Tag, Default);
end;

procedure TIniFile.SetEntry(const Section, Tag, Value: AnsiString);
var
  E: PIniEntry;
begin
  E := SearchEntry(Section, Tag);
  if E <> nil then
    SetEntry(Section, Tag, Value, E.GetComment)
  else
    SetEntry(Section, Tag, Value, '');
end;

procedure TIniFile.SetEntry(const Section, Tag, Value, Comment: AnsiString);
var
  E: PIniEntry;
  S: PIniSection;
  Was: AnsiString;
begin
  E := SearchEntry(Section, Tag);
  if E = nil then
  begin
    if (Value = '') and not MakeNullEntries then
      Exit;                                     { nothing to write for an empty value of a tag that is not there }
    S := SearchSection(Section);
    if S = nil then
    begin
      if (FCount > 0) and (FSections[FCount - 1].FCount > 0) and (Trim(FSections[FCount - 1].FEntries[FSections[FCount - 1].FCount - 1].GetText) <> '') then
        FSections[FCount - 1].AddEntry('');     { a blank line before a new section }
      S := AddSection(Section);
    end;
    S.AddEntry(Tag, Value, Comment);
    FModified := True;
    Exit;
  end;
  Was := E.GetText;
  E.SetValue(Value);
  E.SetComment(Comment);
  if E.GetText <> Was then
    FModified := True;
end;

function TIniFile.GetIntEntry(const Section, Tag: AnsiString; Default: LongInt): LongInt;
begin
  Result := StrToIntDef(Trim(GetEntry(Section, Tag, IntToStr(Default))), Default);
end;

procedure TIniFile.SetIntEntry(const Section, Tag: AnsiString; Value: LongInt);
begin
  SetEntry(Section, Tag, IntToStr(Value));
end;

function TIniFile.GetBoolEntry(const Section, Tag: AnsiString; Default: Boolean): Boolean;
var
  S: AnsiString;
begin
  S := Lower(Trim(GetEntry(Section, Tag, '')));
  if (S = '1') or (S = 'true') or (S = 'yes') or (S = 'on') then
    Result := True
  else if (S = '0') or (S = 'false') or (S = 'no') or (S = 'off') then
    Result := False
  else
    Result := Default;
end;

procedure TIniFile.SetBoolEntry(const Section, Tag: AnsiString; Value: Boolean);
begin
  if Value then
    SetEntry(Section, Tag, '1')
  else
    SetEntry(Section, Tag, '0');
end;

function TIniFile.EntryExists(const Section, Tag: AnsiString): Boolean;
begin
  Result := SearchEntry(Section, Tag) <> nil;
end;

procedure TIniFile.DeleteSection(const Section: AnsiString);
var
  I: Integer;
begin
  I := IndexOf(Section);
  if I < 0 then
    Exit;
  FSections[I].Free;
  Move(FSections[I + 1], FSections[I], (FCount - I - 1) * SizeOf(TIniSection));
  Dec(FCount);
  FModified := True;
end;

procedure TIniFile.DeleteEntry(const Section, Tag: AnsiString);
var
  S: PIniSection;
begin
  S := SearchSection(Section);
  if (S <> nil) and (S.SearchEntry(Tag) <> nil) then
  begin
    S.DeleteEntry(Tag);
    FModified := True;
  end;
end;

function TIniFile.SectionCount: Integer;
begin
  Result := FCount;
end;

function TIniFile.SectionAt(I: Integer): PIniSection;
begin
  Result := FSections[I];
end;

end.
