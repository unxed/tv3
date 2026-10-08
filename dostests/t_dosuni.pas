program t_dosuni;
{ UTF-8 file names under a DOS that has the provider DOS-UTF8/NAMES (DOSBox-X from October 2026, option "utf8 file names").
  The program has UTF-8 inside. It prints the state of the provider, the names of the current directory as the program sees them (NameFromDos), and
  makes a file with a name of its own (NameToDos); dostests/utf8-names.sh runs it and checks the output and the host directory.
  TV_DOS_UTF8_NAMES=0 in the DOS environment keeps the code page: the same names then come in the form of the code page and U+XXXX in braces. }
{$I ../src/tvdefs.inc}
uses Dos, SysUtils, TvCodePg, TvUtf8, TvDosNames, TvDos;

const
  NewName = #$D0#$BD#$D0#$BE#$D0#$B2#$D1#$8B#$D0#$B9'.txt';       { новый.txt }
  NewName2 = #$E6#$96#$B0'.txt';                                  { 新.txt }

var
  SR: TSearchRec;
  F: Text;
  Names: array[0..63] of string;
  N, I, J: Integer;
  T: string;

procedure MakeFile(const Name: string);
begin
  Assign(F, NameToDos(Name));
  {$I-}
  Rewrite(F);
  {$I+}
  if IOResult = 0 then
  begin
    WriteLn(F, 'made by t_dosuni');
    Close(F);
    WriteLn('MADE:', Name);
  end
  else
    WriteLn('NOTMADE:', Name);
end;

begin
  Utf8Enabled := True;
  DosNamesInit;
  WriteLn('PROVIDER:', Ord(NamesProvider));
  WriteLn('UTF8MODE:', Ord(NamesUtf8));
  WriteLn('LFN:', Ord(LFNSupport));
  WriteLn('CODEPAGE:', CpCurrent);
  MakeFile(NewName);
  MakeFile(NewName2);
  N := 0;
  if FindFirst(NameToDos('*'), faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and (N < 64) then
      begin
        Names[N] := NameFromDos(SR.Name);
        Inc(N);
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  for I := 0 to N - 2 do                                          { sorted: the order of the directory is not the same everywhere }
    for J := I + 1 to N - 1 do
      if Names[J] < Names[I] then
      begin
        T := Names[I]; Names[I] := Names[J]; Names[J] := T;
      end;
  for I := 0 to N - 1 do
    WriteLn('ENTRY:', Names[I]);
  WriteLn('END');
end.
