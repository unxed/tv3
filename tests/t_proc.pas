program t_proc;
{ TvProc: running programs. Unix only (it needs /bin/sh and echo). }
{$I ../src/tvdefs.inc}
uses SysUtils, TvSys, TvProc;
{$I testlib.inc}

var
  Susp, Res: Integer;

procedure OnS;
begin
  Inc(Susp);
end;

procedure OnR;
begin
  Inc(Res);
end;

begin
  Check(RunQuiet('exit 0') = 0, 'RunQuiet: exit code 0');
  Check(RunQuiet('exit 7') = 7, 'RunQuiet: exit code 7');
  Check(RunQuiet('kill -9 $$') = 137, 'RunQuiet: killed = 128 + signal');
  Check(RunCapture('/bin/echo', ['hello', 'world']) = 'hello world'#10, 'RunCapture: the output');
  Check(RunCapture('/bin/sh', ['-c', 'echo out; echo err 1>&2']) = 'out'#10'err'#10, 'RunCapture: both outputs');
  Check(RunCapture('/no/such/program', []) = '', 'RunCapture: a missing program');
  Check(RunFirstLine('/bin/sh', ['-c', 'echo one; echo two']) = 'one', 'RunFirstLine');
  Susp := 0; Res := 0;
  OnSuspend := @OnS;
  OnResume := @OnR;
  Check(RunShell('exit 3') = 3, 'RunShell: the exit code');
  Check((Susp = 1) and (Res = 1), 'RunShell: the terminal is given back and taken again');
  Finish;
end.
