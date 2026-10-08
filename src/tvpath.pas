{ TvPath: the form of a path on the system: the separator, the root, drives, absolute paths, joining and splitting.

  MIT. The one place of tv3 (and of the programs over it) that knows how a path looks: other code does not spell a
  separator, a drive letter or a root by hand (tools/check-paths.py counts the places that still do).

  Each function has two forms: one for the system the program runs on, and one that takes the rules of a system
  (UnixPathRules, DosPathRules), so the logic of every system is tested on any of them (tests/t_path.pas).
    Unix         '/' only; no drives; the root is '/'; a backslash is an ordinary character of a name; case matters.
    DOS/Windows  '\' (and '/' read as '\'); "C:" drives and "\\server\share" roots; case is ignored. }
unit TvPath;

{$I tvdefs.inc}

interface

type
  TPathRules = record
    Sep: Char;              { the separator that is written }
    AltSep: Char;           { a second character read as a separator (#0: none) }
    Drives: Boolean;        { "C:" drive prefixes and "\\server\share" roots }
    CaseSensitive: Boolean; { names that differ in case are different files }
    ListSep: Char;          { between the directories of a list such as PATH }
    AllFiles: string[3];    { the mask of every file }
  end;

const
  UnixPathRules: TPathRules = (Sep: '/'; AltSep: #0; Drives: False; CaseSensitive: True; ListSep: ':'; AllFiles: '*');
  DosPathRules: TPathRules = (Sep: '\'; AltSep: '/'; Drives: True; CaseSensitive: False; ListSep: ';'; AllFiles: '*.*');

{$IF DEFINED(GO32V2) OR DEFINED(WINDOWS) OR DEFINED(OS2) OR DEFINED(MSDOS)}
  {$DEFINE TV_DRIVES}
{$ENDIF}

{$IFDEF TV_DRIVES}
  PathSep = '\';
  PathHasDrives = True;
  PathAllFiles = '*.*';
{$ELSE}
  PathSep = '/';
  PathHasDrives = False;
  PathAllFiles = '*';
{$ENDIF}

{ The rules of the system the program runs on. }
function NativePathRules: TPathRules;

{ C is a separator (on DOS and Windows '/' as well as '\'). }
function IsPathSep(C: Char): Boolean; overload;
function IsPathSep(C: Char; const R: TPathRules): Boolean; overload;
function EndsWithSep(const S: AnsiString): Boolean; overload;
function EndsWithSep(const S: AnsiString; const R: TPathRules): Boolean; overload;

{ The drive part: "C:" or "\\server\share"; '' without drives or when the path has none. }
function PathDrive(const S: AnsiString): AnsiString; overload;
function PathDrive(const S: AnsiString; const R: TPathRules): AnsiString; overload;
{ The length of the root: the drive part and the separator after it ("/" 1, "C:\" 3, "\" 1, "\\srv\sh\" 9); for a
  path without a root directory it is the length of the drive part ("C:x" 2, "x" 0). }
function PathRootLen(const S: AnsiString): Integer; overload;
function PathRootLen(const S: AnsiString; const R: TPathRules): Integer; overload;
{ The path starts at a root directory ("/x", "\x", "C:\x"): it does not depend on the current directory. }
function PathIsRooted(const S: AnsiString): Boolean; overload;
function PathIsRooted(const S: AnsiString; const R: TPathRules): Boolean; overload;
{ The path is complete: rooted, and with a drive where the system has drives ("/x", "C:\x", "\\srv\sh\x"). }
function PathIsAbsolute(const S: AnsiString): Boolean; overload;
function PathIsAbsolute(const S: AnsiString; const R: TPathRules): Boolean; overload;
{ The path is a root and nothing more ("/", "C:\", "\"). }
function PathIsRoot(const S: AnsiString): Boolean; overload;
function PathIsRoot(const S: AnsiString; const R: TPathRules): Boolean; overload;

{ A separator at the end (none is added to '' or to a bare drive "C:"). }
function PathAddSep(const S: AnsiString): AnsiString; overload;
function PathAddSep(const S: AnsiString; const R: TPathRules): AnsiString; overload;
{ No separator at the end, except that of a root ("/", "C:\"). }
function PathDelSep(const S: AnsiString): AnsiString; overload;
function PathDelSep(const S: AnsiString; const R: TPathRules): AnsiString; overload;
{ Name in Dir; a rooted Name or an empty Dir gives Name. }
function PathJoin(const Dir, Name: AnsiString): AnsiString; overload;
function PathJoin(const Dir, Name: AnsiString; const R: TPathRules): AnsiString; overload;

{ Dir is the drive and the directories with the last separator; Ext starts with its dot. A name that starts with a
  dot and has no other one (".profile"), and the names "." and "..", have no extension. }
procedure PathSplit(const S: AnsiString; out Dir, Name, Ext: AnsiString); overload;
procedure PathSplit(const S: AnsiString; out Dir, Name, Ext: AnsiString; const R: TPathRules); overload;
function PathDir(const S: AnsiString): AnsiString; overload;
function PathDir(const S: AnsiString; const R: TPathRules): AnsiString; overload;
{ The last part with its extension. }
function PathName(const S: AnsiString): AnsiString; overload;
function PathName(const S: AnsiString; const R: TPathRules): AnsiString; overload;
function PathExt(const S: AnsiString): AnsiString; overload;
function PathExt(const S: AnsiString; const R: TPathRules): AnsiString; overload;

{ The separators written as those of the system ('/' becomes '\' on DOS and Windows; nothing changes on Unix). }
function PathNative(const S: AnsiString): AnsiString; overload;
function PathNative(const S: AnsiString; const R: TPathRules): AnsiString; overload;
{ PathNative, without repeated separators and the parts "." and "x\.." (".." stops at the root and stays at the
  start of a relative path); a separator at the end stays. }
function PathNormalize(const S: AnsiString): AnsiString; overload;
function PathNormalize(const S: AnsiString; const R: TPathRules): AnsiString; overload;
{ The full path: a relative one is taken from the current directory (of its drive). }
function PathExpand(const S: AnsiString): AnsiString;
{ A relative S is taken from Base (Base itself may be relative to the current directory). }
function PathExpandFrom(const S, Base: AnsiString): AnsiString;
{ The full path of S when it is relative to the directory Cur (an absolute path): the logic of PathExpand without
  the system. On a system with drives a path such as "D:x" or "\x" takes the drive of Cur only if it is the same. }
function PathExpandIn(const S, Cur: AnsiString; const R: TPathRules): AnsiString;

{ The two names are the same file name by the rules of the system (case is ignored on DOS and Windows). }
function PathSameName(const A, B: AnsiString): Boolean; overload;
function PathSameName(const A, B: AnsiString; const R: TPathRules): Boolean; overload;

{ The root of the current directory: "/" or "C:\". }
function PathCurRoot: AnsiString;

implementation

uses
  SysUtils;

function NativePathRules: TPathRules;
begin
{$IFDEF TV_DRIVES}
  Result := DosPathRules;
{$ELSE}
  Result := UnixPathRules;
{$ENDIF}
end;

function IsPathSep(C: Char; const R: TPathRules): Boolean;
begin
  Result := (C = R.Sep) or ((R.AltSep <> #0) and (C = R.AltSep));
end;

function IsPathSep(C: Char): Boolean;
begin
{$IFDEF TV_DRIVES}
  Result := (C = '\') or (C = '/');
{$ELSE}
  Result := C = '/';
{$ENDIF}
end;

function EndsWithSep(const S: AnsiString; const R: TPathRules): Boolean;
begin
  Result := (S <> '') and IsPathSep(S[Length(S)], R);
end;

function EndsWithSep(const S: AnsiString): Boolean;
begin
  Result := EndsWithSep(S, NativePathRules);
end;

function IsLetter(C: Char): Boolean; inline;
begin
  Result := C in ['A'..'Z', 'a'..'z'];
end;

{ the length of the drive part }
function DriveLen(const S: AnsiString; const R: TPathRules): Integer;
var
  I, Parts: Integer;
begin
  Result := 0;
  if not R.Drives then
    Exit;
  if (Length(S) >= 2) and IsLetter(S[1]) and (S[2] = ':') then
    Exit(2);
  { "\\server\share": two parts after the two separators }
  if (Length(S) >= 3) and IsPathSep(S[1], R) and IsPathSep(S[2], R) and not IsPathSep(S[3], R) then
  begin
    I := 3;
    Parts := 0;
    while I <= Length(S) do
    begin
      if IsPathSep(S[I], R) then
      begin
        Inc(Parts);
        if Parts = 2 then
          Break;
      end;
      Inc(I);
    end;
    Result := I - 1;
  end;
end;

function PathDrive(const S: AnsiString; const R: TPathRules): AnsiString;
begin
  Result := Copy(S, 1, DriveLen(S, R));
end;

function PathDrive(const S: AnsiString): AnsiString;
begin
  Result := PathDrive(S, NativePathRules);
end;

function PathRootLen(const S: AnsiString; const R: TPathRules): Integer;
begin
  Result := DriveLen(S, R);
  if (Result < Length(S)) and IsPathSep(S[Result + 1], R) then
    Inc(Result);
end;

function PathRootLen(const S: AnsiString): Integer;
begin
  Result := PathRootLen(S, NativePathRules);
end;

function PathIsRooted(const S: AnsiString; const R: TPathRules): Boolean;
var
  D: Integer;
begin
  D := DriveLen(S, R);
  Result := ((D < Length(S)) and IsPathSep(S[D + 1], R)) or ((D > 2) and (D = Length(S)));
end;

function PathIsRooted(const S: AnsiString): Boolean;
begin
  Result := PathIsRooted(S, NativePathRules);
end;

function PathIsAbsolute(const S: AnsiString; const R: TPathRules): Boolean;
begin
  Result := PathIsRooted(S, R) and (not R.Drives or (DriveLen(S, R) > 0));
end;

function PathIsAbsolute(const S: AnsiString): Boolean;
begin
  Result := PathIsAbsolute(S, NativePathRules);
end;

function PathIsRoot(const S: AnsiString; const R: TPathRules): Boolean;
begin
  Result := (S <> '') and PathIsRooted(S, R) and (PathRootLen(S, R) = Length(S));
end;

function PathIsRoot(const S: AnsiString): Boolean;
begin
  Result := PathIsRoot(S, NativePathRules);
end;

function PathAddSep(const S: AnsiString; const R: TPathRules): AnsiString;
begin
  Result := S;
  if (S <> '') and not EndsWithSep(S, R) and not ((DriveLen(S, R) = 2) and (Length(S) = 2)) then
    Result := S + R.Sep;
end;

function PathAddSep(const S: AnsiString): AnsiString;
begin
  Result := PathAddSep(S, NativePathRules);
end;

function PathDelSep(const S: AnsiString; const R: TPathRules): AnsiString;
var
  N, Root: Integer;
begin
  N := Length(S);
  Root := PathRootLen(S, R);
  while (N > Root) and IsPathSep(S[N], R) do
    Dec(N);
  Result := Copy(S, 1, N);
end;

function PathDelSep(const S: AnsiString): AnsiString;
begin
  Result := PathDelSep(S, NativePathRules);
end;

function PathJoin(const Dir, Name: AnsiString; const R: TPathRules): AnsiString;
begin
  if (Dir = '') or PathIsRooted(Name, R) or (DriveLen(Name, R) > 0) then
    Result := Name
  else if Name = '' then
    Result := Dir
  else
    Result := PathAddSep(Dir, R) + Name;
end;

function PathJoin(const Dir, Name: AnsiString): AnsiString;
begin
  Result := PathJoin(Dir, Name, NativePathRules);
end;

{ the index of the last character of the directory part (0: none) }
function DirEnd(const S: AnsiString; const R: TPathRules): Integer;
var
  D: Integer;
begin
  D := DriveLen(S, R);
  Result := Length(S);
  while (Result > D) and not IsPathSep(S[Result], R) do
    Dec(Result);
end;

procedure PathSplit(const S: AnsiString; out Dir, Name, Ext: AnsiString; const R: TPathRules);
var
  E, I, Dot: Integer;
  N: AnsiString;
begin
  E := DirEnd(S, R);
  Dir := Copy(S, 1, E);
  N := Copy(S, E + 1, MaxInt);
  Dot := 0;
  if (N <> '.') and (N <> '..') then
    for I := Length(N) downto 2 do
      if N[I] = '.' then
      begin
        Dot := I;
        Break;
      end;
  if Dot > 0 then
  begin
    Name := Copy(N, 1, Dot - 1);
    Ext := Copy(N, Dot, MaxInt);
  end
  else
  begin
    Name := N;
    Ext := '';
  end;
end;

procedure PathSplit(const S: AnsiString; out Dir, Name, Ext: AnsiString);
begin
  PathSplit(S, Dir, Name, Ext, NativePathRules);
end;

function PathDir(const S: AnsiString; const R: TPathRules): AnsiString;
begin
  Result := Copy(S, 1, DirEnd(S, R));
end;

function PathDir(const S: AnsiString): AnsiString;
begin
  Result := PathDir(S, NativePathRules);
end;

function PathName(const S: AnsiString; const R: TPathRules): AnsiString;
begin
  Result := Copy(S, DirEnd(S, R) + 1, MaxInt);
end;

function PathName(const S: AnsiString): AnsiString;
begin
  Result := PathName(S, NativePathRules);
end;

function PathExt(const S: AnsiString; const R: TPathRules): AnsiString;
var
  D, N: AnsiString;
begin
  PathSplit(S, D, N, Result, R);
end;

function PathExt(const S: AnsiString): AnsiString;
begin
  Result := PathExt(S, NativePathRules);
end;

function PathNative(const S: AnsiString; const R: TPathRules): AnsiString;
var
  I: Integer;
begin
  Result := S;
  if R.AltSep <> #0 then
    for I := 1 to Length(Result) do
      if Result[I] = R.AltSep then
        Result[I] := R.Sep;
end;

function PathNative(const S: AnsiString): AnsiString;
begin
  Result := PathNative(S, NativePathRules);
end;

function PathNormalize(const S: AnsiString; const R: TPathRules): AnsiString;
var
  Root, Part: AnsiString;
  Parts: array of AnsiString;
  N, I, J, Count: Integer;
  Rooted, TrailSep: Boolean;
begin
  Result := PathNative(S, R);
  if Result = '' then
    Exit;
  N := PathRootLen(Result, R);
  Root := Copy(Result, 1, N);
  Rooted := PathIsRooted(Result, R);
  TrailSep := (Length(Result) > N) and EndsWithSep(Result, R);
  Parts := nil;
  SetLength(Parts, Length(Result));
  Count := 0;
  I := N + 1;
  while I <= Length(Result) do
  begin
    J := I;
    while (J <= Length(Result)) and (Result[J] <> R.Sep) do
      Inc(J);
    Part := Copy(Result, I, J - I);
    if (Part = '') or (Part = '.') then
      { nothing }
    else if (Part = '..') and (Count > 0) and (Parts[Count - 1] <> '..') then
      Dec(Count)
    else if (Part = '..') and Rooted then
      { above the root is the root }
    else
    begin
      Parts[Count] := Part;
      Inc(Count);
    end;
    I := J + 1;
  end;
  Result := Root;
  for I := 0 to Count - 1 do
  begin
    if I > 0 then
      Result := Result + R.Sep;
    Result := Result + Parts[I];
  end;
  if (Count = 0) and (Root = '') then
    Result := '.';
  if TrailSep and (Count > 0) then
    Result := Result + R.Sep;
end;

function PathNormalize(const S: AnsiString): AnsiString;
begin
  Result := PathNormalize(S, NativePathRules);
end;

function PathExpandIn(const S, Cur: AnsiString; const R: TPathRules): AnsiString;
var
  D, CurD: AnsiString;
begin
  if PathIsAbsolute(S, R) then
    Exit(PathNormalize(S, R));
  D := PathDrive(S, R);
  CurD := PathDrive(Cur, R);
  if (D <> '') and not SameText(D, CurD) then
    { "D:x" with the current directory of another drive: the root of that drive }
    Exit(PathNormalize(D + R.Sep + Copy(S, Length(D) + 1, MaxInt), R));
  if PathIsRooted(S, R) then
    Result := CurD + Copy(S, Length(D) + 1, MaxInt)
  else
    Result := PathJoin(Cur, Copy(S, Length(D) + 1, MaxInt), R);
  Result := PathNormalize(Result, R);
end;

function PathExpand(const S: AnsiString): AnsiString;
begin
  if S = '' then
    Exit(PathAddSep(GetCurrentDir));
{$IFDEF TV_DRIVES}
  { the RTL knows the current directory of each drive }
  Result := PathNormalize(ExpandFileName(S));
  if EndsWithSep(S) then
    Result := PathAddSep(Result);
{$ELSE}
  Result := PathExpandIn(S, GetCurrentDir, UnixPathRules);
{$ENDIF}
end;

function PathExpandFrom(const S, Base: AnsiString): AnsiString;
begin
  if (Base = '') or PathIsRooted(S) or (DriveLen(S, NativePathRules) > 0) then
    Result := PathExpand(S)
  else
    Result := PathExpand(PathJoin(Base, S));
end;

function PathSameName(const A, B: AnsiString; const R: TPathRules): Boolean;
begin
  if R.CaseSensitive then
    Result := A = B
  else
    Result := AnsiCompareText(A, B) = 0;
end;

function PathSameName(const A, B: AnsiString): Boolean;
begin
  Result := PathSameName(A, B, NativePathRules);
end;

function PathCurRoot: AnsiString;
var
  C: AnsiString;
begin
  C := GetCurrentDir;
  Result := Copy(C, 1, PathRootLen(C));
  if not PathIsRooted(Result) then
    Result := PathAddSep(Result);
end;

end.
