program t_wild;
{ TvWild: file masks. }
{$I ../src/tvdefs.inc}
uses TvUtf8, TvWild;
{$I testlib.inc}

const
  Privet = #$D0#$9F#$D1#$80#$D0#$B8#$D0#$B2#$D0#$B5#$D1#$82;      { Привет }

begin
  Utf8Enabled := True;
  Check(WildMatch('readme.txt', '*.txt'), '*.txt');
  Check(not WildMatch('readme.txt', '*.pas'), '*.pas does not');
  Check(WildMatch('README.TXT', '*.txt'), 'case is ignored');
  Check(not WildMatch('README.TXT', '*.txt', True), 'case is kept on request');
  Check(WildMatch('a.b.c', '*.c'), 'the star takes dots');
  Check(WildMatch('abc', 'a?c'), '?');
  Check(not WildMatch('ac', 'a?c'), '? needs a character');
  Check(WildMatch('abc', '*'), 'a lone star');
  Check(WildMatch('noext', '*.*'), '*.* is every name, as in DOS');
  Check(WildMatch('', '*'), 'the star matches the empty name');
  Check(WildMatch('abc', 'a*b*c'), 'two stars');
  Check(WildMatch('aXbXc', 'a*b*c'), 'two stars with text');
  Check(not WildMatch('abcd', 'a*b*c'), 'two stars: the end must match');
  Check(WildMatch('aaa', 'a*a'), 'backtracking');
  Check(WildMatch('b.pas', '[a-c].pas'), 'a range');
  Check(not WildMatch('d.pas', '[a-c].pas'), 'out of the range');
  Check(WildMatch('d.pas', '[!a-c].pas'), 'a negated set');
  Check(WildMatch('[x', '[x'), 'a [ that is no set is a plain character');
  Check(WildMatch(Privet + '.txt', #$D0#$BF'*.TXT'), 'Cyrillic, case ignored');
  Check(WildMatch(Privet, '??????'), '? is a character, not a byte');
  Check(not WildMatch(Privet, '?????????????'), '? is not a byte (too many)');

  Check(WildMatchList('a.pas', '*.pas;*.inc'), 'a list: the first');
  Check(WildMatchList('a.inc', '*.pas;*.inc'), 'a list: the second');
  Check(WildMatchList('a.inc', '*.pas, *.inc'), 'a list with , and spaces');
  Check(not WildMatchList('a.txt', '*.pas;*.inc'), 'a list: none');
  Check(not WildMatchList('test.pas', '*.pas|test*'), 'an exclusion');
  Check(WildMatchList('main.pas', '*.pas|test*'), 'not excluded');
  Check(WildMatchList('main.pas', '|test*'), 'only exclusions: the rest is wanted');
  Check(not WildMatchList('test1', '|test*'), 'only exclusions: the excluded is not');
  Check(not WildMatchList('a', ''), 'an empty list matches nothing');
  Check(HasWild('a*b') and HasWild('a?') and HasWild('[a]') and not HasWild('abc'), 'HasWild');
  Finish;
end.
