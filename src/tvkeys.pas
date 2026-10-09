{ TvKeys: key codes, key modifiers and TKey (normalized key combinations).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/tkeys.h  (kb* constants, converted mechanically)
    source/tvision/tkey.cpp  (TKey constructor)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Key codes are BIOS-style: the scan code in the high byte and the character in
  the low byte (kbF1 = $3B00, kbEnter = $1C0D). The modifier masks are the DOS
  BIOS ones (the non-"flat" set of the original); kbEnhanced is an addition of
  tv3. TKey makes equal the combinations that can be written in several
  ways: kbCtrlA = TKey('A', kbCtrlShift); kbCtrlTab with kbShift = kbTab with
  kbShift or kbCtrlShift; kbAltDel with kbCtrlShift = kbCtrlDel with kbAltShift. }
unit TvKeys;

{$I tvdefs.inc}

interface

const
  { key codes: scan code in the high byte, character in the low byte }

  { no key }
  kbNoKey = $0000;

  { Ctrl + letter: the control character, no scan code }
  kbCtrlA = $0001;  kbCtrlB = $0002;  kbCtrlC = $0003;  kbCtrlD = $0004;
  kbCtrlE = $0005;  kbCtrlF = $0006;  kbCtrlG = $0007;  kbCtrlH = $0008;
  kbCtrlI = $0009;  kbCtrlJ = $000A;  kbCtrlK = $000B;  kbCtrlL = $000C;
  kbCtrlM = $000D;  kbCtrlN = $000E;  kbCtrlO = $000F;  kbCtrlP = $0010;
  kbCtrlQ = $0011;  kbCtrlR = $0012;  kbCtrlS = $0013;  kbCtrlT = $0014;
  kbCtrlU = $0015;  kbCtrlV = $0016;  kbCtrlW = $0017;  kbCtrlX = $0018;
  kbCtrlY = $0019;  kbCtrlZ = $001A;

  { Alt + letter: scan code only }
  kbAltA = $1E00;  kbAltB = $3000;  kbAltC = $2E00;  kbAltD = $2000;
  kbAltE = $1200;  kbAltF = $2100;  kbAltG = $2200;  kbAltH = $2300;
  kbAltI = $1700;  kbAltJ = $2400;  kbAltK = $2500;  kbAltL = $2600;
  kbAltM = $3200;  kbAltN = $3100;  kbAltO = $1800;  kbAltP = $1900;
  kbAltQ = $1000;  kbAltR = $1300;  kbAltS = $1F00;  kbAltT = $1400;
  kbAltU = $1600;  kbAltV = $2F00;  kbAltW = $1100;  kbAltX = $2D00;
  kbAltY = $1500;  kbAltZ = $2C00;

  { Alt + the keys of the top row, left half and right half }
  kbAltMinus = $8200;  kbAlt1 = $7800;  kbAlt2 = $7900;  kbAlt3 = $7A00;
  kbAlt4 = $7B00;  kbAlt5 = $7C00;
  kbAltEqual = $8300;  kbAlt6 = $7D00;  kbAlt7 = $7E00;  kbAlt8 = $7F00;
  kbAlt9 = $8000;  kbAlt0 = $8100;

  { function keys: plain, with Shift, with Ctrl, with Alt }
  kbF1       = $3B00;  kbShiftF1  = $5400;  kbCtrlF1   = $5E00;  kbAltF1    = $6800;
  kbF2       = $3C00;  kbShiftF2  = $5500;  kbCtrlF2   = $5F00;  kbAltF2    = $6900;
  kbF3       = $3D00;  kbShiftF3  = $5600;  kbCtrlF3   = $6000;  kbAltF3    = $6A00;
  kbF4       = $3E00;  kbShiftF4  = $5700;  kbCtrlF4   = $6100;  kbAltF4    = $6B00;
  kbF5       = $3F00;  kbShiftF5  = $5800;  kbCtrlF5   = $6200;  kbAltF5    = $6C00;
  kbF6       = $4000;  kbShiftF6  = $5900;  kbCtrlF6   = $6300;  kbAltF6    = $6D00;
  kbF7       = $4100;  kbShiftF7  = $5A00;  kbCtrlF7   = $6400;  kbAltF7    = $6E00;
  kbF8       = $4200;  kbShiftF8  = $5B00;  kbCtrlF8   = $6500;  kbAltF8    = $6F00;
  kbF9       = $4300;  kbShiftF9  = $5C00;  kbCtrlF9   = $6600;  kbAltF9    = $7000;
  kbF10      = $4400;  kbShiftF10 = $5D00;  kbCtrlF10  = $6700;  kbAltF10   = $7100;
  kbF11      = $8500;  kbShiftF11 = $8700;  kbCtrlF11  = $8900;  kbAltF11   = $8B00;
  kbF12      = $8600;  kbShiftF12 = $8800;  kbCtrlF12  = $8A00;  kbAltF12   = $8C00;

  { cursor movement }
  kbAltDown   = $A000;  kbAltEnd    = $9F00;  kbAltHome   = $9700;
  kbAltLeft   = $9B00;  kbAltPgDn   = $A100;  kbAltPgUp   = $9900;
  kbAltRight  = $9D00;  kbAltUp     = $9800;  kbCtrlDown  = $9100;
  kbCtrlEnd   = $7500;  kbCtrlHome  = $7700;  kbCtrlLeft  = $7300;
  kbCtrlPgDn  = $7600;  kbCtrlPgUp  = $8400;  kbCtrlRight = $7400;
  kbCtrlUp    = $8D00;  kbDown      = $5000;  kbEnd       = $4F00;
  kbHome      = $4700;  kbLeft      = $4B00;  kbPgDn      = $5100;
  kbPgUp      = $4900;  kbRight     = $4D00;  kbUp        = $4800;

  { editing keys }
  kbAltBack   = $0E00;  kbAltDel    = $A300;  kbAltEnter  = $A600;
  kbAltEsc    = $0100;  kbAltIns    = $A200;  kbAltSpace  = $0200;
  kbAltTab    = $A500;  kbBack      = $0E08;  kbCtrlBack  = $0E7F;
  kbCtrlDel   = $0600;  kbCtrlEnter = $1C0A;  kbCtrlIns   = $0400;
  kbCtrlTab   = $9400;  kbDel       = $5300;  kbEnter     = $1C0D;
  kbEsc       = $011B;  kbIns       = $5200;  kbShiftDel  = $0700;
  kbShiftIns  = $0500;  kbShiftTab  = $0F00;  kbTab       = $0F09;

  { other keys }
  kbCtrlPrtSc = $7200;  kbGrayMinus = $4A2D;  kbGrayPlus  = $4E2B;

  { key modifiers, as found in the ControlKeyState of keyboard and mouse
    events; left and right Ctrl (and Alt) share one bit }
  kbLeftShift  = $0001;  kbRightShift = $0002;
  kbLeftCtrl   = $0004;  kbRightCtrl  = $0004;
  kbLeftAlt    = $0008;  kbRightAlt   = $0008;
  kbShift      = kbLeftShift or kbRightShift;
  kbCtrlShift  = kbLeftCtrl or kbRightCtrl;
  kbAltShift   = kbLeftAlt or kbRightAlt;

  { lock states and flags }
  kbScrollState = $0010;
  kbNumState    = $0020;
  kbCapsState   = $0040;
  kbInsState    = $0080;
  kbPaste       = $0100;
  kbEnhanced    = $0200;    { an "enhanced" (extended) key }

type
  { a normalized key combination: Code is a key code, Mods only has the
    kbShift, kbCtrlShift and kbAltShift bits }
  TKey = record
    Code: Word;
    Mods: Word;
    constructor Create(KeyCode: Word; ShiftState: Word = 0);
    class operator :=(KeyCode: Word): TKey;
    class operator =(const A, B: TKey): Boolean; inline;
    class operator <>(const A, B: TKey): Boolean; inline;
  end;

{ Maps the Wordstar control keys (Ctrl+S, Ctrl+D, ...) to the arrow keys; other keys
  are returned unchanged (drivers2.cpp: ctrlToArrow). }
function CtrlToArrow(KeyCode: Word): Word;

implementation

type
  TLookupEntry = record
    Normal: Word;           { 0: keep the key code }
    Mods: Byte;
  end;

var
  CtrlLookup: array[0..$1A] of TLookupEntry;
  ExtLookup: array[0..$A6] of TLookupEntry;     { indexed by the scan code }
  CtrlBackEntry, CtrlEnterEntry: TLookupEntry;

procedure Ext(Scan: Byte; Normal: Word; Mods: Byte);
begin
  ExtLookup[Scan].Normal := Normal;
  ExtLookup[Scan].Mods := Mods;
end;

procedure InitLookups;
var
  I: Integer;
begin
  FillChar(CtrlLookup, SizeOf(CtrlLookup), 0);
  FillChar(ExtLookup, SizeOf(ExtLookup), 0);
  for I := 1 to $1A do
  begin
    CtrlLookup[I].Normal := Ord('A') + I - 1;
    CtrlLookup[I].Mods := kbCtrlShift;
  end;

  Ext($01, kbEsc, kbAltShift);   Ext($02, Ord(' '), kbAltShift);
  Ext($04, kbIns, kbCtrlShift);  Ext($05, kbIns, kbShift);
  Ext($06, kbDel, kbCtrlShift);  Ext($07, kbDel, kbShift);
  Ext($0E, kbBack, kbAltShift);  Ext($0F, kbTab, kbShift);
  for I := 0 to 9 do
    Ext($10 + I, Ord('QWERTYUIOP'[I + 1]), kbAltShift);
  for I := 0 to 8 do
    Ext($1E + I, Ord('ASDFGHJKL'[I + 1]), kbAltShift);
  for I := 0 to 6 do
    Ext($2C + I, Ord('ZXCVBNM'[I + 1]), kbAltShift);
  Ext($35, Ord('/'), kbCtrlShift);  Ext($37, Ord('*'), kbCtrlShift);
  for I := 0 to 9 do
  begin
    Ext($3B + I, kbF1 + I * $100, 0);
    Ext($54 + I, kbF1 + I * $100, kbShift);
    Ext($5E + I, kbF1 + I * $100, kbCtrlShift);
    Ext($68 + I, kbF1 + I * $100, kbAltShift);
  end;
  Ext($47, kbHome, 0);   Ext($48, kbUp, 0);    Ext($49, kbPgUp, 0);
  Ext($4A, Ord('-'), kbCtrlShift);
  Ext($4B, kbLeft, 0);   Ext($4D, kbRight, 0);
  Ext($4E, Ord('+'), kbCtrlShift);
  Ext($4F, kbEnd, 0);    Ext($50, kbDown, 0);  Ext($51, kbPgDn, 0);
  Ext($52, kbIns, 0);    Ext($53, kbDel, 0);
  Ext($72, kbCtrlPrtSc, kbCtrlShift);
  Ext($73, kbLeft, kbCtrlShift);   Ext($74, kbRight, kbCtrlShift);
  Ext($75, kbEnd, kbCtrlShift);    Ext($76, kbPgDn, kbCtrlShift);
  Ext($77, kbHome, kbCtrlShift);
  for I := 0 to 8 do
    Ext($78 + I, Ord('1') + I, kbAltShift);
  Ext($81, Ord('0'), kbAltShift);
  Ext($82, Ord('-'), kbAltShift);  Ext($83, Ord('='), kbAltShift);
  Ext($84, kbPgUp, kbCtrlShift);
  Ext($85, kbF11, 0);          Ext($86, kbF12, 0);
  Ext($87, kbF11, kbShift);    Ext($88, kbF12, kbShift);
  Ext($89, kbF11, kbCtrlShift); Ext($8A, kbF12, kbCtrlShift);
  Ext($8B, kbF11, kbAltShift);  Ext($8C, kbF12, kbAltShift);
  Ext($8D, kbUp, kbCtrlShift);    Ext($91, kbDown, kbCtrlShift);
  Ext($94, kbTab, kbCtrlShift);
  Ext($97, kbHome, kbAltShift);   Ext($98, kbUp, kbAltShift);
  Ext($99, kbPgUp, kbAltShift);   Ext($9B, kbLeft, kbAltShift);
  Ext($9D, kbRight, kbAltShift);  Ext($9F, kbEnd, kbAltShift);
  Ext($A0, kbDown, kbAltShift);   Ext($A1, kbPgDn, kbAltShift);
  Ext($A2, kbIns, kbAltShift);    Ext($A3, kbDel, kbAltShift);
  Ext($A5, kbTab, kbAltShift);    Ext($A6, kbEnter, kbAltShift);

  CtrlBackEntry.Normal := kbBack;   CtrlBackEntry.Mods := kbCtrlShift;
  CtrlEnterEntry.Normal := kbEnter; CtrlEnterEntry.Mods := kbCtrlShift;
end;

{ Ctrl+letter delivered as scan code of the letter and character 1..26 }
function IsRawCtrlKey(ScanCode, CharCode: Byte): Boolean;
const
  ScanKeys: array[0..34] of Char = 'QWERTYUIOP'#0#0#0#0'ASDFGHJKL'#0#0#0#0#0'ZXCVBNM';
begin
  Result := (ScanCode >= 16) and (ScanCode < 16 + 35)
    and (Ord(ScanKeys[ScanCode - 16]) = CharCode - 1 + Ord('A'));
end;

function IsPrintableCharacter(CharCode: Byte): Boolean;
begin
  Result := (CharCode >= Ord(' ')) and (CharCode <> $7F) and (CharCode <> $FF);
end;

function IsKeypadCharacter(ScanCode: Byte): Boolean;
begin
  Result := (ScanCode = $35) or (ScanCode = $37) or (ScanCode = $4A) or (ScanCode = $4E);
end;

constructor TKey.Create(KeyCode: Word; ShiftState: Word);
var
  ACode, AMods: Word;
  ScanCode, CharCode: Byte;
  Entry: ^TLookupEntry;
begin
  ACode := KeyCode;
  AMods := 0;
  if (ShiftState and kbShift) <> 0 then AMods := AMods or kbShift;
  if (ShiftState and kbCtrlShift) <> 0 then AMods := AMods or kbCtrlShift;
  if (ShiftState and kbAltShift) <> 0 then AMods := AMods or kbAltShift;
  ScanCode := KeyCode shr 8;
  CharCode := KeyCode and $FF;
  Entry := nil;
  if (KeyCode <= kbCtrlZ) or IsRawCtrlKey(ScanCode, CharCode) then
    Entry := @CtrlLookup[CharCode]
  else if CharCode = 0 then
  begin
    if ScanCode <= High(ExtLookup) then
      Entry := @ExtLookup[ScanCode];
  end
  else if IsPrintableCharacter(CharCode) then
  begin
    if (CharCode >= Ord('a')) and (CharCode <= Ord('z')) then
      ACode := CharCode - Ord('a') + Ord('A')
    else if not IsKeypadCharacter(ScanCode) then
      ACode := ACode and $FF;
  end
  else if KeyCode = kbCtrlBack then
    Entry := @CtrlBackEntry
  else if KeyCode = kbCtrlEnter then
    Entry := @CtrlEnterEntry;
  if Entry <> nil then
  begin
    AMods := AMods or Entry^.Mods;
    if Entry^.Normal <> 0 then
      ACode := Entry^.Normal;
  end;
  Code := ACode;
  if ACode <> kbNoKey then
    Mods := AMods
  else
    Mods := 0;
end;

class operator TKey.:=(KeyCode: Word): TKey;
begin
  Result := TKey.Create(KeyCode);
end;

class operator TKey.=(const A, B: TKey): Boolean;
begin
  Result := (A.Code = B.Code) and (A.Mods = B.Mods);
end;

class operator TKey.<>(const A, B: TKey): Boolean;
begin
  Result := not (A = B);
end;

function CtrlToArrow(KeyCode: Word): Word;
const
  Map: array[0..10, 0..1] of Word = (
    (kbCtrlA, kbHome), (kbCtrlC, kbPgDn), (kbCtrlD, kbRight),
    (kbCtrlE, kbUp), (kbCtrlF, kbEnd), (kbCtrlG, kbDel),
    (kbCtrlH, kbBack), (kbCtrlR, kbPgUp), (kbCtrlS, kbLeft),
    (kbCtrlV, kbIns), (kbCtrlX, kbDown));
var
  I: Integer;
begin
  Result := KeyCode;
  for I := Low(Map) to High(Map) do
    if Map[I, 0] = KeyCode and $FF then
      Exit(Map[I, 1]);
end;

initialization
  InitLookups;
end.
