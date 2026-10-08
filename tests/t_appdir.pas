program t_appdir;
{ TvAppDir: the directories of a program on XDG systems, macOS, Windows and DOS (on any system), and the native ones. }
{$I ../src/tvdefs.inc}
uses
{$IFDEF UNIX}
  BaseUnix,
{$ENDIF}
  SysUtils, TvPath, TvAppDir;
{$I testlib.inc}

var
  EnvNames, EnvValues: array of AnsiString;

procedure SetEnv(const Name, Value: AnsiString);
var
  I: Integer;
begin
  for I := 0 to High(EnvNames) do
    if EnvNames[I] = Name then
    begin
      EnvValues[I] := Value;
      Exit;
    end;
  I := Length(EnvNames);
  SetLength(EnvNames, I + 1);
  SetLength(EnvValues, I + 1);
  EnvNames[I] := Name;
  EnvValues[I] := Value;
end;

procedure ClearEnv;
begin
  SetLength(EnvNames, 0);
  SetLength(EnvValues, 0);
end;

function FakeEnv(const Name: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(EnvNames) do
    if EnvNames[I] = Name then
      Exit(EnvValues[I]);
end;

function D(Kind: TAppDirKind; Sys: TAppDirSystem): AnsiString;
begin
  Result := AppDirIn(Kind, 'app', Sys, @FakeEnv, 'C:\PROG', 'APPDIR');
end;

var
  Tmp, Dir: AnsiString;
{$IFDEF UNIX}
  St: TStat;
{$ENDIF}
begin
  { XDG: the defaults under HOME }
  ClearEnv;
  SetEnv('HOME', '/home/u');
  Check(D(adConfig, adsXdg) = '/home/u/.config/app', 'XDG config default');
  Check(D(adData, adsXdg) = '/home/u/.local/share/app', 'XDG data default');
  Check(D(adState, adsXdg) = '/home/u/.local/state/app', 'XDG state default');
  Check(D(adCache, adsXdg) = '/home/u/.cache/app', 'XDG cache default');
  SetEnv('HOME', '/home/u/');
  Check(D(adConfig, adsXdg) = '/home/u/.config/app', 'XDG: HOME with a separator at the end');

  { XDG: the variables }
  SetEnv('XDG_CONFIG_HOME', '/c');
  SetEnv('XDG_DATA_HOME', '/d/');
  SetEnv('XDG_STATE_HOME', '/s');
  SetEnv('XDG_CACHE_HOME', '/k');
  Check(D(adConfig, adsXdg) = '/c/app', 'XDG_CONFIG_HOME');
  Check(D(adData, adsXdg) = '/d/app', 'XDG_DATA_HOME');
  Check(D(adState, adsXdg) = '/s/app', 'XDG_STATE_HOME');
  Check(D(adCache, adsXdg) = '/k/app', 'XDG_CACHE_HOME');

  { XDG: a relative value is ignored }
  SetEnv('XDG_CONFIG_HOME', 'rel/c');
  SetEnv('XDG_STATE_HOME', './s');
  Check(D(adConfig, adsXdg) = '/home/u/.config/app', 'XDG: a relative XDG_CONFIG_HOME is ignored');
  Check(D(adState, adsXdg) = '/home/u/.local/state/app', 'XDG: a relative XDG_STATE_HOME is ignored');

  { XDG: no HOME }
  ClearEnv;
  Check(D(adConfig, adsXdg) = '', 'XDG: no HOME, no directory');
  SetEnv('XDG_CACHE_HOME', '/k');
  Check(D(adCache, adsXdg) = '/k/app', 'XDG: the variable without HOME');
  SetEnv('HOME', 'home');
  Check(D(adConfig, adsXdg) = '', 'XDG: a relative HOME is ignored');

  { macOS }
  ClearEnv;
  SetEnv('HOME', '/Users/u');
  SetEnv('XDG_CONFIG_HOME', '/c');
  Check(D(adConfig, adsMac) = '/Users/u/Library/Application Support/app', 'macOS config');
  Check(D(adData, adsMac) = '/Users/u/Library/Application Support/app', 'macOS data');
  Check(D(adState, adsMac) = '/Users/u/Library/Application Support/app', 'macOS state');
  Check(D(adCache, adsMac) = '/Users/u/Library/Caches/app', 'macOS cache');
  ClearEnv;
  Check(D(adConfig, adsMac) = '', 'macOS: no HOME, no directory');

  { Windows }
  ClearEnv;
  SetEnv('APPDATA', 'C:\Users\u\AppData\Roaming');
  SetEnv('LOCALAPPDATA', 'C:\Users\u\AppData\Local\');
  Check(D(adConfig, adsWindows) = 'C:\Users\u\AppData\Roaming\app', 'Windows config');
  Check(D(adData, adsWindows) = 'C:\Users\u\AppData\Roaming\app', 'Windows data');
  Check(D(adState, adsWindows) = 'C:\Users\u\AppData\Local\app', 'Windows state');
  Check(D(adCache, adsWindows) = 'C:\Users\u\AppData\Local\app', 'Windows cache');
  SetEnv('LOCALAPPDATA', '');
  Check(D(adCache, adsWindows) = 'C:\Users\u\AppData\Roaming\app', 'Windows: APPDATA without LOCALAPPDATA');
  SetEnv('LOCALAPPDATA', 'Local');
  Check(D(adState, adsWindows) = 'C:\Users\u\AppData\Roaming\app', 'Windows: a relative LOCALAPPDATA is ignored');
  SetEnv('APPDATA', '\\srv\home\u');
  Check(D(adConfig, adsWindows) = '\\srv\home\u\app', 'Windows: APPDATA on a share');
  ClearEnv;
  Check(D(adConfig, adsWindows) = '', 'Windows: no APPDATA, no directory');

  { DOS }
  ClearEnv;
  Check(D(adConfig, adsDos) = 'C:\PROG', 'DOS: the directory of the program');
  Check(D(adCache, adsDos) = 'C:\PROG', 'DOS: the cache too');
  SetEnv('APPDIR', 'D:\CFG\');
  Check(D(adConfig, adsDos) = 'D:\CFG', 'DOS: the variable of the program');
  Check(D(adState, adsDos) = 'D:\CFG', 'DOS: the variable of the program for the state');
  Check(AppDirIn(adConfig, 'app', adsDos, @FakeEnv, 'C:\PROG\', '') = 'C:\PROG', 'DOS: no variable named');

  { native }
  Check(AppDirPath(adConfig, 'app') = AppDirIn(adConfig, 'app', NativeAppDirSystem, @AppDirGetEnv, AppDirProgramDir),
    'native: the rules of this system');
{$IF DEFINED(UNIX) AND NOT DEFINED(DARWIN)}
  Check(NativeAppDirSystem = adsXdg, 'native: XDG on Unix');
{$ENDIF}

  { MakeAppDir }
  Tmp := PathJoin(GetTempDir(False), 't_appdir.' + IntToStr(GetProcessID));
  Dir := PathJoin(PathJoin(Tmp, 'a'), 'b');
  Check(not DirectoryExists(Dir), 'MakeAppDir: not there before');
  Check(MakeAppDir(Dir) and DirectoryExists(Dir), 'MakeAppDir makes the missing directories');
  Check(MakeAppDir(Dir), 'MakeAppDir: a directory that is there');
{$IFDEF UNIX}
  Check((fpStat(Dir, St) = 0) and (St.st_mode and &777 = &700), 'MakeAppDir: mode 0700');
{$ENDIF}
  Check(not MakeAppDir(''), 'MakeAppDir: no name');
  RemoveDir(Dir);
  RemoveDir(PathJoin(Tmp, 'a'));
  RemoveDir(Tmp);
  Check(not DirectoryExists(Tmp), 'the test directory removed');

  Finish;
end.
