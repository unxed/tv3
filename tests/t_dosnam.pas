program t_dosnam;
{ TvDosNames: a name at the border of a DOS with UTF-8 names, for a program with a code page inside. }
{$I ../src/tvdefs.inc}
uses TvCodePg, TvUtf8, TvDosNames;
{$I testlib.inc}

const
  Privet_cp866 = #$8F#$E0#$A8#$A2#$A5#$E2;                       { "Привет" on cp866 }
  Privet_utf8 = #$D0#$9F#$D1#$80#$D0#$B8#$D0#$B2#$D0#$B5#$D1#$82;
  Japanese_utf8 = #$E6#$97#$A5#$E6#$9C#$AC#$E8#$AA#$9E;         { 日本語: not on cp866 }

begin
  CpSelect(866);

  NamesUtf8 := False;
  Check(DosNameToUtf8(Privet_cp866) = Privet_cp866, 'without the provider a name goes as it is');
  Check(DosNameFromUtf8(Privet_utf8) = Privet_utf8, 'without the provider a name comes as it is');

  NamesUtf8 := True;
  Check(DosNameToUtf8(Privet_cp866) = Privet_utf8, 'a name of the page goes as UTF-8');
  Check(DosNameFromUtf8(Privet_utf8) = Privet_cp866, 'a UTF-8 name comes as the bytes of the page');
  Check(DosNameToUtf8('readme.txt') = 'readme.txt', 'ASCII is not changed (to)');
  Check(DosNameFromUtf8('readme.txt') = 'readme.txt', 'ASCII is not changed (from)');
  Check(DosNameToUtf8(Privet_cp866 + '.' + 'txt') = Privet_utf8 + '.txt', 'the extension stays');

  { a character that the page cannot show: the escape U+XXXX in braces, and the character again on the way back }
  Check(DosNameFromUtf8(Japanese_utf8) = '{U+65E5}{U+672C}{U+8A9E}', 'a name outside the page comes as the escapes');
  Check(DosNameToUtf8('{U+65E5}{U+672C}{U+8A9E}') = Japanese_utf8, 'and the escapes go back as the characters');
  Check(DosNameFromUtf8(Privet_utf8 + Japanese_utf8) = Privet_cp866 + '{U+65E5}{U+672C}{U+8A9E}', 'a mixed name: the page bytes and the escapes');
  Check(DosNameToUtf8(Privet_cp866 + '{U+65E5}') = Privet_utf8 + #$E6#$97#$A5, 'a mixed name goes back');
  Check(DosNameFromUtf8('a{U+x}') = 'a{U+007B}U+x}', 'a { that starts the text of an escape is escaped');
  Check(DosNameToUtf8('a{U+007B}U+x}') = 'a{U+x}', 'and read back');

  { not UTF-8: as it is }
  Check(DosNameFromUtf8(#$FF#$FE'a') = #$FF#$FE'a', 'bytes that are not UTF-8 come as they are');

  Check(DosNameFromUtf8(DosNameToUtf8(Privet_cp866)) = Privet_cp866, 'the way there and back');

  { the general pair: a program with UTF-8 inside (TvUtf8.Utf8Enabled) }
  NamesUtf8 := False;
  NamesMapped := False;
  Check(NameToDos(Privet_utf8) = Privet_utf8, 'NameToDos does nothing unless the names are mapped');
  NamesMapped := True;
  Utf8Enabled := True;
  NamesUtf8 := True;
  Check(NameToDos(Privet_utf8) = Privet_utf8, 'UTF-8 program, UTF-8 DOS: as it is');
  Check(NameFromDos(Privet_utf8) = Privet_utf8, 'UTF-8 program, UTF-8 DOS: as it is (from)');
  NamesUtf8 := False;
  NamesProvider := False;
  Check(NameToDos(Privet_utf8) = Privet_cp866, 'UTF-8 program, DOS page: the bytes of the page');
  Check(NameFromDos(Privet_cp866) = Privet_utf8, 'UTF-8 program, DOS page: from the bytes of the page');
  Check(NameToDos(Japanese_utf8) = '___', 'a character that the page lacks is _ without a provider');
  NamesProvider := True;
  Check(NameToDos(Japanese_utf8) = '{U+65E5}{U+672C}{U+8A9E}', 'a character that the page lacks is {U+XXXX} with a provider');
  Check(NameToDos('a' + Japanese_utf8 + '.txt') = 'a{U+65E5}{U+672C}{U+8A9E}.txt', 'the rest of the name stays');
  Check(NameFromDos('{U+65E5}{U+672C}{U+8A9E}') = Japanese_utf8, '{U+XXXX} from the DOS is the character');
  Check(NameFromDos(Privet_cp866 + '{U+65E5}') = Privet_utf8 + #$E6#$97#$A5, 'bytes of the page and an escape in one name');
  Check(NameFromDos(NameToDos(Privet_utf8 + Japanese_utf8)) = Privet_utf8 + Japanese_utf8, 'the way there and back with an escape');
  Check(NameToDos('{U+x}') = '{U+007B}U+x}', 'a { that starts the text of an escape is escaped');
  Check(NameFromDos('{U+007B}U+x}') = '{U+x}', 'and read back');
  Check(NameFromDos('{U+12}') = '{U+12}', 'less than 4 digits is no escape');
  Check(NameFromDos('{U+110000}') = '{U+110000}', 'above U+10FFFF is no escape');
  NamesProvider := False;
  Check(NameFromDos('{U+65E5}') = '{U+65E5}', 'without a provider {U+XXXX} is plain text');
  { a program with a page inside }
  Utf8Enabled := False;
  NamesUtf8 := True;
  Check(NameToDos(Privet_cp866) = Privet_utf8, 'page program, UTF-8 DOS: to UTF-8');
  NamesUtf8 := False;
  Check(NameToDos(Privet_cp866) = Privet_cp866, 'page program, DOS page: as it is');
  Utf8Enabled := True;
  NamesMapped := False;
  Finish;
end.
