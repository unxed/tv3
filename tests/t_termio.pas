program t_termio;
{$I ../src/tvdefs.inc}
uses SysUtils, TvEvents, TvKeys, TvCodePg, TvTermIO;
{$I testlib.inc}

var
  Bytes: string;
  BytePos: Integer;
  Input: TTermInput;
  State: TInputState;

function Reader(TimeoutMs: Integer): Integer;
begin
  if BytePos <= Length(Bytes) then
  begin
    Result := Ord(Bytes[BytePos]);
    Inc(BytePos);
  end
  else
    Result := -1;
end;

{ feeds the bytes and parses one event }
function Parse(const S: string; var Ev: TEvent): Boolean;
begin
  Bytes := S;
  BytePos := 1;
  Input.Init(@Reader, 1);
  Result := ParseEvent(Input, Ev, State);
end;

function Key(const S: string): Word;
var
  Ev: TEvent;
begin
  if Parse(S, Ev) and (Ev.What = evKeyDown) then
    Result := Ev.KeyCode
  else
    Result := $FFFF;
end;

function Mods(const S: string): Word;
var
  Ev: TEvent;
begin
  if Parse(S, Ev) then
    Result := Ev.ControlKeyState
  else
    Result := $FFFF;
end;

const
  E = #27;

var
  Ev: TEvent;
begin
  FillChar(State, SizeOf(State), 0);
  CpSelect(cpIdCp866);

  { plain keys }
  Check(Key('a') = Ord('a'), 'a');
  Check(Parse('a', Ev) and (Ev.TextLength = 1) and (Ev.Text[0] = 'a'), 'a has its text');
  Check(Key(#1) = kbCtrlA, 'Ctrl+A');
  Check(Mods(#1) = kbLeftCtrl, 'Ctrl+A: the Ctrl bit');
  Check(Key(#13) = kbEnter, 'Enter (CR)');
  Check(Key(#10) = kbEnter, 'Enter (LF)');
  Check(Key(#9) = kbTab, 'Tab');
  Check(Key(#127) = kbBack, 'Backspace (DEL)');
  Check(Key(#8) = kbBack, 'Backspace (BS)');
  Check(Key(E) = kbEsc, 'Esc alone');
  Check(Key(E + 'x') = kbAltX, 'Alt+X (Esc, x)');
  Check(Mods(E + 'x') = kbLeftAlt, 'Alt+X: the Alt bit');
  Check(Key(E + '5') = kbAlt5, 'Alt+5');
  Check(Key(E + #127) = kbAltBack, 'Alt+Backspace');
  Check(Key(E + E) = kbAltEsc, 'Alt+Esc (Esc Esc)');

  { UTF-8 text: the character code is that of the code page 866 }
  Check(Parse(#$D1#$8F, Ev) and (Ev.TextLength = 2) and (Ev.CharCode = $EF), 'UTF-8 "ya": 2 bytes, CP866 code $EF');
  Check(Parse(#$E2#$82#$AC, Ev) and (Ev.TextLength = 3) and (Ev.CharCode = 0), 'the euro sign: 3 bytes, no code in CP866');

  { arrows and others: xterm, with and without modifiers }
  Check(Key(E + '[A') = kbUp, 'Up');
  Check(Key(E + '[D') = kbLeft, 'Left');
  Check(Key(E + '[H') = kbHome, 'Home (CSI H)');
  Check(Key(E + '[F') = kbEnd, 'End (CSI F)');
  Check(Key(E + '[1~') = kbHome, 'Home (CSI 1 ~)');
  Check(Key(E + '[3~') = kbDel, 'Del');
  Check(Key(E + '[2~') = kbIns, 'Ins');
  Check(Key(E + '[5~') = kbPgUp, 'PgUp');
  Check(Key(E + '[6~') = kbPgDn, 'PgDn');
  Check(Key(E + '[Z') = kbShiftTab, 'Shift+Tab (CSI Z)');
  Check(Key(E + '[1;2A') = kbUp, 'Shift+Up: the key is Up');
  Check(Mods(E + '[1;2A') = kbShift, 'Shift+Up: the Shift bit');
  Check(Key(E + '[1;5C') = kbCtrlRight, 'Ctrl+Right');
  Check(Key(E + '[1;3D') = kbAltLeft, 'Alt+Left');
  Check(Key(E + '[3;2~') = kbShiftDel, 'Shift+Del');
  Check(Key(E + '[3;5~') = kbCtrlDel, 'Ctrl+Del');

  { function keys }
  Check(Key(E + 'OP') = kbF1, 'F1 (SS3 P)');
  Check(Key(E + 'OS') = kbF4, 'F4 (SS3 S)');
  Check(Key(E + 'O2P') = kbShiftF1, 'Shift+F1 (SS3 2 P)');
  Check(Key(E + '[15~') = kbF5, 'F5');
  Check(Key(E + '[21~') = kbF10, 'F10');
  Check(Key(E + '[23~') = kbShiftF1, 'F11 of xterm is Shift+F1 (as Putty and the Linux console)');
  Check(Key(E + '[15;5~') = kbCtrlF5, 'Ctrl+F5');
  Check(Key(E + '[24;3~') = kbAltF12, 'Alt+F12');
  Check(Key(E + '[[A') = kbF1, 'F1 of the Linux console (CSI [ A)');
  Check(Key(E + '[[E') = kbF5, 'F5 of the Linux console');

  { the protocols for modifiers }
  Check(Key(E + '[97;5u') = kbCtrlA, 'kitty: Ctrl+A');
  Check(Key(E + '[27;5;97~') = kbCtrlA, 'modifyOtherKeys: Ctrl+A');
  Check(Key(E + '[13;5u') = kbCtrlEnter, 'kitty: Ctrl+Enter');
  Check(Parse(E + '[1;5:3u', Ev) = False, 'kitty: a release is ignored');
  Check(Parse(E + '[97;1:3u', Ev) = False, 'kitty: the release of a is ignored unless it is asked for');
  Check(Parse(E + '[97;1:2u', Ev) and (Ev.What = evKeyDown) and (Ev.CharCode = Ord('a')), 'kitty: a repeat is a press');
  Check((Ev.KeyFlags and kfRepeat) <> 0, '... marked as a repeat');
  Check(Parse(E + '[97;1:1u', Ev) and (Ev.KeyFlags = 0), 'kitty: a press is not marked');
  Check(Parse(E + '[97u', Ev) and (Ev.KeyFlags = 0), 'kitty: no type of event, no mark');
  State.ReportKeyUp := True;
  Check(Parse(E + '[97;1:3u', Ev) and (Ev.What = evKeyUp) and (Ev.CharCode = Ord('a')), 'kitty: the release of a is evKeyUp when it is asked for');
  Check(Parse(E + '[97;5:3u', Ev) and (Ev.What = evKeyUp) and (Ev.KeyCode = kbCtrlA), 'kitty: the release of Ctrl+A');
  Check(Parse(E + '[97;1:5u', Ev) = False, 'kitty: an unknown type of event is ignored');
  State.ReportKeyUp := False;
  { the release of a modifier by itself: only when the application asks (ReportModUp), evKeyUp with KeyCode 0 and the modifiers that are still down }
  Check(Parse(E + '[57442;1:3u', Ev) = False, 'kitty: the release of Ctrl is ignored unless it is asked for');
  Check(not State.KittyReply, 'kitty: a key of the protocol does not tell that the terminal speaks it (a multiplexer can send one)');
  Check(Parse(E + '[?0u', Ev) = False, 'kitty: the answer to the query of the flags is not a key');
  Check(State.KittyReply, '... it tells that the terminal speaks the protocol');
  State.KittyReply := False;
  Check(Parse(E + '[?15u', Ev) = False, 'kitty: the answer with flags set');
  Check(State.KittyReply, '... also');
  State.KittyReply := False;
  Check(Parse(E + '[?62;22c', Ev) = False, 'the answer of a terminal to the query of the attributes is not a key');
  Check(not State.KittyReply, '... and not the answer of the keyboard protocol');
  Check(Key(E + '[97;5u') = kbCtrlA, 'after an answer the keys are still read');
  State.ReportModUp := True;
  Check(Parse(E + '[57442;1:3u', Ev) and (Ev.What = evKeyUp) and (Ev.KeyCode = 0) and (Ev.ControlKeyState = 0), 'kitty: the release of Ctrl is evKeyUp with no modifier');
  Check(Parse(E + '[57448;2:3u', Ev) and (Ev.What = evKeyUp) and ((Ev.ControlKeyState and kbCtrlShift) = 0) and ((Ev.ControlKeyState and kbShift) <> 0),
    'kitty: the release of the right Ctrl with Shift still held');
  Check(Parse(E + '[57441;5:3u', Ev) and (Ev.What = evKeyUp) and ((Ev.ControlKeyState and kbShift) = 0) and ((Ev.ControlKeyState and kbCtrlShift) <> 0),
    'kitty: the release of Shift with Ctrl still held');
  Check(Parse(E + '[57442;5u', Ev) = False, 'kitty: the press of Ctrl is not reported');
  Check(Parse(E + '[57444;1:3u', Ev) = False, 'kitty: the release of Super is not reported');
  State.ReportModUp := False;
  Check(Parse(E + '[1080u', Ev) and (Ev.TextLength = 2) and (Ev.CharCode = $A8), 'kitty: a Cyrillic letter (U+0438 = CP866 $A8)');

  { mouse }
  FillChar(State, SizeOf(State), 0);
  Check(Parse(E + '[<0;10;5M', Ev) and (Ev.What = evMouse) and (Ev.Where.X = 9) and (Ev.Where.Y = 4) and
    (Ev.Buttons = mbLeftButton), 'SGR mouse: the left button down at 9,4 (zero based)');
  Check(Parse(E + '[<32;11;5M', Ev) and (Ev.Buttons = mbLeftButton) and (Ev.Where.X = 10), 'SGR mouse: a drag keeps the button');
  Check(Parse(E + '[<0;11;5m', Ev) and (Ev.Buttons = 0), 'SGR mouse: release');
  Check(Parse(E + '[<2;1;1M', Ev) and (Ev.Buttons = mbRightButton), 'SGR mouse: the right button');
  Check(Parse(E + '[<2;1;1m', Ev) and (Ev.Buttons = 0), '... and up');
  Check(Parse(E + '[<64;3;3M', Ev) and (Ev.Wheel = mwUp), 'SGR mouse: wheel up');
  Check(Parse(E + '[<65;3;3M', Ev) and (Ev.Wheel = mwDown), 'SGR mouse: wheel down');
  Check(Parse(E + '[<16;3;3M', Ev) and ((Ev.ControlKeyState and kbLeftCtrl) <> 0), 'SGR mouse: Ctrl held');
  Check(Parse(E + '[M' + #32 + #43 + #37, Ev) and (Ev.Where.X = 10) and (Ev.Where.Y = 4) and (Ev.Buttons = mbLeftButton),
    'X10 mouse: the left button at 10,4');
  Check(Parse(E + '[M' + #35 + #43 + #37, Ev) and (Ev.Buttons = 0), 'X10 mouse: release');

  { the win32 input mode: ESC [ Vk ; Sc ; Uc ; Kd ; Cs ; Rc _ }
  Check(Key(E + '[38;72;0;1;0;1_') = kbUp, 'win32: Up');
  Check(Parse(E + '[38;72;0;0;0;1_', Ev) = False, 'win32: a release is ignored');
  { a key that is pressed again before its release is a repeat; a modifier is not counted }
  State.HeldVk := 0;
  Check(Parse(E + '[40;80;0;1;0;1_', Ev) and (Ev.KeyCode = kbDown) and (Ev.KeyFlags = 0), 'win32: the first press of Down is not a repeat');
  Check(Parse(E + '[40;80;0;1;0;1_', Ev) and (Ev.KeyCode = kbDown) and ((Ev.KeyFlags and kfRepeat) <> 0), 'win32: Down again with no release is a repeat');
  Check(Parse(E + '[16;42;0;1;16;1_', Ev) = False, 'win32: Shift pressed in between');
  Check(Parse(E + '[40;80;0;1;16;1_', Ev) and ((Ev.KeyFlags and kfRepeat) <> 0), '... Down is still held');
  Check(Parse(E + '[40;80;0;0;0;1_', Ev) = False, 'win32: the release (not asked for) is dropped');
  Check(Parse(E + '[40;80;0;1;0;1_', Ev) and (Ev.KeyFlags = 0), '... and the next press is not a repeat');
  Check(Parse(E + '[38;72;0;1;0;1_', Ev) and (Ev.KeyCode = kbUp) and (Ev.KeyFlags = 0), 'win32: another key is not a repeat');
  Check(Parse(E + '[38;72;0;1;0;3_', Ev) and ((Ev.KeyFlags and kfRepeat) <> 0), 'win32: a repeat count above 1 is a repeat');
  State.HeldVk := 0;
  { what the event brings from the win32 mode }
  Check(Parse(E + '[65;30;97;1;16;3_', Ev) and (Ev.VirtualKey = 65) and (Ev.RepeatCount = 3) and (Ev.Win32State = 16), 'win32: the virtual key, the repeat count and the state are in the event');
  Check(Parse(E + '[38;72;0;1;256;1_', Ev) and (Ev.VirtualKey = 38) and (Ev.Win32State = $100), 'win32: Up: the state tells that the key is an enhanced one');
  State.ReportKeyUp := True;
  Check(Parse(E + '[65;30;97;0;0;1_', Ev) and (Ev.What = evKeyUp) and (Ev.VirtualKey = 65) and (Ev.CharCode = Ord('a')), 'win32: a release is evKeyUp when it is asked for');
  Check(Parse(E + '[38;72;0;0;0;1_', Ev) and (Ev.What = evKeyUp) and (Ev.KeyCode = kbUp), 'win32: the release of Up');
  Check(Parse(E + '[16;42;0;0;0;1_', Ev) = False, 'win32: the release of Shift alone is not reported');
  State.ReportKeyUp := False;
  State.ReportModUp := True;
  Check(Parse(E + '[17;29;0;0;0;1_', Ev) and (Ev.What = evKeyUp) and (Ev.KeyCode = 0) and (Ev.ControlKeyState = 0) and (Ev.VirtualKey = 17),
    'win32: the release of Ctrl is evKeyUp with no modifier when it is asked for (without ReportKeyUp)');
  Check(Parse(E + '[17;29;0;0;8;1_', Ev) and (Ev.What = evKeyUp) and ((Ev.ControlKeyState and kbCtrlShift) = 0),
    'win32: ... also when the terminal still tells Ctrl in the state');
  Check(Parse(E + '[162;29;0;0;16;1_', Ev) and (Ev.What = evKeyUp) and ((Ev.ControlKeyState and kbShift) <> 0),
    'win32: the release of the left Ctrl with Shift held');
  Check(Parse(E + '[16;42;0;1;16;1_', Ev) = False, 'win32: the press of Shift is not reported');
  Check(Parse(E + '[18;56;0;0;0;1_', Ev) and (Ev.What = evKeyUp) and ((Ev.ControlKeyState and kbAltShift) = 0), 'win32: the release of Alt');
  State.ReportModUp := False;
  Check(Parse(E + '[16;42;0;1;16;1_', Ev) = False, 'win32: Shift alone is not a key');
  Check(Key(E + '[65;30;97;1;0;1_') = Ord('a'), 'win32: a');
  Check(Parse(E + '[65;30;65;1;16;1_', Ev) and (Ev.KeyCode = Ord('A')) and ((Ev.ControlKeyState and kbShift) <> 0), 'win32: Shift+A');
  Check(Key(E + '[65;30;1;1;8;1_') = kbCtrlA, 'win32: Ctrl+A (the character is a control one)');
  Check(Key(E + '[70;33;102;1;2;1_') = kbAltF, 'win32: Alt+F');
  Check(Key(E + '[116;63;0;1;8;1_') = kbCtrlF5, 'win32: Ctrl+F5');
  Check(Key(E + '[122;87;0;1;0;1_') = kbF11, 'win32: F11');
  Check(Key(E + '[13;28;13;1;0;1_') = kbEnter, 'win32: Enter');
  Check(Key(E + '[13;28;13;1;8;1_') = kbCtrlEnter, 'win32: Ctrl+Enter');
  Check(Key(E + '[9;15;9;1;16;1_') = kbShiftTab, 'win32: Shift+Tab');
  Check(Key(E + '[27;1;27;1;0;1_') = kbEsc, 'win32: Esc');
  Check(Key(E + '[8;14;8;1;0;1_') = kbBack, 'win32: Backspace');
  Check(Parse(E + '[66;48;1080;1;0;1_', Ev) and (Ev.TextLength = 2) and (Ev.CharCode = $A8), 'win32: a Cyrillic letter (U+0438 = CP866 $A8)');
  Check(Parse(E + '[0;0;55357;1;0;1_', Ev) = False, 'win32: the first half of a pair is waited for');
  Check(Parse(E + '[0;0;56832;1;0;1_', Ev) and (Ev.TextLength = 4), 'win32: U+1F600 from the two halves');
  Check(Parse(E + '[81;16;64;1;10;1_', Ev) and (Ev.KeyCode = Ord('@')) and ((Ev.ControlKeyState and (kbCtrlShift or kbAltShift)) = 0),
    'win32: AltGr + a character is the character');
  Check(Parse(E + '[18;56;945;0;0;1_', Ev) and (Ev.TextLength = 2), 'win32: Alt + numpad: the character comes with the release of Alt');

  { an APC string is skipped whole }
  Check(Parse(#27'_' + StringOfChar('A', 200) + #7'x', Ev) = False, 'an APC string is skipped whole');
  Check(BytePos = Length(Bytes), '... and the next byte is left');

  { what is not a key }
  Check(Parse(E + '[200~', Ev) = False, 'the start of a paste is not a key');
  Check(State.BracketedPaste, '... it is remembered');
  Check(Parse('v', Ev) and ((Ev.ControlKeyState and kbPaste) <> 0), 'a key of the paste has kbPaste');
  Check(Parse(E + '[201~', Ev) = False, 'the end of a paste');
  Check(not State.BracketedPaste, '... it is remembered');
  Check(Parse(E + ']52;c;AAAA' + #7 + 'x', Ev) = False, 'an OSC answer is skipped to the BEL');
  Check(BytePos = Length(Bytes), '... and the next byte is left');
  Check(Parse(E + 'P1+r726561642d636c6970626f617264=31' + E + '\x', Ev) = False, 'a DCS answer is skipped to the ST');
  Check(BytePos = Length(Bytes), '... and the next byte is left');
  Check(State.Osc52Full, '... the capability read-clipboard of the answer is remembered');
  { the introducer of a string with nothing after it is a key: Alt and P, ], _ (Alt+Shift+P is ESC P) }
  Check(Key(E + 'P') = kbAltP, 'Esc P alone is Alt+P');
  Check(Parse(E + 'P', Ev) and (Ev.What = evKeyDown) and ((Ev.ControlKeyState and kbLeftAlt) <> 0), 'Alt+P: the Alt bit');
  Check(Parse(E + ']', Ev) and (Ev.What = evKeyDown) and ((Ev.ControlKeyState and kbLeftAlt) <> 0) and (Ev.Text[0] = ']'), 'Esc ] alone is Alt+]');
  Check(Parse(E + '_', Ev) and (Ev.What = evKeyDown) and ((Ev.ControlKeyState and kbLeftAlt) <> 0) and (Ev.Text[0] = '_'), 'Esc _ alone is Alt+_');
  Check(Parse(E + '[12;34R', Ev) = False, 'the answer with the position of the cursor is skipped');
  Check(Parse(E + '[0n', Ev) = False, 'the answer to ESC [ 5 n (ESC [ 0 n) is skipped');
  Check(Parse('', Ev) = False, 'no input, no event');

  { a sequence that the program does not know is not lost as keys: Esc and Alt+key }
  Check(Key(E + '[99;99;99;99;99;99;99X') <> kbEsc, 'a too long sequence is not an Esc');

  Finish;
end.
