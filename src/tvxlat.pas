{ TvXlat: shortcuts that work in any keyboard layout.

  MIT (see LICENSE).

  A key that the terminal reports as a letter of another script (Alt+Ы, Ctrl+К) is the Latin key that sits at the same place of the keyboard (Alt+S, Ctrl+R). The
  tables below give, for a layout, its letters in the order of the Latin keys q w e r t y u i o p [ ] a s d f g h j k l ; ' z x c v b n m , . (and ` \ on the
  keys that some layouts have a letter on). More layouts can be added: XlatAdd, or a file with lines "letters of the layout = Latin keys" (XlatLoadFile).

  XlatModded changes the key code of a combination with Ctrl or Alt; XlatPlain gives the Latin text of a plain letter, for the places that look for a letter among
  their hot keys (menus, buttons of a dialog) after the key itself found nothing. Typing is not touched: a letter that a view takes as text is taken before. }
unit TvXlat;

{$I tvdefs.inc}

interface

uses
  TvEvents;

{ The Latin character (lower case a..z or the sign) on the key where the layout has the character CodePoint; 0 if no layout has it. }
function XlatLatin(CodePoint: LongWord): LongWord;

{ Adds a layout: its characters (lower case then upper case, UTF-8) in the order of the Latin keys, which are
  "qwertyuiop[]asdfghjkl;'zxcvbnm,.`\" ; a character that the layout has not is written as a blank. }
procedure XlatAdd(const Letters: AnsiString);
{ Lines of the form  letters = keys  ('#' starts a comment); the keys are written like the Latin ones above. False if the file cannot be read. }
function XlatLoadFile(const Name: AnsiString): Boolean;

{ Alt+letter, Ctrl+letter of another script: the key code of the Latin letter is put in the event. True if the event was changed. }
function XlatModded(var Event: TEvent): Boolean;
{ A plain letter of another script as the Latin letter (Text, CharCode); True if the event was changed. }
function XlatPlain(var Event: TEvent): Boolean;

var
  { False: nothing is translated }
  XlatEnabled: Boolean = True;

implementation

uses
  SysUtils, TvKeys, TvUtf8, TvTermIO;

const
  LatinKeys = 'qwertyuiop[]asdfghjkl;''zxcvbnm,.`\';

var
  Map: array of record
    From, To_: LongWord;
  end;
  MapCount: Integer;
  Loaded: Boolean;

var
  Override_: Boolean;     { a layout that is added later wins over the ones before it (the built-in ones do not: the first layout that has the letter keeps it) }

procedure Put(From, To_: LongWord);
var
  I: Integer;
begin
  for I := 0 to MapCount - 1 do
    if Map[I].From = From then
    begin
      if Override_ then
        Map[I].To_ := To_;
      Exit;
    end;
  if MapCount = Length(Map) then
    SetLength(Map, MapCount * 2 + 64);
  Map[MapCount].From := From;
  Map[MapCount].To_ := To_;
  Inc(MapCount);
end;

function Decode(const S: AnsiString; out Cps: array of LongWord): Integer;
var
  I, Used: Integer;
  Cp: LongWord;
begin
  Result := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if not Utf8Decode(PByte(@S[I]), Length(S) - I + 1, Cp, Used) then
    begin
      Cp := Ord(S[I]);
      Used := 1;
    end;
    if Result <= High(Cps) then
      Cps[Result] := Cp;
    Inc(Result);
    Inc(I, Used);
  end;
end;

{ Lower case letters, then the upper case ones, in the order of LatinKeys }
procedure AddPair(const Layout, Keys: AnsiString);
var
  L, K: array[0..127] of LongWord;
  NL, NK, I: Integer;
  C: LongWord;
begin
  NL := Decode(Layout, L);
  NK := Decode(Keys, K);
  if NL > 128 then NL := 128;
  if NK > 128 then NK := 128;
  for I := 0 to NL - 1 do
    if (I < NK) and (L[I] > 32) and (L[I] <> K[I]) then
    begin
      C := K[I];
      Put(L[I], C);
    end;
end;

procedure XlatAdd(const Letters: AnsiString);
var
  P: Integer;
  Half: AnsiString;
begin
  { the layout may give the lower case letters only, or both cases separated by a blank-free bar "|" }
  P := Pos('|', Letters);
  if P = 0 then
    AddPair(Letters, LatinKeys)
  else
  begin
    Half := Copy(Letters, 1, P - 1);
    AddPair(Half, LatinKeys);
    AddPair(Copy(Letters, P + 1, MaxInt), UpperCase(LatinKeys));
  end;
end;

procedure Init;
begin
  if Loaded then
    Exit;
  Loaded := True;
  Override_ := False;
  { Russian, Ukrainian, Belarusian, Bulgarian, Serbian: the letters of the keys q..p [ ] a..l ; ' z..m , . }
  XlatAdd('йцукенгшщзхъфывапролджэячсмитьбю');
  XlatAdd('йцукенгшщзхїфівапролджєячсмитьбю');       { Ukrainian: ї on ], і on s, є on ' }
  XlatAdd('йцукенгшщзхъфывапролджэячсмитьбю|ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ');
  XlatAdd('йцукенгшщзхїфівапролджєячсмитьбю|ЙЦУКЕНГШЩЗХЇФІВАПРОЛДЖЄЯЧСМИТЬБЮ');
  XlatAdd('љњертзуиопшђасдфгхјклчћжзџцвбнм|ЉЊЕРТЗУИОПШЂАСДФГХЈКЛЧЋЖЗЏЦВБНМ');
  XlatAdd('ўцукенгшщзх''ъфывапролджэячсмітьбю');
  XlatAdd('чявертъуиопшщасдфгхйклзьюцжбнм|ЧЯВЕРТЪУИОПШЩАСДФГХЙКЛЗЬЮЦЖБНМ');
  { Greek: the lower case letters of the keys q..p a..l z..m }
  XlatAdd(';ςερτυθιοπ[]ασδφγηξκλ΄ζχψωβνμ,.');
  { Hebrew }
  XlatAdd('/'''+'קראטוןםפ[]שדגכעיחלךף,זסבהנמצתץ');
  Override_ := True;
end;

function XlatLatin(CodePoint: LongWord): LongWord;
var
  I: Integer;
  Lo: LongWord;
begin
  Result := 0;
  if CodePoint < 128 then
    Exit;
  Init;
  for I := 0 to MapCount - 1 do
    if Map[I].From = CodePoint then
      Exit(Map[I].To_);
  { the upper case letter of a layout that gave lower case ones only }
  for I := 0 to MapCount - 1 do
    if (Map[I].From < 65536) and (Map[I].From > 127) then
      ;
  Lo := 0;
  if (CodePoint >= $410) and (CodePoint <= $42F) then
    Lo := CodePoint + $20
  else if (CodePoint >= $400) and (CodePoint <= $40F) then
    Lo := CodePoint + $50
  else if (CodePoint >= $391) and (CodePoint <= $3A9) then
    Lo := CodePoint + $20;
  if Lo <> 0 then
    for I := 0 to MapCount - 1 do
      if Map[I].From = Lo then
        Exit(Map[I].To_);
end;

function XlatLoadFile(const Name: AnsiString): Boolean;
var
  F: Text;
  Line: AnsiString;
  P: Integer;
begin
  Result := False;
  Assign(F, Name);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult <> 0 then
    Exit;
  Init;
  while not Eof(F) do
  begin
    ReadLn(F, Line);
    P := Pos('#', Line);
    if P > 0 then
      Line := Copy(Line, 1, P - 1);
    P := Pos('=', Line);
    if P > 1 then
      AddPair(Trim(Copy(Line, 1, P - 1)), Trim(Copy(Line, P + 1, MaxInt)));
  end;
  Close(F);
  Result := True;
end;

function FirstCodePoint(const Event: TEvent; out Cp: LongWord): Boolean;
var
  Used: Integer;
begin
  Result := (Event.KeyDown.TextLength > 0) and Utf8Decode(PByte(@Event.KeyDown.Text[0]), Event.KeyDown.TextLength, Cp, Used);
end;

function XlatModded(var Event: TEvent): Boolean;
var
  Cp, Lat: LongWord;
  Big: Integer;
  Code: Word;
begin
  Result := False;
  if not XlatEnabled or (Event.What <> evKeyDown) then
    Exit;
  if (Event.KeyDown.ControlKeyState and (kbCtrlShift or kbAltShift)) = 0 then
    Exit;
  if not FirstCodePoint(Event, Cp) or (Cp < 128) then
    Exit;
  Lat := XlatLatin(Cp);
  if (Lat >= Ord('A')) and (Lat <= Ord('Z')) then
    Inc(Lat, 32);
  if (Lat < Ord('a')) or (Lat > Ord('z')) then
    Exit;
  if (Event.KeyDown.ControlKeyState and kbAltShift) <> 0 then
    Big := 2
  else
    Big := 1;
  Code := ModdedKeyCode(Word(Lat - Ord('a') + Ord('A')), Big);
  if Code = 0 then
    Exit;
  Event.KeyDown.KeyCode := Code;
  Event.KeyDown.TextLength := 0;          { it is a shortcut now, not text (as Alt+X is) }
  Result := True;
end;

function XlatPlain(var Event: TEvent): Boolean;
var
  Cp, Lat: LongWord;
begin
  Result := False;
  if not XlatEnabled or (Event.What <> evKeyDown) then
    Exit;
  if (Event.KeyDown.ControlKeyState and (kbCtrlShift or kbAltShift)) <> 0 then
    Exit;
  if not FirstCodePoint(Event, Cp) or (Cp < 128) then
    Exit;
  Lat := XlatLatin(Cp);
  if Lat = 0 then
    Exit;
  Event.KeyDown.Text[0] := Char(Lat);
  Event.KeyDown.TextLength := 1;
  Event.KeyDown.CharScan.CharCode := Byte(Lat);
  Result := True;
end;

end.
