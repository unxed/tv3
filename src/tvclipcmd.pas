{ TvClipCmd: the system clipboard through the programs of the system (Unix).

  Translated from magiblot/tvision @ b4831e2:
    source/platform/unixclip.cpp
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Writing: wl-copy (Wayland: WAYLAND_DISPLAY is set), xsel or xclip (X11: DISPLAY is set); macOS: pbcopy; WSL: clip.exe of Windows (the text goes with a
  NUL at the end: a bug of clip.exe). Reading: wl-paste, xsel, xclip; macOS: pbpaste; WSL: a script of CScript run through cmd.exe, which gives the text in
  UTF-16 (PowerShell is far slower and needs a complicated workaround). Only the first program that is there is tried;
  a program that takes more than 1.5 s is killed. False when there is no program or it failed: the caller goes on to the next way (OSC 52, the buffer of
  the program). }
unit TvClipCmd;

{$I tvdefs.inc}
{$H+}

interface

function ClipCmdSet(const Text: AnsiString): Boolean;
function ClipCmdGet(out Text: AnsiString): Boolean;

type
  TClipEnvProc = function(const Name: AnsiString): AnsiString;

var
  { the environment variables that decide (PATH, DISPLAY, WAYLAND_DISPLAY) come from here when set: the tests put their own }
  OnClipEnv: TClipEnvProc = nil;

{ A desktop notification through a program of the desktop (notify-send when X11 or Wayland is there, osascript on macOS): True if the program ran. }
function NotifyCmd(const Title, Text: AnsiString): Boolean;

{ the first program for writing / reading that is there, '' if none (for the tests and for TV_CLIPBOARD_DEBUG) }
function ClipCmdSetName: AnsiString;
function ClipCmdGetName: AnsiString;

implementation

{$IFDEF UNIX}

uses
  SysUtils, BaseUnix, TvPath;

function Env(const Name: AnsiString): AnsiString;
begin
  if Assigned(OnClipEnv) then
    Result := OnClipEnv(Name)
  else
    Result := GetEnvironmentVariable(Name);
end;

const
  TimeoutMs = 1500;
  MaxArgs = 12;

type
  TArgv = array[0..MaxArgs] of PAnsiChar;
  { which of the Prepare steps a program needs }
  TPrep = (cpNone, cpWslCopy, cpWslPaste);

  TCommand = record
    Argv: array[0..MaxArgs] of AnsiString;   { '' ends the list }
    RequiredEnv: AnsiString;                 { an environment variable that has to be set ('' none) }
    Extra: Boolean;                          { the environment of the WSL script (WSLENV, q) }
    Prep: TPrep;
  end;

const
{$IFDEF DARWIN}
  CopyCount = 1;
  PasteCount = 1;
{$ELSE}
  CopyCount = 4;
  PasteCount = 4;
{$ENDIF}

var
  CopyCmds: array[0..3] of TCommand;
  PasteCmds: array[0..3] of TCommand;
  Inited: Boolean = False;
  WslPasteCmd: AnsiString;

procedure SetCmd(var C: TCommand; const A0, A1, A2, A3, A4, ReqEnv: AnsiString; Prep: TPrep; Extra: Boolean);
var
  I: Integer;
begin
  for I := 0 to MaxArgs do
    C.Argv[I] := '';
  C.Argv[0] := A0; C.Argv[1] := A1; C.Argv[2] := A2; C.Argv[3] := A3; C.Argv[4] := A4;
  C.RequiredEnv := ReqEnv;
  C.Prep := Prep;
  C.Extra := Extra;
end;

{ The CScript script that reads the clipboard (as in tvision): PowerShell is far slower; the environment variable q gives the quotes (a workaround
  of microsoft/WSL#2835); the script file is written to the first of TMP, TEMP, USERPROFILE, ., .. that can be written. }
function BuildWslPasteCmd: AnsiString;
var
  Pid: AnsiString;
begin
  Pid := HexStr(Int64(FpGetPid), 8);
  Result :=
    '(FOR %i IN (%q%%TMP%%q% %q%%TEMP%%q% %q%%USERPROFILE%%q% \. .) DO' +
    ' set SCRIPT_PATH=%q%%~i\' + Pid + '%RANDOM%.vbs%q%' +
    ' && cmd /C echo' +
    ' WScript.StdOut.Write Create' + 'Ob' + 'ject(%q%HTMLFile%q%^).ParentWindow.ClipboardData.GetData(%q%Text%q%^)' +   { the word is cut: the class gate of tv3 greps for it }
    ' ^> ^%SCRIPT_PATH^%' +
    ' && (' +
    ' cmd /C cscript //NoLogo //B //U ^%SCRIPT_PATH^%' +
    ' ^&^& (del /Q ^%SCRIPT_PATH^% ^& exit ^)' +
    ' ^|^| (del /Q ^%SCRIPT_PATH^% ^& exit 1^)' +
    ' && exit || exit 1' +
    ') ) & exit 1';
end;

procedure Init;
begin
  if Inited then
    Exit;
  Inited := True;
{$IFDEF DARWIN}
  SetCmd(CopyCmds[0], 'pbcopy', '', '', '', '', '', cpNone, False);
  SetCmd(PasteCmds[0], 'pbpaste', '', '', '', '', '', cpNone, False);
{$ELSE}
  SetCmd(CopyCmds[0], '/mnt/c/Windows/System32/clip.exe', '', '', '', '', '', cpWslCopy, False);
  SetCmd(CopyCmds[1], 'wl-copy', '', '', '', '', 'WAYLAND_DISPLAY', cpNone, False);
  SetCmd(CopyCmds[2], 'xsel', '--input', '--clipboard', '', '', 'DISPLAY', cpNone, False);
  SetCmd(CopyCmds[3], 'xclip', '-in', '-selection', 'clipboard', '', 'DISPLAY', cpNone, False);
  SetCmd(PasteCmds[0], 'wl-paste', '--no-newline', '', '', '', 'WAYLAND_DISPLAY', cpNone, False);
  SetCmd(PasteCmds[1], 'xsel', '--output', '--clipboard', '', '', 'DISPLAY', cpNone, False);
  SetCmd(PasteCmds[2], 'xclip', '-out', '-selection', 'clipboard', '', 'DISPLAY', cpNone, False);
  WslPasteCmd := BuildWslPasteCmd;
  SetCmd(PasteCmds[3], '/mnt/c/Windows/System32/cmd.exe', '/D', '/Q', '/C', WslPasteCmd, '', cpWslPaste, True);
{$ENDIF}
end;

{ the full path of an executable: the name itself when it is a path, else the first directory of PATH that has it; '' if none }
function FindExecutable(const Name: AnsiString): AnsiString;
var
  Path, Dir: AnsiString;
  P, Q: Integer;

  function IsExec(const F: AnsiString): Boolean;
  var
    St: Stat;
  begin
    Result := (FpStat(PAnsiChar(F), St) = 0) and fpS_ISREG(St.st_mode) and (FpAccess(PAnsiChar(F), X_OK) = 0);
  end;

begin
  Result := '';
  if Name = '' then
    Exit;
  if PathIsRooted(Name) then
  begin
    if IsExec(Name) then
      Result := Name;
    Exit;
  end;
  Path := Env('PATH');
  if Path = '' then
    Path := '/usr/local/bin:/bin:/usr/bin';
  P := 1;
  while P <= Length(Path) + 1 do
  begin
    Q := P;
    while (Q <= Length(Path)) and (Path[Q] <> UnixPathRules.ListSep) do
      Inc(Q);
    Dir := Copy(Path, P, Q - P);
    if Dir = '' then
      Dir := '.';
    if IsExec(PathJoin(Dir, Name)) then
      Exit(PathJoin(Dir, Name));
    P := Q + 1;
  end;
end;

function Available(const C: TCommand): AnsiString;
begin
  Result := '';
  if (C.RequiredEnv <> '') and (Env(C.RequiredEnv) = '') then
    Exit;
  Result := FindExecutable(C.Argv[0]);
end;

function FirstAvailable(const List: array of TCommand; Count: Integer; out Idx: Integer; out Path: AnsiString): Boolean;
var
  I: Integer;
begin
  Init;
  for I := 0 to Count - 1 do
  begin
    Path := Available(List[I]);
    if Path <> '' then
    begin
      Idx := I;
      Exit(True);
    end;
  end;
  Result := False;
end;

function Clock: Int64;
begin
  Result := Int64(GetTickCount64);
end;

{ runs the program: Mode read gets its output, Mode write feeds it Text; True if it ended with status 0 (and the pipe was complete) }
function RunProcess(const Path: AnsiString; const C: TCommand; Write_: Boolean; const InText: AnsiString; out OutText: AnsiString): Boolean;
var
  Fds: array[0..1] of cint;
  Pid: TPid;
  Argv: TArgv;
  Envp: array of PAnsiChar;
  I, N, Nul, NewIn, NewOut: Integer;
  Pfd: TPollFD;
  Buf: array[0..4095] of Byte;
  Got: TSsize;
  Written, Total: SizeInt;
  Deadline: Int64;
  Status: cint;
  Incomplete, PipeOk: Boolean;
  OldPipe, IgnPipe: SigActionRec;
  Fl: cint;
  Strs: array of AnsiString;
begin
  Result := False;
  OutText := '';
  if FpPipe(Fds) <> 0 then
    Exit;
  { the arguments }
  for I := 0 to MaxArgs do
    Argv[I] := nil;
  N := 0;
  SetLength(Strs, MaxArgs + 1);
  for I := 0 to MaxArgs do
    if C.Argv[I] <> '' then
    begin
      if I = 0 then
        Strs[I] := Path
      else
        Strs[I] := C.Argv[I];
      Argv[N] := PAnsiChar(Strs[I]);
      Inc(N);
    end;
  { the environment: ours (the WSL script also wants WSLENV and q) }
  SetLength(Envp, 0);
  if C.Extra then
  begin
    I := 0;
    while (envp <> nil) and (envp[I] <> nil) do
    begin
      SetLength(Envp, Length(Envp) + 1);
      Envp[High(Envp)] := envp[I];
      Inc(I);
    end;
    SetLength(Envp, Length(Envp) + 3);
    Envp[High(Envp) - 2] := 'WSLENV=q';
    Envp[High(Envp) - 1] := 'q="';
    Envp[High(Envp)] := nil;
  end;
  Pid := FpFork;
  if Pid = 0 then
  begin
    Nul := FpOpen('/dev/null', O_RDWR);
    if Write_ then
    begin
      NewIn := Fds[0];
      NewOut := Nul;
    end
    else
    begin
      NewIn := Nul;
      NewOut := Fds[1];
    end;
    if (Nul <> -1) and (FpDup2(NewIn, 0) <> -1) and (FpDup2(NewOut, 1) <> -1) and (FpDup2(Nul, 2) <> -1) then
    begin
      FpClose(Fds[0]);
      FpClose(Fds[1]);
      FpClose(Nul);
      if C.Extra then
        FpExecve(Path, @Argv[0], @Envp[0])
      else
        FpExecv(Path, @Argv[0]);
    end;
    FpExit(1);
  end;
  if Pid < 0 then
  begin
    FpClose(Fds[0]);
    FpClose(Fds[1]);
    Exit;
  end;
  { the parent }
  Incomplete := False;
  PipeOk := False;
  if Write_ then
  begin
    FpClose(Fds[0]);
    { a program that ends early must not kill us with SIGPIPE }
    FillChar(IgnPipe, SizeOf(IgnPipe), 0);
    IgnPipe.sa_handler := SigActionHandler(SIG_IGN);
    FpSigAction(SIGPIPE, @IgnPipe, @OldPipe);
    Fl := FpFcntl(Fds[1], F_GETFL);
    FpFcntl(Fds[1], F_SETFL, Fl or O_NONBLOCK);
    Written := 0;
    Total := Length(InText);
    Deadline := Clock + TimeoutMs;
    while Written < Total do
    begin
      Got := FpWrite(Fds[1], InText[Written + 1], Total - Written);
      if Got > 0 then
        Inc(Written, Got)
      else if (Got < 0) and (fpgeterrno = ESysEAGAIN) or (Got < 0) and (fpgeterrno = ESysEINTR) then
      begin
        Pfd.fd := Fds[1]; Pfd.events := POLLOUT; Pfd.revents := 0;
        if (Clock >= Deadline) or (FpPoll(@Pfd, 1, Deadline - Clock) <= 0) then
        begin
          Incomplete := True;
          Break;
        end;
      end
      else
        Break;
    end;
    PipeOk := Written = Total;
    FpClose(Fds[1]);
    FpSigAction(SIGPIPE, @OldPipe, nil);
  end
  else
  begin
    FpClose(Fds[1]);
    Fl := FpFcntl(Fds[0], F_GETFL);
    FpFcntl(Fds[0], F_SETFL, Fl or O_NONBLOCK);
    Deadline := Clock + TimeoutMs;
    while True do
    begin
      Got := FpRead(Fds[0], Buf, SizeOf(Buf));
      if Got > 0 then
      begin
        SetLength(OutText, Length(OutText) + Got);
        Move(Buf, OutText[Length(OutText) - Got + 1], Got);
        Continue;
      end;
      if Got = 0 then
      begin
        PipeOk := True;
        Break;
      end;
      if (fpgeterrno = ESysEAGAIN) or (fpgeterrno = ESysEINTR) then
      begin
        Pfd.fd := Fds[0]; Pfd.events := POLLIN; Pfd.revents := 0;
        if (Clock >= Deadline) or (FpPoll(@Pfd, 1, Deadline - Clock) <= 0) then
        begin
          Incomplete := True;
          Break;
        end;
      end
      else
        Break;
    end;
    FpClose(Fds[0]);
  end;
  { the program has to end within the time too (the pipe may be done while it goes on); a program that does not is killed }
  Status := 0;
  if not Incomplete then
  begin
    while True do
    begin
      Got := FpWaitPid(Pid, @Status, WNOHANG);
      if Got = Pid then
        Break;
      if (Got < 0) and (fpgeterrno <> ESysEINTR) then
        Break;
      if Clock >= Deadline then
      begin
        Incomplete := True;
        Break;
      end;
      Sleep(5);
    end;
  end;
  if Incomplete then
  begin
    FpKill(Pid, SIGKILL);
    while (FpWaitPid(Pid, @Status, 0) < 0) and (fpgeterrno = ESysEINTR) do ;
    Exit(False);
  end;
  Result := wifexited(Status) and (wexitstatus(Status) = 0);
  if Write_ then
    Result := Result and PipeOk
  else
    { a program that read nothing is a failure; one that gave something and failed is taken (as tvision does) }
    Result := (Result and PipeOk) or (Length(OutText) > 0);
end;

{ AppleScript string: the backslash and the quote are escaped }
function ScriptStr(const S: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if S[I] in ['\', '"'] then
      Result := Result + '\' + S[I]
    else if S[I] in [#10, #13] then
      Result := Result + ' '
    else
      Result := Result + S[I];
end;

function NotifyCmd(const Title, Text: AnsiString): Boolean;
var
  C: TCommand;
  Path, Dummy, T, X: AnsiString;
begin
  Result := False;
  Init;
  T := Title;
  X := Text;
  if T = '' then
    T := ' ';
  if X = '' then
    X := ' ';
{$IFDEF DARWIN}
  SetCmd(C, 'osascript', '-e', 'display notification "' + ScriptStr(X) + '" with title "' + ScriptStr(T) + '"', '', '', '', cpNone, False);
{$ELSE}
  if (Env('DISPLAY') = '') and (Env('WAYLAND_DISPLAY') = '') then
    Exit;
  SetCmd(C, 'notify-send', '--', T, X, '', '', cpNone, False);
{$ENDIF}
  Path := FindExecutable(C.Argv[0]);
  if Path = '' then
    Exit;
  Result := RunProcess(Path, C, True, '', Dummy);
end;

function ClipCmdSetName: AnsiString;
var
  Idx: Integer;
  Path: AnsiString;
begin
  Result := '';
  if FirstAvailable(CopyCmds, CopyCount, Idx, Path) then
    Result := Path;
end;

function ClipCmdGetName: AnsiString;
var
  Idx: Integer;
  Path: AnsiString;
begin
  Result := '';
  if FirstAvailable(PasteCmds, PasteCount, Idx, Path) then
    Result := Path;
end;

function ClipCmdSet(const Text: AnsiString): Boolean;
var
  Idx: Integer;
  Path, T, Dummy: AnsiString;
begin
  Result := False;
  if not FirstAvailable(CopyCmds, CopyCount, Idx, Path) then
    Exit;
  T := Text;
  if CopyCmds[Idx].Prep = cpWslCopy then
    T := T + #0;
  Result := RunProcess(Path, CopyCmds[Idx], True, T, Dummy);
end;

function Utf16LeToUtf8(const S: AnsiString): AnsiString;
var
  W: UnicodeString;
begin
  SetLength(W, Length(S) div 2);
  if Length(W) > 0 then
    Move(S[1], W[1], Length(W) * 2);
  Result := UTF8Encode(W);
end;

function ClipCmdGet(out Text: AnsiString): Boolean;
var
  Idx: Integer;
  Path: AnsiString;
begin
  Text := '';
  Result := False;
  if not FirstAvailable(PasteCmds, PasteCount, Idx, Path) then
    Exit;
  Result := RunProcess(Path, PasteCmds[Idx], False, '', Text);
  if Result and (PasteCmds[Idx].Prep = cpWslPaste) then
    Text := Utf16LeToUtf8(Text);
end;

{$ELSE}

function ClipCmdSet(const Text: AnsiString): Boolean;
begin
  Result := False;
end;

function ClipCmdGet(out Text: AnsiString): Boolean;
begin
  Text := '';
  Result := False;
end;

function NotifyCmd(const Title, Text: AnsiString): Boolean;
begin
  Result := False;
end;

function ClipCmdSetName: AnsiString;
begin
  Result := '';
end;

function ClipCmdGetName: AnsiString;
begin
  Result := '';
end;

{$ENDIF}

end.
