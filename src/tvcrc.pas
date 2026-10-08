{ TvCrc: the CRC-32 of zip, PNG and Ethernet (polynomial $04C11DB7, bits reflected).

  MIT (see LICENSE).

  The value of nothing is 0, and a value goes on over more data: Crc32(Crc32(0, A), B) is the CRC of A followed by B
  (the same convention as crc32() of zlib). The CRC of the ASCII text '123456789' is $CBF43926. }
unit TvCrc;

{$I tvdefs.inc}

interface

function Crc32(Crc: LongWord; const Buf; Len: SizeInt): LongWord;
function Crc32Str(Crc: LongWord; const S: AnsiString): LongWord;

implementation

var
  Table: array[Byte] of LongWord;
  TableReady: Boolean = False;

procedure FillTable;
const
  Reflected = $EDB88320;
var
  B: Integer;
  K: Integer;
  V: LongWord;
begin
  for B := 0 to 255 do
  begin
    V := B;
    for K := 1 to 8 do
      if Odd(V) then
        V := (V shr 1) xor Reflected
      else
        V := V shr 1;
    Table[B] := V;
  end;
  TableReady := True;
end;

function Crc32(Crc: LongWord; const Buf; Len: SizeInt): LongWord;
var
  P: PByte;
  I: SizeInt;
begin
  if not TableReady then
    FillTable;
  Result := not Crc;
  P := @Buf;
  for I := 1 to Len do
  begin
    Result := Table[Byte(Result) xor P^] xor (Result shr 8);
    Inc(P);
  end;
  Result := not Result;
end;

function Crc32Str(Crc: LongWord; const S: AnsiString): LongWord;
begin
  if S = '' then
    Result := Crc
  else
    Result := Crc32(Crc, S[1], Length(S));
end;

end.
