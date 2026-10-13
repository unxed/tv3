{ Unix implementation of TvTermOs (included from tvtermos.pas under UNIX). }

var
  SavedTios: Termios;
  OldWinch, OldTerm, OldHup: SigActionRec;
  DeathProc: TOsHook = nil;

function OsIsTerminal: Boolean;
begin
  Result := (IsATTY(0) <> 0) and (IsATTY(1) <> 0);
end;

procedure OsRawOn;
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

procedure OsRawOff;
begin
  TCSetAttr(0, TCSANOW, SavedTios);
end;

procedure OsWrite(P: PByte; Len: Integer);
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

function OsInputReady(TimeoutMs: Integer): Boolean;
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

function OsRead(var Buf; Size: Integer): Integer;
begin
  Result := FpRead(0, Buf, Size);
end;

procedure OsSize(out W, H: Integer);
var
  Ws: TWinSize;
begin
  W := 0;
  H := 0;
  FillChar(Ws, SizeOf(Ws), 0);
  if FpIoctl(1, TIOCGWINSZ, @Ws) = 0 then
  begin
    W := Ws.ws_col;
    H := Ws.ws_row;
  end;
  if W <= 0 then
    W := StrToIntDef(GetEnvironmentVariable('COLUMNS'), 80);
  if H <= 0 then
    H := StrToIntDef(GetEnvironmentVariable('LINES'), 25);
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

procedure OsHandlersOn(AfterDeath: TOsHook);
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

procedure OsHandlersOff;
begin
  FpSigAction(SIGWINCH, @OldWinch, nil);
  FpSigAction(SIGTERM, @OldTerm, nil);
  FpSigAction(SIGHUP, @OldHup, nil);
end;

procedure OsExit(Code: Integer);
begin
  FpExit(Code);
end;

function OsClipSet(const Text: AnsiString): Boolean;
begin
  Result := False;
end;

function OsClipGet(out Text: AnsiString): Boolean;
begin
  Text := '';
  Result := False;
end;

