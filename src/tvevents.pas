{ TvEvents: the event record and the event constants.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/system.h (event codes and masks, mouse button/wheel/flag
                              constants, MouseEventType, KeyDownEvent,
                              MessageEvent, TEvent),
    source/platform/win32con.cpp (virtualKeyCodeToTVisionKeyCode, getWin32Key,
                              getWin32KeyText: the win32 fields, in reverse),
    source/platform/termio.cpp (moddedKeyCodes, normalizeKey: in reverse)
  The event queue, mouse and screen classes of system.h are platform code and
  are replaced by the backends (DESIGN.md). Borland disclaimer and MIT
  notice: COPYRIGHT.magiblot.

  TEvent is one flat record instead of nested
  structs: What, ControlKeyState, then the part of the event kind:
    mouse    Where, EventFlags, Buttons, Wheel
    key down KeyCode (= CharCode + ScanCode shl 8), Text/TextLength (UTF-8); and what the win32 input mode of terminals
             (KEY_EVENT_RECORD of Windows) tells and the old key code does not: VirtualKey, RepeatCount, Win32State
    key up   (evKeyUp, only if a program asked: TvSys.KeyUpEvents) the same fields
    message  Command and Info* (several views of the same bytes)
  ControlKeyState is shared by mouse and keyboard events. }
unit TvEvents;

{$I tvdefs.inc}

interface

uses
  TvUtf8,     { MaxCharSize }
  TvGeom,
  TvKeys;

const
  { What: the kind of an event, one bit each }
  evMouseDown  = $0001;
  evMouseUp    = $0002;
  evMouseMove  = $0004;
  evMouseAuto  = $0008;
  evKeyDown    = $0010;
  evMouseWheel = $0020;
  { a key was released (Windows, and terminals in win32 input mode). It is
    outside evKeyboard so that views that do not know it never see it; it is
    routed like a key press to a view that has evKeyUp in its EventMask }
  evKeyUp      = $0040;
  evCommand    = $0100;
  evBroadcast  = $0200;

  { groups of event kinds }
  evNothing  = $0000;
  evKeyboard = evKeyDown;
  evMouse    = evMouseDown or evMouseUp or evMouseMove or evMouseAuto or evMouseWheel;
  evMessage  = $FF00;

  { mouse button state masks }
  mbLeftButton   = $01;
  mbRightButton  = $02;
  mbMiddleButton = $04;

  { mouse wheel state masks }
  mwUp    = $01;
  mwDown  = $02;
  mwLeft  = $04;
  mwRight = $08;

  { mouse event flags }
  meMouseMoved  = $01;
  meDoubleClick = $02;
  meTripleClick = $04;

  { Win32State: dwControlKeyState of KEY_EVENT_RECORD (left and right Alt and Ctrl are told apart, unlike ControlKeyState) }
  wkRightAlt = $0001;
  wkLeftAlt = $0002;
  wkRightCtrl = $0004;
  wkLeftCtrl = $0008;
  wkShift = $0010;
  wkNumLock = $0020;
  wkScrollLock = $0040;
  wkCapsLock = $0080;
  wkEnhanced = $0100;

  { KeyFlags of a key event }
  kfRepeat = $01;

type
  MouseEventType = record
    ControlKeyState: Word;     { first in the key and in the mouse events: the same field for both }
    Where: TPoint;
    EventFlags: Word;
    Buttons: Byte;
    Wheel: Byte;
  end;

  CharScanType = record
    CharCode: Byte;
    ScanCode: Byte;
  end;

  KeyDownEvent = record
    ControlKeyState: Word;
    Text: array[0..MaxCharSize - 1] of Char;    { UTF-8, no terminating NUL }
    TextLength: Byte;
    VirtualKey: Word;      { Windows VK_* code; 0 if unknown (see EventVirtualKey) }
    RepeatCount: Word;     { 0 means 1 }
    Win32State: Word;      { dwControlKeyState from the terminal; 0 if unknown (see EventWin32State) }
    KeyFlags: Byte;        { kfRepeat for an auto repeat, when the terminal reports it }
    KeyCodePadding: array[0..2] of Byte;   { KeyCode must not overlap the 64-bit InfoPtr }
    case Byte of
      0: (KeyCode: Word);
      1: (CharScan: CharScanType);
  end;

  MessageEvent = record
    CommandPadding: Word;  { the place of ControlKeyState: a command made of a key keeps its modifiers }
    Command: Word;
    { Keep the message payload after the key fields.  On 64-bit
      targets a Pointer is wider than the old KeyCode slot; putting
      InfoPtr at the old offset made it overlap KeyCode. }
    InfoPadding: array[0..15] of Byte;
    case Byte of
      0: (InfoByte: Byte);
      1: (InfoChar: Char);
      2: (InfoWord: Word);
      3: (InfoInt: SmallInt);
      4: (InfoLong: LongInt);
      5: (InfoPtr: Pointer);
  end;

  TEvent = record
    What: Word;
    case Byte of
      0: (Mouse: MouseEventType);
      1: (KeyDown: KeyDownEvent);
      2: (Message: MessageEvent);
  end;

type
  PEvent = ^TEvent;

{ All zero: What = evNothing. }
procedure ClearEvent(out Event: TEvent);
{ The text of a key down event. }
function EventText(const Event: TEvent): ShortString;
{ The normalized key combination of a key down event. }
function EventKey(const Event: TEvent): TKey;
{ A key down event for a key code; the text is the character for printable ASCII. }
procedure MakeKeyEvent(out Event: TEvent; KeyCode, ControlKeyState: Word);

{ The fields of the win32 input mode for a key event (ESC [ Vk ; Sc ; Uc ; Kd ; Cs ; Rc _): what the event brings, and where it brings nothing, what can be
  worked out from the key code and the modifiers (for a US keyboard layout). Vk is the virtual key (VK_*), Sc the scan code of the key. }
function EventVirtualKey(const Event: TEvent): Word;
function EventScanCode(const Event: TEvent): Word;
{ dwControlKeyState: Shift, Ctrl, Alt (left ones if the event does not tell), the lock keys, wkEnhanced for the keys of the cursor block }
function EventWin32State(const Event: TEvent): Word;
{ The text of the key as UTF-16 units (1 or 2: above U+FFFF it is a pair); for a key without text, the control character of Enter, Tab, Esc, Backspace and Ctrl+letters,
  else 0 units. }
function EventUtf16(const Event: TEvent; out Hi, Lo: Word): Integer;

implementation

type
  TVkEntry = record
    Vk: Byte;
    Code: Word;
  end;

  TModEntry = record
    Base: Word;
    Codes: array[0..2] of Word;
  end;

const
  VkTableSize = 79;
  VkTable: array[0..VkTableSize - 1] of TVkEntry = (
    (Vk: $08; Code: kbBack),         (Vk: $09; Code: kbTab),
    (Vk: $0D; Code: kbEnter),        (Vk: $1B; Code: kbEsc),
    (Vk: $30; Code: $0B00 or $30),   (Vk: $31; Code: $0200 or $31),
    (Vk: $32; Code: $0300 or $32),   (Vk: $33; Code: $0400 or $33),
    (Vk: $34; Code: $0500 or $34),   (Vk: $35; Code: $0600 or $35),
    (Vk: $36; Code: $0700 or $36),   (Vk: $37; Code: $0800 or $37),
    (Vk: $38; Code: $0900 or $38),   (Vk: $39; Code: $0A00 or $39),
    (Vk: $20; Code: $3900 or $20),   (Vk: $41; Code: $1E00 or $41),
    (Vk: $42; Code: $3000 or $42),   (Vk: $43; Code: $2E00 or $43),
    (Vk: $44; Code: $2000 or $44),   (Vk: $45; Code: $1200 or $45),
    (Vk: $46; Code: $2100 or $46),   (Vk: $47; Code: $2200 or $47),
    (Vk: $48; Code: $2300 or $48),   (Vk: $49; Code: $1700 or $49),
    (Vk: $4A; Code: $2400 or $4A),   (Vk: $4B; Code: $2500 or $4B),
    (Vk: $4C; Code: $2600 or $4C),   (Vk: $4D; Code: $3200 or $4D),
    (Vk: $4E; Code: $3100 or $4E),   (Vk: $4F; Code: $1800 or $4F),
    (Vk: $50; Code: $1900 or $50),   (Vk: $51; Code: $1000 or $51),
    (Vk: $52; Code: $1300 or $52),   (Vk: $53; Code: $1F00 or $53),
    (Vk: $54; Code: $1400 or $54),   (Vk: $55; Code: $1600 or $55),
    (Vk: $56; Code: $2F00 or $56),   (Vk: $57; Code: $1100 or $57),
    (Vk: $58; Code: $2D00 or $58),   (Vk: $59; Code: $1500 or $59),
    (Vk: $5A; Code: $2C00 or $5A),   (Vk: $21; Code: kbPgUp),
    (Vk: $22; Code: kbPgDn),         (Vk: $23; Code: kbEnd),
    (Vk: $24; Code: kbHome),         (Vk: $25; Code: kbLeft),
    (Vk: $26; Code: kbUp),           (Vk: $27; Code: kbRight),
    (Vk: $28; Code: kbDown),         (Vk: $2D; Code: kbIns),
    (Vk: $2E; Code: kbDel),          (Vk: $60; Code: $5200 or $30),
    (Vk: $61; Code: $4F00 or $31),   (Vk: $62; Code: $5000 or $32),
    (Vk: $63; Code: $5100 or $33),   (Vk: $64; Code: $4B00 or $34),
    (Vk: $65; Code: $4C00 or $35),   (Vk: $66; Code: $4D00 or $36),
    (Vk: $67; Code: $4700 or $37),   (Vk: $68; Code: $4800 or $38),
    (Vk: $69; Code: $4900 or $39),   (Vk: $6A; Code: $3700 or $2A),
    (Vk: $6B; Code: $4E00 or $2B),   (Vk: $6C; Code: $7E00 or $2C),
    (Vk: $6D; Code: $4A00 or $2D),   (Vk: $6E; Code: $5300 or $2E),
    (Vk: $6F; Code: $3500 or $2F),   (Vk: $70; Code: kbF1),
    (Vk: $71; Code: kbF2),           (Vk: $72; Code: kbF3),
    (Vk: $73; Code: kbF4),           (Vk: $74; Code: kbF5),
    (Vk: $75; Code: kbF6),           (Vk: $76; Code: kbF7),
    (Vk: $77; Code: kbF8),           (Vk: $78; Code: kbF9),
    (Vk: $79; Code: kbF10),          (Vk: $7A; Code: kbF11),
    (Vk: $7B; Code: kbF12)
  );

  ModTableSize = 65;
  ModTable: array[0..ModTableSize - 1] of TModEntry = (
    (Base: Ord('A'); Codes: (0, kbCtrlA, kbAltA)), (Base: Ord('B'); Codes: (0, kbCtrlB, kbAltB)),
    (Base: Ord('C'); Codes: (0, kbCtrlC, kbAltC)), (Base: Ord('D'); Codes: (0, kbCtrlD, kbAltD)),
    (Base: Ord('E'); Codes: (0, kbCtrlE, kbAltE)), (Base: Ord('F'); Codes: (0, kbCtrlF, kbAltF)),
    (Base: Ord('G'); Codes: (0, kbCtrlG, kbAltG)), (Base: Ord('H'); Codes: (0, kbCtrlH, kbAltH)),
    (Base: Ord('I'); Codes: (0, kbCtrlI, kbAltI)), (Base: Ord('J'); Codes: (0, kbCtrlJ, kbAltJ)),
    (Base: Ord('K'); Codes: (0, kbCtrlK, kbAltK)), (Base: Ord('L'); Codes: (0, kbCtrlL, kbAltL)),
    (Base: Ord('M'); Codes: (0, kbCtrlM, kbAltM)), (Base: Ord('N'); Codes: (0, kbCtrlN, kbAltN)),
    (Base: Ord('O'); Codes: (0, kbCtrlO, kbAltO)), (Base: Ord('P'); Codes: (0, kbCtrlP, kbAltP)),
    (Base: Ord('Q'); Codes: (0, kbCtrlQ, kbAltQ)), (Base: Ord('R'); Codes: (0, kbCtrlR, kbAltR)),
    (Base: Ord('S'); Codes: (0, kbCtrlS, kbAltS)), (Base: Ord('T'); Codes: (0, kbCtrlT, kbAltT)),
    (Base: Ord('U'); Codes: (0, kbCtrlU, kbAltU)), (Base: Ord('V'); Codes: (0, kbCtrlV, kbAltV)),
    (Base: Ord('W'); Codes: (0, kbCtrlW, kbAltW)), (Base: Ord('X'); Codes: (0, kbCtrlX, kbAltX)),
    (Base: Ord('Y'); Codes: (0, kbCtrlY, kbAltY)), (Base: Ord('Z'); Codes: (0, kbCtrlZ, kbAltZ)),
    (Base: Ord('1'); Codes: (0, 0, kbAlt1)),       (Base: Ord('2'); Codes: (0, 0, kbAlt2)),
    (Base: Ord('3'); Codes: (0, 0, kbAlt3)),       (Base: Ord('4'); Codes: (0, 0, kbAlt4)),
    (Base: Ord('5'); Codes: (0, 0, kbAlt5)),       (Base: Ord('6'); Codes: (0, 0, kbAlt6)),
    (Base: Ord('7'); Codes: (0, 0, kbAlt7)),       (Base: Ord('8'); Codes: (0, 0, kbAlt8)),
    (Base: Ord('9'); Codes: (0, 0, kbAlt9)),       (Base: Ord('0'); Codes: (0, 0, kbAlt0)),
    (Base: Ord(' '); Codes: (0, 0, kbAltSpace)),   (Base: Ord('-'); Codes: (0, 0, kbAltMinus)),
    (Base: Ord('='); Codes: (0, 0, kbAltEqual)),
    (Base: kbF1; Codes: (kbShiftF1, kbCtrlF1, kbAltF1)),     (Base: kbF2; Codes: (kbShiftF2, kbCtrlF2, kbAltF2)),
    (Base: kbF3; Codes: (kbShiftF3, kbCtrlF3, kbAltF3)),     (Base: kbF4; Codes: (kbShiftF4, kbCtrlF4, kbAltF4)),
    (Base: kbF5; Codes: (kbShiftF5, kbCtrlF5, kbAltF5)),     (Base: kbF6; Codes: (kbShiftF6, kbCtrlF6, kbAltF6)),
    (Base: kbF7; Codes: (kbShiftF7, kbCtrlF7, kbAltF7)),     (Base: kbF8; Codes: (kbShiftF8, kbCtrlF8, kbAltF8)),
    (Base: kbF9; Codes: (kbShiftF9, kbCtrlF9, kbAltF9)),     (Base: kbF10; Codes: (kbShiftF10, kbCtrlF10, kbAltF10)),
    (Base: kbF11; Codes: (kbShiftF11, kbCtrlF11, kbAltF11)), (Base: kbF12; Codes: (kbShiftF12, kbCtrlF12, kbAltF12)),
    (Base: kbEsc; Codes: (0, 0, kbAltEsc)),                  (Base: kbBack; Codes: (0, kbCtrlBack, kbAltBack)),
    (Base: kbTab; Codes: (kbShiftTab, kbCtrlTab, kbAltTab)), (Base: kbEnter; Codes: (0, kbCtrlEnter, kbAltEnter)),
    (Base: kbHome; Codes: (0, kbCtrlHome, kbAltHome)),       (Base: kbUp; Codes: (0, kbCtrlUp, kbAltUp)),
    (Base: kbPgUp; Codes: (0, kbCtrlPgUp, kbAltPgUp)),       (Base: kbLeft; Codes: (0, kbCtrlLeft, kbAltLeft)),
    (Base: kbRight; Codes: (0, kbCtrlRight, kbAltRight)),    (Base: kbEnd; Codes: (0, kbCtrlEnd, kbAltEnd)),
    (Base: kbDown; Codes: (0, kbCtrlDown, kbAltDown)),       (Base: kbPgDn; Codes: (0, kbCtrlPgDn, kbAltPgDn)),
    (Base: kbIns; Codes: (kbShiftIns, kbCtrlIns, kbAltIns)), (Base: kbDel; Codes: (kbShiftDel, kbCtrlDel, kbAltDel))
  );

  ModBits: array[0..2] of Word = (kbShift, kbCtrlShift, kbAltShift);

{ The key without the modifier that its key code carries (kbCtrlLeft: kbLeft
  and kbCtrlShift); other key codes are their own base. }
procedure UnmodKey(KeyCode: Word; out Base, Mods: Word);
var
  I, J: Integer;
begin
  Base := KeyCode;
  Mods := 0;
  if KeyCode = 0 then
    Exit;
  for I := 0 to ModTableSize - 1 do
    for J := 0 to 2 do
      if ModTable[I].Codes[J] = KeyCode then
      begin
        Base := ModTable[I].Base;
        Mods := ModBits[J];
        Exit;
      end;
end;

function VkOfBase(Base: Word): Word;
var
  I: Integer;
  C: Byte;
begin
  Result := 0;
  if Base = 0 then
    Exit;
  for I := 0 to VkTableSize - 1 do
    if VkTable[I].Code = Base then
      Exit(VkTable[I].Vk);
  C := Lo(Base);
  if (C >= Ord('a')) and (C <= Ord('z')) then
    Dec(C, $20);
  if ((C >= Ord('A')) and (C <= Ord('Z'))) or ((C >= Ord('0')) and (C <= Ord('9'))) or (C = Ord(' ')) then
    Result := C;
end;

function CodeOfVk(Vk: Word): Word;
var
  I: Integer;
begin
  Result := 0;
  if Vk = 0 then
    Exit;
  for I := 0 to VkTableSize - 1 do
    if VkTable[I].Vk = Vk then
      Exit(VkTable[I].Code);
end;

function IsCursorBlockKey(Base: Word): Boolean;
begin
  Result := (Base = kbIns) or (Base = kbDel) or (Base = kbHome) or (Base = kbEnd) or
            (Base = kbPgUp) or (Base = kbPgDn) or (Base = kbLeft) or (Base = kbUp) or
            (Base = kbRight) or (Base = kbDown);
end;

procedure ClearEvent(out Event: TEvent);
begin
  FillChar(Event, SizeOf(Event), 0);
end;

function EventText(const Event: TEvent): ShortString;
var
  N, I: Integer;
begin
  N := Event.KeyDown.TextLength;
  if N > MaxCharSize then
    N := MaxCharSize;
  SetLength(Result, N);
  for I := 0 to N - 1 do
    Result[I + 1] := Event.KeyDown.Text[I];
end;

function EventKey(const Event: TEvent): TKey;
begin
  Result := TKey.Create(Event.KeyDown.KeyCode, Event.KeyDown.ControlKeyState);
end;

procedure MakeKeyEvent(out Event: TEvent; KeyCode, ControlKeyState: Word);
var
  C: Byte;
begin
  ClearEvent(Event);
  Event.What := evKeyDown;
  Event.KeyDown.KeyCode := KeyCode;
  Event.KeyDown.ControlKeyState := ControlKeyState;
  C := Lo(KeyCode);
  if (C >= Ord(' ')) and (C < $7F) then
  begin
    Event.KeyDown.Text[0] := Chr(C);
    Event.KeyDown.TextLength := 1;
  end;
end;

function EventVirtualKey(const Event: TEvent): Word;
var
  Base, Mods: Word;
begin
  Result := Event.KeyDown.VirtualKey;
  if Result <> 0 then
    Exit;
  UnmodKey(Event.KeyDown.KeyCode, Base, Mods);
  Result := VkOfBase(Base);
end;

function EventScanCode(const Event: TEvent): Word;
var
  Base, Mods: Word;
begin
  UnmodKey(Event.KeyDown.KeyCode, Base, Mods);
  Result := Hi(Base);
  if Result = 0 then
    Result := Hi(CodeOfVk(EventVirtualKey(Event)));
end;

function EventWin32State(const Event: TEvent): Word;
var
  Base, Mods, M: Word;
begin
  Result := Event.KeyDown.Win32State;
  if Result <> 0 then
    Exit;
  UnmodKey(Event.KeyDown.KeyCode, Base, Mods);
  M := Event.KeyDown.ControlKeyState or Mods;
  if (M and kbShift) <> 0 then
    Result := Result or wkShift;
  if (M and kbCtrlShift) <> 0 then
    Result := Result or wkLeftCtrl;
  if (M and kbAltShift) <> 0 then
    Result := Result or wkLeftAlt;
  if (M and kbScrollState) <> 0 then
    Result := Result or wkScrollLock;
  if (M and kbNumState) <> 0 then
    Result := Result or wkNumLock;
  if (M and kbCapsState) <> 0 then
    Result := Result or wkCapsLock;
  if ((M and kbEnhanced) <> 0) or IsCursorBlockKey(Base) then
    Result := Result or wkEnhanced;
end;

function EventUtf16(const Event: TEvent; out Hi, Lo: Word): Integer;
var
  Buf: array[0..MaxCharSize - 1] of Byte;
  N, I, Used: Integer;
  CodePoint: LongWord;
  Base, Mods, KeyCode: Word;
  C, L: Byte;
begin
  Hi := 0;
  Lo := 0;
  Result := 0;

  N := Event.KeyDown.TextLength;
  if N > MaxCharSize then
    N := MaxCharSize;
  for I := 0 to N - 1 do
    Buf[I] := Ord(Event.KeyDown.Text[I]);
  if (N > 0) and Utf8Decode(@Buf[0], N, CodePoint, Used) then
  begin
    if CodePoint < $10000 then
    begin
      Lo := Word(CodePoint);
      Result := 1;
    end
    else
    begin
      Dec(CodePoint, $10000);
      Hi := Word($D800 + (CodePoint shr 10));
      Lo := Word($DC00 + (CodePoint and $3FF));
      Result := 2;
    end;
    Exit;
  end;

  KeyCode := Event.KeyDown.KeyCode;
  C := KeyCode and $FF;
  UnmodKey(KeyCode, Base, Mods);
  if ((KeyCode shr 8) = 0) and (C >= $01) and (C <= $1A) then
  begin
    Lo := C;
    Result := 1;
  end
  else if (Base = kbEnter) or (Base = kbTab) or (Base = kbEsc) or (Base = kbBack) then
  begin
    if (C <> 0) and ((C < $20) or (C = $7F)) then
      Lo := C
    else
      Lo := Base and $FF;
    Result := 1;
  end
  else if ((Event.KeyDown.ControlKeyState or Mods) and kbCtrlShift) <> 0 then
  begin
    L := Base and $FF;
    if (L >= Ord('a')) and (L <= Ord('z')) then
      Dec(L, $20);
    if (L >= Ord('A')) and (L <= Ord('Z')) then
    begin
      Lo := L - $40;
      Result := 1;
    end;
  end;
end;

end.
