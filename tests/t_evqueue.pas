program t_evqueue;
{ TEventQueue over the hook OnPollEvent of the backend. }
{$I ../src/tvdefs.inc}
uses TvEvents, TvKeys, TvSys;
{$I testlib.inc}

var
  Queue: array[0..127] of Word;
  QHead, QTail: Integer;
  LastTimeout: Integer;
  Polls: Integer;

procedure Push(What: Word);
begin
  Queue[QTail] := What;
  Inc(QTail);
end;

procedure Reset;
begin
  QHead := 0;
  QTail := 0;
  Polls := 0;
end;

procedure FakePoll(TimeoutMs: Integer; var Event: TEvent);
begin
  LastTimeout := TimeoutMs;
  Inc(Polls);
  ClearEvent(Event);
  if QHead < QTail then
  begin
    Event.What := Queue[QHead];
    if Event.What = evKeyDown then
      Event.KeyDown.KeyCode := $011B
    else if Event.What = evCommand then
      Event.Message.Command := 52
    else
      Event.Mouse.Where.X := QHead;
    Inc(QHead);
  end;
end;

function TakeAll: Integer;
var
  E: TEvent;
begin
  Result := 0;
  repeat
    TEventQueue.GetMouseEvent(E);
    if E.What = evNothing then
      TEventQueue.GetKeyEvent(E);
    if E.What <> evNothing then
      Inc(Result);
  until E.What = evNothing;
end;

var
  E: TEvent;
  I: Integer;
  S: AnsiString;
begin
  Check(TEventQueue.DoubleDelay = 8, 'the double click delay is 8 ticks');
  Check(not TEventQueue.MouseReverse, 'the buttons are not swapped');

  OnPollEvent := @FakePoll;
  Reset;
  TEventQueue.GetKeyEvent(E);
  Check(E.What = evNothing, 'empty: no key event');
  TEventQueue.GetMouseEvent(E);
  Check(E.What = evNothing, 'empty: no mouse event');

  Push(evKeyDown);
  TEventQueue.GetKeyEvent(E);
  Check((E.What = evKeyDown) and (E.KeyDown.KeyCode = $011B), 'a key');
  TEventQueue.GetKeyEvent(E);
  Check(E.What = evNothing, 'the key was taken');

  { a loop that reads only the keys: the mouse events wait for GetMouseEvent }
  Reset;
  Push(evMouseMove); Push(evMouseDown); Push(evKeyDown);
  TEventQueue.GetKeyEvent(E);
  Check((E.What = evKeyDown) and (E.KeyDown.KeyCode = $011B), 'the key behind two mouse events');
  TEventQueue.GetKeyEvent(E);
  Check(E.What = evNothing, 'no other key');
  TEventQueue.GetMouseEvent(E);
  Check((E.What = evMouseMove) and (E.Mouse.Where.X = 0), 'the first mouse event was kept');
  TEventQueue.GetMouseEvent(E);
  Check((E.What = evMouseDown) and (E.Mouse.Where.X = 1), 'the second one too, in order');
  TEventQueue.GetMouseEvent(E);
  Check(E.What = evNothing, 'nothing left');

  { the commands of the backend come with the keys }
  Reset;
  Push(evCommand);
  TEventQueue.GetMouseEvent(E);
  Check(E.What = evNothing, 'a command is not a mouse event');
  TEventQueue.GetKeyEvent(E);
  Check((E.What = evCommand) and (E.Message.Command = 52), 'a command of the backend');

  { the wait }
  Reset;
  TEventQueue.WaitForEvents(30);
  Check((Polls = 1) and (LastTimeout = 30), 'the wait asks the backend with the timeout');
  TEventQueue.GetMouseEvent(E);
  TEventQueue.GetKeyEvent(E);
  Check((Polls = 1) and (E.What = evNothing), 'right after a wait that found nothing the backend is not asked again');
  TEventQueue.GetKeyEvent(E);
  Check(Polls = 2, 'later it is');
  Push(evMouseUp);
  TEventQueue.WaitForEvents(30);
  Polls := 0;
  TEventQueue.WaitForEvents(30);
  Check(Polls = 0, 'an event is waiting: no wait');
  TEventQueue.GetMouseEvent(E);
  Check(E.What = evMouseUp, 'the event the wait got');

  { a long loop of keys only: the queue keeps the newest mouse events }
  Reset;
  for I := 1 to 100 do
    Push(evMouseMove);
  TEventQueue.GetKeyEvent(E);
  Check(E.What = evNothing, 'only mouse events: no key');
  Check(QHead = QTail, 'all were read from the backend');
  Check(TakeAll = 64, 'the queue holds 64 of them');

  { paste text }
  Reset;
  Push(evKeyDown);
  TEventQueue.SetPasteText('a'#13#10'Ж'#13'b');
  Polls := 0;
  TEventQueue.WaitForEvents(1000);
  Check(Polls = 0, 'paste text is waiting: no wait');
  S := '';
  for I := 1 to 5 do
  begin
    TEventQueue.GetKeyEvent(E);
    if (E.What = evKeyDown) and ((E.KeyDown.ControlKeyState and kbPaste) <> 0) and (E.KeyDown.KeyCode = 0) then
      S := S + EventText(E);
  end;
  Check(S = 'a'#10'Ж'#10'b', 'paste events, one character each, CR and CR LF as LF');
  TEventQueue.GetKeyEvent(E);
  Check((E.What = evKeyDown) and (E.KeyDown.KeyCode = $011B), 'then the key of the backend');
  TEventQueue.SetPasteText('');
  TEventQueue.GetKeyEvent(E);
  Check(E.What = evNothing, 'empty paste text: nothing');

  OnPollEvent := nil;
  TEventQueue.WaitForEvents(10);
  TEventQueue.GetKeyEvent(E);
  Check(E.What = evNothing, 'no backend: no events');
  Finish;
end.
