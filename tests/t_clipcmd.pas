program t_clipcmd;
{ The clipboard through the programs of the system (TvClipCmd, Unix): fake programs in a directory of their own are put in PATH. }
{$I ../src/tvdefs.inc}
{$H+}
uses SysUtils, BaseUnix, TvClipCmd;
{$I testlib.inc}

{$IFDEF UNIX}
var
  Dir, Store: AnsiString;
  EnvPath, EnvDisplay, EnvWayland: AnsiString;

function FakeEnv(const Name: AnsiString): AnsiString;
begin
  if Name = 'PATH' then Result := EnvPath
  else if Name = 'DISPLAY' then Result := EnvDisplay
  else if Name = 'WAYLAND_DISPLAY' then Result := EnvWayland
  else Result := '';
end;

procedure PutScript(const Name, Body: AnsiString);
var
  F: Text;
begin
  Assign(F, Dir + '/' + Name);
  Rewrite(F);
  WriteLn(F, '#!/bin/sh');
  Write(F, Body);
  Close(F);
  FpChmod(Dir + '/' + Name, &755);
end;

function Slurp(const Name: AnsiString): AnsiString;
var
  F: file;
  N: LongInt;
begin
  Result := '';
  Assign(F, Name);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then
    Exit;
  SetLength(Result, FileSize(F));
  if Length(Result) > 0 then
    BlockRead(F, Result[1], Length(Result), N);
  Close(F);
end;

procedure Spit(const Name, Text: AnsiString);
var
  F: file;
begin
  Assign(F, Name);
  Rewrite(F, 1);
  if Length(Text) > 0 then
    BlockWrite(F, Text[1], Length(Text));
  Close(F);
end;

var
  Got: AnsiString;
  T0: Int64;
  Big: AnsiString;
  I: Integer;
{$ENDIF}

begin
{$IFDEF UNIX}
  Dir := GetTempDir + 'tvclipcmd.' + IntToStr(FpGetPid);
  ForceDirectories(Dir);
  Store := Dir + '/store.txt';
  EnvPath := Dir; EnvDisplay := ''; EnvWayland := '';
  OnClipEnv := @FakeEnv;
  PutScript('xclip', 'case " $* " in'#10' *" -in "*) /bin/cat > "'+Store+'";;'#10' *" -out "*) /bin/cat "'+Store+'";;'#10'esac'#10);
  PutScript('xsel', 'case " $* " in'#10' *" --input "*) /bin/cat > "'+Store+'.xsel";;'#10' *" --output "*) /bin/cat "'+Store+'.xsel";;'#10'esac'#10);
  PutScript('wl-copy', '/bin/cat > "'+Store+'.wl"'#10);
  PutScript('wl-paste', '/bin/cat "'+Store+'.wl"'#10);

  { no display: no program }
  Check(ClipCmdSetName = '', 'without DISPLAY and WAYLAND_DISPLAY there is no program to write with');
  Check(ClipCmdGetName = '', 'or to read with');
  Check(not ClipCmdSet('x'), 'so writing fails');
  Check(not ClipCmdGet(Got), 'and reading');

  { X11: xsel is tried before xclip (the list of tvision: wl-copy, xsel, xclip) }
  EnvDisplay := ':0';
  Check(Pos('/xsel', ClipCmdSetName) > 0, 'with DISPLAY: xsel is the first program that writes');
  Check(Pos('/xsel', ClipCmdGetName) > 0, 'and reads');
  Check(ClipCmdSet('Привет'#10'мир'), 'writing through xsel');
  Check(Slurp(Store + '.xsel') = 'Привет'#10'мир', 'the text arrived as it is (UTF-8, line break)');
  Check(ClipCmdGet(Got) and (Got = 'Привет'#10'мир'), 'reading through xsel');

  { xclip alone }
  FpUnlink(Dir + '/xsel');
  Check(Pos('/xclip', ClipCmdSetName) > 0, 'without xsel: xclip');
  Check(ClipCmdSet('abc'#0'def') and (Slurp(Store) = 'abc'#0'def'), 'xclip: the text with a NUL goes whole');
  Check(ClipCmdGet(Got) and (Got = 'abc'#0'def'), 'xclip: and comes back whole');

  { Wayland first }
  EnvWayland := 'wayland-0';
  Check(Pos('/wl-copy', ClipCmdSetName) > 0, 'with WAYLAND_DISPLAY: wl-copy comes first');
  Check(ClipCmdSet('wl text') and (Slurp(Store + '.wl') = 'wl text'), 'writing through wl-copy');
  Check(ClipCmdGet(Got) and (Got = 'wl text'), 'reading through wl-paste');
  EnvWayland := '';

  { a big text }
  Big := '';
  for I := 1 to 20000 do
    Big := Big + 'line ' + IntToStr(I) + ' Жук'#10;
  Check(ClipCmdSet(Big) and (Slurp(Store) = Big), 'a text of ' + IntToStr(Length(Big)) + ' bytes is written');
  Check(ClipCmdGet(Got) and (Got = Big), 'and read back');

  { an empty clipboard: the program gives nothing and ends with 0: the text is empty and the call succeeds }
  Spit(Store, '');
  Check(ClipCmdGet(Got) and (Got = ''), 'an empty clipboard is an empty text');

  { programs that fail or hang }
  PutScript('xclip', 'exit 1'#10);
  Check(not ClipCmdSet('x'), 'a program that fails: writing fails');
  Check(not ClipCmdGet(Got), 'and reading');
  PutScript('xclip', '/bin/sleep 20'#10);
  T0 := Int64(GetTickCount64);
  Check(not ClipCmdSet('x'), 'a program that hangs: writing fails');
  Check(Int64(GetTickCount64) - T0 < 4000, 'after the time out (1.5 s), the program is killed');
  T0 := Int64(GetTickCount64);
  Check(not ClipCmdGet(Got), 'and reading fails');
  Check(Int64(GetTickCount64) - T0 < 4000, 'also within the time out');

  { clean up }
  FpUnlink(Dir + '/xclip'); FpUnlink(Dir + '/wl-copy'); FpUnlink(Dir + '/wl-paste');
  FpUnlink(Store); FpUnlink(Store + '.xsel'); FpUnlink(Store + '.wl');
  RemoveDir(Dir);
{$ELSE}
  Check(not ClipCmdSet('x'), 'there are no programs here');
{$ENDIF}
  Finish;
end.
