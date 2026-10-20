{ A program for tv/tests/pty/test_vtrun.py: runs a shell command on the screen of the application (VtRunScreen), then shows the screen again (VtShowScreen). }
program rundemo;
{$I ../../src/tvdefs.inc}
uses TvUnix, TvVt, TvVtRun, TvPty;
var
  Emu: TVtEmu;
  Pty: TPty;
  St, St3, MarkerStatus, SessionStatus: Integer;
  Why: TVtSessionExit;
begin
  Emu := nil;
  if not UnixInit then
  begin
    WriteLn('no terminal');
    Halt(1);
  end;
  St := VtRunScreen(Emu, '/bin/sh', ['sh', '-c', 'echo hello; read x; echo got:$x; exit 5'], '', '$ mycommand', 1);
  VtShowScreen(Emu);
  St3 := VtRunScreen(Emu, '/bin/sh', ['sh', '-c', 'exit 3'], '', '', 0);
  Pty := nil;
  MarkerStatus := -1;
  SessionStatus := -1;
  if VtSessionStart(Emu, Pty, '/bin/sh', ['sh', '-c', 'printf ''\033]0;dn-done:7\007''; sleep 1; exit 2'], '') then
  begin
    VtSessionPump(Emu, Pty, Why, MarkerStatus);
    if Why = vtsCommandDone then
    begin
      VtSessionPump(Emu, Pty, Why, SessionStatus);
      if Why <> vtsProcessEnded then
        SessionStatus := -1;
    end;
    VtSessionStop(Emu, Pty);
  end;
  Emu.Free;
  UnixDone;
  WriteLn('DONE ', St);
  WriteLn('EXIT 3 ', St3);
  WriteLn('SESSION ', MarkerStatus, ' ', SessionStatus);
end.
