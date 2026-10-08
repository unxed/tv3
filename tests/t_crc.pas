program t_crc;
{ TvCrc: CRC-32. }
{$I ../src/tvdefs.inc}
uses TvCrc;
{$I testlib.inc}

var
  Buf: array[0..255] of Byte;
  I: Integer;
  Sh: ShortString;
begin
  Check(Crc32Str(0, '') = 0, 'the CRC of nothing is 0');
  Check(Crc32(7, Buf, 0) = 7, 'no data keeps the value');
  Check(Crc32Str(0, '123456789') = $CBF43926, 'the check value of CRC-32');
  Check(Crc32Str(0, 'a') = $E8B7BE43, 'one byte');
  Check(Crc32Str(0, 'The quick brown fox jumps over the lazy dog') = $414FA339, 'a sentence');
  Check(Crc32Str(0, 'MICROSOFT') = $795B3767, 'a key word of an ini file');
  Check(Crc32Str(0, 'BORLAND') = $4DF4784C, 'another key word');
  Check(Crc32Str(Crc32Str(0, 'The quick brown '), 'fox jumps over the lazy dog') = $414FA339, 'the value goes on over two parts');
  for I := 0 to 255 do
    Buf[I] := I;
  Check(Crc32(0, Buf, 256) = $29058C73, 'all byte values');
  Sh := 'BORLAND';
  Check(Crc32(0, Sh[1], Length(Sh)) = $4DF4784C, 'a buffer of a short string');
  Finish;
end.
