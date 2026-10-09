{ TvEvents: the event record and the event constants.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/system.h (event codes and masks, mouse button/wheel/flag
                              constants, MouseEventType, KeyDownEvent,
                              MessageEvent, TEvent)
  The event queue, mouse and screen classes of system.h are platform code and
  are replaced by the backends (tv/DESIGN.md). Borland disclaimer and MIT
  notice: COPYRIGHT.magiblot.

  TEvent is one flat record (as in the Pascal Turbo Vision) instead of nested
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

procedure ClearEvent(out Event: TEvent);
begin
  FillChar(Event, SizeOf(Event), 0);
end;

function EventText(const Event: TEvent): ShortString;
var
  N: Integer;
begin
  N := Event.KeyDown.TextLength;
  if N > MaxCharSize then
    N := MaxCharSize;
  SetLength(Result, N);
  if N > 0 then
    Move(Event.KeyDown.Text[0], Result[1], N);
end;

function EventKey(const Event: TEvent): TKey;
begin
  Result := KeyMake(Event.KeyDown.KeyCode, Event.KeyDown.ControlKeyState);
end;

procedure MakeKeyEvent(out Event: TEvent; KeyCode, ControlKeyState: Word);
begin
  ClearEvent(Event);
  Event.What := evKeyDown;
  Event.KeyDown.KeyCode := KeyCode;
  Event.KeyDown.ControlKeyState := ControlKeyState;
  if (Event.KeyDown.CharScan.CharCode >= $20) and (Event.KeyDown.CharScan.CharCode < $7F) then
  begin
    Event.KeyDown.Text[0] := Char(Event.KeyDown.CharScan.CharCode);
    Event.KeyDown.TextLength := 1;
  end;
end;

{ the scan code of a key that a modifier changed: the code of the key itself (Shift+F1 is $54, F1 is $3B) }
function BaseScan(Scan: Byte): Byte;
begin
  case Scan of
    $54..$5D: Result := Scan - $54 + $3B;       { Shift+F1..F10 }
    $5E..$67: Result := Scan - $5E + $3B;       { Ctrl+F1..F10 }
    $68..$71: Result := Scan - $68 + $3B;       { Alt+F1..F10 }
    $87, $89, $8B: Result := $85;
    $88, $8A, $8C: Result := $86;
    $73: Result := $4B;                          { Ctrl+Left, Right, End, PgDn, Home, PgUp, Up, Down, Ins, Del }
    $74: Result := $4D;
    $75: Result := $4F;
    $76: Result := $51;
    $77: Result := $47;
    $84: Result := $49;
    $8D: Result := $48;
    $91: Result := $50;
    $92: Result := $52;
    $93: Result := $53;
    $97: Result := $47;                          { Alt+Home, Up, PgUp, Left, Right, End, Down, PgDn, Ins, Del }
    $98: Result := $48;
    $99: Result := $49;
    $9B: Result := $4B;
    $9D: Result := $4D;
    $9F: Result := $4F;
    $A0: Result := $50;
    $A1: Result := $51;
    $A2: Result := $52;
    $A3: Result := $53;
  else
    Result := Scan;
  end;
end;

function KeyOfScan(Scan: Byte): Word;
begin
  case BaseScan(Scan) of
    $3B..$44: Result := $70 + (BaseScan(Scan) - $3B);   { F1..F10 }
    $85: Result := $7A;
    $86: Result := $7B;
    $47: Result := $24;                                 { Home }
    $48: Result := $26;
    $49: Result := $21;
    $4B: Result := $25;
    $4D: Result := $27;
    $4F: Result := $23;
    $50: Result := $28;
    $51: Result := $22;
    $52: Result := $2D;
    $53: Result := $2E;
    $94, $0F: Result := $09;
    $01: Result := $1B;
    $0E: Result := $08;
    $1C: Result := $0D;
  else
    Result := 0;
  end;
end;

function IsCursorBlock(Vk: Word): Boolean;
begin
  Result := Vk in [$21..$28, $2D, $2E];
end;

function OemVk(Ch: Byte): Word;
const
  { the characters of Shift+0 .. Shift+9 on a US keyboard }
  ShiftedDigits = ')!@#$%^&*(';
  { the OEM keys in pairs (without and with Shift) and their virtual keys VK_OEM_1 .. VK_OEM_7 }
  OemPairs = ';:=+,<-_.>/?`~[{\|]}''"';
  OemKeys: array[0..10] of Byte = ($BA, $BB, $BC, $BD, $BE, $BF, $C0, $DB, $DC, $DD, $DE);
var
  P: Integer;
begin
  case Chr(Ch) of
    'a'..'z': Exit(Ch - 32);
    'A'..'Z', '0'..'9', ' ': Exit(Ch);
  end;
  P := Pos(Chr(Ch), ShiftedDigits);
  if P > 0 then
    Exit(Ord('0') + P - 1);
  P := Pos(Chr(Ch), OemPairs);
  if P > 0 then
    Exit(OemKeys[(P - 1) div 2]);
  Result := 0;
end;

function EventVirtualKey(const Event: TEvent): Word;
begin
  if Event.KeyDown.VirtualKey <> 0 then
    Exit(Event.KeyDown.VirtualKey);
  Result := 0;
  if (Event.KeyDown.CharScan.CharCode >= 1) and (Event.KeyDown.CharScan.CharCode <= 26) and (Event.KeyDown.CharScan.CharCode <> 8) and (Event.KeyDown.CharScan.CharCode <> 9) and (Event.KeyDown.CharScan.CharCode <> 13) then
    Exit(Event.KeyDown.CharScan.CharCode + 64);                      { Ctrl+A.. }
  if Event.KeyDown.CharScan.CharCode = 0 then
    Exit(KeyOfScan(Event.KeyDown.CharScan.ScanCode));
  Result := KeyOfScan(Event.KeyDown.CharScan.ScanCode);
  if (Result = 0) or (Event.KeyDown.CharScan.CharCode > 32) then
    Result := OemVk(Event.KeyDown.CharScan.CharCode);
  if (Result = 0) and (Event.KeyDown.TextLength = 1) then
    Result := OemVk(Ord(Event.KeyDown.Text[0]));
end;

function EventScanCode(const Event: TEvent): Word;
var
  Vk: Word;
begin
  Vk := EventVirtualKey(Event);
  if Event.KeyDown.CharScan.CharCode = 0 then
    Exit(BaseScan(Event.KeyDown.CharScan.ScanCode));
  case Vk of
    $41..$5A:
      begin
        case Chr(Vk) of
          'Q': Result := $10; 'W': Result := $11; 'E': Result := $12; 'R': Result := $13; 'T': Result := $14;
          'Y': Result := $15; 'U': Result := $16; 'I': Result := $17; 'O': Result := $18; 'P': Result := $19;
          'A': Result := $1E; 'S': Result := $1F; 'D': Result := $20; 'F': Result := $21; 'G': Result := $22;
          'H': Result := $23; 'J': Result := $24; 'K': Result := $25; 'L': Result := $26;
          'Z': Result := $2C; 'X': Result := $2D; 'C': Result := $2E; 'V': Result := $2F; 'B': Result := $30;
          'N': Result := $31; 'M': Result := $32;
        else
          Result := 0;
        end;
      end;
    $31..$39: Result := $02 + (Vk - $31);
    $30: Result := $0B;
    $20: Result := $39;
    $BA: Result := $27;
    $BB: Result := $0D;
    $BC: Result := $33;
    $BD: Result := $0C;
    $BE: Result := $34;
    $BF: Result := $35;
    $C0: Result := $29;
    $DB: Result := $1A;
    $DC: Result := $2B;
    $DD: Result := $1B;
    $DE: Result := $28;
    $0D: Result := $1C;
    $09: Result := $0F;
    $08: Result := $0E;
    $1B: Result := $01;
  else
    Result := BaseScan(Event.KeyDown.CharScan.ScanCode);
  end;
end;

function EventWin32State(const Event: TEvent): Word;
var
  M: Word;
begin
  if Event.KeyDown.Win32State <> 0 then
    Exit(Event.KeyDown.Win32State);
  M := Event.KeyDown.ControlKeyState;
  Result := 0;
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
  if ((M and kbEnhanced) <> 0) or ((Event.KeyDown.CharScan.CharCode = 0) and IsCursorBlock(EventVirtualKey(Event))) then
    Result := Result or wkEnhanced;
end;

function EventUtf16(const Event: TEvent; out Hi, Lo: Word): Integer;
var
  Cp: LongWord;
  L: Integer;
begin
  Hi := 0;
  Lo := 0;
  Result := 0;
  if Event.KeyDown.TextLength > 0 then
  begin
    if not Utf8Decode(@Event.KeyDown.Text[0], Event.KeyDown.TextLength, Cp, L) then
      Exit;
    if Cp >= $10000 then
    begin
      Dec(Cp, $10000);
      Hi := $D800 + (Cp shr 10);
      Lo := $DC00 + (Cp and $3FF);
      Exit(2);
    end;
    Lo := Cp;
    Exit(1);
  end;
  case Event.KeyDown.CharScan.CharCode of
    1..26, 27: begin Lo := Event.KeyDown.CharScan.CharCode; Result := 1; end;
  end;
end;

end.
