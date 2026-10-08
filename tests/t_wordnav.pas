program t_wordnav;
{$I ../src/tvdefs.inc}
uses TvWordNav;
{$I testlib.inc}

{ the positions that Ctrl+Right visits from 0, as a string of numbers }
function Walk(const S: ShortString; Right, Fine: Boolean): ShortString;
var
  P, N: Integer;
  T: ShortString;
begin
  Result := '';
  if Right then
    P := 0
  else
    P := Length(S);
  repeat
    if Right then
      N := WordNavRight(S, P, Fine)
    else
      N := WordNavLeft(S, P, Fine);
    Str(N, T);
    Result := Result + T + ' ';
    P := N;
  until (Right and (P >= Length(S))) or (not Right and (P <= 0));
end;

begin
  Check(WordClassOf(' ') = wnSpace, 'a space is a space');
  Check(WordClassOf('.') = wnDivider, 'a dot is a divider');
  Check((WordClassOf('_') = wnWord) and (WordClassOf('$') = wnWord) and (WordClassOf('#') = wnWord) and (WordClassOf('@') = wnWord), '_ $ # @ are word characters');
  Check(WordClassOf(#$D0) = wnWord, 'a non-ASCII byte is a word character');

  { WORDNAV.md: foo.bar takes two jumps to the right }
  Check(Walk('foo.bar', True, False) = '3 7 ', 'Ctrl+Right: foo.bar takes two jumps');
  Check(Walk('foo.bar', False, False) = '4 0 ', 'Ctrl+Left: foo.bar takes two jumps');
  Check(Walk('...///', True, False) = '6 ', 'a run of mixed dividers is crossed in one jump');
  Check(Walk('foo bar baz', True, False) = '4 8 11 ', 'Ctrl+Right stops at the start of the next token (not before a space)');
  Check(Walk('foo bar baz', False, False) = '8 4 0 ', 'Ctrl+Left stops at the start of a word');
  Check(Walk('a.-/b', True, False) = '1 5 ', 'a.-/b: a| then the end of the field');
  Check(Walk('a.-/b', True, True) = '1 2 3 4 5 ', 'Ctrl+Shift+Right in a field visits every position of the divider run');
  Check(Walk('foo bar', True, True) = '4 7 ', 'Ctrl+Shift+Right in a field does not stop before a space');
  Check(Walk('foo bar', False, True) = '4 0 ', 'Ctrl+Shift+Left in a field');
  Check(Walk('a.-/b', False, True) = '4 3 2 0 ', 'Ctrl+Shift+Left: every divider but the one after a word character');
  Check(WordNavRight('abc', 3) = 3, 'at the end: stays');
  Check(WordNavLeft('abc', 0) = 0, 'at the start: stays');
  Check(WordNavRight('', 0) = 0, 'an empty line');
  Finish;
end.
