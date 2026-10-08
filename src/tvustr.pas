{ TvUStr: strings of bytes that hold UTF-8, counted by characters and by screen cells.

  MIT as the one place for what dn and fpide each had in their own unit (columns, cutting, padding, case).

  Terms:
    byte index   1-based position in the string (the Pascal one)
    column       0-based number of the character; a character is a valid UTF-8 sequence, or one stray byte (a byte that is not a part of a
                 sequence stays as it is and counts as one column: nothing is lost on a file in another code page)
    cell         a place on the screen: a column of a wide character (CJK) takes two cells, a combining mark takes none
  Utf8Enabled of TvUtf8 False (a program with a code page inside): one byte is one column and one cell, the functions do not decode.

  The case of a character is the simple mapping of Unicode for the scripts that have it in the BMP and are used in file names and text:
  Latin (Basic, Supplement, Extended-A, Extended Additional), Greek, Cyrillic (with the extensions), Armenian, Georgian is caseless here,
  the full-width Latin and the circled and Roman numerals. No tables of the RTL are used (the unit works under DOS too). }
unit TvUStr;

{$I tvdefs.inc}

interface

uses
  TvUtf8;

{ --- bytes and columns --- }

{ The number of bytes of the character that starts at byte index Idx: 1 for ASCII and for a stray byte, 0 outside the string. }
function U8CharBytes(const S: AnsiString; Idx: Integer): Integer;
function U8IsAscii(const S: AnsiString): Boolean;
{ The number of columns (characters) of S. }
function U8Len(const S: AnsiString): Integer;
{ The byte index where column Col starts; Length(S) + 1 when Col is at or after the end. }
function U8Idx(const S: AnsiString; Col: Integer): Integer;
{ The column of the byte at index Idx (Idx may be Length(S) + 1; further, one byte is one column). }
function U8Col(const S: AnsiString; Idx: Integer): Integer;
{ The byte index of the character before the one at Idx (1 at the start). }
function U8PrevIdx(const S: AnsiString; Idx: Integer): Integer;

{ --- cutting (columns are 0-based) --- }

function U8Copy(const S: AnsiString; Col, Cnt: Integer): AnsiString;
function U8Char(const S: AnsiString; Col: Integer): AnsiString;
procedure U8Delete(var S: AnsiString; Col, Cnt: Integer); overload;
procedure U8Delete(var S: ShortString; Col, Cnt: Integer); overload;
procedure U8Insert(const Sub: AnsiString; var S: AnsiString; Col: Integer); overload;
procedure U8Insert(const Sub: AnsiString; var S: ShortString; Col: Integer); overload;
{ The character at Col as a byte (the first byte of it) or ' ' past the end. }
function U8ColChar(const S: AnsiString; Col: Integer): Char;
{ The code point at Col (a stray byte: its value; past the end: 0) and the UTF-8 bytes of a code point. }
function U8CodePoint(const S: AnsiString; Col: Integer): LongWord;
function U8Encode(CP: LongWord): AnsiString;
{ The longest beginning of S of at most MaxBytes bytes that does not split a character. }
function U8Prefix(const S: AnsiString; MaxBytes: Integer): AnsiString;
{ Without the last character. }
procedure U8DeleteLast(var S: AnsiString); overload;
procedure U8DeleteLast(var S: ShortString); overload;

{ --- screen cells --- }

{ The cells of Cnt columns from Col (past the end: one cell per column). }
function U8Cells(const S: AnsiString; Col, Cnt: Integer): Integer;
{ The cells of the whole string. }
function U8Cols(const S: AnsiString): Integer;
{ The column that is drawn at the cell number Cell (the column that covers it; past the end: columns of one cell). }
function U8ColAtCell(const S: AnsiString; Cell: Integer): Integer;
{ S padded with spaces to Cells cells (not cut when longer). }
function U8Pad(const S: AnsiString; Cells: Integer): AnsiString;
{ S cut to at most Cells cells (a wide character that does not fit is dropped). }
function U8Fit(const S: AnsiString; Cells: Integer): AnsiString;

{ --- case --- }

function CpUpper(CP: LongWord): LongWord;
function CpLower(CP: LongWord): LongWord;
function U8Upper(const S: AnsiString): AnsiString;
function U8Lower(const S: AnsiString): AnsiString;
{ The first letter in the upper case, the rest as it is. }
function U8CapFirst(const S: AnsiString): AnsiString;
{ A and B equal when the case is ignored. }
function U8EqualNoCase(const A, B: AnsiString): Boolean;

implementation

{ --- bytes and columns --- }

function U8CharBytes(const S: AnsiString; Idx: Integer): Integer;
var
  Lead: Byte;
  Avail: Integer;
  Dummy: LongWord;
begin
  Result := 0;
  Avail := Length(S) - Idx + 1;
  if (Idx <= 0) or (Avail <= 0) then
    Exit;
  Lead := Byte(S[Idx]);
  { a sequence that does not decode is left as one stray byte }
  if (Lead < $80) or not Utf8Enabled
    or not Utf8Decode(@S[Idx], Avail, Dummy, Result) then
    Result := 1;
end;

function U8IsAscii(const S: AnsiString): Boolean;
var
  K: Integer;
begin
  for K := 1 to Length(S) do
    if Byte(S[K]) >= $80 then
      Exit(False);
  Result := True;
end;

function U8Len(const S: AnsiString): Integer;
var
  P, Last: Integer;
begin
  Last := Length(S);
  if (not Utf8Enabled) or U8IsAscii(S) then
    Exit(Last);
  Result := 0;
  P := 1;
  while P <= Last do
  begin
    P := P + U8CharBytes(S, P);
    Inc(Result);
  end;
end;

function U8Idx(const S: AnsiString; Col: Integer): Integer;
var
  Last: Integer;
begin
  Last := Length(S);
  if Col <= 0 then
    Exit(1);
  if not Utf8Enabled then
  begin
    if Col > Last then
      Col := Last;
    Exit(Col + 1);
  end;
  Result := 1;
  while (Col > 0) and (Result <= Last) do
  begin
    Result := Result + U8CharBytes(S, Result);
    Dec(Col);
  end;
end;

function U8Col(const S: AnsiString; Idx: Integer): Integer;
var
  P, Last, Step: Integer;
begin
  if Idx <= 1 then
    Exit(0);
  if not Utf8Enabled then
    Exit(Idx - 1);
  Last := Length(S);
  Result := 0;
  P := 1;
  while P < Idx do
  begin
    if P > Last then
    begin
      { beyond the string every byte position is a column of its own }
      Result := Result + (Idx - P);
      Break;
    end;
    Step := U8CharBytes(S, P);
    if P + Step > Idx then
      Break;                       { Idx points inside this character }
    P := P + Step;
    Inc(Result);
  end;
end;

function U8PrevIdx(const S: AnsiString; Idx: Integer): Integer;
var
  I: Integer;
begin
  Result := 1;
  I := 1;
  while I < Idx do
  begin
    Result := I;
    Inc(I, U8CharBytes(S, I) + Ord(U8CharBytes(S, I) = 0));
  end;
end;

{ --- cutting --- }

function U8Copy(const S: AnsiString; Col, Cnt: Integer): AnsiString;
var
  First: Integer;
begin
  if Col < 0 then
  begin
    Cnt := Cnt + Col;
    Col := 0;
  end;
  if Cnt <= 0 then
    Exit('');
  First := U8Idx(S, Col);
  Result := Copy(S, First, U8Idx(S, Col + Cnt) - First);
end;

function U8Char(const S: AnsiString; Col: Integer): AnsiString;
begin
  Result := U8Copy(S, Col, 1);
end;

procedure U8Delete(var S: AnsiString; Col, Cnt: Integer);
var
  First: Integer;
begin
  if Col < 0 then
  begin
    Cnt := Cnt + Col;
    Col := 0;
  end;
  if Cnt <= 0 then
    Exit;
  First := U8Idx(S, Col);
  Delete(S, First, U8Idx(S, Col + Cnt) - First);
end;

procedure U8Delete(var S: ShortString; Col, Cnt: Integer);
var
  T: AnsiString;
begin
  T := S;
  U8Delete(T, Col, Cnt);
  S := T;
end;

procedure U8Insert(const Sub: AnsiString; var S: AnsiString; Col: Integer);
begin
  Insert(Sub, S, U8Idx(S, Col));
end;

procedure U8Insert(const Sub: AnsiString; var S: ShortString; Col: Integer);
var
  T: AnsiString;
begin
  T := S;
  U8Insert(Sub, T, Col);
  S := T;
end;

function U8ColChar(const S: AnsiString; Col: Integer): Char;
var
  P: Integer;
begin
  Result := ' ';
  if Col < 0 then
    Exit;
  P := U8Idx(S, Col);
  if P <= Length(S) then
    Result := S[P];
end;

function U8CodePoint(const S: AnsiString; Col: Integer): LongWord;
var
  P, Used: Integer;
begin
  Result := 0;
  if Col < 0 then
    Exit;
  P := U8Idx(S, Col);
  if P > Length(S) then
    Exit;
  if not (Utf8Enabled and (Byte(S[P]) >= $80)
    and Utf8Decode(@S[P], Length(S) - P + 1, Result, Used)) then
    Result := Byte(S[P]);
end;

function U8Encode(CP: LongWord): AnsiString;
var
  Buf: array[0..MaxCharSize - 1] of Byte;
begin
  SetString(Result, PAnsiChar(@Buf[0]), Utf8Encode(CP, @Buf[0]));
end;

function U8Prefix(const S: AnsiString; MaxBytes: Integer): AnsiString;
var
  N: Integer;
begin
  if MaxBytes < 0 then
    MaxBytes := 0;
  if Length(S) <= MaxBytes then
    Exit(S);
  N := MaxBytes;
  if Utf8Enabled then
    while (N > 0) and ((Byte(S[N + 1]) and $C0) = $80) do      { back over the continuation bytes of a character that does not fit }
      Dec(N);
  Result := Copy(S, 1, N);
end;

procedure U8DeleteLast(var S: AnsiString);
var
  L: Integer;
begin
  L := Length(S);
  if L = 0 then
    Exit;
  if Utf8Enabled then
    while (L > 1) and ((Byte(S[L]) and $C0) = $80) do
      Dec(L);
  SetLength(S, L - 1);
end;

procedure U8DeleteLast(var S: ShortString);
var
  T: AnsiString;
begin
  T := S;
  U8DeleteLast(T);
  S := T;
end;

{ --- screen cells --- }

{ The cells of the character at byte index P that takes Bytes bytes: only a multi-byte character has a width of its own. }
function CellsAt(const S: AnsiString; P, Bytes: Integer): Integer;
var
  CP: LongWord;
  Used: Integer;
begin
  Result := 1;
  if (Bytes > 1) and Utf8Decode(@S[P], Bytes, CP, Used) then
  begin
    Result := CharWidth(CP);
    if Result < 0 then
      Result := 1;
  end;
end;

function U8Cells(const S: AnsiString; Col, Cnt: Integer): Integer;
var
  P, Last, Bytes: Integer;
begin
  if Cnt <= 0 then
    Exit(0);
  if (not Utf8Enabled) or U8IsAscii(S) then
    Exit(Cnt);
  Last := Length(S);
  P := U8Idx(S, Col);
  Result := 0;
  while Cnt > 0 do
  begin
    if P > Last then
    begin
      Result := Result + Cnt;
      Break;
    end;
    Bytes := U8CharBytes(S, P);
    Result := Result + CellsAt(S, P, Bytes);
    P := P + Bytes;
    Dec(Cnt);
  end;
end;

function U8Cols(const S: AnsiString): Integer;
begin
  Result := U8Cells(S, 0, U8Len(S));
end;

function U8ColAtCell(const S: AnsiString; Cell: Integer): Integer;
var
  P, Last, Bytes, Used: Integer;
begin
  if Cell <= 0 then
    Exit(0);
  if (not Utf8Enabled) or U8IsAscii(S) then
    Exit(Cell);
  Last := Length(S);
  Result := 0;
  Used := 0;                         { cells taken by the columns before Result }
  P := 1;
  while P <= Last do
  begin
    Bytes := U8CharBytes(S, P);
    Used := Used + CellsAt(S, P, Bytes);
    if Used > Cell then
      Exit;
    P := P + Bytes;
    Inc(Result);
  end;
  Result := Result + (Cell - Used);
end;

function U8Pad(const S: AnsiString; Cells: Integer): AnsiString;
var
  N: Integer;
begin
  N := U8Cols(S);
  Result := S;
  if N < Cells then
    Result := Result + StringOfChar(' ', Cells - N);
end;

function U8Fit(const S: AnsiString; Cells: Integer): AnsiString;
var
  Col, Acc, W, N: Integer;
begin
  if Cells <= 0 then
    Exit('');
  if (not Utf8Enabled) or U8IsAscii(S) then
    Exit(Copy(S, 1, Cells));
  N := U8Len(S);
  Acc := 0;
  Col := 0;
  while Col < N do
  begin
    W := U8Cells(S, Col, 1);
    if Acc + W > Cells then
      Break;
    Inc(Acc, W);
    Inc(Col);
  end;
  Result := U8Copy(S, 0, Col);
end;

{ --- case --- }

{ Pairs: the upper letter is at the even (or the odd) code point and the lower one right after it. }
function PairUpper(CP, Lo, Hi: LongWord; UpperIsEven: Boolean): LongWord;
begin
  Result := CP;
  if (CP >= Lo) and (CP <= Hi) and (Odd(CP) = UpperIsEven) then
    Result := CP - 1;
end;

function PairLower(CP, Lo, Hi: LongWord; UpperIsEven: Boolean): LongWord;
begin
  Result := CP;
  if (CP >= Lo) and (CP <= Hi) and (Odd(CP) <> UpperIsEven) then
    Result := CP + 1;
end;

function CpUpper(CP: LongWord): LongWord;
begin
  Result := CP;
  if CP < $80 then
  begin
    if (CP >= $61) and (CP <= $7A) then
      Result := CP - $20;
    Exit;
  end;
  case CP of
    $B5: Exit($39C);
    $E0..$F6, $F8..$FE: Exit(CP - $20);
    $FF: Exit($178);
    $100..$12F: Exit(PairUpper(CP, $100, $12F, True));
    $131: Exit($49);
    $132..$137: Exit(PairUpper(CP, $132, $137, True));
    $139..$148: Exit(PairUpper(CP, $139, $148, False));
    $14A..$177: Exit(PairUpper(CP, $14A, $177, True));
    $17A..$17E: Exit(PairUpper(CP, $179, $17E, False));
    $17F: Exit($53);
    $1CE: Exit($1CD);
    $1E00..$1E95, $1EA0..$1EFF: Exit(PairUpper(CP, $1E00, $1EFF, True));
    $3AC: Exit($386);
    $3AD..$3AF: Exit(CP - $25);
    $3B1..$3C1, $3C3..$3CB: Exit(CP - $20);
    $3C2: Exit($3A3);
    $3CC: Exit($38C);
    $3CD, $3CE: Exit(CP - $3F);
    $430..$44F: Exit(CP - $20);
    $450..$45F: Exit(CP - $50);
    $460..$481, $48A..$4BF, $4D0..$52F: Exit(PairUpper(CP, $460, $52F, True));
    $4C2..$4CE: Exit(PairUpper(CP, $4C1, $4CE, False));
    $4CF: Exit($4C0);
    $561..$586: Exit(CP - $30);
    $2170..$217F: Exit(CP - $10);
    $24D0..$24E9: Exit(CP - $1A);
    $FF41..$FF5A: Exit(CP - $20);
  end;
end;

function CpLower(CP: LongWord): LongWord;
begin
  Result := CP;
  if CP < $80 then
  begin
    if (CP >= $41) and (CP <= $5A) then
      Result := CP + $20;
    Exit;
  end;
  case CP of
    $C0..$D6, $D8..$DE: Exit(CP + $20);
    $100..$12F: Exit(PairLower(CP, $100, $12F, True));
    $130: Exit($69);
    $132..$137: Exit(PairLower(CP, $132, $137, True));
    $139..$148: Exit(PairLower(CP, $139, $148, False));
    $14A..$177: Exit(PairLower(CP, $14A, $177, True));
    $178: Exit($FF);
    $179..$17E: Exit(PairLower(CP, $179, $17E, False));
    $1CD: Exit($1CE);
    $1E00..$1E95, $1EA0..$1EFF: Exit(PairLower(CP, $1E00, $1EFF, True));
    $386: Exit($3AC);
    $388..$38A: Exit(CP + $25);
    $38C: Exit($3CC);
    $38E, $38F: Exit(CP + $3F);
    $391..$3A1, $3A3..$3AB: Exit(CP + $20);
    $400..$40F: Exit(CP + $50);
    $410..$42F: Exit(CP + $20);
    $460..$481, $48A..$4BF, $4D0..$52F: Exit(PairLower(CP, $460, $52F, True));
    $4C0: Exit($4CF);
    $4C1..$4CD: Exit(PairLower(CP, $4C1, $4CE, False));
    $531..$556: Exit(CP + $30);
    $2160..$216F: Exit(CP + $10);
    $24B6..$24CF: Exit(CP + $1A);
    $FF21..$FF3A: Exit(CP + $20);
  end;
end;

function AsciiCase(C: Char; Up: Boolean): Char;
begin
  Result := C;
  if Up then
  begin
    if (C >= 'a') and (C <= 'z') then
      Result := Chr(Ord(C) - 32);
  end
  else if (C >= 'A') and (C <= 'Z') then
    Result := Chr(Ord(C) + 32);
end;

function MapCase(const S: AnsiString; Up: Boolean): AnsiString;
var
  I, N, Used: Integer;
  CP, M: LongWord;
begin
  Result := S;
  if (not Utf8Enabled) or U8IsAscii(S) then
  begin
    for I := 1 to Length(Result) do
      Result[I] := AsciiCase(Result[I], Up);
    Exit;
  end;
  Result := '';
  I := 1;
  N := Length(S);
  while I <= N do
    if (Byte(S[I]) >= $80) and Utf8Decode(@S[I], N - I + 1, CP, Used) and (Used > 1) then
    begin
      if Up then M := CpUpper(CP) else M := CpLower(CP);
      if M = CP then
        Result := Result + Copy(S, I, Used)
      else
        Result := Result + U8Encode(M);
      Inc(I, Used);
    end
    else
    begin
      Result := Result + AsciiCase(S[I], Up);      { ASCII, or a stray byte (stays as it is) }
      Inc(I);
    end;
end;

function U8Upper(const S: AnsiString): AnsiString;
begin
  Result := MapCase(S, True);
end;

function U8Lower(const S: AnsiString): AnsiString;
begin
  Result := MapCase(S, False);
end;

function U8CapFirst(const S: AnsiString): AnsiString;
var
  N: Integer;
begin
  if S = '' then
    Exit('');
  N := U8CharBytes(S, 1);
  Result := U8Upper(Copy(S, 1, N)) + Copy(S, N + 1, MaxInt);
end;

function U8EqualNoCase(const A, B: AnsiString): Boolean;
begin
  Result := (A = B) or (U8Lower(A) = U8Lower(B));
end;

end.
