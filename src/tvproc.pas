{ TvProc: running programs from a program of tv3.

  MIT as the one place for what dn (the backends of its OSRun) and fpide (the output of the compiler) did each for itself.

  RunShell gives the terminal back (TvSys.OnSuspend), runs a command line in the shell of the system, optionally waits for Enter, and takes the terminal again
  (OnResume); RunQuiet runs a command without touching the screen; RunCapture runs a program and returns what it wrote (both outputs); RestartSelf starts
  the program again with its arguments. The results of the runners are exit codes: 0..255, 128 + signal for a program that was killed, -1 when it could
  not be run. DOS has no RunCapture (no pipes); its RunShell is Dos.Exec of COMSPEC. }
unit TvProc;

{$I tvdefs.inc}

interface

function RunShell(const CmdLine: AnsiString; Pause: Boolean = False; const PauseText: AnsiString = 'Press Enter to return...'): LongInt;
function RunQuiet(const CmdLine: AnsiString): LongInt;
{$IFNDEF GO32V2}
{ The whole output (standard output and standard error) of a program; '' if it could not be run. }
function RunCapture(const Exe: AnsiString; const Args: array of AnsiString): AnsiString;
{ The first line of the output. }
function RunFirstLine(const Exe: AnsiString; const Args: array of AnsiString): AnsiString;
{$ENDIF}
{ Replaces this process with the same program and arguments (Unix), or starts a new one and goes on (elsewhere: the caller leaves). }
procedure RestartSelf;

implementation

uses
  SysUtils,
{$IFDEF UNIX}
  BaseUnix, Unix,
{$ENDIF}
{$IFNDEF GO32V2}
  Process,
{$ENDIF}
{$IFDEF GO32V2}
  Dos,
{$ELSE}
  TvUnix,
{$ENDIF}
  TvSys;

{$IFDEF UNIX}
function ExitCodeOf(Status: LongInt): LongInt;
begin
  if Status = -1 then
    Exit(-1);
  if (Status and $7F) <> 0 then
    Result := 128 + (Status and $7F)
  else
    Result := (Status shr 8) and $FF;
end;
{$ENDIF}

function RunQuiet(const CmdLine: AnsiString): LongInt;
begin
{$IFDEF UNIX}
  Result := ExitCodeOf(fpSystem(CmdLine));
{$ELSE}
  {$IFDEF GO32V2}
  Dos.DosError := 0;
  Dos.Exec(GetEnvironmentVariable('COMSPEC'), '/c ' + CmdLine);
  if Dos.DosError <> 0 then
    Result := -1
  else
    Result := Dos.DosExitCode;
  {$ELSE}
  try
    Result := ExecuteProcess(GetEnvironmentVariable('COMSPEC'), '/c ' + CmdLine);
  except
    Result := -1;
  end;
  {$ENDIF}
{$ENDIF}
end;

{ Gives the terminal back: the hook of TvSys if the program has one, else the terminal backend of tv3 (Unix and Windows; DOS has nothing to give). }
procedure GiveTerminal;
begin
  if Assigned(OnSuspend) then
    OnSuspend()
{$IFNDEF GO32V2}
  else
    UnixSuspend
{$ENDIF}
    ;
end;

procedure TakeTerminal;
begin
  if Assigned(OnResume) then
    OnResume()
{$IFNDEF GO32V2}
  else
    UnixResume
{$ENDIF}
    ;
end;

function RunShell(const CmdLine: AnsiString; Pause: Boolean; const PauseText: AnsiString): LongInt;
begin
  GiveTerminal;
  WriteLn;
{$IFDEF UNIX}
  WriteLn('$ ', CmdLine);
{$ELSE}
  WriteLn('> ', CmdLine);
{$ENDIF}
  Flush(Output);
  Result := RunQuiet(CmdLine);
  if Pause {$IFNDEF GO32V2}and (UnixActive or Assigned(OnSuspend)){$ENDIF} then
  begin
    WriteLn;
    Write(PauseText);
    Flush(Output);
    ReadLn;
  end;
  TakeTerminal;
end;

{$IFNDEF GO32V2}
function RunCapture(const Exe: AnsiString; const Args: array of AnsiString): AnsiString;
const
  ChunkSize = 4096;
var
  P: TProcess;
  Got, Have: LongInt;
  A, Buf: AnsiString;

  function ReadChunk: LongInt;
  begin
    if Have + ChunkSize > Length(Buf) then
      SetLength(Buf, Have + ChunkSize * 4);
    ReadChunk := P.Output.Read(Buf[Have + 1], ChunkSize);
    if ReadChunk > 0 then
      Inc(Have, ReadChunk);
  end;

begin
  Result := '';
  Buf := '';
  Have := 0;
  P := TProcess.Create(nil);
  try
    P.Executable := Exe;
    for A in Args do
      P.Parameters.Add(A);
    P.Options := [poUsePipes, poStderrToOutPut];
    try
      P.Execute;
    except
      Exit('');
    end;
    { read while it runs, so that a full pipe does not stop it }
    while True do
      if P.Output.NumBytesAvailable > 0 then
        ReadChunk
      else if P.Running then
        Sleep(1)
      else
        Break;
    { the rest, up to the end of the pipe }
    repeat
      Got := ReadChunk;
    until Got <= 0;
    Result := Copy(Buf, 1, Have);
  finally
    P.Free;
  end;
end;

function RunFirstLine(const Exe: AnsiString; const Args: array of AnsiString): AnsiString;
var
  K: Integer;
begin
  Result := RunCapture(Exe, Args);
  for K := 1 to Length(Result) do
    if Result[K] in [#10, #13] then
    begin
      SetLength(Result, K - 1);
      Break;
    end;
end;
{$ENDIF}

procedure RestartSelf;
var
  Strs: array of AnsiString;
{$IFDEF UNIX}
  Args: array of PAnsiChar;
{$ENDIF}
  I: Integer;
begin
{$IFDEF UNIX}
  SetLength(Strs, ParamCount + 1);
  SetLength(Args, ParamCount + 2);
  for I := 0 to ParamCount do
  begin
    Strs[I] := ParamStr(I);
    Args[I] := PAnsiChar(Strs[I]);
  end;
  Args[ParamCount + 1] := nil;
  fpExecve(PAnsiChar(Strs[0]), @Args[0], envp);       { returns only when it failed }
{$ELSE}
  SetLength(Strs, ParamCount);
  for I := 1 to ParamCount do
    Strs[I - 1] := ParamStr(I);
  ExecuteProcess(ParamStr(0), Strs);
{$ENDIF}
end;

end.
