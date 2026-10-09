{ Tests of TvXlat. }
program t_xlat;
{$I ../src/tvdefs.inc}
uses SysUtils, TvKeys, TvEvents, TvUtf8, TvXlat;
{$I testlib.inc}

function KeyEv(Cp: LongWord; Mods: Word): TEvent;
begin
  ClearEvent(Result);
  Result.What := evKeyDown;
  Result.KeyDown.ControlKeyState := Mods;
  Result.KeyDown.TextLength := Utf8Encode(Cp, PByte(@Result.KeyDown.Text[0]));
end;

var
  E: TEvent;
begin
  Check(XlatLatin($444) = Ord('a'), 'ф is the key of a');
  Check(XlatLatin($44B) = Ord('s'), 'ы is the key of s');
  Check(XlatLatin($419) = Ord('Q'), 'Й (upper case) is the key of Q');
  Check(XlatLatin($456) = Ord('s'), 'Ukrainian і is the key of s');
  Check(XlatLatin($457) = Ord(']'), 'Ukrainian ї is the key of ]');
  Check(XlatLatin($3B1) = Ord('a'), 'Greek α is the key of a');
  Check(XlatLatin(Ord('a')) = 0, 'a Latin letter is itself (0: nothing to do)');
  E := KeyEv($44B, kbLeftAlt);
  Check(XlatModded(E) and (E.KeyDown.KeyCode = kbAltS), 'Alt+ы becomes Alt+S');
  E := KeyEv($43A, kbLeftCtrl);
  Check(XlatModded(E) and (E.KeyDown.KeyCode = kbCtrlR), 'Ctrl+к becomes Ctrl+R');
  E := KeyEv($43A, 0);
  Check(not XlatModded(E), 'a plain letter is not a combination');
  Check(XlatPlain(E) and (E.KeyDown.TextLength = 1) and (E.KeyDown.Text[0] = 'r'), 'a plain к is r for the hot keys');
  E := KeyEv($44B, kbLeftAlt);
  Check(not XlatPlain(E), 'a combination is not plain');
  XlatAdd('ABC');
  Check(XlatLatin(Ord('A')) = 0, 'ASCII is never mapped');
  XlatEnabled := False;
  E := KeyEv($44B, kbLeftAlt);
  Check(not XlatModded(E), 'XlatEnabled = False: nothing');
  XlatEnabled := True;
  Finish;
end.
