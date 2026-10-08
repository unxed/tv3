program t_clip;
{$I ../src/tvdefs.inc}
uses TvCodePg, TvClip;
{$I testlib.inc}

var
  KeptCount: Integer;
  Taken: Boolean;

{ a backend that keeps formats (the far2l terminal): takes the items when Taken }
function FakeSetItems(const Items: array of TClipItem): Boolean;
begin
  KeptCount := Length(Items);
  Result := Taken;
end;

function FakeGetItem(Format: LongWord; out Data: AnsiString): Boolean;
begin
  Data := 'from the backend';
  Result := Taken and (Format = cfHtml);
end;

var
  Stored: AnsiString;
  SysHas: Boolean;
  Fail: Boolean;
  Got: AnsiString;
  VFmt: LongWord;

function FakeSet(const Text: AnsiString): Boolean;
begin
  Result := not Fail;
  if Result then
  begin
    Stored := Text;
    SysHas := True;
  end;
end;

function FakeGet(out Text: AnsiString): Boolean;
begin
  Text := Stored;
  Result := SysHas;
end;

begin
  CpSelect(866);

  { without a system clipboard: the internal buffer }
  Check(ClipboardGetText = '', 'empty at the start');
  ClipboardSetText('hello');
  Check(ClipboardGetText = 'hello', 'the internal buffer keeps the text');
  Check(not ClipboardIsSystem, 'and it did not reach a system clipboard');

  { with a system clipboard }
  OnClipboardSet := @FakeSet;
  OnClipboardGet := @FakeGet;
  Stored := ''; SysHas := False; Fail := False;
  ClipboardSetText('Привет');
  Check(Stored = 'Привет', 'the text goes to the system clipboard');
  Check(ClipboardIsSystem, 'which is known');
  Check(ClipboardGetText = 'Привет', 'and comes back from it');
  Stored := 'from another program';
  Check(ClipboardGetText = 'from another program', 'the system clipboard has priority');
  Stored := '';
  Check(ClipboardGetText = 'Привет', 'an empty system clipboard: the internal buffer');
  Fail := True;
  ClipboardSetText('local only');
  Check(not ClipboardIsSystem, 'a failed system set is known');
  Check(ClipboardGetText = 'local only', 'the internal buffer still has the text');
  OnClipboardSet := nil;
  OnClipboardGet := nil;

  { several formats }
  VFmt := ClipboardRegisterFormat(VerticalBlockFormat);
  Check(VFmt >= cfFirstRegistered, 'a registered format is $C000 or more');
  Check(ClipboardRegisterFormat(VerticalBlockFormat) = VFmt, 'the same name, the same number');
  Check(ClipboardRegisterFormat('Other') <> VFmt, 'another name, another number');
  Check(ClipboardFormatName(VFmt) = VerticalBlockFormat, 'the name of a number');
  ClipboardSetItems([ClipItem(cfUnicodeText, 'block'), ClipItem(VFmt, #0#0#0#0)]);
  Check(ClipboardGetText = 'block', 'the text item is the text of the clipboard');
  Check(ClipboardHasItem(VFmt) and ClipboardGetItem(VFmt, Got) and (Got = #0#0#0#0), 'the other format is kept in the program');
  Check(ClipboardGetItem(cfUnicodeText, Got) and (Got = 'block'), 'the text as cfUnicodeText (UTF-8 here)');
  Check(not ClipboardHasItem(cfHtml), 'a format that was not set');
  ClipboardSetText('plain');
  Check(not ClipboardHasItem(VFmt), 'a text set alone drops the other formats');
  OnClipboardSet := @FakeSet;
  OnClipboardGet := @FakeGet;
  Stored := ''; SysHas := False; Fail := False;
  ClipboardSetItems([ClipItem(cfText, 'col'), ClipItem(VFmt, 'v')]);
  Check(ClipboardHasItem(VFmt), 'with a system clipboard of text only: the format stays in the program');
  Stored := 'copied elsewhere';
  Check(not ClipboardHasItem(VFmt), 'until the text of the system clipboard changes');
  OnClipboardSetItems := @FakeSetItems;
  OnClipboardGetItem := @FakeGetItem;
  Taken := True;
  Stored := '';
  ClipboardSetItems([ClipItem(cfText, 'x'), ClipItem(cfHtml, '<b>x</b>')]);
  Check((KeptCount = 2) and (Stored = ''), 'a backend that keeps formats takes them all');
  Check(ClipboardGetItem(cfHtml, Got) and (Got = 'from the backend'), 'and gives them');
  OnClipboardSetItems := nil;
  OnClipboardGetItem := nil;
  OnClipboardSet := nil;
  OnClipboardGet := nil;

  { conversions }
  Check(Utf8ToOem('abc') = 'abc', 'ASCII is not changed');
  Check(Utf8ToOem('Жук') = #$86#$E3#$AA, 'UTF-8 to CP866');
  Check(Utf8ToOem('a€b') = 'a?b', 'a character the page has not: ?');
  Check(Utf8ToOem(#$86) = #$86, 'a byte that is not UTF-8 is a character of the page already');
  Check(OemToUtf8(#$86#$E3#$AA) = 'Жук', 'CP866 to UTF-8');
  Check(OemToUtf8('x'#$C4'y') = 'x─y', 'a line drawing character');
  Check(OemToUtf8(Utf8ToOem('Привет, мир!')) = 'Привет, мир!', 'round trip');
  CpSelect(437);
  Check(Utf8ToOem('é') = #$82, 'CP437: e acute');
  Check(Utf8ToOem('Ж') = '?', 'CP437 has no Cyrillic');
  Check(CpSelect(1125), 'CP1125 (Ukrainian) is known');
  Check(Utf8ToOem('і') = #$F7, 'CP1125: the Ukrainian i');
  Check(Utf8ToOem('Ґ') = #$F2, 'CP1125: ge with upturn');
  Check(OemToUtf8(#$F9) = 'ї', 'CP1125: yi to UTF-8');
  Check(Utf8ToOem('Ж') = #$86, 'CP1125 keeps the Russian letters of CP866');
  CpSelect(866);

  Check(ToCrLf('a'#10'b') = 'a'#13#10'b', 'LF to CR LF');
  Check(ToCrLf('a'#13#10'b') = 'a'#13#10'b', 'CR LF stays');
  Check(ToCrLf('a'#13'b') = 'a'#13#10'b', 'a lone CR');
  Check(ToCrLf('a'#10#10'b') = 'a'#13#10#13#10'b', 'empty lines');
  Check(ToCrLf('') = '', 'empty text');
  Check(ToLf('a'#13#10'b'#13'c'#10'd') = 'a'#10'b'#10'c'#10'd', 'every break to LF');
  Check(ToLf(ToCrLf('x'#10'y')) = 'x'#10'y', 'round trip of line breaks');
  Check(Base64Encode('') = '', 'base64: empty');
  Check(Base64Encode('f') = 'Zg==', 'base64: one byte');
  Check(Base64Encode('fo') = 'Zm8=', 'base64: two bytes');
  Check(Base64Encode('foo') = 'Zm9v', 'base64: three bytes');
  Check(Base64Encode('foobar') = 'Zm9vYmFy', 'base64: six bytes');
  Check((Base64Decode('Zg==') = 'f') and (Base64Decode('Zm8=') = 'fo') and (Base64Decode('Zm9vYmFy') = 'foobar') and (Base64Decode('') = ''), 'base64: decode');
  Check(Base64Decode('Zm9v'#10'YmFy') = 'foobar', 'base64: the characters of the alphabet only are taken');
  Finish;
end.
