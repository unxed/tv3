{ The help compiler tvhc (tv/tools/tvhc.pas): the test builds it with fpc (the tool is a program, not a unit), compiles a text
  of a help and reads the file with THelpFile. Run in tv/tests (as the others). }
program t_tvhc;
{$I ../src/tvdefs.inc}
uses SysUtils, Classes, TvGeom, TvObjs, TvHelp;
{$I testlib.inc}

const
  Htx = 't_tvhc.htx';
  Hlp = 't_tvhc.hlp';
  Bad = 't_tvhc_bad.htx';
  Sym = 't_tvhc_sym.pas';

procedure WriteText(const Name: string; const Lines: array of string);
var
  F: TextFile;
  I: Integer;
begin
  AssignFile(F, Name);
  Rewrite(F);
  for I := 0 to High(Lines) do
    Writeln(F, Lines[I]);
  CloseFile(F);
end;

function ReadAll(const Name: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  L.LoadFromFile(Name);
  Result := L.Text;
  L.Free;
end;

var
  Tool, Fpc, BuildDir: string;
  SR: TSearchRec;
  HF: THelpFile;
  T: THelpTopic;
  P: TPoint;
  L: Byte;
  Rf: Integer;
begin
  { Keep compiler output outside the source tree and use a fresh directory per run. }
  BuildDir := GetTempFileName(GetTempDir(False), 'tv3');
  DeleteFile(BuildDir);
  ForceDirectories(BuildDir);
  Fpc := ExeSearch('fpc', GetEnvironmentVariable('PATH'));
  if (Fpc = '') or (ExecuteProcess(Fpc, ['-Fu../src', '-FU' + BuildDir, '-FE' + BuildDir, '-vewn', '../tools/tvhc.pas']) <> 0) then
  begin
    Writeln('cannot build tvhc (is fpc in the path? cwd must be tv/tests)');
    Halt(1);
  end;
  Tool := BuildDir + DirectorySeparator + 'tvhc';

  WriteText(Htx, [
    '; a comment',
    '.topic First=1   ; a comment of the line',
    '.title The first',
    'See {the second:Second} and {Second}.',
    '',
    #179'kept line one',
    #179'kept line two',
    '',
    '.topic Second=300, Alias {an author}',
    'A {{ brace and {a::b:Third}.',
    '.topic Third',
    'The next number.',
    '.topic Empty=900',
    '',
    '.topic Last',
    'See {nowhere}.']);
  Check(ExecuteProcess(Tool, [Htx, Hlp, Sym, '/4DN_OSP']) = 0, 'a good text is compiled (a reference to nowhere is a warning)');

  RegisterType(RHelpTopic);
  RegisterType(RHelpIndex);
  HF := THelpFile.Create(TBufStream.Create(Hlp, stOpenRead, 1024));
  T := HF.GetTopic(1);
  T.SetWidth(40);
  Check(Copy(T.GetLine(1), 1, 1) = #218, '.title: a box, line 1');
  Check(T.GetLine(2) = #179' The first '#219, '.title: a box, line 2: ' + T.GetLine(2));
  Check(T.GetLine(5) = 'See the second and Second.', 'braces are cut: ' + T.GetLine(5));
  Check(T.GetNumCrossRefs = 2, 'topic 1 has two references');
  T.GetCrossRef(0, P, L, Rf);
  Check((Rf = 300) and (L = 10) and (P.X = 4) and (P.Y = 5), 'the reference "the second:Second" leads to 300 (column 4, length 10)');
  T.GetCrossRef(1, P, L, Rf);
  Check((Rf = 300) and (L = 6) and (P.X = 19), 'the reference "Second" leads to 300 (column 19, length 6)');
  Check(T.GetLine(7) = 'kept line one', 'a paragraph of bars is not wrapped, the bar is cut: ' + T.GetLine(7));
  Check(T.GetLine(8) = 'kept line two', '... and its next line');
  T.Free;

  T := HF.GetTopic(300);
  Check(T.GetLine(1) = 'A { brace and a:b.', 'a brace and a colon are escaped by doubling: ' + T.GetLine(1));
  T.GetCrossRef(0, P, L, Rf);
  Check(Rf = 302, 'the reference leads to Third = 302 (the counter goes on after 300, 301): ' + IntToStr(Rf));
  T.Free;
  T := HF.GetTopic(301);
  Check(T.GetLine(1) = 'A { brace and a:b.', 'Alias (301) is the same text');
  T.Free;
  T := HF.GetTopic(302);
  Check(T.GetLine(1) = 'The next number.', 'Third has the number 302');
  T.Free;
  T := HF.GetTopic(900);
  Check(Pos('No help available', T.GetLine(2)) > 0, 'a topic with no text is not in the file');
  T.Free;
  T := HF.GetTopic(901);
  T.GetCrossRef(0, P, L, Rf);
  Check(Rf = 65535, 'a reference to a topic that is not there leads to 65535');
  T.Free;
  HF.Free;
  Check(Pos('hcThird', ReadAll(Sym)) > 0, 'the unit of the constants has hcThird');

  { a text in UTF-8 (the help of DN built with -dDNUTF8): the box of .title is as wide as the text in columns }
  WriteText('t_tvhc_u8.htx', ['.topic U=1', '.title Привет', 'Текст.']);
  Check(ExecuteProcess(Tool, ['t_tvhc_u8.htx', 't_tvhc_u8.hlp', 't_tvhc_u8.sym', '/4DN_OSP']) = 0, 'a text in UTF-8 is compiled');
  HF := THelpFile.Create(TBufStream.Create('t_tvhc_u8.hlp', stOpenRead, 1024));
  T := HF.GetTopic(1);
  T.SetWidth(40);
  Check(T.GetLine(1) = #218 + StringOfChar(#196, 8), '.title in UTF-8: the top of the box has 6 + 2 columns: ' + IntToStr(Length(T.GetLine(1))));
  T.Free;
  HF.Free;
  DeleteFile('t_tvhc_u8.htx'); DeleteFile('t_tvhc_u8.hlp'); DeleteFile('t_tvhc_u8.sym');

  WriteText(Bad, ['.topic A=1', 'a {b:Nowhere']);
  Check(ExecuteProcess(Tool, [Bad, 't_tvhc_bad.hlp']) <> 0, 'an unterminated reference is an error');
  Check(not FileExists('t_tvhc_bad.hlp'), '... and no file is written');

  DeleteFile(Htx); DeleteFile(Hlp); DeleteFile(Bad); DeleteFile(Sym);
  if FindFirst(BuildDir + DirectorySeparator + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
        DeleteFile(BuildDir + DirectorySeparator + SR.Name);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  RemoveDir(BuildDir);
  Finish;
end.
