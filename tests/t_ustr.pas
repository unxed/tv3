program t_ustr;
{ TvUStr: UTF-8 strings by columns and cells, case. }
{$I ../src/tvdefs.inc}
uses TvUtf8, TvUStr;
{$I testlib.inc}

const
  Privet = #$D0#$9F#$D1#$80#$D0#$B8#$D0#$B2#$D0#$B5#$D1#$82;      { Привет }
  Japan = #$E6#$97#$A5#$E6#$9C#$AC;                                { 日本 }
  Smile = #$F0#$9F#$98#$80;                                        { U+1F600 }
  EAcute = #$C3#$A9;

var
  S: AnsiString;
  Sh: ShortString;
  CP, L, U: LongWord;
  Bad: Integer;

begin
  Utf8Enabled := True;
  Check(U8Len('abc') = 3, 'ASCII: length');
  Check(U8Len(Privet) = 6, 'Cyrillic: 6 columns, 12 bytes');
  Check(U8Len('a' + EAcute + Smile) = 3, 'mixed: 3 columns');
  Check(U8Len('a'#$80'b') = 3, 'a stray byte is one column');
  Check(U8Len('ab'#$D0) = 3, 'a truncated sequence at the end is one column');
  Check(U8Idx(Privet, 0) = 1, 'Idx of column 0');
  Check(U8Idx(Privet, 2) = 5, 'Idx of column 2');
  Check(U8Idx(Privet, 6) = 13, 'Idx at the end = Length+1');
  Check(U8Idx(Privet, 99) = 13, 'Idx past the end');
  Check(U8Col(Privet, 5) = 2, 'Col of byte 5');
  Check(U8Col(Privet, 13) = 6, 'Col at the end');
  Check(U8Col(Privet, 15) = 8, 'Col past the end: one byte, one column');
  Check(U8Copy(Privet, 1, 3) = #$D1#$80#$D0#$B8#$D0#$B2, 'Copy 3 columns');
  Check(U8Copy(Privet, -2, 4) = #$D0#$9F#$D1#$80, 'Copy from a negative column');
  Check(U8Copy(Privet, 4, 99) = #$D0#$B5#$D1#$82, 'Copy past the end');
  Check(U8Char(Privet, 1) = #$D1#$80, 'Char');
  S := Privet; U8Delete(S, 1, 2);
  Check(S = #$D0#$9F#$D0#$B2#$D0#$B5#$D1#$82, 'Delete 2 columns');
  S := Privet; U8Insert('x', S, 3);
  Check(S = #$D0#$9F#$D1#$80#$D0#$B8'x'#$D0#$B2#$D0#$B5#$D1#$82, 'Insert at a column');
  Sh := Privet; U8Delete(Sh, 0, 1);
  Check(Sh = #$D1#$80#$D0#$B8#$D0#$B2#$D0#$B5#$D1#$82, 'Delete in a ShortString');
  Check(U8CodePoint(Privet, 1) = $440, 'code point');
  Check(U8CodePoint('a'#$80, 1) = $80, 'code point of a stray byte');
  Check(U8CodePoint('a', 5) = 0, 'code point past the end = 0');
  Check(U8Encode($439) = #$D0#$B9, 'Encode');
  Check(U8Prefix(Privet, 5) = #$D0#$9F#$D1#$80, 'Prefix does not split a character');
  Check(U8Prefix(Privet, 99) = Privet, 'Prefix longer than the string');
  S := Privet; U8DeleteLast(S);
  Check(S = #$D0#$9F#$D1#$80#$D0#$B8#$D0#$B2#$D0#$B5, 'DeleteLast');
  S := 'ab'; U8DeleteLast(S);
  Check(S = 'a', 'DeleteLast ASCII');
  Check(U8PrevIdx(Privet, 5) = 3, 'PrevIdx');

  { cells }
  Check(U8Cols(Japan) = 4, 'wide characters: 2 cells each');
  Check(U8Cols('a' + Japan) = 5, 'wide and narrow');
  Check(U8Cols('a'#$CC#$81) = 1, 'a combining mark takes no cell');
  Check(U8Cells(Japan, 1, 1) = 2, 'cells of one wide character');
  Check(U8Cells('ab', 1, 3) = 3, 'cells past the end');
  Check(U8ColAtCell('a' + Japan + 'b', 2) = 1, 'the column under cell 2 (inside a wide character)');
  Check(U8ColAtCell('a' + Japan + 'b', 4) = 2, 'the column under cell 4');
  Check(U8ColAtCell('ab', 5) = 5, 'past the end: one cell per column');
  Check(U8Pad(Japan, 6) = Japan + '  ', 'Pad counts cells');
  Check(U8Pad(Japan, 2) = Japan, 'Pad does not cut');
  Check(U8Fit('a' + Japan, 2) = 'a', 'Fit drops a wide character that does not fit');
  Check(U8Fit('a' + Japan, 3) = 'a' + #$E6#$97#$A5, 'Fit');

  { case }
  Check(U8Upper(Privet) = #$D0#$9F#$D0#$A0#$D0#$98#$D0#$92#$D0#$95#$D0#$A2, 'Upper Cyrillic');
  Check(U8Lower(#$D0#$9F#$D0#$A0#$D0#$98) = #$D0#$BF#$D1#$80#$D0#$B8, 'Lower Cyrillic');
  Check(U8Upper('abc' + EAcute) = 'ABC' + #$C3#$89, 'Upper Latin-1');
  Check(U8Upper('a'#$80'b') = 'A'#$80'B', 'a stray byte stays');
  Check(U8Upper(Japan) = Japan, 'a caseless script stays');
  Check(U8CapFirst(Privet) = #$D0#$9F#$D1#$80#$D0#$B8#$D0#$B2#$D0#$B5#$D1#$82, 'CapFirst keeps the rest');
  Check(U8CapFirst(#$D0#$BF#$D1#$80) = #$D0#$9F#$D1#$80, 'CapFirst');
  Check(U8EqualNoCase(Privet, U8Upper(Privet)), 'equal ignoring case');
  Check(not U8EqualNoCase(Privet, 'privet'), 'not equal');
  Check(CpUpper($3C2) = $3A3, 'final sigma');
  Check(CpLower($130) = $69, 'dotted I');
  Check(CpUpper($45F) = $40F, 'Cyrillic Dzhe');

  { the pairs are consistent: Lower(Upper(x)) and Upper(Lower(x)) are x for the letters that have both }
  Bad := 0;
  for CP := $80 to $24FF do
  begin
    L := CpLower(CP);
    U := CpUpper(CP);
    if (L <> CP) and (CpUpper(L) <> CP) and not ((CP = $130) or (CP = $3A3) or (CP = $1E9E)) then Inc(Bad);
    if (U <> CP) and (CpLower(U) <> CP) and not ((CP = $B5) or (CP = $131) or (CP = $17F) or (CP = $3C2)) then Inc(Bad);
  end;
  Check(Bad = 0, 'Lower and Upper are inverse to each other');

  { a program with a code page inside: one byte is one column }
  Utf8Enabled := False;
  Check(U8Len(Privet) = 12, 'no UTF-8: one byte, one column');
  Check(U8Cols(Privet) = 12, 'no UTF-8: one byte, one cell');
  Check(U8Idx(Privet, 3) = 4, 'no UTF-8: Idx');
  Check(U8Upper('abc') = 'ABC', 'no UTF-8: ASCII case');
  Utf8Enabled := True;

  Finish;
end.
