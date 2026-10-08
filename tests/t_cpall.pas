program t_cpall;
{ Every OEM page of DOS that TvCodePg knows: the pages keep what a text needs (a round trip of every byte), and the glyphs of TvGlyphs land on every page
  (the frames and the shades are the same bytes in all of them; the other glyphs have a byte or the plain sign). }
{$I ../src/tvdefs.inc}
uses SysUtils, TvCodePg, TvGlyphs;
{$I testlib.inc}

const
  { the Cyrillic pages first, then the Latin ones, then the rest }
  Pages: array[0..16] of Integer = (
    866, 1125, 855,
    437, 850, 858, 852, 857, 860, 861, 863, 865, 775,
    737, 869, 862, 864);
  FrameGlyphs: array[0..10] of LongWord = (glLightH, glLightV, glLightDR, glLightDL, glLightUR, glLightUL, glDblH, glDblV, glDblDR, glDblDL, glBlockFull);

var
  P, B, G: Integer;
  Bad, Lost, Landed: Integer;
  CP: LongWord;
begin
  for P := Low(Pages) to High(Pages) do
  begin
    Check(CpSelect(Pages[P]), 'page ' + IntToStr(Pages[P]) + ' is known');
    Bad := 0;
    for B := 32 to 255 do
      if B <> $7F then
      begin
        CP := CpToUnicode(B);
        if (CP <> $FFFD) and (CpFromUnicode(CP) = 0) then
          Inc(Bad);                              { a character that cannot come back to its byte }
      end;
    Check(Bad = 0, 'page ' + IntToStr(Pages[P]) + ': every byte comes back from its character (' + IntToStr(Bad) + ' do not)');
    Lost := 0;
    for G := Low(FrameGlyphs) to High(FrameGlyphs) do
      if ((CpFromUnicode(FrameGlyphs[G]) = 0) and (CpFallback(FrameGlyphs[G]) = 0)) or
         ((CpFromUnicode(FrameGlyphs[G]) <> 0) and (GlyphByte(FrameGlyphs[G]) <> CpFromUnicode(FrameGlyphs[G]))) then
        Inc(Lost);
    Check(Lost = 0, 'page ' + IntToStr(Pages[P]) + ': the frames and the full block land on a byte of the page or on a plain sign (' + IntToStr(Lost) + ' do not)');
    Landed := 0;
    for G := glLightH to glLightH do
      Inc(Landed);
    Check(((CpFromUnicode(glShadeLight) <> 0) or (CpFallback(glShadeLight) <> 0)) and ((CpFromUnicode(glShadeMedium) <> 0) or (CpFallback(glShadeMedium) <> 0)) and
        ((CpFromUnicode(glShadeDark) <> 0) or (CpFallback(glShadeDark) <> 0)), 'page ' + IntToStr(Pages[P]) + ': the shades');
    { a glyph that a page lacks has a plain sign, never nothing }
    Check((CpFromUnicode(glDot) <> 0) or (CpFallback(glDot) <> 0), 'page ' + IntToStr(Pages[P]) + ': the dot has a byte or a plain sign');
    Check((CpFromUnicode(glTriUp) <> 0) or (CpFallback(glTriUp) <> 0), 'page ' + IntToStr(Pages[P]) + ': the arrow up has a byte or a plain sign');
  end;
  CpSelect(866);
  Finish;
end.
