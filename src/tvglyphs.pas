{ TvGlyphs: the frame, shade, block and arrow characters by name.

  MIT, see LICENSE.

  A glyph is a Unicode code point (glLightH = U+2500), never a byte of a code page: a program does not write #196 or #$C4 for a line.
  The cells of the screen hold UTF-8 (TvCell); the DOS backend lands a glyph on the code page of the machine (TvCodePg.CpFromUnicode, else the
  plain sign CpFallback), so the same name draws on Linux, Windows and DOS.

  Ways to use a glyph:
    - in a cell: SetCellGlyph, TDrawBuffer.MoveGlyph / PutGlyph (TvDrawBuf);
    - in a 16-bit buffer or where a byte is wanted (a word of WriteBufW, a Char argument): GlyphByte, the position in the IBM PC character set,
      which is the same in every DOS code page for these characters;
    - in a string of one byte per column (a table cell, S[K] := ...): GlyphChar;
    - in text that is cut and aligned by characters: GlyphStr, UTF-8 while TvUtf8.Utf8Enabled, else the byte of the page;
    - in a typed constant or a case label, where a call is not allowed: the Char constants gc* (the bytes of the IBM PC set). }
unit TvGlyphs;

{$I tvdefs.inc}

interface

uses
  TvCell;

const
  { light lines }
  glLightH         = $2500;   { ─ }
  glLightV         = $2502;   { │ }
  glLightDR        = $250C;   { ┌ down and right }
  glLightDL        = $2510;   { ┐ }
  glLightUR        = $2514;   { └ }
  glLightUL        = $2518;   { ┘ }
  glLightVR        = $251C;   { ├ }
  glLightVL        = $2524;   { ┤ }
  glLightDH        = $252C;   { ┬ }
  glLightUH        = $2534;   { ┴ }
  glLightVH        = $253C;   { ┼ }
  { double lines }
  glDblH           = $2550;   { ═ }
  glDblV           = $2551;   { ║ }
  glDblDR          = $2554;   { ╔ }
  glDblDL          = $2557;   { ╗ }
  glDblUR          = $255A;   { ╚ }
  glDblUL          = $255D;   { ╝ }
  glDblVR          = $2560;   { ╠ }
  glDblVL          = $2563;   { ╣ }
  glDblDH          = $2566;   { ╦ }
  glDblUH          = $2569;   { ╩ }
  glDblVH          = $256C;   { ╬ }
  { a single and a double line meeting }
  glDownSglRightDbl = $2552;  { ╒ }
  glDownDblRightSgl = $2553;  { ╓ }
  glDownSglLeftDbl  = $2555;  { ╕ }
  glDownDblLeftSgl  = $2556;  { ╖ }
  glUpSglRightDbl   = $2558;  { ╘ }
  glUpDblRightSgl   = $2559;  { ╙ }
  glUpSglLeftDbl    = $255B;  { ╛ }
  glUpDblLeftSgl    = $255C;  { ╜ }
  glVertSglRightDbl = $255E;  { ╞ }
  glVertDblRightSgl = $255F;  { ╟ }
  glVertSglLeftDbl  = $2561;  { ╡ }
  glVertDblLeftSgl  = $2562;  { ╢ }
  glDownSglHorizDbl = $2564;  { ╤ }
  glDownDblHorizSgl = $2565;  { ╥ }
  glUpSglHorizDbl   = $2567;  { ╧ }
  glUpDblHorizSgl   = $2568;  { ╨ }
  glVertSglHorizDbl = $256A;  { ╪ }
  glVertDblHorizSgl = $256B;  { ╫ }
  { blocks and shades }
  glShadeLight     = $2591;   { ░ }
  glShadeMedium    = $2592;   { ▒ }
  glShadeDark      = $2593;   { ▓ }
  glBlockFull      = $2588;   { █ }
  glBlockLower     = $2584;   { ▄ lower half }
  glBlockUpper     = $2580;   { ▀ upper half }
  glBlockLeft      = $258C;   { ▌ left half }
  glBlockRight     = $2590;   { ▐ right half }
  glSquare         = $25A0;   { ■ }
  glDot            = $2219;   { ∙ }
  glMidDot         = $00B7;   { · }
  glTriUp          = $25B2;   { ▲ }
  glTriDown        = $25BC;   { ▼ }
  glTriRight       = $25BA;   { ► }
  glTriLeft        = $25C4;   { ◄ }
  glUpDown         = $2195;   { ↕ }
  glArrowUp        = $2191;   { ↑ }
  glArrowDown      = $2193;   { ↓ }
  glArrowRight     = $2192;   { → }
  glArrowLeft      = $2190;   { ← }
  glIdentical      = $2261;   { ≡ }
  glRadical        = $221A;   { √ }

const
  { the same glyphs as Char constants, for a typed constant or a case label, where a function call is not allowed (the bytes of the IBM PC set) }
  gcShadeLight  = #$B0;
  gcShadeMedium = #$B1;
  gcShadeDark   = #$B2;
  gcBlockFull   = #$DB;
  gcBlockLower  = #$DC;
  gcBlockUpper  = #$DF;
  gcBlockLeft   = #$DD;
  gcBlockRight  = #$DE;
  gcDot         = #$F9;
  gcMidDot      = #$FA;
  gcRadical     = #$FB;
  gcSquare      = #$FE;
  gcIdentical   = #$F0;
  gcLightH      = #$C4;
  gcLightV      = #$B3;
  gcLightDR     = #$DA;
  gcLightDL     = #$BF;
  gcLightUR     = #$C0;
  gcLightUL     = #$D9;
  gcLightVR     = #$C3;
  gcLightVL     = #$B4;
  gcLightDH     = #$C2;
  gcLightUH     = #$C1;
  gcLightVH     = #$C5;
  gcTriUp       = #$1E;
  gcTriDown     = #$1F;
  gcTriRight    = #$10;
  gcTriLeft     = #$11;

function GlyphByte(CodePoint: LongWord): Byte;
  {` The byte of the current code page for a glyph; a page that lacks it gives the position in the IBM PC character set (CP437, the same in the DOS code pages for the characters
  above), 0 when the code point is not one of the glyphs of this unit. `}
function GlyphChar(CodePoint: LongWord): Char;
  {` The glyph as one Char of a string that has one byte per column (S[K] := ..., the text of a table cell): the byte of the IBM PC set, which TvText
  shows as the glyph in every build (a byte that is not UTF-8 is a character of the page). `}
function GlyphStr(CodePoint: LongWord): ShortString;
  {` The glyph as text: UTF-8 while TvUtf8.Utf8Enabled, else the byte of the page. `}
function GlyphRun(CodePoint: LongWord; Count: Integer): ShortString;
  {` Count glyphs one after another as text (as GlyphStr). `}
procedure SetCellGlyph(var Cell: TScreenCell; CodePoint: LongWord);
  {` Puts the glyph into one cell (the attribute is kept). `}

implementation

uses
  TvUtf8, TvCodePg;

const
  { the glyphs by their position $B0..$DF (and a few above) in the IBM PC set }
  Table: array[0..47] of record
    Cp: Word;
    Pc: Byte;
  end = (
    (Cp: $2591; Pc: $B0), (Cp: $2592; Pc: $B1), (Cp: $2593; Pc: $B2), (Cp: $2502; Pc: $B3), (Cp: $2524; Pc: $B4), (Cp: $2561; Pc: $B5),
    (Cp: $2562; Pc: $B6), (Cp: $2556; Pc: $B7), (Cp: $2555; Pc: $B8), (Cp: $2563; Pc: $B9), (Cp: $2551; Pc: $BA), (Cp: $2557; Pc: $BB),
    (Cp: $255D; Pc: $BC), (Cp: $255C; Pc: $BD), (Cp: $255B; Pc: $BE), (Cp: $2510; Pc: $BF), (Cp: $2514; Pc: $C0), (Cp: $2534; Pc: $C1),
    (Cp: $252C; Pc: $C2), (Cp: $251C; Pc: $C3), (Cp: $2500; Pc: $C4), (Cp: $253C; Pc: $C5), (Cp: $255E; Pc: $C6), (Cp: $255F; Pc: $C7),
    (Cp: $255A; Pc: $C8), (Cp: $2554; Pc: $C9), (Cp: $2569; Pc: $CA), (Cp: $2566; Pc: $CB), (Cp: $2560; Pc: $CC), (Cp: $2550; Pc: $CD),
    (Cp: $256C; Pc: $CE), (Cp: $2567; Pc: $CF), (Cp: $2568; Pc: $D0), (Cp: $2564; Pc: $D1), (Cp: $2565; Pc: $D2), (Cp: $2559; Pc: $D3),
    (Cp: $2558; Pc: $D4), (Cp: $2552; Pc: $D5), (Cp: $2553; Pc: $D6), (Cp: $256B; Pc: $D7), (Cp: $256A; Pc: $D8), (Cp: $2518; Pc: $D9),
    (Cp: $250C; Pc: $DA), (Cp: $2588; Pc: $DB), (Cp: $2584; Pc: $DC), (Cp: $258C; Pc: $DD), (Cp: $2590; Pc: $DE), (Cp: $2580; Pc: $DF)
  );
  Extra: array[0..13] of record
    Cp: Word;
    Pc: Byte;
  end = ((Cp: $25A0; Pc: $FE), (Cp: $2219; Pc: $F9), (Cp: $221A; Pc: $FB), (Cp: $00B7; Pc: $FA), (Cp: $25B2; Pc: $1E), (Cp: $25BC; Pc: $1F),
         (Cp: $25BA; Pc: $10), (Cp: $25C4; Pc: $11), (Cp: $2195; Pc: $12), (Cp: $2191; Pc: $18), (Cp: $2193; Pc: $19), (Cp: $2192; Pc: $1A),
         (Cp: $2190; Pc: $1B), (Cp: $2261; Pc: $F0));

function GlyphByte(CodePoint: LongWord): Byte;
var
  I: Integer;
begin
  { the byte of the current code page when it has the glyph (the frames are the same bytes on the pages of DOS except 864, the Arabic one) }
  Result := CpFromUnicode(CodePoint);
  if (Result <> 0) and ((Result < $20) or (Result >= $7F)) and (CodePoint > $7F) then
    Exit;
  Result := 0;
  for I := Low(Table) to High(Table) do
    if Table[I].Cp = CodePoint then
      Exit(Table[I].Pc);
  for I := Low(Extra) to High(Extra) do
    if Extra[I].Cp = CodePoint then
      Exit(Extra[I].Pc);
  Result := 0;
end;

function GlyphChar(CodePoint: LongWord): Char;
begin
  Result := Chr(GlyphByte(CodePoint));
end;

function GlyphStr(CodePoint: LongWord): ShortString;
var
  Buf: array[0..MaxCharSize - 1] of Byte;
  N: Integer;
begin
  if not Utf8Enabled then
    Exit(GlyphChar(CodePoint));
  N := Utf8Encode(CodePoint, @Buf[0]);
  SetLength(Result, N);
  if N > 0 then
    Move(Buf[0], Result[1], N);
end;

function GlyphRun(CodePoint: LongWord; Count: Integer): ShortString;
var
  One: ShortString;
  I: Integer;
begin
  One := GlyphStr(CodePoint);
  Result := '';
  for I := 1 to Count do
  begin
    if Length(Result) + Length(One) > 255 then
      Break;
    Result := Result + One;
  end;
end;

procedure SetCellGlyph(var Cell: TScreenCell; CodePoint: LongWord);
var
  Buf: array[0..7] of Byte;
begin
  Cell.Character.InitWithMultiByteChar(@Buf[0], Utf8Encode(CodePoint, @Buf[0]), False);
end;

end.
