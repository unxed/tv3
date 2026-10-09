{ TvVtKeys: what a terminal program must receive for a key or a mouse event (the input side of the terminal view, PLAN.md item 8.3): the bytes of a key
  (UTF-8 text, control characters, the sequences of the cursor keys and of the function keys with the modifiers of xterm) and the report of a mouse event
  (X10, UTF-8, SGR and urxvt encodings). The state of the modes comes from TvVt (application cursor keys, the mouse mode).

  The sequences are the ones that xterm sends (XTerm Control Sequences). }
unit TvVtKeys;

{$I tvdefs.inc}

interface

uses
  TvEvents;

{ the bytes for a key event; '' when the key has none (a modifier alone, a key that no terminal sends). Win32: the program asked for the win32 input mode (ESC [ ? 9001 h):
  every key and every release (evKeyUp) is ESC [ Vk ; Sc ; Uc ; Kd ; Cs ; Rc _ (the fields of KEY_EVENT_RECORD); a character above U+FFFF is a pair of such sequences.
  Kitty: the flags of the keyboard protocol of Kitty that the program asked for (CSI > flags u): 1 disambiguate (Esc, and keys with Ctrl or Alt, as CSI code ; modifiers u), 2 the types of events (the releases), 8 every key as an escape code. }
function VtKeyBytes(const Event: TEvent; AppCursor: Boolean; Win32: Boolean = False; Kitty: Integer = 0): AnsiString;

{ the report of a mouse event at the cell (X, Y) of the terminal (0-based) for the mouse mode (9, 1000, 1002, 1003) and the encoding (0, 1005, 1006, 1015).
  Press: Down = True, Button 0..2 (left, middle, right); release: Down = False; wheel: Wheel 1 (up) or 2 (down); a move: Moved = True.
  '' when the mode does not want the event. }
function VtMouseBytes(Mode, Enc, X, Y, Button: Integer; Down, Moved: Boolean; Wheel: Integer; Mods: Word): AnsiString;

{ the text that goes into the terminal as a paste; with the bracketed paste mode it is in ESC [ 200 ~ ... ESC [ 201 ~ }
function VtPasteBytes(const Text: AnsiString; Bracketed: Boolean): AnsiString;

implementation

uses
  TvKeys, TvUtf8;

function IntStr(V: LongInt): AnsiString;
var
  S: string[16];
begin
  Str(V, S);
  Result := S;
end;

{ the modifier value of xterm: 1 + shift 1 + alt 2 + ctrl 4 }
function ModValue(Mods: Word): Integer;
begin
  Result := 1;
  if (Mods and kbShift) <> 0 then Inc(Result, 1);
  if (Mods and kbAltShift) <> 0 then Inc(Result, 2);
  if (Mods and kbCtrlShift) <> 0 then Inc(Result, 4);
end;

function CsiKey(const Final: AnsiString; Mods: Word; Num: Integer): AnsiString;
var
  M: Integer;
begin
  M := ModValue(Mods);
  if Num = 0 then
  begin
    if M = 1 then
      Result := #27'[' + Final
    else
      Result := #27'[1;' + IntStr(M) + Final;
  end
  else
  begin
    if M = 1 then
      Result := #27'[' + IntStr(Num) + '~'
    else
      Result := #27'[' + IntStr(Num) + ';' + IntStr(M) + '~';
  end;
end;

{ the keyboard protocol of Kitty. A key that is a character (or Enter, Tab, Backspace, Esc) becomes CSI code ; modifiers : type u when the flags want it; a functional key
  (the cursor keys, F1..F12, Home...) keeps its legacy sequence and gets the type of the event if the flags say so. Done is False when the legacy bytes are right. }
function KittyKeyBytes(const Event: TEvent; Flags: Integer; AppCursor: Boolean; out Done: Boolean): AnsiString;
var
  Mods, M, T, Code, Used: Integer;
  Cp: LongWord;
  Ev2: TEvent;
  Legacy, Rest, Num, Fin: AnsiString;
  P: Integer;
  Escaped: Boolean;

  function Tail(Wanted: Boolean): AnsiString;
  begin
    Result := '';
    if (M > 1) or (Wanted and (T <> 1)) then
    begin
      Result := ';' + IntStr(M);
      if Wanted and (T <> 1) then
        Result := Result + ':' + IntStr(T);
    end;
  end;

begin
  Done := False;
  Result := '';
  T := 1;
  if Event.What = evKeyUp then
    T := 3;
  Mods := Event.KeyDown.ControlKeyState;
  M := ModValue(Mods);
  Code := 0;
  case Event.KeyDown.KeyCode of
    kbEsc: Code := 27;
    kbEnter, kbCtrlEnter: Code := 13;
    kbTab, kbShiftTab: Code := 9;
    kbBack, kbCtrlBack: Code := 127;
  end;
  if Event.KeyDown.KeyCode = kbShiftTab then
    M := ModValue(Mods or kbShift);
  if (Event.KeyDown.KeyCode = kbCtrlEnter) or (Event.KeyDown.KeyCode = kbCtrlBack) then
    M := ModValue(Mods or kbCtrlShift);
  if Code = 0 then
  begin
    if Event.KeyDown.TextLength > 0 then
    begin
      if Utf8Decode(@Event.KeyDown.Text[0], Event.KeyDown.TextLength, Cp, Used) then
      begin
        Code := Cp;
        if (Code >= Ord('A')) and (Code <= Ord('Z')) then
          Inc(Code, 32);                     { the code of a letter is the one of the key, lower case }
      end;
    end
    else if (Event.KeyDown.CharScan.CharCode >= 1) and (Event.KeyDown.CharScan.CharCode <= 26) and (Event.KeyDown.CharScan.ScanCode = 0) then
    begin
      Code := Event.KeyDown.CharScan.CharCode + 96;           { Ctrl and a letter without text: the letter }
      M := ModValue(Mods or kbCtrlShift);
    end;
  end;
  if Code <> 0 then
  begin
    Escaped := ((Flags and 8) <> 0) or (Code = 27) or ((Mods and (kbCtrlShift or kbAltShift)) <> 0)
      or (M > 4) or ((Event.KeyDown.KeyCode = kbShiftTab) or (Event.KeyDown.KeyCode = kbCtrlEnter) or (Event.KeyDown.KeyCode = kbCtrlBack));
    if not Escaped then
    begin
      if T = 3 then
      begin
        Done := True;                        { the release of a character that is sent as text: nothing }
        Exit('');
      end;
      Exit;                                  { the legacy bytes }
    end;
    Done := True;
    if (T = 3) and ((Flags and 2) = 0) then
      Exit('');
    Result := #27'[' + IntStr(Code) + Tail((Flags and 2) <> 0) + 'u';
    Exit;
  end;
  { a functional key: its legacy sequence, with the type of the event }
  Ev2 := Event;
  Ev2.What := evKeyDown;
  Legacy := VtKeyBytes(Ev2, AppCursor, False, 0);
  if (Length(Legacy) >= 3) and (Legacy[1] = #27) and ((Legacy[2] = '[') or (Legacy[2] = 'O')) then
  begin
    Done := True;
    if (T = 3) and ((Flags and 2) = 0) then
      Exit('');
    if (T = 1) or ((Flags and 2) = 0) then
      Exit(Legacy);
    Rest := Copy(Legacy, 3, MaxInt);
    Fin := Copy(Rest, Length(Rest), 1);
    Rest := Copy(Rest, 1, Length(Rest) - 1);
    P := Pos(';', Rest);
    if P > 0 then
      Num := Copy(Rest, 1, P - 1)
    else
      Num := Rest;
    if Num = '' then
      Num := '1';
    if Fin = '~' then
      Result := #27'[' + Num + Tail(True) + '~'
    else
      Result := #27'[1' + Tail(True) + Fin;
    Exit;
  end;
end;

{ the win32 input mode: the sequence of one KEY_EVENT_RECORD }
function Win32Seq(Vk, Sc, Uc, Kd, Cs, Rc: LongInt): AnsiString;
begin
  Result := #27'[' + IntStr(Vk) + ';' + IntStr(Sc) + ';' + IntStr(Uc) + ';' + IntStr(Kd) + ';' + IntStr(Cs) + ';' + IntStr(Rc) + '_';
end;

function Win32KeyBytes(const Event: TEvent): AnsiString;
var
  Vk, Sc, Cs, Rc, Kd, N: LongInt;
  Hi, Lo: Word;
begin
  Vk := EventVirtualKey(Event);
  Cs := EventWin32State(Event);
  Rc := Event.KeyDown.RepeatCount;
  if Rc < 1 then
    Rc := 1;
  Kd := Ord(Event.What <> evKeyUp);
  N := EventUtf16(Event, Hi, Lo);
  if (Vk = 0) and (N = 0) then
    Exit('');                                     { a key that has no name and no text }
  if Vk = 0 then
    Vk := $E7;                                    { VK_PACKET: a character that is not a key }
  Sc := EventScanCode(Event);
  { Ctrl and a letter is the control character, as Windows tells it }
  if (N = 1) and ((Cs and (wkLeftCtrl or wkRightCtrl)) <> 0) and ((Cs and (wkLeftAlt or wkRightAlt)) = 0) then
  begin
    if (Lo >= Ord('a')) and (Lo <= Ord('z')) then
      Lo := Lo - 32;
    if (Lo >= Ord('@')) and (Lo <= Ord('_')) then
      Lo := Lo - 64;
  end;
  if N = 2 then
    Result := Win32Seq(Vk, Sc, Hi, Kd, Cs, Rc) + Win32Seq(Vk, Sc, Lo, Kd, Cs, Rc)
  else
    Result := Win32Seq(Vk, Sc, Lo, Kd, Cs, Rc);
end;

function VtKeyBytes(const Event: TEvent; AppCursor: Boolean; Win32: Boolean; Kitty: Integer): AnsiString;
var
  Done: Boolean;
  Mods: Word;
  K: Word;
  C: Byte;
  Text: AnsiString;
begin
  Result := '';
  if Win32 then
    Exit(Win32KeyBytes(Event));
  if Kitty <> 0 then
  begin
    Result := KittyKeyBytes(Event, Kitty, AppCursor, Done);
    if Done then
      Exit;
  end;
  if Event.What = evKeyUp then
    Exit('');                                    { the releases are only for the win32 input mode }
  Mods := Event.KeyDown.ControlKeyState;
  K := Event.KeyDown.KeyCode;
  case K of
    kbUp, kbDown, kbRight, kbLeft, kbHome, kbEnd:
      begin
        case K of
          kbUp: Text := 'A';
          kbDown: Text := 'B';
          kbRight: Text := 'C';
          kbLeft: Text := 'D';
          kbHome: Text := 'H';
        else
          Text := 'F';
        end;
        if AppCursor and (ModValue(Mods) = 1) then
          Result := #27'O' + Text
        else
          Result := CsiKey(Text, Mods, 0);
        Exit;
      end;
    kbPgUp: Exit(CsiKey('', Mods, 5));
    kbPgDn: Exit(CsiKey('', Mods, 6));
    kbIns: Exit(CsiKey('', Mods, 2));
    kbDel: Exit(CsiKey('', Mods, 3));
    kbF1, kbF2, kbF3, kbF4:
      begin
        Text := Chr(Ord('P') + (K - kbF1) div $100);
        if ModValue(Mods) = 1 then
          Exit(#27'O' + Text);
        Exit(CsiKey(Text, Mods, 0));
      end;
    kbF5: Exit(CsiKey('', Mods, 15));
    kbF5 + $100: Exit(CsiKey('', Mods, 17));
    kbF5 + $200: Exit(CsiKey('', Mods, 18));
    kbF5 + $300: Exit(CsiKey('', Mods, 19));
    kbF5 + $400: Exit(CsiKey('', Mods, 20));
    kbF5 + $500: Exit(CsiKey('', Mods, 21));   { F10 }
    kbF11: Exit(CsiKey('', Mods, 23));
    kbF12: Exit(CsiKey('', Mods, 24));
    kbEnter: Result := #13;
    kbEsc: Result := #27;
    kbBack: Result := #127;
    kbCtrlBack: Result := #8;
    kbTab: Result := #9;
    kbShiftTab: Exit(#27'[Z');
  end;
  if Result = '' then
  begin
    if Event.KeyDown.TextLength > 0 then
    begin
      SetLength(Text, Event.KeyDown.TextLength);
      Move(Event.KeyDown.Text[0], Text[1], Event.KeyDown.TextLength);
      { Ctrl and a letter or one of @ [ \ ] ^ _ ?: the control character }
      if ((Mods and kbCtrlShift) <> 0) and (Length(Text) = 1) then
      begin
        C := Ord(Text[1]);
        if (C >= Ord('a')) and (C <= Ord('z')) then
          C := C - 32;
        if (C >= Ord('@')) and (C <= Ord('_')) then
          Text := Chr(C - 64)
        else if C = Ord(' ') then
          Text := #0
        else if C = Ord('?') then
          Text := #127;
      end;
      Result := Text;
    end
    else if (K >= 1) and (K <= $FF) then
      Result := Chr(K)                        { Ctrl and a letter: the control character itself }
    else
      Exit('');
  end;
  if ((Mods and kbAltShift) <> 0) and (Result <> '') then
    Result := #27 + Result;
end;

function VtMouseBytes(Mode, Enc, X, Y, Button: Integer; Down, Moved: Boolean; Wheel: Integer; Mods: Word): AnsiString;
var
  B: Integer;
  Buf: array[0..4] of Byte;
  N: Integer;
begin
  Result := '';
  if Mode = 0 then
    Exit;
  if Wheel <> 0 then
    B := 64 + (Wheel - 1)
  else if Moved then
  begin
    if Mode < 1003 then
      if (Mode < 1002) or (Button < 0) then
        Exit;                                  { 1000 does not report moves; 1002 only with a button down }
    if Button < 0 then
      B := 3 + 32
    else
      B := Button + 32;
  end
  else if Down then
    B := Button
  else
  begin
    if Mode = 9 then
      Exit;                                    { X10: the presses only }
    if Enc = 1006 then
      B := Button
    else
      B := 3;                                  { the old encodings do not say which button is released }
  end;
  if Mode <> 9 then
  begin
    if (Mods and kbShift) <> 0 then Inc(B, 4);
    if (Mods and kbAltShift) <> 0 then Inc(B, 8);
    if (Mods and kbCtrlShift) <> 0 then Inc(B, 16);
  end;
  case Enc of
    1006:
      begin
        Result := #27'[<' + IntStr(B) + ';' + IntStr(X + 1) + ';' + IntStr(Y + 1);
        if Down or (Wheel <> 0) or Moved then
          Result := Result + 'M'
        else
          Result := Result + 'm';
      end;
    1015:
      Result := #27'[' + IntStr(B + 32) + ';' + IntStr(X + 1) + ';' + IntStr(Y + 1) + 'M';
    1005:
      begin
        Result := #27'[M' + Chr(B + 32);
        N := Utf8Encode(X + 33, @Buf[0]);
        SetLength(Result, Length(Result) + N);
        Move(Buf[0], Result[Length(Result) - N + 1], N);
        N := Utf8Encode(Y + 33, @Buf[0]);
        SetLength(Result, Length(Result) + N);
        Move(Buf[0], Result[Length(Result) - N + 1], N);
      end;
  else
    if (X > 222) or (Y > 222) then
      Exit('');                                { the old encoding cannot say it }
    Result := #27'[M' + Chr(B + 32) + Chr(X + 33) + Chr(Y + 33);
  end;
end;

function VtPasteBytes(const Text: AnsiString; Bracketed: Boolean): AnsiString;
begin
  if Bracketed then
    Result := #27'[200~' + Text + #27'[201~'
  else
    Result := Text;
end;

end.
