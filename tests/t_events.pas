program t_events;
{$I ../src/tvdefs.inc}
uses TvGeom, TvKeys, TvEvents;
{$I testlib.inc}

var
  E: TEvent;
  K: TKey;
  Hi, Lo: Word;
begin
  Check(evMouse = (evMouseDown or evMouseUp or evMouseMove or evMouseAuto or evMouseWheel),
    'evMouse is the union of the mouse events');
  Check((evMessage and evCommand <> 0) and (evMessage and evBroadcast <> 0), 'evMessage covers commands');
  Check(evMessage and evKeyDown = 0, 'evMessage does not cover keys');

  ClearEvent(E);
  Check((E.What = evNothing) and (E.KeyDown.ControlKeyState = 0), 'ClearEvent');

  { key code aliases its character and scan code }
  E.KeyDown.KeyCode := $1C0D;
  Check((E.KeyDown.CharScan.CharCode = $0D) and (E.KeyDown.CharScan.ScanCode = $1C), 'KeyCode = ScanCode shl 8 + CharCode');
  E.KeyDown.CharScan.CharCode := $41;
  E.KeyDown.CharScan.ScanCode := $1E;
  Check(E.KeyDown.KeyCode = $1E41, 'CharCode and ScanCode make the KeyCode');

  { message information aliases }
  E.Message.InfoLong := $12345678;
  Check(E.Message.InfoWord = $5678, 'InfoWord is the low word of InfoLong');
  Check(E.Message.InfoByte = $78, 'InfoByte is the low byte');
  E.Message.InfoPtr := nil;
  Check(E.Message.InfoLong = 0, 'InfoPtr and InfoLong overlay');
  E.Message.InfoPtr := @E;
  E.KeyDown.KeyCode := $1E41;
  Check(E.Message.InfoPtr = @E, '64-bit message pointer does not overlap key code');
  E.Message.InfoPtr := nil;
  Check(E.KeyDown.KeyCode = $1E41, 'message pointer does not overwrite key code');
  E.Message.InfoInt := -2;
  Check(E.Message.InfoWord = $FFFE, 'InfoInt is a signed InfoWord');

  { mouse part }
  ClearEvent(E);
  E.What := evMouseDown;
  E.Mouse.Where.X := 12;
  E.Mouse.Where.Y := 5;
  E.Mouse.Buttons := mbLeftButton or mbRightButton;
  E.Mouse.EventFlags := meDoubleClick;
  Check((E.Mouse.Where.X = 12) and (E.Mouse.Where.Y = 5) and (E.Mouse.Buttons = 3) and (E.Mouse.EventFlags = meDoubleClick), 'mouse fields');

  { key events }
  MakeKeyEvent(E, Ord('x'), kbShift);
  Check((E.What = evKeyDown) and (E.KeyDown.ControlKeyState = kbShift), 'MakeKeyEvent');
  Check(EventText(E) = 'x', 'text of a printable key');
  K := EventKey(E);
  Check((K.Code = Ord('X')) and (K.Mods = kbShift), 'EventKey normalizes');
  MakeKeyEvent(E, kbF1, 0);
  Check(EventText(E) = '', 'no text for a function key');
  Check(EventKey(E).Code = kbF1, 'EventKey of F1');

  { UTF-8 text }
  ClearEvent(E);
  E.What := evKeyDown;
  E.KeyDown.Text[0] := #$C3;
  E.KeyDown.Text[1] := #$A9;
  E.KeyDown.TextLength := 2;
  Check(EventText(E) = #$C3#$A9, 'UTF-8 text of a key event');
  E.KeyDown.TextLength := 9;
  Check(Length(EventText(E)) = 4, 'text length is capped');

  { the fields of the win32 input mode: what the event does not tell is worked out from the key code }
  MakeKeyEvent(E, Ord('a'), 0);
  Check((EventVirtualKey(E) = 65) and (EventScanCode(E) = $1E) and (EventWin32State(E) = 0), 'win32 fields: a');
  MakeKeyEvent(E, Ord('a'), kbShift or kbCtrlShift or kbAltShift);
  Check(EventWin32State(E) = (wkShift or wkLeftCtrl or wkLeftAlt), 'win32 fields: the modifiers');
  MakeKeyEvent(E, kbLeft, 0);
  Check((EventVirtualKey(E) = $25) and (EventScanCode(E) = $4B) and ((EventWin32State(E) and wkEnhanced) <> 0), 'win32 fields: Left');
  MakeKeyEvent(E, kbCtrlLeft, 0);
  Check((EventVirtualKey(E) = $25) and (EventScanCode(E) = $4B), 'win32 fields: Ctrl+Left is the key Left');
  MakeKeyEvent(E, kbF5, 0);
  Check((EventVirtualKey(E) = $74) and (EventScanCode(E) = $3F), 'win32 fields: F5');
  E.KeyDown.VirtualKey := 77;
  E.KeyDown.Win32State := $0108;
  Check((EventVirtualKey(E) = 77) and (EventWin32State(E) = $0108), 'win32 fields: what the terminal told is not changed');
  MakeKeyEvent(E, Ord('a'), 0);
  Check((EventUtf16(E, Hi, Lo) = 1) and (Lo = 97), 'win32 fields: the UTF-16 unit of the text');
  Finish;
end.
