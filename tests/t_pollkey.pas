program t_pollkey;
{$I ../src/tvdefs.inc}
uses TvEvents, TvSys;
{$I testlib.inc}

var
  Queue: array[0..7] of Word;
  QHead, QTail: Integer;

procedure Push(What: Word);
begin
  Queue[QTail] := What;
  Inc(QTail);
end;

procedure FakePoll(TimeoutMs: Integer; var Event: TEvent);
begin
  ClearEvent(Event);
  if QHead < QTail then
  begin
    Event.What := Queue[QHead];
    if Event.What = evKeyDown then
      Event.KeyCode := $011B;
    Inc(QHead);
  end;
end;

var
  E: TEvent;
begin
  OnPollEvent := @FakePoll;
  QHead := 0;
  QTail := 0;
  PollKeyEvent(E);
  Check(E.What = evNothing, 'empty queue: evNothing');

  Push(evKeyDown);
  PollKeyEvent(E);
  Check((E.What = evKeyDown) and (E.KeyCode = $011B), 'a key is returned');
  PollKeyEvent(E);
  Check(E.What = evNothing, 'the key was taken');

  QHead := 0; QTail := 0;
  Push(evMouseMove); Push(evMouseDown); Push(evKeyDown);
  PollKeyEvent(E);
  Check((E.What = evKeyDown) and (E.KeyCode = $011B), 'mouse events before the key are dropped');
  PollKeyEvent(E);
  Check(E.What = evNothing, 'nothing left');

  QHead := 0; QTail := 0;
  Push(evMouseMove); Push(evMouseUp);
  PollKeyEvent(E);
  Check(E.What = evNothing, 'only mouse events: evNothing, and no stale fields');
  Check(QHead = QTail, 'the mouse events were consumed');

  OnPollEvent := nil;
  PollKeyEvent(E);
  Check(E.What = evNothing, 'no backend: evNothing');
  Finish;
end.
