{ TvWordNav: the word boundaries of Ctrl+Left and Ctrl+Right in an input field, by the rules of the navigation guidelines of vtui (WORDNAV.md): three character classes (space, divider, word) and stop conditions on the pair of characters around the new cursor position.

  MIT (see LICENSE).

  A position is the number of bytes before the cursor (0 .. Length(S)). The text is a byte string: every byte of $80 and above is a word character, so the
  stops fall between ASCII bytes and a multi-byte character is never split (the step of at least one character is the job of the caller). }
unit TvWordNav;

{$I tvdefs.inc}

interface

const
  wnSpace = 0;
  wnDivider = 1;
  wnWord = 2;

var
  { UX guidelines of vtui: Ctrl+Left and Ctrl+Right in input fields follow these rules; False: the classic jump over blanks only }
  UxWordNav: Boolean = True;
  { the word dividers (a space and a tab are not among them) }
  WordDividers: ShortString = '~!%^&*()+|{}:"<>?`-=\[];'',./';

function WordClassOf(Ch: Char): Integer;

{ The position after Ctrl+Right (Fine = False) or Ctrl+Shift+Right in an input field (Fine = True), starting at Pos; it moves at least one byte. }
function WordNavRight(const S: ShortString; Pos: Integer; Fine: Boolean = False): Integer;

{ The same to the left. }
function WordNavLeft(const S: ShortString; Pos: Integer; Fine: Boolean = False): Integer;

implementation

function WordClassOf(Ch: Char): Integer;
begin
  if (Ch = ' ') or (Ch = #9) then
    Result := wnSpace
  else if (Ch < #128) and (Pos(Ch, WordDividers) > 0) then
    Result := wnDivider
  else
    Result := wnWord;
end;

{ Q is the new position, the character before it and the one at it }
function StopsRight(const S: ShortString; Q: Integer; Fine: Boolean): Boolean;
var
  Prev, Curr: Integer;
begin
  if Q >= Length(S) then
    Exit(True);
  Prev := WordClassOf(S[Q]);
  Curr := WordClassOf(S[Q + 1]);
  if Fine then
    { everywhere except inside a word and before a space }
    Result := not ((Prev = wnWord) and (Curr = wnWord)) and (Curr <> wnSpace)
  else
    Result := ((Prev = wnSpace) and (Curr <> wnSpace)) or ((Prev = wnWord) and (Curr = wnDivider));
end;

function StopsLeft(const S: ShortString; Q: Integer; Fine: Boolean): Boolean;
var
  Prev, Curr: Integer;
begin
  if Q <= 0 then
    Exit(True);
  Prev := WordClassOf(S[Q]);
  Curr := WordClassOf(S[Q + 1]);
  if Fine then
    { everywhere except inside a word, before a space and on a divider that follows a word character }
    Result := not ((Prev = wnWord) and (Curr = wnWord)) and (Curr <> wnSpace) and not ((Prev = wnWord) and (Curr = wnDivider))
  else
    Result := ((Prev = wnSpace) and (Curr <> wnSpace)) or ((Prev = wnDivider) and (Curr = wnWord));
end;

function WordNavRight(const S: ShortString; Pos: Integer; Fine: Boolean): Integer;
begin
  Result := Pos;
  if Result >= Length(S) then
    Exit(Length(S));
  repeat
    Inc(Result);
  until StopsRight(S, Result, Fine);
end;

function WordNavLeft(const S: ShortString; Pos: Integer; Fine: Boolean): Integer;
begin
  Result := Pos;
  if Result <= 0 then
    Exit(0);
  repeat
    Dec(Result);
  until StopsLeft(S, Result, Fine);
end;

end.
