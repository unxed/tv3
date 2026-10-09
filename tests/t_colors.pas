program t_colors;
{$I ../src/tvdefs.inc}
uses TvColors;
{$I testlib.inc}

var
  A, B: TColorAttr;
  P: TAttrPair;
  C: TColorBIOS;
begin
  { RGB packing }
  Check(LongWord(TColorRGB.Create($7F, $00, $BB)) = $7F00BB, 'RGB packs 0xRRGGBB');
  Check((TColorRGB($7F00BB).GetRed = $7F) and (TColorRGB($7F00BB).GetGreen = 0) and (TColorRGB($7F00BB).GetBlue = $BB), 'RGB unpack');
  Check((TColorRGB($AA7F00BB).GetRed = $7F) and (TColorRGB($AA7F00BB).GetGreen = $00) and (TColorRGB($AA7F00BB).GetBlue = $BB), 'RGB ignores the top byte');

  { BIOS <-> XTerm16 swaps red and blue }
  Check(Byte(TColorConversion.BIOStoXTerm16(1)) = 4, 'BIOS blue -> xterm 4');
  Check(Byte(TColorConversion.BIOStoXTerm16(4)) = 1, 'BIOS red -> xterm 1');
  Check(Byte(TColorConversion.BIOStoXTerm16(2)) = 2, 'BIOS green -> xterm 2');
  Check(Byte(TColorConversion.BIOStoXTerm16(6)) = 3, 'BIOS red+green -> xterm 3 (yellow)');
  Check(Byte(TColorConversion.BIOStoXTerm16($F)) = $F, 'BIOS white');
  Check(Byte(TColorConversion.XTerm16toBIOS(Byte(TColorConversion.BIOStoXTerm16($B)))) = $B, 'BIOS/xterm roundtrip');

  { RGB -> 16 colors }
  Check(Byte(TColorConversion.RGBtoXTerm16(TColorRGB.Create(0, 0, 0))) = 0, 'black -> 0');
  Check(Byte(TColorConversion.RGBtoXTerm16(TColorRGB.Create(255, 255, 255))) = 15, 'white -> 15');
  Check(Byte(TColorConversion.RGBtoXTerm16(TColorRGB.Create(255, 0, 0))) = 9, 'red -> 9');
  Check(Byte(TColorConversion.RGBtoXTerm16(TColorRGB.Create(128, 0, 0))) = 1, 'dark red -> 1');
  Check(Byte(TColorConversion.RGBtoXTerm16(TColorRGB.Create(0, 255, 0))) = 10, 'green -> 10');
  Check(Byte(TColorConversion.RGBtoXTerm16(TColorRGB.Create(0, 0, 255))) = 12, 'blue -> 12');
  Check(Byte(TColorConversion.RGBtoXTerm16(TColorRGB.Create(255, 255, 0))) = 11, 'yellow -> 11');
  Check(Byte(TColorConversion.RGBtoXTerm16(TColorRGB.Create(128, 128, 128))) = 8, 'mid gray -> 8');
  Check(Byte(TColorConversion.RGBtoXTerm16(TColorRGB.Create(192, 192, 192))) = 7, 'light gray -> 7');
  Check(Byte(TColorConversion.RGBtoXTerm16(TColorRGB.Create(10, 10, 10))) = 0, 'near black -> 0');

  { RGB -> 256 colors and back }
  Check(Byte(TColorConversion.RGBtoXTerm256(TColorRGB.Create(0, 0, 0))) = 16, '256: black');
  Check(Byte(TColorConversion.RGBtoXTerm256(TColorRGB.Create(255, 255, 255))) = 231, '256: white');
  Check(Byte(TColorConversion.RGBtoXTerm256(TColorRGB.Create(255, 0, 0))) = 196, '256: red');
  Check(LongWord(TColorConversion.XTerm256toRGB(196)) = LongWord(TColorRGB.Create(255, 0, 0)), '256 -> RGB red');
  Check(LongWord(TColorConversion.XTerm256toRGB(232)) = LongWord(TColorRGB.Create(8, 8, 8)), '256 -> RGB first gray');
  Check(LongWord(TColorConversion.XTerm256toRGB(255)) = LongWord(TColorRGB.Create(238, 238, 238)), '256 -> RGB last gray');
  Check(Byte(TColorConversion.XTerm256toXTerm16(196)) = 9, '256 -> 16: red');

  { TColor }
  Check(Default(TColor).IsDefault, 'default color');
  Check((TColor(TColorBIOS($1F))).IsBIOS and (Byte((TColor(TColorBIOS($1F))).AsBIOS) = $F), 'BIOS color keeps 4 bits');
  Check((TColor(TColorRGB($7F00BB))).IsRGB and (LongWord((TColor(TColorRGB($7F00BB))).AsRGB) = $7F00BB), 'RGB color');
  Check((TColor(TColorXTerm(200))).IsXTerm and (Byte((TColor(TColorXTerm(200))).AsXTerm) = 200), 'xterm color');
  Check(Byte(Default(TColor).ToBIOS(True)) = 7, 'default fg -> 7');
  Check(Byte(Default(TColor).ToBIOS(False)) = 0, 'default bg -> 0');
  Check(Byte((TColor(TColorRGB($FF0000))).ToBIOS(True)) = 12, 'RGB red -> BIOS 12');
  Check(Byte((TColor(TColorXTerm(196))).ToBIOS(True)) = 12, 'xterm 196 -> BIOS 12');
  Check(Byte((TColor(TColorXTerm(4))).ToBIOS(True)) = 1, 'xterm 4 (blue) -> BIOS 1');

  { TColorAttr }
  A := TColorAttr(LongInt($1F));
  Check(Byte(A.GetForeground.AsBIOS) = $F, 'attr fg from BIOS byte');
  Check(Byte(A.GetBackground.AsBIOS) = $1, 'attr bg from BIOS byte');
  Check(Byte(A) = $1F, 'attr -> BIOS byte');
  Check(A.ToBIOS = $1F, 'attr quantized to BIOS');

  A := TColorAttr.Create(TColor(TColorRGB($7F00BB)), TColor(TColorBIOS(3)), slBold or slItalic);
  Check(A.GetStyle = slBold or slItalic, 'attr style');
  Check(LongWord(A.GetForeground.AsRGB) = $7F00BB, 'attr fg RGB survives');
  Check(Byte(A) = $5F, 'non-BIOS attr gives 0x5F');

  A.SetStyle(slUnderline);
  A.SetForeground(TColor(TColorBIOS(5)));
  A.SetBackground(TColor(TColorXTerm(100)));
  Check((A.GetStyle = slUnderline) and (Byte(A.GetForeground.AsBIOS) = 5)
    and (Byte(A.GetBackground.AsXTerm) = 100), 'attr setters');

  B := Default(TColorAttr);
  Check(B.GetForeground.IsDefault and B.GetBackground.IsDefault and (B.GetStyle = 0),
    'zero attr is default/default/no style');

  A := TColorAttr(LongInt($1F));
  B := A.Reversed;
  Check(Byte(B) = $F1, 'reversed swaps BIOS colors');
  B := (TColorAttr.Create(Default(TColor), TColor(TColorBIOS(2)))).Reversed;
  Check(B.GetStyle = slReverse, 'reversed with default color toggles slReverse');
  Check((A.Reversed.Reversed = A), 'reversed twice is identity');

  Check((TAttrPair.Create(A, B)[0] = A) and (TAttrPair.Create(A, B)[1] = B), 'attr pair');
  P := $1F70;
  Check((P[0] = $70) and (P[1] = $1F) and (Word(P) = $1F70), 'a pair of BIOS attributes');
  Check(((P shr 8)[0] = $1F) and ((TColorAttr(LongInt($1F)) shl 8)[1] = $1F), 'shr 8 and shl 8 of the legacy code');
  P := TAttrPair.Create(0, $1F);
  P := P or TColorAttr(LongInt($4E));
  Check((P[0] = $4E) and (P[1] = $1F), 'or sets the lower attribute when it is 0');
  C := $0B;
  C.SetIntensity(False);
  C.SetRed(True);
  Check((Byte(C) = $07) and C.GetRed and C.GetGreen and C.GetBlue, 'TColorBIOS setters');
  Check((TColor(#$0C) = TColor(TColorBIOS($0C))) and (TColor($123456).IsRGB), 'TColor from a char and from an integer');
  Check((TColorAttr(LongInt($1F)) = $1F) and (TColorAttr(LongInt($1F)) <> $1E), 'TColorAttr compared with a BIOS attribute');

  Finish;
end.
