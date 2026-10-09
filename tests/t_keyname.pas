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
  Result := (A = B);
end;

begin
  Check(KeyToStr(TKey.Create(kbF5)) = 'F5', 'F5');
  Check(KeyToStr(TKey.Create(kbCtrlF5)) = 'Ctrl+F5', 'a code with the modifier in it');
  Check(KeyToStr(TKey.Create(kbF5, kbCtrlShift or kbShift)) = 'Ctrl+Shift+F5', 'modifiers in the order Ctrl Alt Shift');
  Check(KeyToStr(TKey.Create(kbAltEnter)) = 'Alt+Enter', 'Alt+Enter');
  Check(KeyToStr(TKey.Create(kbCtrlA)) = 'Ctrl+A', 'Ctrl+A');
  Check(KeyToStr(TKey.Create(kbAltQ)) = 'Alt+Q', 'Alt+Q');
  Check(KeyToStr(TKey.Create(kbShiftTab)) = 'Shift+Tab', 'Shift+Tab');
  Check(KeyToStr(TKey.Create(kbEsc)) = 'Esc', 'Esc');
  Check(KeyToStr(TKey.Create(kbAlt5)) = 'Alt+5', 'Alt+digit');
  Check(KeyToStr(TKey.Create(kbCtrlPgUp)) = 'Ctrl+PageUp', 'Ctrl+PageUp');
  Check(KeyToStr(TKey.Create(Ord('+'))) = '+', 'a printable character');
  Check(KeyToStr(TKey.Create(kbGrayPlus)) = 'Num+', 'the keypad plus');
  Check(KeyToStr(TKey.Create(kbNoKey)) = '', 'no key: empty');
  Check(KeyToStr(TKey.Create($FE00)) = 'Key $FE00', 'a key without a name');

  Check(Same(K('F5'), TKey.Create(kbF5)), 'read F5');
  Check(Same(K('ctrl+f5'), TKey.Create(kbCtrlF5)), 'read: case does not matter, Ctrl+F5 = kbCtrlF5');
  Check(Same(K('Ctrl-S'), TKey.Create(kbCtrlS)), 'read: - for +');
  Check(Same(K('Alt+Shift+F10'), TKey.Create(kbF10, kbAltShift or kbShift)), 'read: Alt+Shift+F10');
  Check(Same(K('Ctrl++'), TKey.Create(Ord('+'), kbCtrlShift)), 'read: the key + with Ctrl');
  Check(Same(K('Ctrl--'), TKey.Create(Ord('-'), kbCtrlShift)), 'read: the key - with Ctrl');
  Check(Same(K('Num-'), TKey.Create(kbGrayMinus)), 'read: Num-');
  Check(Same(K('Del'), TKey.Create(kbDel)), 'read: Del');
  Check(Same(K('PgDn'), TKey.Create(kbPgDn)), 'read: PgDn');
  Check(Same(K('Return'), TKey.Create(kbEnter)), 'read: Return');
  Check(Same(K('Alt+a'), TKey.Create(kbAltA)), 'read: Alt+a');
  Check(Same(K('Space'), TKey.Create(Ord(' '))), 'read: Space');
  Check(Same(K('Key $FE00'), TKey.Create($FE00)), 'read: Key $XXXX');
  Check(K('Hyper+X').Mods = $FFFF, 'an unknown modifier is no key');
  Check(K('').Mods = $FFFF, 'the empty text is no key');
  Check(K('Ctrl+').Mods = $FFFF, 'a modifier alone is no key');

  Check(KeyCodeToStr(kbAltF3) = 'Alt+F3', 'KeyCodeToStr');
  Check(Same(K(KeyToStr(TKey.Create(kbCtrlHome))), TKey.Create(kbCtrlHome)), 'the way there and back: Ctrl+Home');
  Check(Same(K(KeyToStr(TKey.Create(kbShiftIns))), TKey.Create(kbShiftIns)), 'the way there and back: Shift+Insert');
  Finish;
end.
