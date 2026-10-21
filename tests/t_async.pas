program t_async;
{ The asynchronous contract (docs/ASYNC.md): TEventQueue.WakeUp, called from another thread, ends a WaitForEvents that
  is waiting. The check needs TEventQueue.WakeUp; TvSys declares the constant TvAsyncCore when it has it. Without it
  the test prints a SKIP line and passes, so that the missing check is visible in the log and CI stays green. }
{$I ../src/tvdefs.inc}
uses {$IFDEF UNIX}cthreads,{$ENDIF} SysUtils, Classes, TvSys;
{$I testlib.inc}

{$IF DECLARED(TvAsyncCore)}
type
  TWaker = class(TThread)
  protected
    procedure Execute; override;
  end;

procedure TWaker.Execute;
begin
  Sleep(100);
  TEventQueue.WakeUp;
end;

var
  Waker: TWaker;
  T0, Elapsed: QWord;
{$ENDIF}

begin
{$IF DECLARED(TvAsyncCore)}
  { a wake-up before the wait is kept: the wait returns at once }
  TEventQueue.WakeUp;
  T0 := GetTickCount64;
  TEventQueue.WaitForEvents(5000);
  Check(GetTickCount64 - T0 < 1000, 'a WakeUp before WaitForEvents ends the next wait at once');

  { a wake-up from another thread ends a wait that is already blocked }
  Waker := TWaker.Create(False);
  T0 := GetTickCount64;
  TEventQueue.WaitForEvents(5000);
  Elapsed := GetTickCount64 - T0;
  Waker.WaitFor;
  Waker.Free;
  Check(Elapsed < 2000, 'WakeUp from a second thread wakes WaitForEvents');
{$ELSE}
  WriteLn('SKIP WakeUp from a second thread wakes WaitForEvents: TvSys has no TEventQueue.WakeUp yet ',
    '(it comes with the event-loop core, step S3 of unxed/tv3#12)');
{$ENDIF}
  Finish;
end.
