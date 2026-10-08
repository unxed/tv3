program t_path;
{ TvPath: the rules of Unix and of DOS/Windows (on any system), and the native forms on this one. }
{$I ../src/tvdefs.inc}
uses SysUtils, TvPath;
{$I testlib.inc}

var
  U, D: TPathRules;
  Dir, Name, Ext, Cur: AnsiString;

function Split(const S: AnsiString; const R: TPathRules): AnsiString;
begin
  PathSplit(S, Dir, Name, Ext, R);
  Result := Dir + '|' + Name + '|' + Ext;
end;

begin
  U := UnixPathRules;
  D := DosPathRules;

  { separators }
  Check(IsPathSep('/', U) and not IsPathSep('\', U), 'Unix: only / is a separator');
  Check(IsPathSep('/', D) and IsPathSep('\', D), 'DOS: \ and /');
  Check(EndsWithSep('a/', U) and not EndsWithSep('a\', U) and EndsWithSep('a\', D), 'EndsWithSep');

  { drives and roots }
  Check(PathDrive('C:\x', U) = '', 'Unix: no drives');
  Check(PathDrive('c:\x', D) = 'c:', 'DOS: the drive letter');
  Check(PathDrive('\\srv\share\x', D) = '\\srv\share', 'DOS: a UNC share');
  Check(PathDrive('\\srv', D) = '\\srv', 'DOS: a UNC server alone');
  Check(PathRootLen('/a', U) = 1, 'Unix root length');
  Check(PathRootLen('a', U) = 0, 'Unix relative');
  Check(PathRootLen('C:\a', D) = 3, 'DOS root length');
  Check(PathRootLen('C:a', D) = 2, 'DOS drive-relative');
  Check(PathRootLen('\\srv\sh\a', D) = 9, 'UNC root length');
  Check(PathIsRooted('/a', U) and not PathIsRooted('a/b', U) and not PathIsRooted('C:\a', U), 'Unix rooted');
  Check(PathIsRooted('\a', D) and PathIsRooted('/a', D) and PathIsRooted('C:\a', D) and not PathIsRooted('C:a', D), 'DOS rooted');
  Check(PathIsAbsolute('/a', U) and not PathIsAbsolute('\a', U), 'Unix absolute');
  Check(PathIsAbsolute('C:\a', D) and PathIsAbsolute('\\srv\sh\a', D) and PathIsAbsolute('\\srv\sh', D), 'DOS absolute');
  Check(not PathIsAbsolute('\a', D) and not PathIsAbsolute('C:a', D) and not PathIsAbsolute('a', D), 'DOS not absolute');
  Check(PathIsRoot('/', U) and not PathIsRoot('/a', U) and not PathIsRoot('', U) and not PathIsRoot('C:\', U), 'Unix PathIsRoot');
  Check(PathIsRoot('C:\', D) and PathIsRoot('\', D) and PathIsRoot('\\srv\sh\', D) and not PathIsRoot('C:', D), 'DOS PathIsRoot');

  { separators at the end, joining }
  Check(PathAddSep('a', U) = 'a/', 'Unix add');
  Check(PathAddSep('a', D) = 'a\', 'DOS add');
  Check((PathAddSep('/', U) = '/') and (PathAddSep('', U) = ''), 'add to the root and to nothing');
  Check(PathAddSep('C:', D) = 'C:', 'DOS: a bare drive stays');
  Check(PathAddSep('a\', U) = 'a\/', 'Unix: a backslash is a character of the name');
  Check(PathDelSep('/a/', U) = '/a', 'Unix del');
  Check(PathDelSep('/', U) = '/', 'Unix: the root keeps its separator');
  Check((PathDelSep('C:\', D) = 'C:\') and (PathDelSep('C:\a\', D) = 'C:\a') and (PathDelSep('\', D) = '\'), 'DOS del');
  Check(PathJoin('/a', 'b', U) = '/a/b', 'Unix join');
  Check(PathJoin('/a/', 'b', U) = '/a/b', 'Unix join after a separator');
  Check(PathJoin('/a', '/b', U) = '/b', 'Unix join with a rooted name');
  Check(PathJoin('', 'b', U) = 'b', 'join with no directory');
  Check(PathJoin('C:\a', 'b', D) = 'C:\a\b', 'DOS join');
  Check(PathJoin('C:', 'b', D) = 'C:b', 'DOS join to a bare drive');
  Check(PathJoin('C:\a', 'D:x', D) = 'D:x', 'DOS join with another drive');
  Check(PathJoin('/a', 'C:x', U) = '/a/C:x', 'Unix: C: is a name');

  { splitting }
  Check(Split('/a/b/file.name.ext', U) = '/a/b/|file.name|.ext', 'Unix split');
  Check(Split('file', U) = '|file|', 'split a bare name');
  Check(Split('/a/b/', U) = '/a/b/||', 'split a directory');
  Check(Split('/a/.profile', U) = '/a/|.profile|', 'a dot name has no extension');
  Check(Split('/a/.x.conf', U) = '/a/|.x|.conf', 'a dot name with an extension');
  Check(Split('..', U) = '|..|', '.. has no extension');
  Check(Split('a\b.txt', U) = '|a\b|.txt', 'Unix: a backslash is not a separator');
  Check(Split('C:\a\b.txt', U) = '|C:\a\b|.txt', 'Unix: a drive is not split');
  Check(Split('c:\dir\sub\file.name.ext', D) = 'c:\dir\sub\|file.name|.ext', 'DOS split');
  Check(Split('c:file.txt', D) = 'c:|file|.txt', 'DOS split after a bare drive');
  Check(Split('c:/a/b.txt', D) = 'c:/a/|b|.txt', 'DOS split with /');
  Check(PathDir('/a/b', U) = '/a/', 'PathDir');
  Check(PathName('/a/b.c', U) = 'b.c', 'PathName');
  Check(PathExt('/a.d/b', U) = '', 'PathExt: no dot in the name');
  Check(PathExt('C:\a.d\b.PAS', D) = '.PAS', 'PathExt keeps the case');

  { the form of the system }
  Check(PathNative('a/b\c', U) = 'a/b\c', 'Unix: nothing changes');
  Check(PathNative('a/b\c', D) = 'a\b\c', 'DOS: / becomes \');
  Check(PathNormalize('/a//b/./c/../d/', U) = '/a/b/d/', 'Unix normalize');
  Check(PathNormalize('/../a', U) = '/a', 'Unix: .. stops at the root');
  Check(PathNormalize('../a/..', U) = '..', 'Unix: a relative .. stays');
  Check(PathNormalize('a/..', U) = '.', 'Unix: nothing left is .');
  Check(PathNormalize('/a\b/../c', U) = '/c', 'Unix: a\b is one name');
  Check(PathNormalize('C:/a/../b', D) = 'C:\b', 'DOS normalize');
  Check(PathNormalize('\\srv\sh\a\..\..\b', D) = '\\srv\sh\b', 'UNC normalize stops at the share');
  Check(PathNormalize('C:\', D) = 'C:\', 'DOS normalize of a root');

  { expanding against a given current directory }
  Check(PathExpandIn('b', '/home/u', U) = '/home/u/b', 'Unix expand');
  Check(PathExpandIn('../b/', '/home/u', U) = '/home/b/', 'Unix expand ..');
  Check(PathExpandIn('/x', '/home/u', U) = '/x', 'Unix expand absolute');
  Check(PathExpandIn('C:\x', '/home/u', U) = '/home/u/C:\x', 'Unix: C:\x is a relative name');
  Check(PathExpandIn('b', 'C:\a', D) = 'C:\a\b', 'DOS expand');
  Check(PathExpandIn('\b', 'C:\a', D) = 'C:\b', 'DOS expand rooted');
  Check(PathExpandIn('c:b', 'C:\a', D) = 'C:\a\b', 'DOS expand on the same drive');
  Check(PathExpandIn('D:b', 'C:\a', D) = 'D:\b', 'DOS expand on another drive');
  Check(PathExpandIn('d/e', '\\srv\sh\a', D) = '\\srv\sh\a\d\e', 'UNC expand');

  { names }
  Check(not PathSameName('A.txt', 'a.txt', U) and PathSameName('A.txt', 'a.txt', D), 'case of names');

  { the native forms }
  Check(PathSep = NativePathRules.Sep, 'PathSep');
  Check(PathAllFiles = NativePathRules.AllFiles, 'PathAllFiles');
{$IFDEF UNIX}
  Check(not PathHasDrives and (PathSep = '/') and (PathAllFiles = '*'), 'Unix: no drives, /, *');
{$ENDIF}
{$IF DEFINED(GO32V2) OR DEFINED(WINDOWS)}
  Check(PathHasDrives and (PathSep = '\') and (PathAllFiles = '*.*'), 'DOS/Windows: drives, \, *.*');
{$ENDIF}
  Cur := GetCurrentDir;
  Check(PathIsAbsolute(Cur), 'the current directory is absolute');
  Check(PathExpand('x') = PathJoin(Cur, 'x'), 'PathExpand of a name');
  Check(PathExpand('a/../x') = PathJoin(Cur, 'x'), 'PathExpand with ..');
  Check(PathExpandFrom('x', 'sub') = PathJoin(PathJoin(Cur, 'sub'), 'x'), 'PathExpandFrom');
  Check(PathIsRoot(PathCurRoot) and (Copy(Cur, 1, Length(PathCurRoot)) = PathCurRoot), 'PathCurRoot');
  Check(PathExpand(PathCurRoot) = PathCurRoot, 'the root expands to itself');
{$IFDEF UNIX}
  Check(PathExpand('a\b') = Cur + '/a\b', 'Unix: a backslash in a name is kept by PathExpand');
  Check(Pos(':', PathCurRoot) = 0, 'Unix: no drive letter in the root');
{$ENDIF}
  Finish;
end.
