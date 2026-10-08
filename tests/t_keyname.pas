program t_keyname;
{ TvKeyName: "Ctrl+Shift+F5" <-> TKey. }
{$I ../src/tvdefs.inc}
uses TvKeys, TvKeyName;
{$I testlib.inc}

function K(const S: AnsiString): TKey;
begin
  if not StrToKey(S, Result) then
  begin
    Result.Code := 0;
    Result.Mods := $FFFF;
  end;
end;

function Same(const A, B: TKey): Boolean;
begin
  Result := KeyEq(A, B);
end;

begin
  Check(KeyToStr(KeyMake(kbF5)) = 'F5', 'F5');
  Check(KeyToStr(KeyMake(kbCtrlF5)) = 'Ctrl+F5', 'a code with the modifier in it');
  Check(KeyToStr(KeyMake(kbF5, kbCtrlShift or kbShift)) = 'Ctrl+Shift+F5', 'modifiers in the order Ctrl Alt Shift');
  Check(KeyToStr(KeyMake(kbAltEnter)) = 'Alt+Enter', 'Alt+Enter');
  Check(KeyToStr(KeyMake(kbCtrlA)) = 'Ctrl+A', 'Ctrl+A');
  Check(KeyToStr(KeyMake(kbAltQ)) = 'Alt+Q', 'Alt+Q');
  Check(KeyToStr(KeyMake(kbShiftTab)) = 'Shift+Tab', 'Shift+Tab');
  Check(KeyToStr(KeyMake(kbEsc)) = 'Esc', 'Esc');
  Check(KeyToStr(KeyMake(kbAlt5)) = 'Alt+5', 'Alt+digit');
  Check(KeyToStr(KeyMake(kbCtrlPgUp)) = 'Ctrl+PageUp', 'Ctrl+PageUp');
  Check(KeyToStr(KeyMake(Ord('+'))) = '+', 'a printable character');
  Check(KeyToStr(KeyMake(kbGrayPlus)) = 'Num+', 'the keypad plus');
  Check(KeyToStr(KeyMake(kbNoKey)) = '', 'no key: empty');
  Check(KeyToStr(KeyMake($FE00)) = 'Key $FE00', 'a key without a name');

  Check(Same(K('F5'), KeyMake(kbF5)), 'read F5');
  Check(Same(K('ctrl+f5'), KeyMake(kbCtrlF5)), 'read: case does not matter, Ctrl+F5 = kbCtrlF5');
  Check(Same(K('Ctrl-S'), KeyMake(kbCtrlS)), 'read: - for +');
  Check(Same(K('Alt+Shift+F10'), KeyMake(kbF10, kbAltShift or kbShift)), 'read: Alt+Shift+F10');
  Check(Same(K('Ctrl++'), KeyMake(Ord('+'), kbCtrlShift)), 'read: the key + with Ctrl');
  Check(Same(K('Ctrl--'), KeyMake(Ord('-'), kbCtrlShift)), 'read: the key - with Ctrl');
  Check(Same(K('Num-'), KeyMake(kbGrayMinus)), 'read: Num-');
  Check(Same(K('Del'), KeyMake(kbDel)), 'read: Del');
  Check(Same(K('PgDn'), KeyMake(kbPgDn)), 'read: PgDn');
  Check(Same(K('Return'), KeyMake(kbEnter)), 'read: Return');
  Check(Same(K('Alt+a'), KeyMake(kbAltA)), 'read: Alt+a');
  Check(Same(K('Space'), KeyMake(Ord(' '))), 'read: Space');
  Check(Same(K('Key $FE00'), KeyMake($FE00)), 'read: Key $XXXX');
  Check(K('Hyper+X').Mods = $FFFF, 'an unknown modifier is no key');
  Check(K('').Mods = $FFFF, 'the empty text is no key');
  Check(K('Ctrl+').Mods = $FFFF, 'a modifier alone is no key');

  Check(KeyCodeToStr(kbAltF3) = 'Alt+F3', 'KeyCodeToStr');
  Check(Same(K(KeyToStr(KeyMake(kbCtrlHome))), KeyMake(kbCtrlHome)), 'the way there and back: Ctrl+Home');
  Check(Same(K(KeyToStr(KeyMake(kbShiftIns))), KeyMake(kbShiftIns)), 'the way there and back: Shift+Insert');
  Finish;
end.
