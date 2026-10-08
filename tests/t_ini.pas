program t_ini;
{ TvIni: INI files that keep what the user wrote. }
{$I ../src/tvdefs.inc}
uses SysUtils, TvIni;
{$I testlib.inc}

const
  Text1 = '; the top comment'#10'Comment=Do NOT delete'#10#10'[Files]'#10'OpenExts=''*.pas;*.pp'' ;the masks'#10'Count = 5'#10'; between'#10'Name="it''s"'#10 +
          '[Other]'#10'Flag=1'#10;

var
  Ini: TIniFile;
  Seen: Integer;
  T: AnsiString;

procedure CountEntries;
  procedure One(E: PIniEntry);
  begin
    Inc(Seen);
  end;
begin
  Ini.ForEachEntry('Files', @One);
end;

procedure CountSections;
  procedure One(S: PIniSection);
  begin
    Inc(Seen);
  end;
begin
  Ini.ForEachSection(@One);
end;

begin
  Ini := TIniFile.Create('');
  Ini.LoadFromText(Text1);
  Check(Ini.SectionCount = 3, 'three sections: the main one (before the first header), Files, Other');
  Check(Ini.GetEntry(MainSectionName, 'Comment', '') = 'Do NOT delete', 'an entry before the first section');
  Check(Ini.GetEntry('Files', 'OpenExts', '') = '*.pas;*.pp', 'a quoted value keeps its ;');
  Check(Ini.SearchEntry('Files', 'OpenExts').GetComment = 'the masks', 'the comment after a quoted value');
  Check(Ini.GetIntEntry('files', 'COUNT', 0) = 5, 'case does not matter; spaces around =');
  Check(Ini.GetEntry('Files', 'Name', '') = 'it''s', 'a doubled quote is one quote');
  Check(Ini.GetEntry('Files', 'Nope', 'dflt') = 'dflt', 'the default of a missing tag');
  Check(Ini.GetBoolEntry('Other', 'Flag', False), 'a boolean');
  Check(not Ini.IsModified, 'reading changes nothing');
  Check(Ini.SaveToText = Text1, 'saving what was read gives the same text');

  Ini.SetEntry('Files', 'Count', '5');
  Check(not Ini.IsModified, 'setting the same value changes nothing');
  Ini.SetIntEntry('Files', 'Count', 6);
  Check(Ini.IsModified, 'a changed value is a change');
  T := Ini.SaveToText;
  Check(Pos('Count=6'#10, T) > 0, 'the changed entry is written');
  Check(Pos('OpenExts=''*.pas;*.pp'' ;the masks'#10, T) > 0, 'the other entries stay as they were');
  Check(Pos('; between'#10, T) > 0, 'the comment lines stay');

  Ini.SetEntry('Files', 'Path', 'a;b c');
  Check(Pos('Path=''a;b c'''#10, Ini.SaveToText) > 0, 'a value with ; is quoted when written');
  Ini.SetEntry('Files', 'Q', 'x''y;z');
  Check(Pos('Q="x''y;z"'#10, Ini.SaveToText) > 0, 'the other kind of quote when the value has the first one');
  Ini.SetEntry('Files', 'Sp', '  pad ');
  Check(Ini.GetEntry('Files', 'Sp', '') = '  pad ', 'spaces at the ends survive in quotes');
  T := Ini.SaveToText;
  Ini.LoadFromText(T);
  Check(Ini.GetEntry('Files', 'Path', '') = 'a;b c', 'it reads back: ;');
  Check(Ini.GetEntry('Files', 'Q', '') = 'x''y;z', 'it reads back: quotes');
  Check(Ini.GetEntry('Files', 'Sp', '') = '  pad ', 'it reads back: spaces');

  Ini.SetEntry('New', 'A', 'b');
  Check(Ini.GetEntry('New', 'A', '') = 'b', 'a new section and entry');
  Ini.SetEntry('New', 'Empty', '');
  Check(not Ini.EntryExists('New', 'Empty'), 'an empty value of a missing tag is not written');
  Ini.DeleteEntry('New', 'A');
  Check(not Ini.EntryExists('New', 'A'), 'DeleteEntry');
  Ini.DeleteSection('Other');
  Check(Ini.SearchSection('Other') = nil, 'DeleteSection');

  Seen := 0; CountEntries;
  Check(Seen >= 5, 'ForEachEntry skips lines that are no entries');
  Seen := 0; CountSections;
  Check(Seen = Ini.SectionCount, 'ForEachSection');

  Ini.MakeNullEntries := True;
  Ini.GetEntry('Files', 'Fresh', 'x');
  Check(Ini.EntryExists('Files', 'Fresh'), 'MakeNullEntries: reading adds the tag with the default');

  Ini.LoadFromText('a=1'#13#10'[S]'#13#10'b=2'#13#10);
  Check(Ini.SaveToText = 'a=1'#13#10'[S]'#13#10'b=2'#13#10, 'CR LF is kept');
  Ini.LoadFromText(#$EF#$BB#$BF'[S]'#10'b=2'#10);
  Check(Ini.GetEntry('S', 'b', '') = '2', 'a byte order mark is skipped');
  Check(Copy(Ini.SaveToText, 1, 3) = #$EF#$BB#$BF, 'and written back');
  Ini.LoadFromText('[S]'#10'p=Привет'#10);
  Check(Ini.GetEntry('S', 'p', '') = 'Привет', 'UTF-8 goes through unchanged');
  Ini.Free;

  { the Windows profile way }
  Ini := TIniFile.Create('');
  Ini.InlineComments := False;
  Ini.LoadFromText('[App]'#13#10'Cmd=a -r ; b'#13#10'Q=''x'''#13#10'; note'#13#10);
  Check(Ini.GetEntry('App', 'Cmd', '') = 'a -r ; b', 'raw: ; in a value is no comment');
  Check(Ini.GetEntry('App', 'Q', '') = 'x', 'raw: the quotes of the ends are not a part of the value');
  Ini.SetEntry('App', 'New', 'p;q');
  Check(Pos('New=p;q'#13#10, Ini.SaveToText) > 0, 'raw: written as it is');
  Ini.Free;

  { a file }
  T := GetTempDir + 't_ini_' + IntToStr(GetProcessID) + '.ini';
  Ini := TIniFile.Create(T);
  Check(not Ini.Read, 'a missing file: Read is False');
  Ini.SetEntry('A', 'x', '1');
  Check(Ini.Update, 'Update writes');
  Check(not Ini.IsModified, 'and the file is not modified any more');
  Ini.Free;
  Ini := TIniFile.Create(T);
  Check(Ini.Read, 'the file is read back');
  Check(Ini.GetIntEntry('A', 'x', 0) = 1, 'the value of the file');
  Ini.Free;
  DeleteFile(T);
  Finish;
end.
