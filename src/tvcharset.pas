{ TvCharset: the single-byte character sets (code pages of DOS and Windows, KOI8, ISO 8859, Mac Roman), UTF-16, and a guess of the set of a text.

  MIT; the tables (tvcharset.inc) are made by tools/gen-charsets.py from the codecs of Python. TvCodePg keeps the one page that the
  screen of a DOS program shows; this unit converts texts, any set to any, through UTF-8.

  The id of a set is its number among the code pages of Windows (437, 866, 1251 ...); KOI8-R is 20866, KOI8-U 21866, ISO-8859-n is 28590 + n, Mac Roman 10000;
  65001 is UTF-8 and 1200 / 1201 are UTF-16 little and big endian (the units that need only a name or an id of them). }
unit TvCharset;

{$I tvdefs.inc}

interface

const
  csUtf8 = 65001;
  csUtf16LE = 1200;
  csUtf16BE = 1201;
  csCp437 = 437;
  csCp866 = 866;
  csCp1251 = 1251;
  csCp1252 = 1252;
  csKoi8R = 20866;
  csLatin1 = 28591;

{ The id of a set by its name ("cp866", "windows-1251", "koi8-r", "utf-8", "utf-16le", "866" ...), 0 if there is no such set. }
function CharsetId(const Name: AnsiString): LongInt;
{ The usual name of a set ("cp866", "utf-8" ...), '' if there is none. }
function CharsetName(Id: LongInt): AnsiString;
{ True for UTF-8, UTF-16 and the single-byte sets of the tables. }
function CharsetKnown(Id: LongInt): Boolean;
{ How many sets the tables have and the id of the one with the number I (0-based): for lists in dialogs. }
function CharsetListCount: Integer;
function CharsetListId(I: Integer): LongInt;

{ Raw bytes of the set Id as UTF-8. A byte that the set does not define comes as U+FFFD. For UTF-8 the text is returned as it is, for UTF-16 it is converted. }
function CharsetToUtf8(Id: LongInt; const Raw: AnsiString): AnsiString;
{ UTF-8 as bytes of the set. A character that the set lacks becomes '?' and is counted in Lost. }
function CharsetFromUtf8(Id: LongInt; const Text: AnsiString; out Lost: Integer): AnsiString;

{ Is the text valid UTF-8 (shortest forms, no surrogates, at most U+10FFFF)? }
function Utf8Valid(const S: AnsiString): Boolean;
{ True when there is no byte >= $80 }
function IsPlainAscii(const S: AnsiString): Boolean;

{ Of the single-byte sets in Candidates (the first is the one when nothing is better) the one that reads the high bytes of Raw as the most likely text: Cyrillic by the
  frequency of the letters, other scripts by the share of letters and the absence of control and graphic symbols. }
function CharsetGuess(const Raw: AnsiString; const Candidates: array of LongInt): LongInt;

implementation

uses
  TvUtf8;

{$I tvcharset.inc}

type
  TTable = array[0..255] of Word;
  PTable = ^TTable;
  TRevPair = record
    CP: Word;
    B: Byte;
  end;

var
  RevId: LongInt = 0;
  Rev: array[0..255] of TRevPair;
  RevCount: Integer = 0;

function IndexOfId(Id: LongInt): Integer;
var
  I: Integer;
begin
  for I := 0 to CharsetCount - 1 do
    if CharsetIds[I] = Id then
      Exit(I);
  Result := -1;
end;

function Table(Id: LongInt): PTable;
var
  I: Integer;
begin
  I := IndexOfId(Id);
  if I < 0 then
    Result := nil
  else
    Result := PTable(CharsetTables[I]);
end;

function LowerAscii(const S: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'A') and (Result[I] <= 'Z') then
      Result[I] := Chr(Ord(Result[I]) + 32);
end;

function CharsetId(const Name: AnsiString): LongInt;
var
  L: AnsiString;
  I: Integer;
begin
  L := LowerAscii(Name);
  if (L = 'utf-8') or (L = 'utf8') then Exit(csUtf8);
  if (L = 'utf-16le') or (L = 'utf-16') or (L = 'utf16le') then Exit(csUtf16LE);
  if (L = 'utf-16be') or (L = 'utf16be') then Exit(csUtf16BE);
  if (L = 'ascii') or (L = 'us-ascii') then Exit(csLatin1);
  for I := 0 to CharsetNameCount - 1 do
    if CharsetNames[I].N = L then
      Exit(CharsetNames[I].Id);
  Result := 0;
end;

function CharsetName(Id: LongInt): AnsiString;
var
  I: Integer;
begin
  case Id of
    csUtf8: Exit('utf-8');
    csUtf16LE: Exit('utf-16le');
    csUtf16BE: Exit('utf-16be');
  end;
  for I := 0 to CharsetNameCount - 1 do
    if CharsetNames[I].Id = Id then
      Exit(CharsetNames[I].N);
  Result := '';
end;

function CharsetKnown(Id: LongInt): Boolean;
begin
  Result := (Id = csUtf8) or (Id = csUtf16LE) or (Id = csUtf16BE) or (IndexOfId(Id) >= 0);
end;

function CharsetListCount: Integer;
begin
  Result := CharsetCount;
end;

function CharsetListId(I: Integer): LongInt;
begin
  Result := CharsetIds[I];
end;

function Utf8Valid(const S: AnsiString): Boolean;
var
  I, Used: Integer;
  CP: LongWord;
begin
  I := 1;
  while I <= Length(S) do
    if Byte(S[I]) < $80 then
      Inc(I)
    else
    begin
      if not Utf8Decode(@S[I], Length(S) - I + 1, CP, Used) then
        Exit(False);
      Inc(I, Used);
    end;
  Result := True;
end;

function IsPlainAscii(const S: AnsiString): Boolean;
var
  P, Stop: PByte;
begin
  Result := True;
  if S = '' then
    Exit;
  P := PByte(PAnsiChar(S));
  Stop := P + Length(S);
  while P < Stop do
  begin
    if P^ >= $80 then
      Exit(False);
    Inc(P);
  end;
end;

procedure AppendCp(var R: AnsiString; var N: Integer; CP: LongWord);
var
  Buf: array[0..7] of Byte;
  K: Integer;
begin
  K := Utf8Encode(CP, @Buf[0]);
  if N + K > Length(R) then
    SetLength(R, (N + K) * 2 + 16);
  Move(Buf[0], R[N + 1], K);
  Inc(N, K);
end;

function Utf16ToUtf8(const Raw: AnsiString; BigEndian: Boolean): AnsiString;
var
  I, N: Integer;
  U, U2: LongWord;
  CP: LongWord;
begin
  N := 0;
  SetLength(Result, Length(Raw) * 3 div 2 + 8);
  I := 1;
  while I + 1 <= Length(Raw) do
  begin
    if BigEndian then U := (Byte(Raw[I]) shl 8) or Byte(Raw[I + 1]) else U := (Byte(Raw[I + 1]) shl 8) or Byte(Raw[I]);
    Inc(I, 2);
    CP := U;
    if (U >= $D800) and (U <= $DBFF) and (I + 1 <= Length(Raw)) then
    begin
      if BigEndian then U2 := (Byte(Raw[I]) shl 8) or Byte(Raw[I + 1]) else U2 := (Byte(Raw[I + 1]) shl 8) or Byte(Raw[I]);
      if (U2 >= $DC00) and (U2 <= $DFFF) then
      begin
        CP := $10000 + ((U - $D800) shl 10) + (U2 - $DC00);
        Inc(I, 2);
      end
      else
        CP := $FFFD;
    end
    else if (U >= $D800) and (U <= $DFFF) then
      CP := $FFFD;
    AppendCp(Result, N, CP);
  end;
  SetLength(Result, N);
end;

{ A byte that is not a part of valid UTF-8 becomes U+FFFD and is counted in Lost. }
function Utf8ToUtf16(const S: AnsiString; BigEndian: Boolean; out Lost: Integer): AnsiString;
var
  Pos, Used, Len: Integer;
  CP: LongWord;

  procedure PutUnit(W: Word);
  begin
    if BigEndian then
    begin
      Result[Len + 1] := Chr(W shr 8);
      Result[Len + 2] := Chr(W and $FF);
    end
    else
    begin
      Result[Len + 1] := Chr(W and $FF);
      Result[Len + 2] := Chr(W shr 8);
    end;
    Inc(Len, 2);
  end;

begin
  Lost := 0;
  Len := 0;
  { every byte gives at most one 16-bit unit; a 4-byte sequence gives two }
  SetLength(Result, Length(S) * 2);
  Pos := 1;
  while Pos <= Length(S) do
  begin
    if Byte(S[Pos]) < $80 then
    begin
      CP := Byte(S[Pos]);
      Used := 1;
    end
    else if not Utf8Decode(@S[Pos], Length(S) - Pos + 1, CP, Used) then
    begin
      CP := $FFFD;
      Used := 1;
      Inc(Lost);
    end;
    Inc(Pos, Used);
    if CP >= $10000 then
    begin
      Dec(CP, $10000);
      PutUnit($D800 or (CP shr 10));
      PutUnit($DC00 or (CP and $3FF));
    end
    else
      PutUnit(CP);
  end;
  SetLength(Result, Len);
end;

function CharsetToUtf8(Id: LongInt; const Raw: AnsiString): AnsiString;
var
  T: PTable;
  I, N: Integer;
  U: Word;
begin
  case Id of
    csUtf8: Exit(Raw);
    csUtf16LE: Exit(Utf16ToUtf8(Raw, False));
    csUtf16BE: Exit(Utf16ToUtf8(Raw, True));
  end;
  T := Table(Id);
  if (T = nil) or IsPlainAscii(Raw) then
    Exit(Raw);
  N := 0;
  SetLength(Result, Length(Raw) * 2);
  for I := 1 to Length(Raw) do
    if Byte(Raw[I]) < $80 then
    begin
      Inc(N);
      Result[N] := Raw[I];
    end
    else
    begin
      U := T^[Byte(Raw[I])];
      if U = $FFFF then
        U := $FFFD;
      AppendCp(Result, N, U);
    end;
  SetLength(Result, N);
end;

procedure BuildRev(Id: LongInt);
var
  T: PTable;
  B, I: Integer;
  P: TRevPair;
begin
  T := Table(Id);
  RevCount := 0;
  RevId := Id;
  if T = nil then
    Exit;
  for B := 128 to 255 do
    if T^[B] <> $FFFF then
    begin
      I := RevCount;
      P.CP := T^[B];
      P.B := B;
      while (I > 0) and (Rev[I - 1].CP > P.CP) do
      begin
        Rev[I] := Rev[I - 1];
        Dec(I);
      end;
      Rev[I] := P;
      Inc(RevCount);
    end;
end;

function RevLookup(CP: LongWord): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  Result := -1;
  if CP > $FFFF then
    Exit;
  Lo := 0;
  Hi := RevCount - 1;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) shr 1;
    if Rev[Mid].CP = CP then
      Exit(Rev[Mid].B)
    else if Rev[Mid].CP < CP then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
end;

function CharsetFromUtf8(Id: LongInt; const Text: AnsiString; out Lost: Integer): AnsiString;
var
  I, Used, N, B: Integer;
  CP: LongWord;
begin
  Lost := 0;
  case Id of
    csUtf8: Exit(Text);
    csUtf16LE: Exit(Utf8ToUtf16(Text, False, Lost));
    csUtf16BE: Exit(Utf8ToUtf16(Text, True, Lost));
  end;
  if (Table(Id) = nil) or IsPlainAscii(Text) then
    Exit(Text);
  if RevId <> Id then
    BuildRev(Id);
  N := 0;
  SetLength(Result, Length(Text));
  I := 1;
  while I <= Length(Text) do
  begin
    if Byte(Text[I]) < $80 then
    begin
      Inc(N);
      Result[N] := Text[I];
      Inc(I);
    end
    else
    begin
      if Utf8Decode(@Text[I], Length(Text) - I + 1, CP, Used) then
        Inc(I, Used)
      else
      begin
        CP := $FFFD;
        Inc(I);
      end;
      B := RevLookup(CP);
      Inc(N);
      if B >= 0 then
        Result[N] := Chr(B)
      else
      begin
        Result[N] := '?';
        Inc(Lost);
      end;
    end;
  end;
  SetLength(Result, N);
end;

{ --- the guess --- }

{ The frequency of the letters of Russian text in percent x 10 (lower case; the capitals count half) }
function RussianWeight(CP: LongWord): Integer;
begin
  Result := 0;
  case CP of
    $0430: Result := 80;  { a }  $0431: Result := 16;  $0432: Result := 45;  $0433: Result := 17;  $0434: Result := 30;
    $0435: Result := 85;  $0451: Result := 2;   $0436: Result := 9;   $0437: Result := 16;  $0438: Result := 74;
    $0439: Result := 12;  $043A: Result := 35;  $043B: Result := 40;  $043C: Result := 32;  $043D: Result := 67;
    $043E: Result := 110; $043F: Result := 28;  $0440: Result := 47;  $0441: Result := 55;  $0442: Result := 63;
    $0443: Result := 26;  $0444: Result := 3;   $0445: Result := 10;  $0446: Result := 5;   $0447: Result := 14;
    $0448: Result := 7;   $0449: Result := 3;   $044A: Result := 2;   $044B: Result := 19;  $044C: Result := 17;
    $044D: Result := 3;   $044E: Result := 6;   $044F: Result := 20;
    $0410..$042F: Result := RussianWeight(CP + 32) div 2;
    $0401: Result := 1;
  end;
end;

function CharsetGuess(const Raw: AnsiString; const Candidates: array of LongInt): LongInt;
var
  K, I, Limit: Integer;
  T: PTable;
  Score, Best: Int64;
  U: Word;
begin
  if Length(Candidates) = 0 then
    Exit(csCp1252);
  Result := Candidates[0];
  if IsPlainAscii(Raw) then
    Exit;
  Limit := Length(Raw);
  if Limit > 1 shl 20 then
    Limit := 1 shl 20;                      { the first megabyte tells enough }
  Best := -1;
  for K := 0 to High(Candidates) do
  begin
    T := Table(Candidates[K]);
    if T = nil then
      Continue;
    Score := 0;
    for I := 1 to Limit do
      if Byte(Raw[I]) >= $80 then
      begin
        U := T^[Byte(Raw[I])];
        if U = $FFFF then
          Dec(Score, 50)
        else if (U >= $2500) and (U <= $259F) then
          Dec(Score, 20)                     { frames and blocks are rare in text }
        else if (U >= $80) and (U < $A0) then
          Dec(Score, 50)                     { C1 controls }
        else
          Inc(Score, RussianWeight(U) * 10 + 3 * Ord(((U >= $C0) and (U < $2000)) and (RussianWeight(U) = 0)));
      end;
    if Score > Best then
    begin
      Best := Score;
      Result := Candidates[K];
    end;
  end;
end;

end.
