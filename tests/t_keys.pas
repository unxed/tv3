program t_keys;
{$I ../src/tvdefs.inc}
uses TvKeys;
{$I testlib.inc}

function Same(const A, B: TKey): Boolean;
begin
  Result := (A = B);
end;

var
  K: TKey;
begin
  { constants are BIOS codes }
  Check(kbEnter = $1C0D, 'kbEnter');
  Check(kbF1 = $3B00, 'kbF1');
  Check(kbAltQ = $1000, 'kbAltQ');
  Check(kbNoKey = 0, 'kbNoKey');
  Check(kbShift = 3, 'kbShift');
  Check((kbCtrlShift = 4) and (kbAltShift = 8), 'kbCtrlShift, kbAltShift');

  { the examples in the original header }
  Check(Same(TKey.Create(kbCtrlA), TKey.Create(Ord('A'), kbCtrlShift)), 'kbCtrlA = TKey(A, ctrl)');
  Check(Same(TKey.Create(kbCtrlTab, kbShift), TKey.Create(kbTab, kbShift or kbCtrlShift)),
    'Ctrl+Tab with shift = Tab with shift and ctrl');
  Check(Same(TKey.Create(kbAltDel, kbCtrlShift), TKey.Create(kbCtrlDel, kbAltShift)),
    'Alt+Del with ctrl = Ctrl+Del with alt');

  { the result of the normalization }
  K := TKey.Create(kbCtrlA);
  Check((K.Code = Ord('A')) and (K.Mods = kbCtrlShift), 'Ctrl+A -> A, ctrl');
  K := TKey.Create(kbAltQ);
  Check((K.Code = Ord('Q')) and (K.Mods = kbAltShift), 'Alt+Q -> Q, alt');
  K := TKey.Create(kbShiftF1);
  Check((K.Code = kbF1) and (K.Mods = kbShift), 'Shift+F1 -> F1, shift');
  K := TKey.Create(kbCtrlF10);
  Check((K.Code = kbF10) and (K.Mods = kbCtrlShift), 'Ctrl+F10 -> F10, ctrl');
  K := TKey.Create(kbAltF3);
  Check((K.Code = kbF3) and (K.Mods = kbAltShift), 'Alt+F3 -> F3, alt');
  K := TKey.Create(kbCtrlLeft);
  Check((K.Code = kbLeft) and (K.Mods = kbCtrlShift), 'Ctrl+Left -> Left, ctrl');
  K := TKey.Create(kbCtrlBack);
  Check((K.Code = kbBack) and (K.Mods = kbCtrlShift), 'Ctrl+Backspace');
  K := TKey.Create(kbCtrlEnter);
  Check((K.Code = kbEnter) and (K.Mods = kbCtrlShift), 'Ctrl+Enter');
  K := TKey.Create(kbAlt5);
  Check((K.Code = Ord('5')) and (K.Mods = kbAltShift), 'Alt+5 -> 5, alt');
  K := TKey.Create(kbShiftTab);
  Check((K.Code = kbTab) and (K.Mods = kbShift), 'Shift+Tab -> Tab, shift');
  K := TKey.Create(kbAltEnter);
  Check((K.Code = kbEnter) and (K.Mods = kbAltShift), 'Alt+Enter');
  K := TKey.Create(kbF11);
  Check((K.Code = kbF11) and (K.Mods = 0), 'F11');
  K := TKey.Create(kbCtrlPrtSc);
  Check((K.Code = kbCtrlPrtSc) and (K.Mods = kbCtrlShift), 'Ctrl+PrtSc');

  { keys that stay as they are }
  K := TKey.Create(kbEnter);
  Check((K.Code = kbEnter) and (K.Mods = 0), 'Enter is unchanged');
  K := TKey.Create(kbEsc);
  Check((K.Code = kbEsc) and (K.Mods = 0), 'Esc is unchanged');
  K := TKey.Create(kbHome);
  Check((K.Code = kbHome) and (K.Mods = 0), 'Home is unchanged');

  { printable characters }
  K := TKey.Create(Ord('a'));
  Check((K.Code = Ord('A')) and (K.Mods = 0), 'lowercase letters become uppercase');
  K := TKey.Create(Ord('a'), kbShift);
  Check((K.Code = Ord('A')) and (K.Mods = kbShift), 'shift is kept');
  K := TKey.Create($1E61);
  Check((K.Code = Ord('A')) and (K.Mods = 0), 'letter with its scan code');
  K := TKey.Create($0231);
  Check(K.Code = Ord('1'), 'digit loses its scan code');
  K := TKey.Create($372A);
  Check(K.Code = $372A, 'keypad * keeps its scan code');
  K := TKey.Create($4E2B);
  Check(K.Code = $4E2B, 'keypad + keeps its scan code');

  { Ctrl+letter delivered as scan code and control character }
  K := TKey.Create($1E01);
  Check((K.Code = Ord('A')) and (K.Mods = kbCtrlShift), 'raw Ctrl+A');
  K := TKey.Create($320D);
  Check((K.Code = Ord('M')) and (K.Mods = kbCtrlShift), 'raw Ctrl+M (scan code of M, character 13)');
  K := TKey.Create($3201);
  Check((K.Code = $3201) and (K.Mods = 0), 'scan code of M with character 1 is not a raw ctrl key');

  { only shift, ctrl and alt count }
  K := TKey.Create(kbF2, kbScrollState or kbNumState or kbCapsState or kbInsState or kbPaste);
  Check((K.Code = kbF2) and (K.Mods = 0), 'lock states are ignored');
  K := TKey.Create(kbF2, kbLeftShift);
  Check(K.Mods = kbShift, 'left shift is shift');
  K := TKey.Create(kbF2, kbRightShift);
  Check(K.Mods = kbShift, 'right shift is shift');

  { no key }
  K := TKey.Create(kbNoKey, kbShift or kbAltShift);
  Check((K.Code = 0) and (K.Mods = 0), 'no key has no modifiers');

  { Wordstar keys }
  Check(CtrlToArrow(kbCtrlS) = kbLeft, 'CtrlToArrow: Ctrl+S is Left');
  Check(CtrlToArrow(kbCtrlD) = kbRight, 'CtrlToArrow: Ctrl+D is Right');
  Check(CtrlToArrow(kbCtrlE) = kbUp, 'CtrlToArrow: Ctrl+E is Up');
  Check(CtrlToArrow(kbCtrlX) = kbDown, 'CtrlToArrow: Ctrl+X is Down');
  Check(CtrlToArrow(kbCtrlH) = kbBack, 'CtrlToArrow: Ctrl+H is Backspace');
  Check(CtrlToArrow(kbF1) = kbF1, 'CtrlToArrow: other keys are returned as they are');

  Check(not Same(TKey.Create(kbF1), TKey.Create(kbF2)), 'different keys differ');
  Check(not Same(TKey.Create(kbF1), TKey.Create(kbF1, kbShift)), 'different modifiers differ');

  Finish;
end.
