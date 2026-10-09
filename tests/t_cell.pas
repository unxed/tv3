program t_cell;
{$I ../src/tvdefs.inc}
uses TvColors, TvCell, TvCodePg;
{$I testlib.inc}

const
  EAcute: array[0..1] of Byte = ($C3, $A9);
  Combining: array[0..1] of Byte = ($CC, $81);       { U+0301 }
  Cjk: array[0..2] of Byte = ($E4, $B8, $AD);        { U+4E2D }
  Zwj: array[0..2] of Byte = ($E2, $80, $8D);        { U+200D }

var
  C, D: TScreenCharacter;
  A, B: TScreenCell;
  I: Integer;
begin
  Check(SizeOf(TScreenCharacter) = 16, 'TScreenCharacter is 16 bytes');
  Check(SizeOf(TScreenCell) = 24, 'TScreenCell is 24 bytes');

  { single byte }
  C.InitWithChar(Ord('A'));
  Check((Length(C.GetText) = 1) and (C.GetText = 'A'), 'init with a byte');
  Check(not C.IsWide and not C.IsWideCharTrail, 'a byte is narrow, not a trail');

  CpSelect(866);
  Check((CpFallback($2500) = Ord('-')) and (CpFallback($2551) = Ord('|')) and (CpFallback($2554) = Ord('+')) and (CpFallback($2588) = Ord('#')),
    'the plain signs for the lines and blocks that a page lacks');
  Check((CpFallback($4E2D) = 0) and (CpFallback($2190) = Ord('<')), 'no plain sign for a CJK character, arrows have one');

  { multi-byte, narrow and wide }
  C.InitWithMultiByteChar(@EAcute[0], 2, False);
  Check((Length(C.GetText) = 2) and (C.GetText = #$C3#$A9) and not C.IsWide, 'init with UTF-8 text');
  C.InitWithMultiByteChar(@Cjk[0], 3, True);
  Check((Length(C.GetText) = 3) and C.IsWide and not C.IsWideCharTrail, 'wide text');

  { out of range lengths leave an empty character }
  C.InitWithMultiByteChar(@Cjk[0], 0, False);
  Check(C.GetText = #0, 'length 0 leaves an empty character');
  C.InitWithMultiByteChar(@Cjk[0], 5, False);
  Check(C.GetText = #0, 'length 5 leaves an empty character');

  { wide character trail }
  C.InitAsWideCharTrail;
  Check(C.IsWideCharTrail and not C.IsWide, 'wide character trail');

  { zero-width characters are appended }
  C.InitWithChar(Ord('e'));
  C.AppendZeroWidthChar(@Combining[0], 2);
  Check((Length(C.GetText) = 3) and (C.GetText = 'e'#$CC#$81), 'append a combining mark');
  C.AppendZeroWidthChar(@Zwj[0], 3);
  Check(Length(C.GetText) = 6, 'append another zero-width character');

  { a NUL base character becomes a space }
  C.InitWithChar(0);
  C.AppendZeroWidthChar(@Combining[0], 2);
  Check(C.GetText = ' '#$CC#$81, 'NUL base becomes a space');

  { overflow: 15 bytes at most, then the flag sticks and the text stays }
  C.InitWithChar(Ord('a'));
  for I := 1 to 7 do
    C.AppendZeroWidthChar(@Combining[0], 2);          { 1 + 14 = 15 bytes }
  Check(Length(C.GetText) = 15, 'filled to 15 bytes');
  D := C;
  C.AppendZeroWidthChar(@Combining[0], 2);
  Check(C.GetText = D.GetText, 'overflowing append keeps the text');
  Check(CompareByte(C, D, SizeOf(C)) <> 0, 'overflow sets a flag');
  D := C;
  C.AppendZeroWidthChar(@Combining[0], 2);
  Check(CompareByte(C, D, SizeOf(C)) = 0, 'overflow flag is sticky');

  { all zero bytes is a valid cell }
  FillChar(A, SizeOf(A), 0);
  Check((Length(A.Character.GetText) = 1) and (Ord(A.Character.GetText[1]) = 0), 'zeroed cell: one NUL');
  Check(A.Attribute.GetForeground.IsDefault and A.Attribute.GetBackground.IsDefault, 'zeroed cell: default colors');

  { cells from DOS words }
  A := TScreenCell(Word($1F41));
  Check((A.Character.GetText = 'A') and (Byte(A.Attribute) = $1F), 'TScreenCell from a BIOS word');

  { equality }
  B := TScreenCell(Word($1F41));
  Check((A = B), 'equal cells');
  B := TScreenCell(Word($1F42));
  Check(not (A = B), 'different characters');
  B := TScreenCell(Word($2F41));
  Check(not (A = B), 'different attributes');
  C.InitWithMultiByteChar(@Cjk[0], 3, True);
  A := TScreenCell.Create(C, TColorAttr(LongInt($07)));
  B := TScreenCell.Create(C, TColorAttr(LongInt($07)));
  Check((A = B), 'TScreenCell.Create equal');
  D.InitWithMultiByteChar(@Cjk[0], 3, False);
  B := TScreenCell.Create(D, TColorAttr(LongInt($07)));
  Check(not (A = B), 'wide flag counts in equality');

  { the forms of tvision: a character as a 32-bit number, the conversions of a byte and of a BIOS word }
  C.InitWithMultiByteChar($A9C3, False);
  Check((C.GetText = #$C3#$A9) and not C.IsWide, 'a multi-byte character as a number');
  C.InitWithMultiByteChar($41, True);
  Check((C.GetText = 'A') and C.IsWide, 'one byte as a number, wide');
  C := Ord('x');
  Check(C.GetText = 'x', 'TScreenCharacter from a byte');
  A := $1E41;
  B := TScreenCell.Create(D, A.Attribute);
  B.Character := Ord('A');
  Check((A.Character.GetText = 'A') and (Byte(A.Attribute) = $1E) and (A = B) and not (A <> B), 'TScreenCell from a BIOS word, =');
  Finish;
end.
