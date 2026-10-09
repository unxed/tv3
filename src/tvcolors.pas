{ TvColors: colors, color attributes and conversions between color models.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/colors.h        (TColorRGB, TColorBIOS, TColorXTerm, TColorDefault,
                                     TColorConversion, TColor, TColorAttr, TAttrPair,
                                     style flags)
    source/platform/colors.cpp      (RGB -> 16/256 colors, quantization to BIOS)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/docs/API-NAMES.md):
    - the conversions of the C++ constructors and conversion operators are implicit
      operators (:=);
    - TColorAttr << is an operator of the unit (TAttrPair is declared after TColorAttr);
      the array form of TAttrPair is its default property (P[0], P[1]);
    - the lookup tables are built at unit initialization.

  A TColor holds a 24-bit value and a 3-bit type (the 27 bits used by
  TColorAttr). A zero TColor is the terminal default color; a zero
  TColorAttr is default colors without style. }
unit TvColors;

{$I tvdefs.inc}

interface

type
  TColorRGB = record
  private
    FB, FG, FR, FUnused: Byte;
  public
    constructor Create(R, G, B: Byte); overload;
    constructor Create(Rgb: LongWord); overload;
    function GetRed: Byte; inline;
    procedure SetRed(R: Byte); inline;
    function GetGreen: Byte; inline;
    procedure SetGreen(G: Byte); inline;
    function GetBlue: Byte; inline;
    procedure SetBlue(B: Byte); inline;
    class operator :=(Rgb: LongWord): TColorRGB;
    class operator :=(const C: TColorRGB): LongWord;
  end;

  TColorBIOS = record
  private
    FIrgb: Byte;
  public
    constructor Create(Irgb: Byte);
    function GetRed: Boolean; inline;
    procedure SetRed(R: Boolean);
    function GetGreen: Boolean; inline;
    procedure SetGreen(G: Boolean);
    function GetBlue: Boolean; inline;
    procedure SetBlue(B: Boolean);
    function GetIntensity: Boolean; inline;
    procedure SetIntensity(I: Boolean);
    class operator :=(Irgb: Byte): TColorBIOS;
    class operator :=(const C: TColorBIOS): Byte;
  end;

  TColorXTerm = record
  private
    FIdx: Byte;
  public
    constructor Create(Idx: Byte);
    class operator :=(Idx: Byte): TColorXTerm;
    class operator :=(const C: TColorXTerm): Byte;
  end;

  TColorDefault = record
  end;

  TColorConversion = record
  public
    class function BIOStoXTerm16(C: TColorBIOS): TColorXTerm; static;
    class function XTerm16toBIOS(Idx: TColorXTerm): TColorBIOS; static;      { XTerm indices 0-15 }
    class function XTerm256toXTerm16(Idx: TColorXTerm): TColorXTerm; static; { XTerm indices 16-255 -> 0-15 }
    class function XTerm256toRGB(Idx: TColorXTerm): TColorRGB; static;       { XTerm indices 16-255 }
    class function RGBtoXTerm16(C: TColorRGB): TColorXTerm; static;          { XTerm indices 0-15 }
    class function RGBtoXTerm256(C: TColorRGB): TColorXTerm; static;         { XTerm indices 16-255 }
  end;

  TColor = record
  private
    FData: LongWord;
    const
      ctDefault = $0;
      ctBIOS    = $1;
      ctRGB     = $2;
      ctXTerm   = $3;
    function &Type: Byte; inline;
  public
    class operator :=(Bios: Char): TColor;
    class operator :=(Rgb: LongInt): TColor;
    class operator :=(const Bios: TColorBIOS): TColor;
    class operator :=(const Rgb: TColorRGB): TColor;
    class operator :=(const XTerm: TColorXTerm): TColor;
    class operator :=(const Def: TColorDefault): TColor;
    function IsDefault: Boolean; inline;
    function IsBIOS: Boolean; inline;
    function IsRGB: Boolean; inline;
    function IsXTerm: Boolean; inline;
    { The getters do no conversion: check the type first. }
    function AsBIOS: TColorBIOS; inline;
    function AsRGB: TColorRGB; inline;
    function AsXTerm: TColorXTerm; inline;
    { Quantization to BIOS; the default color maps to 7 (foreground) or 0. }
    function ToBIOS(IsForeground: Boolean): TColorBIOS;
    class operator =(const A, B: TColor): Boolean;
    class operator <>(const A, B: TColor): Boolean;
  end;

const
  { TColorAttr style masks }
  slBold      = $001;
  slItalic    = $002;
  slUnderline = $004;
  slBlink     = $008;
  slReverse   = $010;       { prefer Reversed }
  slStrike    = $020;
  { private masks (used inside the library) }
  slWindowShadow = $200;

type
  TColorAttr = record
  private
    FData: QWord;
    const
      FgMask = (QWord(1) shl 27) - 1;
      BgMask = (QWord(1) shl 27) - 1;
      StyleMask = (QWord(1) shl 10) - 1;
  public
    constructor Create(Fg, Bg: TColor; Style: Word = 0);
    class operator :=(Bios: LongInt): TColorAttr;
    function GetForeground: TColor; inline;
    procedure SetForeground(Fg: TColor); inline;
    function GetBackground: TColor; inline;
    procedure SetBackground(Bg: TColor); inline;
    function GetStyle: Word; inline;
    procedure SetStyle(AStyle: Word); inline;
    function Reversed: TColorAttr;
    { a BIOS color attribute, with quantization if needed; the style flags are ignored }
    function ToBIOS: Byte;
    { the BIOS attribute if both colors are BIOS colors and there is no style, else $5F }
    class operator :=(const A: TColorAttr): Byte;
    class operator =(const A, B: TColorAttr): Boolean;
    class operator <>(const A, B: TColorAttr): Boolean;
    class operator =(const A: TColorAttr; Bios: LongInt): Boolean;
    class operator <>(const A: TColorAttr; Bios: LongInt): Boolean;
  end;

  PColorAttr = ^TColorAttr;

  TAttrPair = record
  private
    FAttrs: array[0..1] of TColorAttr;
    function GetAttr(Index: Integer): TColorAttr; inline;
    procedure SetAttr(Index: Integer; const A: TColorAttr); inline;
  public
    constructor Create(const Low: TColorAttr); overload;
    constructor Create(const Low, High: TColorAttr); overload;
    class operator :=(Bios: LongInt): TAttrPair;
    { [0]: low, [1]: high }
    property Attrs[Index: Integer]: TColorAttr read GetAttr write SetAttr; default;
    { the pair of BIOS attributes (both must be BIOS attributes) }
    class operator :=(const P: TAttrPair): Word;
    class operator shr(const P: TAttrPair; Shift: Integer): TAttrPair;
    { for |= : P := P or A }
    class operator or(const P: TAttrPair; const A: TColorAttr): TAttrPair;
    { TColorAttr(const TAttrPair &) }
    class operator :=(const P: TAttrPair): TColorAttr;
  end;

{ TColorAttr << Shift }
operator shl(const A: TColorAttr; Shift: Integer): TAttrPair;

implementation

var
  XTerm256toXTerm16LUT: array[0..255] of TColorXTerm;
  XTerm256toRGBLUT: array[0..255] of TColorRGB;

{ --- TColorRGB ------------------------------------------------------------ }

constructor TColorRGB.Create(R, G, B: Byte);
begin
  FB := B;
  FG := G;
  FR := R;
  FUnused := 0;
end;

constructor TColorRGB.Create(Rgb: LongWord);
begin
  FB := Byte(Rgb);
  FG := Byte(Rgb shr 8);
  FR := Byte(Rgb shr 16);
  FUnused := 0;
end;

function TColorRGB.GetRed: Byte;
begin
  Result := FR;
end;

procedure TColorRGB.SetRed(R: Byte);
begin
  FR := R;
end;

function TColorRGB.GetGreen: Byte;
begin
  Result := FG;
end;

procedure TColorRGB.SetGreen(G: Byte);
begin
  FG := G;
end;

function TColorRGB.GetBlue: Byte;
begin
  Result := FB;
end;

procedure TColorRGB.SetBlue(B: Byte);
begin
  FB := B;
end;

class operator TColorRGB.:=(Rgb: LongWord): TColorRGB;
begin
  Result := TColorRGB.Create(Rgb);
end;

class operator TColorRGB.:=(const C: TColorRGB): LongWord;
begin
  Result := (LongWord(C.FR) shl 16) or (LongWord(C.FG) shl 8) or C.FB;
end;

{ --- TColorBIOS ------------------------------------------------------------ }

constructor TColorBIOS.Create(Irgb: Byte);
begin
  FIrgb := Irgb and $0F;
end;

function TColorBIOS.GetRed: Boolean;
begin
  Result := (FIrgb and $04) <> 0;
end;

procedure TColorBIOS.SetRed(R: Boolean);
begin
  FIrgb := (FIrgb and not $04) or (Ord(R) shl 2);
end;

function TColorBIOS.GetGreen: Boolean;
begin
  Result := (FIrgb and $02) <> 0;
end;

procedure TColorBIOS.SetGreen(G: Boolean);
begin
  FIrgb := (FIrgb and not $02) or (Ord(G) shl 1);
end;

function TColorBIOS.GetBlue: Boolean;
begin
  Result := (FIrgb and $01) <> 0;
end;

procedure TColorBIOS.SetBlue(B: Boolean);
begin
  FIrgb := (FIrgb and not $01) or Ord(B);
end;

function TColorBIOS.GetIntensity: Boolean;
begin
  Result := (FIrgb and $08) <> 0;
end;

procedure TColorBIOS.SetIntensity(I: Boolean);
begin
  FIrgb := (FIrgb and not $08) or (Ord(I) shl 3);
end;

class operator TColorBIOS.:=(Irgb: Byte): TColorBIOS;
begin
  Result := TColorBIOS.Create(Irgb);
end;

class operator TColorBIOS.:=(const C: TColorBIOS): Byte;
begin
  Result := C.FIrgb;
end;

{ --- TColorXTerm ----------------------------------------------------------- }

constructor TColorXTerm.Create(Idx: Byte);
begin
  FIdx := Idx;
end;

class operator TColorXTerm.:=(Idx: Byte): TColorXTerm;
begin
  Result.FIdx := Idx;
end;

class operator TColorXTerm.:=(const C: TColorXTerm): Byte;
begin
  Result := C.FIdx;
end;

{ --- TColorConversion ------------------------------------------------------ }

class function TColorConversion.BIOStoXTerm16(C: TColorBIOS): TColorXTerm;
var
  Aux: Boolean;
begin
  { swap the red and blue bits }
  Aux := C.GetBlue;
  C.SetBlue(C.GetRed);
  C.SetRed(Aux);
  Result := Byte(C);
end;

class function TColorConversion.XTerm16toBIOS(Idx: TColorXTerm): TColorBIOS;
begin
  Result := Byte(BIOStoXTerm16(Byte(Idx)));
end;

class function TColorConversion.XTerm256toXTerm16(Idx: TColorXTerm): TColorXTerm;
begin
  Result := XTerm256toXTerm16LUT[Byte(Idx)];
end;

class function TColorConversion.XTerm256toRGB(Idx: TColorXTerm): TColorRGB;
begin
  Result := XTerm256toRGBLUT[Byte(Idx)];
end;

const
  HuePrecision = 32;
  HueMax = 6 * HuePrecision;
  HueToXTerm: array[0..5] of Byte = (1, 3, 2, 6, 4, 5);

{ RGB -> XTerm16 through an HSL-like intermediate (hue, chroma, lightness):
  chroma < 12 is grayscale (4 levels), otherwise dark/bright/white variant of
  the color picked by hue. Integer arithmetic only. }
function RGBToXTerm16Impl(R, G, B: Byte): TColorXTerm;
var
  Xmin, Xmax, L, C, Hue: Byte;
  H: Integer;
begin
  Xmin := R;
  if G < Xmin then Xmin := G;
  if B < Xmin then Xmin := B;
  Xmax := R;
  if G > Xmax then Xmax := G;
  if B > Xmax then Xmax := B;
  L := (Integer(Xmax) + Integer(Xmin)) div 2;
  C := Xmax - Xmin;
  H := 0;
  if C <> 0 then
  begin
    if Xmax = R then
      H := (HuePrecision * (Integer(G) - Integer(B))) div C
    else if Xmax = G then
      H := (HuePrecision * (Integer(B) - Integer(R))) div C + 2 * HuePrecision
    else
      H := (HuePrecision * (Integer(R) - Integer(G))) div C + 4 * HuePrecision;
    if H < 0 then
      Inc(H, HueMax)
    else if H >= HueMax then
      Dec(H, HueMax);
  end;
  if C >= 12 then
  begin
    if H < HueMax - HuePrecision div 2 then
      Hue := (H + HuePrecision div 2) div HuePrecision
    else
      Hue := (H - (HueMax - HuePrecision div 2)) div HuePrecision;
    if L < 127 then                 { 0.5 * 255 }
      Exit(HueToXTerm[Hue]);
    if L < 235 then                 { 0.925 * 255 }
      Exit(HueToXTerm[Hue] + 8);
    Exit(15);
  end
  else
  begin
    if L < 63 then                  { 0.25 * 255 }
      Exit(0);
    if L < 159 then                 { 0.625 * 255 }
      Exit(8);
    if L < 223 then                 { 0.875 * 255 }
      Exit(7);
    Exit(15);
  end;
end;

class function TColorConversion.RGBtoXTerm16(C: TColorRGB): TColorXTerm;
begin
  Result := RGBToXTerm16Impl(C.GetRed, C.GetGreen, C.GetBlue);
end;

class function TColorConversion.RGBtoXTerm256(C: TColorRGB): TColorXTerm;

  function Scale(V: Byte): Integer;
  begin
    if V < 75 then
      Inc(V, 20);               { compensate for underrepresented dark colors }
    if V < 35 then
      V := 35;
    Result := (V - 35) div 40;
  end;

  function CnvGray(L: Byte): Integer;
  begin
    if L < 8 - 5 then
      Exit(16);                 { totally black }
    if L >= 238 + 5 then
      Exit(231);                { totally white }
    if L < 3 then
      L := 3;
    Result := 232 + (L - 3) div 10;
  end;

var
  Idx: Integer;
  R, G, B, Xmin, Xmax, Chroma, L: Byte;
begin
  R := C.GetRed;
  G := C.GetGreen;
  B := C.GetBlue;
  Idx := 16 + (Scale(R) * 6 + Scale(G)) * 6 + Scale(B);
  if LongWord(C) <> LongWord(XTerm256toRGB(Idx)) then
  begin
    Xmin := R;
    if G < Xmin then Xmin := G;
    if B < Xmin then Xmin := B;
    Xmax := R;
    if G > Xmax then Xmax := G;
    if B > Xmax then Xmax := B;
    Chroma := Xmax - Xmin;
    if (Chroma < 12) or (Idx = 16) then
    begin
      L := (Integer(Xmax) + Integer(Xmin)) div 2;
      Idx := CnvGray(L);
    end;
  end;
  Result := Idx;
end;

procedure InitLUTs;
var
  I, J, K: Integer;
  R, G, B, L: Byte;
begin
  for I := 0 to 255 do
  begin
    XTerm256toXTerm16LUT[I] := 0;
    XTerm256toRGBLUT[I] := 0;
  end;
  for I := 0 to 15 do
    XTerm256toXTerm16LUT[I] := I;
  for I := 0 to 5 do
  begin
    if I <> 0 then R := 55 + I * 40 else R := 0;
    for J := 0 to 5 do
    begin
      if J <> 0 then G := 55 + J * 40 else G := 0;
      for K := 0 to 5 do
      begin
        if K <> 0 then B := 55 + K * 40 else B := 0;
        XTerm256toXTerm16LUT[16 + (I * 6 + J) * 6 + K] := RGBToXTerm16Impl(R, G, B);
        XTerm256toRGBLUT[16 + (I * 6 + J) * 6 + K] := TColorRGB.Create(R, G, B);
      end;
    end;
  end;
  for I := 0 to 23 do
  begin
    L := I * 10 + 8;
    XTerm256toXTerm16LUT[232 + I] := RGBToXTerm16Impl(L, L, L);
    XTerm256toRGBLUT[232 + I] := TColorRGB.Create(L, L, L);
  end;
end;

{ --- TColor ------------------------------------------------------------------ }

function TColor.&Type: Byte;
begin
  Result := Byte(FData shr 24);
end;

class operator TColor.:=(Bios: Char): TColor;
begin
  Result.FData := LongWord(Ord(Bios) and $0F) or (ctBIOS shl 24);
end;

class operator TColor.:=(Rgb: LongInt): TColor;
begin
  Result.FData := LongWord(Rgb and $FFFFFF) or (ctRGB shl 24);
end;

class operator TColor.:=(const Bios: TColorBIOS): TColor;
begin
  Result := Char(Byte(Bios));
end;

class operator TColor.:=(const Rgb: TColorRGB): TColor;
begin
  Result := LongInt(LongWord(Rgb));
end;

class operator TColor.:=(const XTerm: TColorXTerm): TColor;
begin
  Result.FData := LongWord(Byte(XTerm)) or (ctXTerm shl 24);
end;

class operator TColor.:=(const Def: TColorDefault): TColor;
begin
  Result.FData := 0;
end;

function TColor.IsDefault: Boolean;
begin
  Result := &Type = ctDefault;
end;

function TColor.IsBIOS: Boolean;
begin
  Result := &Type = ctBIOS;
end;

function TColor.IsRGB: Boolean;
begin
  Result := &Type = ctRGB;
end;

function TColor.IsXTerm: Boolean;
begin
  Result := &Type = ctXTerm;
end;

function TColor.AsBIOS: TColorBIOS;
begin
  Result := Byte(FData);
end;

function TColor.AsRGB: TColorRGB;
begin
  Result := FData;
end;

function TColor.AsXTerm: TColorXTerm;
begin
  Result := Byte(FData);
end;

function TColor.ToBIOS(IsForeground: Boolean): TColorBIOS;
var
  Idx: Byte;
begin
  case &Type of
    ctBIOS:
      Result := AsBIOS;
    ctRGB:
      Result := TColorConversion.XTerm16toBIOS(TColorConversion.RGBtoXTerm16(AsRGB));
    ctXTerm:
    begin
      Idx := Byte(AsXTerm);
      if Idx >= 16 then
        Idx := Byte(TColorConversion.XTerm256toXTerm16(Idx));
      Result := TColorConversion.XTerm16toBIOS(Idx);
    end;
  else
    if IsForeground then Result := $7 else Result := $0;
  end;
end;

class operator TColor.=(const A, B: TColor): Boolean;
begin
  Result := A.FData = B.FData;
end;

class operator TColor.<>(const A, B: TColor): Boolean;
begin
  Result := A.FData <> B.FData;
end;

{ --- TColorAttr -------------------------------------------------------------- }

constructor TColorAttr.Create(Fg, Bg: TColor; Style: Word);
begin
  FData := (QWord(Fg.FData) and FgMask)
    or ((QWord(Bg.FData) and BgMask) shl 27)
    or (QWord(Style) shl 54);
end;

class operator TColorAttr.:=(Bios: LongInt): TColorAttr;
begin
  Result := TColorAttr.Create(Char(Bios and $FF), Char((Bios shr 4) and $FF));
end;

function TColorAttr.GetForeground: TColor;
begin
  Result.FData := LongWord(FData and FgMask);
end;

procedure TColorAttr.SetForeground(Fg: TColor);
begin
  FData := (FData and not FgMask) or (QWord(Fg.FData) and FgMask);
end;

function TColorAttr.GetBackground: TColor;
begin
  Result.FData := LongWord((FData shr 27) and BgMask);
end;

procedure TColorAttr.SetBackground(Bg: TColor);
begin
  FData := (FData and not (BgMask shl 27)) or ((QWord(Bg.FData) and BgMask) shl 27);
end;

function TColorAttr.GetStyle: Word;
begin
  Result := Word(FData shr 54);
end;

procedure TColorAttr.SetStyle(AStyle: Word);
begin
  FData := (FData and not (StyleMask shl 54)) or (QWord(AStyle) shl 54);
end;

function TColorAttr.Reversed: TColorAttr;
var
  Fg, Bg: TColor;
begin
  Fg := GetForeground;
  Bg := GetBackground;
  { slReverse may look different in different terminals, so the colors are
    swapped by hand unless one of them is the default color }
  if Fg.IsDefault or Bg.IsDefault then
    Result := TColorAttr.Create(Fg, Bg, GetStyle xor slReverse)
  else
    Result := TColorAttr.Create(Bg, Fg, GetStyle);
end;

function TColorAttr.ToBIOS: Byte;
begin
  Result := Byte(GetForeground.ToBIOS(True)) or (Byte(GetBackground.ToBIOS(False)) shl 4);
end;

class operator TColorAttr.:=(const A: TColorAttr): Byte;
var
  Fg, Bg: TColor;
begin
  Fg := A.GetForeground;
  Bg := A.GetBackground;
  if Fg.IsBIOS and Bg.IsBIOS and (A.GetStyle = 0) then
    Result := Byte(Fg.AsBIOS) or (Byte(Bg.AsBIOS) shl 4)
  else
    Result := $5F;
end;

class operator TColorAttr.=(const A, B: TColorAttr): Boolean;
begin
  Result := A.FData = B.FData;
end;

class operator TColorAttr.<>(const A, B: TColorAttr): Boolean;
begin
  Result := not (A = B);
end;

class operator TColorAttr.=(const A: TColorAttr; Bios: LongInt): Boolean;
begin
  Result := A = TColorAttr(LongInt(Byte(Bios)));
end;

class operator TColorAttr.<>(const A: TColorAttr; Bios: LongInt): Boolean;
begin
  Result := not (A = Bios);
end;

{ --- TAttrPair --------------------------------------------------------------- }

constructor TAttrPair.Create(const Low: TColorAttr);
begin
  FAttrs[0] := Low;
  FAttrs[1] := 0;
end;

constructor TAttrPair.Create(const Low, High: TColorAttr);
begin
  FAttrs[0] := Low;
  FAttrs[1] := High;
end;

class operator TAttrPair.:=(Bios: LongInt): TAttrPair;
begin
  Result := TAttrPair.Create(Bios and $FF, (Bios shr 8) and $FF);
end;

function TAttrPair.GetAttr(Index: Integer): TColorAttr;
begin
  Result := FAttrs[Index];
end;

procedure TAttrPair.SetAttr(Index: Integer; const A: TColorAttr);
begin
  FAttrs[Index] := A;
end;

class operator TAttrPair.:=(const P: TAttrPair): Word;
begin
  Result := Byte(P.FAttrs[0]) or (Word(Byte(P.FAttrs[1])) shl 8);
end;

class operator TAttrPair.shr(const P: TAttrPair; Shift: Integer): TAttrPair;
begin
  { legacy code may use shr 8 on a pair to get the higher attribute }
  if Shift = 8 then
    Result := TAttrPair.Create(P.FAttrs[1])
  else
    Result := LongInt(Word(P) shr Shift);
end;

class operator TAttrPair.or(const P: TAttrPair; const A: TColorAttr): TAttrPair;
begin
  { legacy code may use |= on a pair to set the lower attribute, but only when it is the BIOS
    attribute 0; else it is an arithmetic operation }
  Result := P;
  if Result.FAttrs[0] = 0 then
    Result.FAttrs[0] := A
  else
    Result.FAttrs[0] := LongInt(Byte(Result.FAttrs[0]) or Byte(A));
end;

class operator TAttrPair.:=(const P: TAttrPair): TColorAttr;
begin
  Result := P.FAttrs[0];
end;

operator shl(const A: TColorAttr; Shift: Integer): TAttrPair;
begin
  { legacy code may use shl 8 on an attribute to make a pair }
  if Shift = 8 then
    Result := TAttrPair.Create(0, A)
  else
    Result := LongInt(Byte(A)) shl Shift;
end;

initialization
  InitLUTs;
end.
