program t_glyphs;
{$I ../src/tvdefs.inc}
uses TvColors, TvCell, TvUtf8, TvDrawBuf, TvGlyphs;
{$I testlib.inc}

var
  Cells: array[0..3] of TScreenCell;
  B: TDrawBuffer;
  I: Integer;
  Saved: Boolean;
begin
  Check(GlyphByte(glLightH) = $C4, 'byte: light horizontal');
  Check(GlyphByte(glLightV) = $B3, 'byte: light vertical');
  Check(GlyphByte(glDblH) = $CD, 'byte: double horizontal');
  Check(GlyphByte(glDblDR) = $C9, 'byte: double down and right');
  Check(GlyphByte(glDblUL) = $BC, 'byte: double up and left');
  Check(GlyphByte(glVertDblRightSgl) = $C7, 'byte: double vertical, single right');
  Check(GlyphByte(glDownSglRightDbl) = $D5, 'byte: mixed lines');
  Check(GlyphByte(glUpDblHorizSgl) = $D0, 'byte: mixed lines 2');
  Check(GlyphByte(glVertSglHorizDbl) = $D8, 'byte: mixed lines 3');
  Check(GlyphByte(glShadeMedium) = $B1, 'byte: shade');
  Check(GlyphByte(glBlockFull) = $DB, 'byte: full block');
  Check(GlyphByte(glSquare) = $FE, 'byte: square');
  Check(GlyphByte(glDot) = $F9, 'byte: dot');
  Check(GlyphByte(glMidDot) = $FA, 'byte: middle dot');
  Check(GlyphByte(glRadical) = $FB, 'byte: radical');
  Check((GlyphByte(glTriUp) = $1E) and (GlyphByte(glTriDown) = $1F) and (GlyphByte(glTriRight) = $10) and (GlyphByte(glTriLeft) = $11), 'byte: triangles');
  Check(GlyphByte(Ord('a')) = 0, 'byte: not a glyph');
  Check((GlyphChar(glLightH) = gcShadeLight) = False, 'char: not the shade');
  Check((GlyphChar(glShadeLight) = gcShadeLight) and (GlyphChar(glShadeMedium) = gcShadeMedium) and (GlyphChar(glShadeDark) = gcShadeDark) and
        (GlyphChar(glBlockFull) = gcBlockFull) and (GlyphChar(glDot) = gcDot) and (GlyphChar(glMidDot) = gcMidDot) and
        (GlyphChar(glRadical) = gcRadical) and (GlyphChar(glSquare) = gcSquare), 'char: the constants agree with the table');

  Saved := Utf8Enabled;
  Utf8Enabled := True;
  Check(GlyphStr(glLightH) = #$E2#$94#$80, 'string: UTF-8 of U+2500');
  Check(GlyphRun(glLightH, 3) = #$E2#$94#$80#$E2#$94#$80#$E2#$94#$80, 'run: three of them');
  Utf8Enabled := False;
  Check(GlyphStr(glLightH) = #$C4, 'string: the byte of the page');
  Check(GlyphRun(glLightH, 3) = #$C4#$C4#$C4, 'run: three of them, the page');
  Utf8Enabled := Saved;
  Check(GlyphRun(glLightH, 0) = '', 'run: none');

  FillChar(Cells, SizeOf(Cells), 0);
  for I := 0 to 2 do
    SetCellGlyph(Cells[I], glDblH);
  for I := 0 to 2 do
    Check((ScLength(Cells[I].Character) = 3) and (Cells[I].Character.Text[0] = $E2) and (Cells[I].Character.Text[1] = $95) and
          (Cells[I].Character.Text[2] = $90), 'cell: U+2550 in UTF-8');
  Check(Cells[3].Character.Text[0] = 0, 'cell: the next one is untouched');
  { a glyph over a cell that holds a longer text leaves no stray bytes (an overlay that wrote one byte did) }
  SetCellGlyph(Cells[0], glLightH);
  Check((ScLength(Cells[0].Character) = 3) and (Cells[0].Character.Text[0] = $E2) and (Cells[0].Character.Text[1] = $94) and
        (Cells[0].Character.Text[2] = $80), 'cell: replaced as a whole');

  B := TDrawBuffer.Create(80);
  B.MoveGlyph(2, glDblH, AttrFromBIOS($1F), 3);
  Check((PScreenCell(B.Data)[2].Character.Text[0] = $E2) and (AttrAsBIOSByte(PScreenCell(B.Data)[4].Attribute) = $1F), 'draw buffer: MoveGlyph');
  Check(PScreenCell(B.Data)[5].Character.Text[0] = 0, 'draw buffer: only Count cells');
  B.PutGlyph(1, glLightV);
  Check((PScreenCell(B.Data)[1].Character.Text[0] = $E2) and (PScreenCell(B.Data)[1].Character.Text[2] = $82), 'draw buffer: PutGlyph');
  B.Free;
  Finish;
end.
