{ TvTermOsUnix: the operating system calls of the terminal backend on Unix: termios, poll, ioctl, signals.
  The backend of the facade TvTermOs (the code is the same as it was in TvTermOs, only the place is new).

  MIT, see tv/LICENSE. }
unit TvTermOsUnix;

{$I tvdefs.inc}

interface

uses
  TvTermOsBase;

function BackendOsIsTerminal: Boolean;
procedure BackendOsRawOn;
procedure BackendOsRawOff;
procedure BackendOsWrite(P: PByte; Len: Integer);
function BackendOsInputReady(TimeoutMs: Integer): Boolean;
function BackendOsRead(var Buf; Size: Integer): Integer;
procedure BackendOsSize(out W, H: Integer);
function BackendOsClipSet(const Text: AnsiString): Boolean;
function BackendOsClipGet(out Text: AnsiString): Boolean;
procedure BackendOsHandlersOn(AfterDeath: TOsHook);
procedure BackendOsHandlersOff;
procedure BackendOsExit(Code: Integer);

implementation

uses
  SysUtils, BaseUnix, termio;

var
  SavedTios: Termios;
  OldWinch, OldTerm, OldHup: SigActionRec;
  DeathProc: TOsHook = nil;

function BackendOsIsTerminal: Boolean;
begin
  Result := (IsATTY(0) <> 0) and (IsATTY(1) <> 0);
end;

procedure BackendOsRawOn;
var
  Raw: Termios;
begin
  TCGetAttr(0, SavedTios);
  Raw := SavedTios;
  CFMakeRaw(Raw);
  Raw.c_cc[VMIN] := 1;
  Raw.c_cc[VTIME] := 0;
  TCSetAttr(0, TCSANOW, Raw);
end;

procedure BackendOsRawOff;
begin
  TCSetAttr(0, TCSANOW, SavedTios);
end;

procedure BackendOsWrite(P: PByte; Len: Integer);
var
  N: TSsize;
begin
  while Len > 0 do
  begin
    N := FpWrite(1, P^, Len);
    if N < 0 then
    begin
      if fpgeterrno = ESysEINTR then
        Continue;
      if fpgeterrno = ESysEAGAIN then
      begin
        Sleep(1);
        Continue;
      end;
      Exit;
    end;
    Inc(P, N);
    Dec(Len, N);
  end;
end;

function BackendOsInputReady(TimeoutMs: Integer): Boolean;
var
  P: TPollFd;
  R: cint;
begin
  P.fd := 0;
  P.events := POLLIN;
  P.revents := 0;
  R := FpPoll(@P, 1, TimeoutMs);
  Result := (R > 0) and ((P.revents and (POLLIN or POLLHUP)) <> 0);
end;

function BackendOsRead(var Buf; Size: Integer): Integer;
begin
  Result := FpRead(0, Buf, Size);
end;

procedure BackendOsSize(out W, H: Integer);
var
  Ws: TWinSize;
begin
  W := 0;
  H := 0;
  FillChar(Ws, SizeOf(Ws), 0);
  { the kernel knows the size of the terminal of the output or of the input; else COLUMNS and LINES; else what the terminal told; else 80 by 25 }
  if (FpIoctl(1, TIOCGWINSZ, @Ws) = 0) or (FpIoctl(0, TIOCGWINSZ, @Ws) = 0) then
  begin
    W := Ws.ws_col;
    H := Ws.ws_row;
  end;
  if W <= 0 then
    W := StrToIntDef(GetEnvironmentVariable('COLUMNS'), 0);
  if H <= 0 then
    H := StrToIntDef(GetEnvironmentVariable('LINES'), 0);
  if ((W <= 0) or (W > 4095)) and (OsToldCols > 0) then
    W := OsToldCols;
  if ((H <= 0) or (H > 4095)) and (OsToldRows > 0) then
    H := OsToldRows;
  if (W <= 0) or (W > 4095) then
    W := 80;
  if (H <= 0) or (H > 4095) then
    H := 25;
end;

procedure WinchHandler(Sig: cint); cdecl;
begin
  OsResizeFlag := 1;
end;

procedure DeathHandler(Sig: cint); cdecl;
begin
  if Assigned(DeathProc) then
    DeathProc;
  FpExit(128 + Sig);
end;

procedure BackendOsHandlersOn(AfterDeath: TOsHook);
var
  Act: SigActionRec;
begin
  DeathProc := AfterDeath;
  FillChar(Act, SizeOf(Act), 0);
  Act.sa_handler := SigActionHandler(@WinchHandler);
  FpSigAction(SIGWINCH, @Act, @OldWinch);
  Act.sa_handler := SigActionHandler(@DeathHandler);
  FpSigAction(SIGTERM, @Act, @OldTerm);
  FpSigAction(SIGHUP, @Act, @OldHup);
end;

procedure BackendOsHandlersOff;
begin
  FpSigAction(SIGWINCH, @OldWinch, nil);
  FpSigAction(SIGTERM, @OldTerm, nil);
  FpSigAction(SIGHUP, @OldHup, nil);
end;

procedure BackendOsExit(Code: Integer);
begin
  FpExit(Code);
end;

function BackendOsClipSet(const Text: AnsiString): Boolean;
begin
  Result := False;
end;

function BackendOsClipGet(out Text: AnsiString): Boolean;
begin
  Text := '';
  Result := False;
end;


end.
