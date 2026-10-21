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
  TKeyCodeLookupEntry = record
    NormalKeyCode: Word;
    ShiftState: Byte;
  end;

const
  CtrlKeyLookup: array[0..$1A] of TKeyCodeLookupEntry = (
    { $00 } (NormalKeyCode: 0;        ShiftState: 0),
    { $01 } (NormalKeyCode: Ord('A'); ShiftState: kbCtrlShift),
    { $02 } (NormalKeyCode: Ord('B'); ShiftState: kbCtrlShift),
    { $03 } (NormalKeyCode: Ord('C'); ShiftState: kbCtrlShift),
    { $04 } (NormalKeyCode: Ord('D'); ShiftState: kbCtrlShift),
    { $05 } (NormalKeyCode: Ord('E'); ShiftState: kbCtrlShift),
    { $06 } (NormalKeyCode: Ord('F'); ShiftState: kbCtrlShift),
    { $07 } (NormalKeyCode: Ord('G'); ShiftState: kbCtrlShift),
    { $08 } (NormalKeyCode: Ord('H'); ShiftState: kbCtrlShift),
    { $09 } (NormalKeyCode: Ord('I'); ShiftState: kbCtrlShift),
    { $0A } (NormalKeyCode: Ord('J'); ShiftState: kbCtrlShift),
    { $0B } (NormalKeyCode: Ord('K'); ShiftState: kbCtrlShift),
    { $0C } (NormalKeyCode: Ord('L'); ShiftState: kbCtrlShift),
    { $0D } (NormalKeyCode: Ord('M'); ShiftState: kbCtrlShift),
    { $0E } (NormalKeyCode: Ord('N'); ShiftState: kbCtrlShift),
    { $0F } (NormalKeyCode: Ord('O'); ShiftState: kbCtrlShift),
    { $10 } (NormalKeyCode: Ord('P'); ShiftState: kbCtrlShift),
    { $11 } (NormalKeyCode: Ord('Q'); ShiftState: kbCtrlShift),
    { $12 } (NormalKeyCode: Ord('R'); ShiftState: kbCtrlShift),
    { $13 } (NormalKeyCode: Ord('S'); ShiftState: kbCtrlShift),
    { $14 } (NormalKeyCode: Ord('T'); ShiftState: kbCtrlShift),
    { $15 } (NormalKeyCode: Ord('U'); ShiftState: kbCtrlShift),
    { $16 } (NormalKeyCode: Ord('V'); ShiftState: kbCtrlShift),
    { $17 } (NormalKeyCode: Ord('W'); ShiftState: kbCtrlShift),
    { $18 } (NormalKeyCode: Ord('X'); ShiftState: kbCtrlShift),
    { $19 } (NormalKeyCode: Ord('Y'); ShiftState: kbCtrlShift),
    { $1A } (NormalKeyCode: Ord('Z'); ShiftState: kbCtrlShift)
  );

  ExtKeyLookup: array[0..$A6] of TKeyCodeLookupEntry = (
    { $00 } (NormalKeyCode: 0;           ShiftState: 0),
    { $01 } (NormalKeyCode: kbEsc;       ShiftState: kbAltShift),
    { $02 } (NormalKeyCode: Ord(' ');    ShiftState: kbAltShift),
    { $03 } (NormalKeyCode: 0;           ShiftState: 0),
    { $04 } (NormalKeyCode: kbIns;       ShiftState: kbCtrlShift),
    { $05 } (NormalKeyCode: kbIns;       ShiftState: kbShift),
    { $06 } (NormalKeyCode: kbDel;       ShiftState: kbCtrlShift),
    { $07 } (NormalKeyCode: kbDel;       ShiftState: kbShift),
    { $08 } (NormalKeyCode: 0;           ShiftState: 0),
    { $09 } (NormalKeyCode: 0;           ShiftState: 0),
    { $0A } (NormalKeyCode: 0;           ShiftState: 0),
    { $0B } (NormalKeyCode: 0;           ShiftState: 0),
    { $0C } (NormalKeyCode: 0;           ShiftState: 0),
    { $0D } (NormalKeyCode: 0;           ShiftState: 0),
    { $0E } (NormalKeyCode: kbBack;      ShiftState: kbAltShift),
    { $0F } (NormalKeyCode: kbTab;       ShiftState: kbShift),
    { $10 } (NormalKeyCode: Ord('Q');    ShiftState: kbAltShift),
    { $11 } (NormalKeyCode: Ord('W');    ShiftState: kbAltShift),
    { $12 } (NormalKeyCode: Ord('E');    ShiftState: kbAltShift),
    { $13 } (NormalKeyCode: Ord('R');    ShiftState: kbAltShift),
    { $14 } (NormalKeyCode: Ord('T');    ShiftState: kbAltShift),
    { $15 } (NormalKeyCode: Ord('Y');    ShiftState: kbAltShift),
    { $16 } (NormalKeyCode: Ord('U');    ShiftState: kbAltShift),
    { $17 } (NormalKeyCode: Ord('I');    ShiftState: kbAltShift),
    { $18 } (NormalKeyCode: Ord('O');    ShiftState: kbAltShift),
    { $19 } (NormalKeyCode: Ord('P');    ShiftState: kbAltShift),
    { $1A } (NormalKeyCode: 0;           ShiftState: 0),
    { $1B } (NormalKeyCode: 0;           ShiftState: 0),
    { $1C } (NormalKeyCode: 0;           ShiftState: 0),
    { $1D } (NormalKeyCode: 0;           ShiftState: 0),
    { $1E } (NormalKeyCode: Ord('A');    ShiftState: kbAltShift),
    { $1F } (NormalKeyCode: Ord('S');    ShiftState: kbAltShift),
    { $20 } (NormalKeyCode: Ord('D');    ShiftState: kbAltShift),
    { $21 } (NormalKeyCode: Ord('F');    ShiftState: kbAltShift),
    { $22 } (NormalKeyCode: Ord('G');    ShiftState: kbAltShift),
    { $23 } (NormalKeyCode: Ord('H');    ShiftState: kbAltShift),
    { $24 } (NormalKeyCode: Ord('J');    ShiftState: kbAltShift),
    { $25 } (NormalKeyCode: Ord('K');    ShiftState: kbAltShift),
    { $26 } (NormalKeyCode: Ord('L');    ShiftState: kbAltShift),
    { $27 } (NormalKeyCode: 0;           ShiftState: 0),
    { $28 } (NormalKeyCode: 0;           ShiftState: 0),
    { $29 } (NormalKeyCode: 0;           ShiftState: 0),
    { $2A } (NormalKeyCode: 0;           ShiftState: 0),
    { $2B } (NormalKeyCode: 0;           ShiftState: 0),
    { $2C } (NormalKeyCode: Ord('Z');    ShiftState: kbAltShift),
    { $2D } (NormalKeyCode: Ord('X');    ShiftState: kbAltShift),
    { $2E } (NormalKeyCode: Ord('C');    ShiftState: kbAltShift),
    { $2F } (NormalKeyCode: Ord('V');    ShiftState: kbAltShift),
    { $30 } (NormalKeyCode: Ord('B');    ShiftState: kbAltShift),
    { $31 } (NormalKeyCode: Ord('N');    ShiftState: kbAltShift),
    { $32 } (NormalKeyCode: Ord('M');    ShiftState: kbAltShift),
    { $33 } (NormalKeyCode: 0;           ShiftState: 0),
    { $34 } (NormalKeyCode: 0;           ShiftState: 0),
    { $35 } (NormalKeyCode: Ord('/');    ShiftState: kbCtrlShift),
    { $36 } (NormalKeyCode: 0;           ShiftState: 0),
    { $37 } (NormalKeyCode: Ord('*');    ShiftState: kbCtrlShift),
    { $38 } (NormalKeyCode: 0;           ShiftState: 0),
    { $39 } (NormalKeyCode: 0;           ShiftState: 0),
    { $3A } (NormalKeyCode: 0;           ShiftState: 0),
    { $3B } (NormalKeyCode: kbF1;        ShiftState: 0),
    { $3C } (NormalKeyCode: kbF2;        ShiftState: 0),
    { $3D } (NormalKeyCode: kbF3;        ShiftState: 0),
    { $3E } (NormalKeyCode: kbF4;        ShiftState: 0),
    { $3F } (NormalKeyCode: kbF5;        ShiftState: 0),
    { $40 } (NormalKeyCode: kbF6;        ShiftState: 0),
    { $41 } (NormalKeyCode: kbF7;        ShiftState: 0),
    { $42 } (NormalKeyCode: kbF8;        ShiftState: 0),
    { $43 } (NormalKeyCode: kbF9;        ShiftState: 0),
    { $44 } (NormalKeyCode: kbF10;       ShiftState: 0),
    { $45 } (NormalKeyCode: 0;           ShiftState: 0),
    { $46 } (NormalKeyCode: 0;           ShiftState: 0),
    { $47 } (NormalKeyCode: kbHome;      ShiftState: 0),
    { $48 } (NormalKeyCode: kbUp;        ShiftState: 0),
    { $49 } (NormalKeyCode: kbPgUp;      ShiftState: 0),
    { $4A } (NormalKeyCode: Ord('-');    ShiftState: kbCtrlShift),
    { $4B } (NormalKeyCode: kbLeft;      ShiftState: 0),
    { $4C } (NormalKeyCode: 0;           ShiftState: 0),
    { $4D } (NormalKeyCode: kbRight;     ShiftState: 0),
    { $4E } (NormalKeyCode: Ord('+');    ShiftState: kbCtrlShift),
    { $4F } (NormalKeyCode: kbEnd;       ShiftState: 0),
    { $50 } (NormalKeyCode: kbDown;      ShiftState: 0),
    { $51 } (NormalKeyCode: kbPgDn;      ShiftState: 0),
    { $52 } (NormalKeyCode: kbIns;       ShiftState: 0),
    { $53 } (NormalKeyCode: kbDel;       ShiftState: 0),
    { $54 } (NormalKeyCode: kbF1;        ShiftState: kbShift),
    { $55 } (NormalKeyCode: kbF2;        ShiftState: kbShift),
    { $56 } (NormalKeyCode: kbF3;        ShiftState: kbShift),
    { $57 } (NormalKeyCode: kbF4;        ShiftState: kbShift),
    { $58 } (NormalKeyCode: kbF5;        ShiftState: kbShift),
    { $59 } (NormalKeyCode: kbF6;        ShiftState: kbShift),
    { $5A } (NormalKeyCode: kbF7;        ShiftState: kbShift),
    { $5B } (NormalKeyCode: kbF8;        ShiftState: kbShift),
    { $5C } (NormalKeyCode: kbF9;        ShiftState: kbShift),
    { $5D } (NormalKeyCode: kbF10;       ShiftState: kbShift),
    { $5E } (NormalKeyCode: kbF1;        ShiftState: kbCtrlShift),
    { $5F } (NormalKeyCode: kbF2;        ShiftState: kbCtrlShift),
    { $60 } (NormalKeyCode: kbF3;        ShiftState: kbCtrlShift),
    { $61 } (NormalKeyCode: kbF4;        ShiftState: kbCtrlShift),
    { $62 } (NormalKeyCode: kbF5;        ShiftState: kbCtrlShift),
    { $63 } (NormalKeyCode: kbF6;        ShiftState: kbCtrlShift),
    { $64 } (NormalKeyCode: kbF7;        ShiftState: kbCtrlShift),
    { $65 } (NormalKeyCode: kbF8;        ShiftState: kbCtrlShift),
    { $66 } (NormalKeyCode: kbF9;        ShiftState: kbCtrlShift),
    { $67 } (NormalKeyCode: kbF10;       ShiftState: kbCtrlShift),
    { $68 } (NormalKeyCode: kbF1;        ShiftState: kbAltShift),
    { $69 } (NormalKeyCode: kbF2;        ShiftState: kbAltShift),
    { $6A } (NormalKeyCode: kbF3;        ShiftState: kbAltShift),
    { $6B } (NormalKeyCode: kbF4;        ShiftState: kbAltShift),
    { $6C } (NormalKeyCode: kbF5;        ShiftState: kbAltShift),
    { $6D } (NormalKeyCode: kbF6;        ShiftState: kbAltShift),
    { $6E } (NormalKeyCode: kbF7;        ShiftState: kbAltShift),
    { $6F } (NormalKeyCode: kbF8;        ShiftState: kbAltShift),
    { $70 } (NormalKeyCode: kbF9;        ShiftState: kbAltShift),
    { $71 } (NormalKeyCode: kbF10;       ShiftState: kbAltShift),
    { $72 } (NormalKeyCode: kbCtrlPrtSc; ShiftState: kbCtrlShift),
    { $73 } (NormalKeyCode: kbLeft;      ShiftState: kbCtrlShift),
    { $74 } (NormalKeyCode: kbRight;     ShiftState: kbCtrlShift),
    { $75 } (NormalKeyCode: kbEnd;       ShiftState: kbCtrlShift),
    { $76 } (NormalKeyCode: kbPgDn;      ShiftState: kbCtrlShift),
    { $77 } (NormalKeyCode: kbHome;      ShiftState: kbCtrlShift),
    { $78 } (NormalKeyCode: Ord('1');    ShiftState: kbAltShift),
    { $79 } (NormalKeyCode: Ord('2');    ShiftState: kbAltShift),
    { $7A } (NormalKeyCode: Ord('3');    ShiftState: kbAltShift),
    { $7B } (NormalKeyCode: Ord('4');    ShiftState: kbAltShift),
    { $7C } (NormalKeyCode: Ord('5');    ShiftState: kbAltShift),
    { $7D } (NormalKeyCode: Ord('6');    ShiftState: kbAltShift),
    { $7E } (NormalKeyCode: Ord('7');    ShiftState: kbAltShift),
    { $7F } (NormalKeyCode: Ord('8');    ShiftState: kbAltShift),
    { $80 } (NormalKeyCode: Ord('9');    ShiftState: kbAltShift),
    { $81 } (NormalKeyCode: Ord('0');    ShiftState: kbAltShift),
    { $82 } (NormalKeyCode: Ord('-');    ShiftState: kbAltShift),
    { $83 } (NormalKeyCode: Ord('=');    ShiftState: kbAltShift),
    { $84 } (NormalKeyCode: kbPgUp;      ShiftState: kbCtrlShift),
    { $85 } (NormalKeyCode: kbF11;       ShiftState: 0),
    { $86 } (NormalKeyCode: kbF12;       ShiftState: 0),
    { $87 } (NormalKeyCode: kbF11;       ShiftState: kbShift),
    { $88 } (NormalKeyCode: kbF12;       ShiftState: kbShift),
    { $89 } (NormalKeyCode: kbF11;       ShiftState: kbCtrlShift),
    { $8A } (NormalKeyCode: kbF12;       ShiftState: kbCtrlShift),
    { $8B } (NormalKeyCode: kbF11;       ShiftState: kbAltShift),
    { $8C } (NormalKeyCode: kbF12;       ShiftState: kbAltShift),
    { $8D } (NormalKeyCode: kbUp;        ShiftState: kbCtrlShift),
    { $8E } (NormalKeyCode: 0;           ShiftState: 0),
    { $8F } (NormalKeyCode: 0;           ShiftState: 0),
    { $90 } (NormalKeyCode: 0;           ShiftState: 0),
    { $91 } (NormalKeyCode: kbDown;      ShiftState: kbCtrlShift),
    { $92 } (NormalKeyCode: 0;           ShiftState: 0),
    { $93 } (NormalKeyCode: 0;           ShiftState: 0),
    { $94 } (NormalKeyCode: kbTab;       ShiftState: kbCtrlShift),
    { $95 } (NormalKeyCode: 0;           ShiftState: 0),
    { $96 } (NormalKeyCode: 0;           ShiftState: 0),
    { $97 } (NormalKeyCode: kbHome;      ShiftState: kbAltShift),
    { $98 } (NormalKeyCode: kbUp;        ShiftState: kbAltShift),
    { $99 } (NormalKeyCode: kbPgUp;      ShiftState: kbAltShift),
    { $9A } (NormalKeyCode: 0;           ShiftState: 0),
    { $9B } (NormalKeyCode: kbLeft;      ShiftState: kbAltShift),
    { $9C } (NormalKeyCode: 0;           ShiftState: 0),
    { $9D } (NormalKeyCode: kbRight;     ShiftState: kbAltShift),
    { $9E } (NormalKeyCode: 0;           ShiftState: 0),
    { $9F } (NormalKeyCode: kbEnd;       ShiftState: kbAltShift),
    { $A0 } (NormalKeyCode: kbDown;      ShiftState: kbAltShift),
    { $A1 } (NormalKeyCode: kbPgDn;      ShiftState: kbAltShift),
    { $A2 } (NormalKeyCode: kbIns;       ShiftState: kbAltShift),
    { $A3 } (NormalKeyCode: kbDel;       ShiftState: kbAltShift),
    { $A4 } (NormalKeyCode: 0;           ShiftState: 0),
    { $A5 } (NormalKeyCode: kbTab;       ShiftState: kbAltShift),
    { $A6 } (NormalKeyCode: kbEnter;     ShiftState: kbAltShift)
  );

  CtrlBackEntry: TKeyCodeLookupEntry = (NormalKeyCode: kbBack; ShiftState: kbCtrlShift);
  CtrlEnterEntry: TKeyCodeLookupEntry = (NormalKeyCode: kbEnter; ShiftState: kbCtrlShift);

function IsRawCtrlKey(ScanCode, CharCode: Byte): Boolean;
const
  ScanKeys: string[35] = 'QWERTYUIOP'#0#0#0#0'ASDFGHJKL'#0#0#0#0#0'ZXCVBNM';
begin
  Result := (16 <= ScanCode) and (ScanCode < 16 + 35)
    and (Ord(ScanKeys[ScanCode - 16 + 1]) = Integer(CharCode) - 1 + Ord('A'));
end;

function IsPrintableCharacter(CharCode: Byte): Boolean;
begin
  Result := (Ord(' ') <= CharCode) and (CharCode <> $7F) and (CharCode <> $FF);
end;

function IsKeypadCharacter(ScanCode: Byte): Boolean;
begin
  Result := (ScanCode = $35) or (ScanCode = $37)
    or (ScanCode = $4A) or (ScanCode = $4E);
end;

constructor TKey.Create(KeyCode: Word; ShiftState: Word);
var
  NewCode, NewMods: Word;
  ScanCode, CharCode: Byte;
  Entry: TKeyCodeLookupEntry;
  HasEntry: Boolean;
begin
  NewCode := KeyCode;
  NewMods := 0;
  if (ShiftState and kbShift) <> 0 then
    NewMods := NewMods or kbShift;
  if (ShiftState and kbCtrlShift) <> 0 then
    NewMods := NewMods or kbCtrlShift;
  if (ShiftState and kbAltShift) <> 0 then
    NewMods := NewMods or kbAltShift;
  ScanCode := Byte(KeyCode shr 8);
  CharCode := Byte(KeyCode and $FF);

  HasEntry := False;
  Entry.NormalKeyCode := 0;
  Entry.ShiftState := 0;
  if (KeyCode <= kbCtrlZ) or IsRawCtrlKey(ScanCode, CharCode) then
  begin
    Entry := CtrlKeyLookup[CharCode];
    HasEntry := True;
  end
  else if CharCode = 0 then
  begin
    if ScanCode <= High(ExtKeyLookup) then
    begin
      Entry := ExtKeyLookup[ScanCode];
      HasEntry := True;
    end;
  end
  else if IsPrintableCharacter(CharCode) then
  begin
    if (Ord('a') <= CharCode) and (CharCode <= Ord('z')) then
      NewCode := CharCode - Ord('a') + Ord('A')
    else if not IsKeypadCharacter(ScanCode) then
      NewCode := NewCode and $FF;
  end
  else
    case KeyCode of
      kbCtrlBack:
        begin
          Entry := CtrlBackEntry;
          HasEntry := True;
        end;
      kbCtrlEnter:
        begin
          Entry := CtrlEnterEntry;
          HasEntry := True;
        end;
    end;

  if HasEntry then
  begin
    NewMods := NewMods or Entry.ShiftState;
    if Entry.NormalKeyCode <> 0 then
      NewCode := Entry.NormalKeyCode;
  end;

  Code := NewCode;
  if NewCode <> kbNoKey then
    Mods := NewMods
  else
    Mods := 0;
end;

class operator TKey.:=(KeyCode: Word): TKey;
begin
  Result := TKey.Create(KeyCode, 0);
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
  CtrlCodes: array[0..10] of Byte = (
    kbCtrlS, kbCtrlD, kbCtrlE, kbCtrlX, kbCtrlA,
    kbCtrlF, kbCtrlG, kbCtrlV, kbCtrlR, kbCtrlC, kbCtrlH
  );
  ArrowCodes: array[0..10] of Word = (
    kbLeft, kbRight, kbUp, kbDown, kbHome,
    kbEnd, kbDel, kbIns, kbPgUp, kbPgDn, kbBack
  );
var
  I: Integer;
begin
  for I := Low(CtrlCodes) to High(CtrlCodes) do
    if (KeyCode and $00FF) = CtrlCodes[I] then
      Exit(ArrowCodes[I]);
  Result := KeyCode;
end;

end.
