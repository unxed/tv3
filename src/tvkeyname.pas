{ TvKeyName: the names of keys: "Ctrl+Shift+F5" <-> TKey.

  MIT as the one place for what dn (hot keys of the user menu, the log of events) and fpide (key bindings, tools) did separately.

  A name is the modifiers in the order Ctrl, Alt, Shift (all optional), a plus, and the key: a letter or digit, a printable character, or one of
  the names of the table (Esc, Enter, Tab, Backspace, Insert, Delete, Home, End, PageUp, PageDown, Up, Down, Left, Right, Space,
  F1..F12, Num+, Num-, PrintScreen). The names are read without regard to case; "Del", "Ins", "PgUp", "PgDn", "Return", "Escape", "BkSp" and
  "Control" are read as well, "-" may stand instead of "+" ("Ctrl-S"). A key is a TKey, so the combinations that have several writings in the
  codes of TvKeys are one key here (kbCtrlF5 and F5 with Ctrl are both "Ctrl+F5"). }
unit TvKeyName;

{$I tvdefs.inc}

interface

uses
  TvKeys;

{ The name of a key. A key without a name comes as "Key $XXXX"; kbNoKey as an empty text. }
function KeyToStr(const K: TKey): AnsiString;
function KeyCodeToStr(KeyCode: Word): AnsiString;
{ False when the text is no key; K is nothing then. }
function StrToKey(const S: AnsiString; out K: TKey): Boolean;

implementation

uses
  SysUtils;

type
  TKeyRow = record
    N: string[20];
    C: Word;
  end;

const
  KeyCount = 29;
  KeyTable: array[0..KeyCount - 1] of TKeyRow = (
    (N: 'Esc'; C: $011B),
    (N: 'Backspace'; C: $0E08),
    (N: 'Tab'; C: $0F09),
    (N: 'Enter'; C: $1C0D),
    (N: 'F1'; C: $3B00),
    (N: 'F2'; C: $3C00),
    (N: 'F3'; C: $3D00),
    (N: 'F4'; C: $3E00),
    (N: 'F5'; C: $3F00),
    (N: 'F6'; C: $4000),
    (N: 'F7'; C: $4100),
    (N: 'F8'; C: $4200),
    (N: 'F9'; C: $4300),
    (N: 'F10'; C: $4400),
    (N: 'Home'; C: $4700),
    (N: 'Up'; C: $4800),
    (N: 'PageUp'; C: $4900),
    (N: 'Num-'; C: $4A2D),
    (N: 'Left'; C: $4B00),
    (N: 'Right'; C: $4D00),
    (N: 'Num+'; C: $4E2B),
    (N: 'End'; C: $4F00),
    (N: 'Down'; C: $5000),
    (N: 'PageDown'; C: $5100),
    (N: 'Insert'; C: $5200),
    (N: 'Delete'; C: $5300),
    (N: 'F11'; C: $8500),
    (N: 'F12'; C: $8600),
    (N: 'Space'; C: $0020)
  );

  AliasCount = 11;
  Aliases: array[0..AliasCount - 1] of TKeyRow = (
    (N: 'Escape'; C: kbEsc), (N: 'Return'; C: kbEnter), (N: 'BkSp'; C: kbBack),
    (N: 'Ins'; C: kbIns), (N: 'Del'; C: kbDel), (N: 'PgUp'; C: kbPgUp), (N: 'PgDn'; C: kbPgDn),
    (N: 'Plus'; C: kbGrayPlus), (N: 'Minus'; C: kbGrayMinus), (N: 'Spacebar'; C: $0020), (N: 'PrtSc'; C: kbCtrlPrtSc)
  );

function FindName(const Name: AnsiString; out Code: Word): Boolean;
var
  I: Integer;
  L: AnsiString;
begin
  L := LowerCase(Name);
  for I := 0 to KeyCount - 1 do
    if LowerCase(KeyTable[I].N) = L then
    begin
      Code := KeyTable[I].C;
      Exit(True);
    end;
  for I := 0 to AliasCount - 1 do
    if LowerCase(Aliases[I].N) = L then
    begin
      Code := Aliases[I].C;
      Exit(True);
    end;
  Result := False;
end;

function FindCode(Code: Word; out Name: AnsiString): Boolean;
var
  I: Integer;
begin
  for I := 0 to KeyCount - 1 do
    if KeyTable[I].C = Code then
    begin
      Name := KeyTable[I].N;
      Exit(True);
    end;
  Result := False;
end;

function KeyToStr(const K: TKey): AnsiString;
var
  Base, Pre: AnsiString;
  Ch: Byte;
begin
  if K.Code = kbNoKey then
    Exit('');
  Pre := '';
  if K.Mods and kbCtrlShift <> 0 then Pre := Pre + 'Ctrl+';
  if K.Mods and kbAltShift <> 0 then Pre := Pre + 'Alt+';
  if K.Mods and kbShift <> 0 then Pre := Pre + 'Shift+';
  if FindCode(K.Code, Base) then
    Exit(Pre + Base);
  Ch := K.Code and $FF;
  if (K.Code shr 8 = 0) and (Ch > $20) and (Ch < $7F) then
    Exit(Pre + UpCase(Chr(Ch)));
  Result := Pre + 'Key $' + IntToHex(K.Code, 4);
end;

function KeyCodeToStr(KeyCode: Word): AnsiString;
begin
  Result := KeyToStr(KeyMake(KeyCode));
end;

{ "Ctrl+Alt+X" into the modifiers and the text of the key; "Ctrl++" has the key "+", "Num-" has the key "Num-" }
function Split(const S: AnsiString; out Mods: Word; out KeyText: AnsiString): Boolean;
var
  Rest, L: AnsiString;
  P: Integer;
begin
  Mods := 0;
  Rest := Trim(S);
  Result := Rest <> '';
  while Result do
  begin
    P := 2;
    while (P < Length(Rest)) and (Rest[P] <> '+') and (Rest[P] <> '-') do
      Inc(P);
    if P >= Length(Rest) then
      Break;                                    { no separator that is followed by something: the rest is the key }
    L := LowerCase(Trim(Copy(Rest, 1, P - 1)));
    if (L = 'ctrl') or (L = 'control') then Mods := Mods or kbCtrlShift
    else if L = 'alt' then Mods := Mods or kbAltShift
    else if L = 'shift' then Mods := Mods or kbShift
    else
      Break;                                    { not a modifier: it is the key }
    Rest := Trim(Copy(Rest, P + 1, MaxInt));
  end;
  KeyText := Rest;
end;

function StrToKey(const S: AnsiString; out K: TKey): Boolean;
var
  Mods: Word;
  Txt: AnsiString;
  Code: Word;
begin
  K.Code := kbNoKey;
  K.Mods := 0;
  Result := False;
  if not Split(S, Mods, Txt) or (Txt = '') then
    Exit;
  if FindName(Txt, Code) then
  begin
    K := KeyMake(Code, Mods);
    Exit(True);
  end;
  if Length(Txt) = 1 then
  begin
    if (Txt[1] > ' ') and (Txt[1] < #$7F) then
    begin
      K := KeyMake(Ord(UpCase(Txt[1])), Mods);
      Exit(True);
    end;
    Exit;
  end;
  if (Length(Txt) > 5) and (LowerCase(Copy(Txt, 1, 5)) = 'key $') then
  begin
    Code := StrToIntDef('$' + Copy(Txt, 6, MaxInt), 0);
    if Code <> 0 then
    begin
      K := KeyMake(Code, Mods);
      Result := True;
    end;
  end;
end;

end.
