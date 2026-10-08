{ TvAppDir: the directories where a program keeps the files of the user: its configuration, its data, its state (logs,
  crash reports) and its caches, in the place that each system has for them.

  MIT (see LICENSE).

    Linux, the BSDs and other Unix systems (the XDG Base Directory specification):
      config $XDG_CONFIG_HOME/<app> (else ~/.config/<app>), data $XDG_DATA_HOME/<app> (else ~/.local/share/<app>),
      state $XDG_STATE_HOME/<app> (else ~/.local/state/<app>), cache $XDG_CACHE_HOME/<app> (else ~/.cache/<app>);
      a variable that holds a relative path is ignored.
    macOS: ~/Library/Application Support/<app> (config, data, state), ~/Library/Caches/<app> (cache).
    Windows: %APPDATA%\<app> (config, data), %LOCALAPPDATA%\<app> (state, cache; %APPDATA% when there is no
      %LOCALAPPDATA%); a relative value is ignored.
    DOS: the directory named by the environment variable of the program that is given (DosVar), else the directory of
      the program, for all four.

  A directory is '' when it is not known (no HOME, no APPDATA). The paths have no separator at the end. The functions
  that take a system (AppDirIn) do not look at the system the program runs on: the rules of every system are tested on
  any of them (tests/t_appdir.pas). }
unit TvAppDir;

{$I tvdefs.inc}

interface

type
  TAppDirKind = (adConfig, adData, adState, adCache);
  TAppDirSystem = (adsXdg, adsMac, adsWindows, adsDos);
  { The value of an environment variable ('' when it is not set). }
  TAppDirEnv = function(const Name: AnsiString): AnsiString;

{ The system the program runs on. }
function NativeAppDirSystem: TAppDirSystem;
{ The environment of the program. }
function AppDirGetEnv(const Name: AnsiString): AnsiString;
{ The directory of the program (from ParamStr(0)), without a separator at the end. }
function AppDirProgramDir: AnsiString;

{ The directory of the kind for the program App on the system Sys with the environment Env; ProgramDir and DosVar are
  used on DOS. The directory is not made. }
function AppDirIn(Kind: TAppDirKind; const App: AnsiString; Sys: TAppDirSystem; Env: TAppDirEnv;
  const ProgramDir: AnsiString; const DosVar: AnsiString = ''): AnsiString;
{ The same for the system the program runs on. }
function AppDirPath(Kind: TAppDirKind; const App: AnsiString; const DosVar: AnsiString = ''): AnsiString;
{ AppDirPath, and the directory is made when it is not there (on Unix readable by the user only, as the XDG
  specification asks); '' when it is not known or cannot be made. }
function AppDir(Kind: TAppDirKind; const App: AnsiString; const DosVar: AnsiString = ''): AnsiString;

function ConfigDir(const App: AnsiString; const DosVar: AnsiString = ''): AnsiString;
function DataDir(const App: AnsiString; const DosVar: AnsiString = ''): AnsiString;
function StateDir(const App: AnsiString; const DosVar: AnsiString = ''): AnsiString;
function CacheDir(const App: AnsiString; const DosVar: AnsiString = ''): AnsiString;

{ Makes the directory Dir and the missing ones above it (on Unix with the mode 0700). True when Dir is there. }
function MakeAppDir(const Dir: AnsiString): Boolean;

implementation

uses
{$IFDEF UNIX}
  BaseUnix,
{$ENDIF}
  SysUtils, TvPath;

function NativeAppDirSystem: TAppDirSystem;
begin
{$IF DEFINED(DARWIN)}
  Result := adsMac;
{$ELSEIF DEFINED(WINDOWS)}
  Result := adsWindows;
{$ELSEIF DEFINED(UNIX)}
  Result := adsXdg;
{$ELSE}
  Result := adsDos;
{$ENDIF}
end;

function AppDirGetEnv(const Name: AnsiString): AnsiString;
begin
  Result := SysUtils.GetEnvironmentVariable(Name);
end;

function AppDirProgramDir: AnsiString;
begin
  Result := PathDelSep(PathDir(PathExpand(ParamStr(0))));
end;

{ The value of the variable when it is an absolute path by the rules R, else ''. }
function AbsEnv(Env: TAppDirEnv; const Name: AnsiString; const R: TPathRules): AnsiString;
begin
  Result := Env(Name);
  if (Result <> '') and not PathIsAbsolute(Result, R) then
    Result := '';
end;

function XdgDir(Kind: TAppDirKind; const App: AnsiString; Env: TAppDirEnv): AnsiString;
const
  Vars: array[TAppDirKind] of AnsiString = ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME');
var
  R: TPathRules;
  Base, Home: AnsiString;
begin
  R := UnixPathRules;
  Result := '';
  Base := AbsEnv(Env, Vars[Kind], R);
  if Base = '' then
  begin
    Home := AbsEnv(Env, 'HOME', R);
    if Home = '' then
      Exit;
    case Kind of
      adConfig: Base := PathJoin(Home, '.config', R);
      adData: Base := PathJoin(PathJoin(Home, '.local', R), 'share', R);
      adState: Base := PathJoin(PathJoin(Home, '.local', R), 'state', R);
      adCache: Base := PathJoin(Home, '.cache', R);
    end;
  end;
  Result := PathJoin(Base, App, R);
end;

function MacDir(Kind: TAppDirKind; const App: AnsiString; Env: TAppDirEnv): AnsiString;
var
  R: TPathRules;
  Home: AnsiString;
begin
  R := UnixPathRules;
  Result := '';
  Home := AbsEnv(Env, 'HOME', R);
  if Home = '' then
    Exit;
  Result := PathJoin(Home, 'Library', R);
  if Kind = adCache then
    Result := PathJoin(Result, 'Caches', R)
  else
    Result := PathJoin(Result, 'Application Support', R);
  Result := PathJoin(Result, App, R);
end;

function WindowsDir(Kind: TAppDirKind; const App: AnsiString; Env: TAppDirEnv): AnsiString;
var
  R: TPathRules;
  Base: AnsiString;
begin
  R := DosPathRules;
  Result := '';
  Base := '';
  if Kind in [adState, adCache] then
    Base := AbsEnv(Env, 'LOCALAPPDATA', R);
  if Base = '' then
    Base := AbsEnv(Env, 'APPDATA', R);
  if Base = '' then
    Exit;
  Result := PathJoin(Base, App, R);
end;

function AppDirIn(Kind: TAppDirKind; const App: AnsiString; Sys: TAppDirSystem; Env: TAppDirEnv;
  const ProgramDir: AnsiString; const DosVar: AnsiString): AnsiString;
begin
  case Sys of
    adsXdg: Result := XdgDir(Kind, App, Env);
    adsMac: Result := MacDir(Kind, App, Env);
    adsWindows: Result := WindowsDir(Kind, App, Env);
  else
    Result := '';
    if DosVar <> '' then
      Result := Env(DosVar);
    if Result = '' then
      Result := ProgramDir;
  end;
  if Sys in [adsXdg, adsMac] then
    Result := PathDelSep(Result, UnixPathRules)
  else
    Result := PathDelSep(Result, DosPathRules);
end;

function AppDirPath(Kind: TAppDirKind; const App: AnsiString; const DosVar: AnsiString): AnsiString;
var
  Sys: TAppDirSystem;
  Prog: AnsiString;
begin
  Sys := NativeAppDirSystem;
  Prog := '';
  if Sys = adsDos then
    Prog := AppDirProgramDir;
  Result := AppDirIn(Kind, App, Sys, @AppDirGetEnv, Prog, DosVar);
end;

function MakeAppDir(const Dir: AnsiString): Boolean;
var
  Up: AnsiString;
begin
  Result := False;
  if Dir = '' then
    Exit;
  if DirectoryExists(Dir) then
    Exit(True);
  Up := PathDelSep(PathDir(PathDelSep(Dir)));
  if (Up <> '') and (Up <> Dir) and not PathIsRoot(Up) and not DirectoryExists(Up) then
    if not MakeAppDir(Up) then
      Exit;
{$IFDEF UNIX}
  Result := (fpMkdir(Dir, &700) = 0) or DirectoryExists(Dir);
{$ELSE}
  Result := CreateDir(Dir) or DirectoryExists(Dir);
{$ENDIF}
end;

function AppDir(Kind: TAppDirKind; const App: AnsiString; const DosVar: AnsiString): AnsiString;
begin
  Result := AppDirPath(Kind, App, DosVar);
  if (Result <> '') and not MakeAppDir(Result) then
    Result := '';
end;

function ConfigDir(const App: AnsiString; const DosVar: AnsiString): AnsiString;
begin
  Result := AppDir(adConfig, App, DosVar);
end;

function DataDir(const App: AnsiString; const DosVar: AnsiString): AnsiString;
begin
  Result := AppDir(adData, App, DosVar);
end;

function StateDir(const App: AnsiString; const DosVar: AnsiString): AnsiString;
begin
  Result := AppDir(adState, App, DosVar);
end;

function CacheDir(const App: AnsiString; const DosVar: AnsiString): AnsiString;
begin
  Result := AppDir(adCache, App, DosVar);
end;

end.
