{ TvSys: what the program needs from the system, as hooks set by a backend, and the event queue of tvision
  (TEventQueue) that reads them.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/system.h          (TEventQueue: getMouseEvent, getKeyEvent, waitForEvents, wakeUp,
                                       setPasteText, doubleDelay, mouseReverse),
    source/tvision/tevent.cpp         (TEventQueue),
    source/platform/events.cpp,
    include/tvision/internal/events.h (WakeUpEventSource, EventWaiter::waitForEvents).
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  See DESIGN.md and docs/ASYNC.md. A backend (memory for tests, DOS, terminal) sets the hooks
  before the application is created. Without a backend there are no events and the
  clock is the system tick counter. }
unit TvSys;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvEvents;

const
  { the event loop has the asynchronous core of docs/ASYNC.md: TEventQueue.WakeUp and TEventQueue.PostEvent }
  TvAsyncCore = True;

type
  { Waits at most TimeoutMs milliseconds (-1: for ever) for an event and returns it in
    Event, or Event.What = evNothing. Mouse events have priority over key events. }
  TPollEventProc = procedure(TimeoutMs: Integer; var Event: TEvent);
  TClockProc = function: Int64;
  TVideoModeProc = procedure(Mode: Word);
  TNoArgProc = procedure;
  TNotifyProc = procedure(const Title, Text: AnsiString);
  TFKeyTitlesProc = procedure(const Titles: array of AnsiString);
  TWindowMaxSizeFunc = function(out Cols, Rows: Integer): Boolean;
  TWindowMaximizeProc = procedure(Maximize: Boolean);
  TColorBitsFunc = function: Integer;

var
  OnPollEvent: TPollEventProc = nil;
  { milliseconds since some moment; only differences matter }
  GetClockMs: TClockProc = nil;
  OnSetVideoMode: TVideoModeProc = nil;
  { the program is stopped (shell, ^Z) and continued }
  OnSuspend: TNoArgProc = nil;
  OnResume: TNoArgProc = nil;
  { a desktop notification, for the backends that have a way to show it: nothing happens elsewhere }
  OnNotify: TNotifyProc = nil;
  { the titles of the F-keys, for a terminal that has a place for them; the largest window, maximize and restore, the quick edit of the mouse press in
    progress; the color depth of the screen in bits: the backends that can (the far2l terminal extensions) set them }
  OnSetFKeyTitles: TFKeyTitlesProc = nil;
  OnWindowMaxSize: TWindowMaxSizeFunc = nil;
  OnWindowMaximize: TWindowMaximizeProc = nil;
  OnQuickEdit: TNoArgProc = nil;
  OnColorBits: TColorBitsFunc = nil;
  { the window of the program has the focus (the terminals that report it; before the first report it is assumed) }
  AppFocused: Boolean = True;
  { the releases of keys come as evKeyUp events (the terminals of the win32 input mode, Windows); off: they are dropped. A terminal view for a program that asked for
    the win32 input mode of its own (TvVt) sets it. }
  KeyUpEvents: Boolean = False;
  { The application itself wants the releases of the modifiers (the switcher of windows commits when Ctrl is released): evKeyUp with KeyCode = 0 and the
    modifiers that are still held in ControlKeyState. It is meaningful only when KeyUpAvailable; the backends that cannot do it ignore it. }
  KeyUpForApp: Boolean = False;
  { The application wants to know which key events are auto repeats (TEvent.KeyDown.KeyFlags and kfRepeat): the menus ask while they are open, to stop a held arrow at
    the end of the menu. The terminals that tell the repeats (the win32 input mode; the keyboard protocol of Kitty when asked) then do; for
    the others a repeat is a press, as before. }
  KeyRepeatInfo: Boolean = False;
  { Set by the backend when the terminal is known to report the releases of keys: the win32 input mode is on, or the terminal sent a key of the keyboard
    protocol of Kitty (so it speaks it). False: the releases cannot be relied on (most terminals), and a feature that waits for one must not wait. }
  KeyUpAvailable: Boolean = False;

type
  { The events of the backend (OnPollEvent). The events the backend gives are kept in a small queue: GetMouseEvent takes the mouse events, GetKeyEvent the
    others (keys, and the commands of the backend such as cmScreenChanged), so that a loop that reads only the keys does not lose the mouse events. }
  TEventQueue = class
  public
    { two presses closer than this are a double click, in ticks of 55 ms }
    class var DoubleDelay: Word;
    { swap the left and right buttons }
    class var MouseReverse: Boolean;
    class procedure GetMouseEvent(var Event: TEvent); static;
    { The text set by SetPasteText first (key events with kbPaste), then the events of the backend that are not mouse events; evNothing when none is waiting. }
    class procedure GetKeyEvent(var Event: TEvent); static;
    { Waits at most TimeoutMs milliseconds (-1: for ever) for an event or a WakeUp; at once when one is waiting. }
    class procedure WaitForEvents(TimeoutMs: Integer); static;
    { Text that comes as key events with kbPaste, one character each, before the events of the backend; CR and CR LF come as LF. }
    class procedure SetPasteText(const Text: AnsiString); static;
    { Ends a WaitForEvents that is waiting, or the next one if none is (the wake-up is kept until a wait takes it).
      Safe to call from any thread; it allocates nothing. Unix: one byte into a non-blocking self-pipe; Windows: an
      event object; DOS (no threads): a flag. }
    class procedure WakeUp; static;
    { Puts an event into the queue of the loop from any thread (docs/ASYNC.md, a message from a task to the loop) and
      wakes the loop. GetKeyEvent gives these events after the events of the backend, in the order they were posted. }
    class procedure PostEvent(const Event: TEvent); static;
    { The handle a backend may add to its own wait so that WakeUp ends it: the read end of the self-pipe (Unix), the
      event object (Windows); THandle(-1) where there is none (DOS). }
    class function WakeUpHandle: THandle; static;
  end;

{ a desktop notification (the terminal may show it only if the window is not the active one) }
procedure Notify(const Title, Text: AnsiString);
{ The titles of F1 .. F12 (Titles[0] is F1; '' is no title; an empty array clears them), for a terminal that shows them (the Touch Bar of a Mac). }
procedure SetFKeyTitles(const Titles: array of AnsiString);
{ The largest size of the window of the program in cells; False when it is not known. }
function WindowMaxSize(out Cols, Rows: Integer): Boolean;
{ Maximizes the window of the program, or restores it. }
procedure WindowMaximize(Maximize: Boolean);
{ The mouse press in progress becomes a selection of text of the terminal (copied to the clipboard as the terminal does it). }
procedure QuickEdit;
{ The colors the screen shows, in bits (4, 8, 24); 0 when it is not known. }
function ColorBits: Integer;

implementation

uses
{$IFDEF UNIX}
  BaseUnix,
{$ENDIF}
{$IFDEF WINDOWS}
  Windows,
{$ENDIF}
  TvKeys, TvUtf8;

const
  MouseQSize = 64;

type
  TPostedEvents = array of TvEvents.TEvent;

var
  { the mouse events read from the backend and not yet taken }
  MouseQ: array[0..MouseQSize - 1] of TvEvents.TEvent;
  MouseQHead: Integer = 0;
  MouseQCount: Integer = 0;
  { an event of the backend that is not a mouse event, read and not yet taken }
  KeyPending: Boolean = False;
  KeyPendingEvent: TvEvents.TEvent;
  { the last wait asked the backend and got nothing (or ended by a wake-up): the next reads do not ask it again }
  NothingFound: Boolean = False;

  PasteSet: Boolean = False;
  PasteText: AnsiString = '';
  PasteIndex: SizeInt = 0;
  ShouldSkipLf: Boolean = False;

  PostLock: TRTLCriticalSection;
  PostQ: TPostedEvents;
  PostHead: Integer = 0;
  PostCount: Integer = 0;

  WakeSignaled: LongInt = 0;
{$IFDEF UNIX}
  WakeFds: TFilDes;
  WakeOk: Boolean = False;
{$ENDIF}
{$IFDEF WINDOWS}
  WakeEvent: THandle = 0;
{$ENDIF}

{ the wake-up handle }

procedure SysCreate;
{$IFDEF UNIX}
var
  I: Integer;
{$ENDIF}
begin
{$IFDEF UNIX}
  if FpPipe(WakeFds) = 0 then
  begin
    for I := 0 to 1 do
      FpFcntl(WakeFds[I], F_SETFL, FpFcntl(WakeFds[I], F_GETFL, 0) or O_NONBLOCK);
    WakeOk := True;
  end;
{$ENDIF}
{$IFDEF WINDOWS}
  WakeEvent := CreateEvent(nil, False, False, nil);
{$ENDIF}
end;

procedure SysDestroy;
begin
{$IFDEF UNIX}
  if WakeOk then
  begin
    FpClose(WakeFds[0]);
    FpClose(WakeFds[1]);
    WakeOk := False;
  end;
{$ENDIF}
{$IFDEF WINDOWS}
  if WakeEvent <> 0 then
  begin
    CloseHandle(WakeEvent);
    WakeEvent := 0;
  end;
{$ENDIF}
end;

procedure SysSignal;
{$IFDEF UNIX}
var
  C: Char;
{$ENDIF}
begin
{$IFDEF UNIX}
  if WakeOk then
  begin
    C := #0;
    while FpWrite(WakeFds[1], C, 1) = 0 do
      ;
  end;
{$ENDIF}
{$IFDEF WINDOWS}
  if WakeEvent <> 0 then
    SetEvent(WakeEvent);
{$ENDIF}
end;

procedure SysClear;
{$IFDEF UNIX}
var
  C: Char;
{$ENDIF}
begin
{$IFDEF UNIX}
  if WakeOk then
    while FpRead(WakeFds[0], C, 1) = 1 do
      ;
{$ENDIF}
{$IFDEF WINDOWS}
  if WakeEvent <> 0 then
    ResetEvent(WakeEvent);
{$ENDIF}
end;

procedure SysWait(TimeoutMs: Integer);
{$IFDEF UNIX}
var
  Pfd: pollfd;
{$ENDIF}
{$IFDEF WINDOWS}
var
  Ms: DWORD;
{$ENDIF}
begin
{$IFDEF UNIX}
  if WakeOk then
  begin
    if TimeoutMs < 0 then
      TimeoutMs := -1;
    Pfd.fd := WakeFds[0];
    Pfd.events := POLLIN;
    Pfd.revents := 0;
    FpPoll(@Pfd, 1, TimeoutMs);
  end;
{$ENDIF}
{$IFDEF WINDOWS}
  if WakeEvent <> 0 then
  begin
    if TimeoutMs < 0 then
      Ms := INFINITE
    else
      Ms := DWORD(TimeoutMs);
    WaitForSingleObject(WakeEvent, Ms);
  end;
{$ENDIF}
end;

procedure WakeSignal;
begin
  if InterlockedExchange(WakeSignaled, 1) = 0 then
    SysSignal;
end;

function WakeClear: Boolean;
begin
  if WakeSignaled <> 0 then
  begin
    SysClear;
    InterlockedExchange(WakeSignaled, 0);
    Result := True;
  end
  else
    Result := False;
end;

{ the queues }

function IsMouseEvent(const Event: TvEvents.TEvent): Boolean; inline;
begin
  Result := (Event.What and evMouse) <> 0;
end;

procedure ReadBackend(TimeoutMs: Integer; var Event: TvEvents.TEvent);
begin
  TvEvents.ClearEvent(Event);
  OnPollEvent(TimeoutMs, Event);
end;

procedure PushMouse(const Event: TvEvents.TEvent);
begin
  if MouseQCount < MouseQSize then
  begin
    MouseQ[(MouseQHead + MouseQCount) mod MouseQSize] := Event;
    Inc(MouseQCount);
  end;
end;

procedure PopMouse(var Event: TvEvents.TEvent);
begin
  Event := MouseQ[MouseQHead];
  MouseQHead := (MouseQHead + 1) mod MouseQSize;
  Dec(MouseQCount);
end;

procedure StoreBackendEvent(const Event: TvEvents.TEvent);
begin
  if IsMouseEvent(Event) then
    PushMouse(Event)
  else if Event.What <> evNothing then
  begin
    KeyPendingEvent := Event;
    KeyPending := True;
  end;
end;

function PostedWaiting: Boolean;
begin
  EnterCriticalSection(PostLock);
  Result := PostCount > 0;
  LeaveCriticalSection(PostLock);
end;

function TakePosted(var Event: TvEvents.TEvent): Boolean;
begin
  EnterCriticalSection(PostLock);
  Result := PostCount > 0;
  if Result then
  begin
    Event := PostQ[PostHead];
    PostHead := (PostHead + 1) mod Length(PostQ);
    Dec(PostCount);
  end;
  LeaveCriticalSection(PostLock);
end;

function GetPasteEvent(var Event: TvEvents.TEvent): Boolean;
var
  Len, Used: SizeInt;
  U: Integer;
  CodePoint: LongWord;
begin
  Result := False;
  if PasteSet then
  begin
    Len := Length(PasteText) - PasteIndex;
    if Len > 0 then
    begin
      TvUtf8.Utf8Decode(PByte(@PasteText[PasteIndex + 1]), Len, CodePoint, U);
      Used := U;
      if Used < 1 then
        Used := 1;
      if Used > Len then
        Used := Len;
      if Used > MaxCharSize then
        Used := MaxCharSize;
      TvEvents.ClearEvent(Event);
      Event.What := evKeyDown;
      Event.KeyDown.KeyCode := 0;
      Event.KeyDown.ControlKeyState := kbPaste;
      Event.KeyDown.TextLength := Byte(Used);
      Move(PasteText[PasteIndex + 1], Event.KeyDown.Text[0], Used);
      Inc(PasteIndex, Used);
      Result := True;
      Exit;
    end;
    PasteText := '';
    PasteIndex := 0;
    PasteSet := False;
  end;
end;

procedure GetKeyOrPasteEvent(var Event: TvEvents.TEvent);
var
  E: TvEvents.TEvent;
begin
  if GetPasteEvent(Event) then
    Exit;
  if KeyPending then
  begin
    Event := KeyPendingEvent;
    KeyPending := False;
    Exit;
  end;
  if NothingFound then
    NothingFound := False
  else if Assigned(OnPollEvent) then
    repeat
      ReadBackend(0, E);
      if E.What = evNothing then
        Break;
      if not IsMouseEvent(E) then
      begin
        Event := E;
        Exit;
      end;
      PushMouse(E);
    until False;
  if TakePosted(Event) then
    Exit;
  TvEvents.ClearEvent(Event);
end;

{ TEventQueue }

class procedure TEventQueue.GetMouseEvent(var Event: TvEvents.TEvent);
var
  E: TvEvents.TEvent;
begin
  if MouseQCount > 0 then
    PopMouse(Event)
  else if KeyPending or NothingFound or not Assigned(OnPollEvent) then
  begin
    TvEvents.ClearEvent(Event);
    Exit;
  end
  else
  begin
    ReadBackend(0, E);
    if IsMouseEvent(E) then
      Event := E
    else
    begin
      StoreBackendEvent(E);
      TvEvents.ClearEvent(Event);
      Exit;
    end;
  end;
  if MouseReverse and (Event.Mouse.Buttons <> 0) and (Event.Mouse.Buttons <> 3) then
    Event.Mouse.Buttons := Event.Mouse.Buttons xor 3;
end;

class procedure TEventQueue.GetKeyEvent(var Event: TvEvents.TEvent);
begin
  GetKeyOrPasteEvent(Event);

  if ShouldSkipLf then
  begin
    ShouldSkipLf := False;
    if (Event.What = evKeyDown) and ((Event.KeyDown.ControlKeyState and kbPaste) <> 0) and
       ( ((Event.KeyDown.TextLength = 0) and (Event.KeyDown.CharScan.CharCode = 10)) or
         ((Event.KeyDown.TextLength = 1) and (Event.KeyDown.Text[0] = #10)) ) then
      GetKeyOrPasteEvent(Event);
  end;

  if (Event.What = evKeyDown) and ((Event.KeyDown.ControlKeyState and kbPaste) <> 0) then
  begin
    if Event.KeyDown.TextLength = 0 then
    begin
      Event.KeyDown.Text[0] := Chr(Event.KeyDown.CharScan.CharCode);
      Event.KeyDown.TextLength := 1;
    end;
    if Event.KeyDown.Text[0] = #13 then
    begin
      Event.KeyDown.Text[0] := #10;
      ShouldSkipLf := True;
    end;
    Event.KeyDown.KeyCode := 0;
  end;
end;

class procedure TEventQueue.WaitForEvents(TimeoutMs: Integer);
var
  E: TvEvents.TEvent;
begin
  if WakeClear then
  begin
    NothingFound := True;
    Exit;
  end;
  if (MouseQCount > 0) or KeyPending or PasteSet or PostedWaiting then
    Exit;
  if Assigned(OnPollEvent) then
  begin
    ReadBackend(TimeoutMs, E);
    WakeClear;
    if E.What = evNothing then
      NothingFound := True
    else
    begin
      NothingFound := False;
      StoreBackendEvent(E);
    end;
  end
  else
  begin
    SysWait(TimeoutMs);
    WakeClear;
    SysClear;
  end;
end;

class procedure TEventQueue.SetPasteText(const Text: AnsiString);
begin
  PasteText := Text;
  PasteIndex := 0;
  PasteSet := True;
end;

class procedure TEventQueue.WakeUp;
begin
  WakeSignal;
end;

class procedure TEventQueue.PostEvent(const Event: TvEvents.TEvent);
var
  NewQ: TPostedEvents;
  I, N: Integer;
begin
  EnterCriticalSection(PostLock);
  if PostCount = Length(PostQ) then
  begin
    N := Length(PostQ) * 2;
    if N < 16 then
      N := 16;
    SetLength(NewQ, N);
    for I := 0 to PostCount - 1 do
      NewQ[I] := PostQ[(PostHead + I) mod Length(PostQ)];
    PostQ := NewQ;
    PostHead := 0;
  end;
  PostQ[(PostHead + PostCount) mod Length(PostQ)] := Event;
  Inc(PostCount);
  LeaveCriticalSection(PostLock);
  WakeSignal;
end;

class function TEventQueue.WakeUpHandle: THandle;
begin
{$IFDEF UNIX}
  if WakeOk then
    Result := THandle(WakeFds[0])
  else
    Result := THandle(-1);
{$ELSE}
{$IFDEF WINDOWS}
  if WakeEvent <> 0 then
    Result := WakeEvent
  else
    Result := THandle(-1);
{$ELSE}
  Result := THandle(-1);
{$ENDIF}
{$ENDIF}
end;

{ the hooks }

procedure Notify(const Title, Text: AnsiString);
begin
  if Assigned(OnNotify) then
    OnNotify(Title, Text);
end;

procedure SetFKeyTitles(const Titles: array of AnsiString);
begin
  if Assigned(OnSetFKeyTitles) then
    OnSetFKeyTitles(Titles);
end;

function WindowMaxSize(out Cols, Rows: Integer): Boolean;
begin
  Cols := 0;
  Rows := 0;
  if Assigned(OnWindowMaxSize) then
    Result := OnWindowMaxSize(Cols, Rows)
  else
    Result := False;
end;

procedure WindowMaximize(Maximize: Boolean);
begin
  if Assigned(OnWindowMaximize) then
    OnWindowMaximize(Maximize);
end;

procedure QuickEdit;
begin
  if Assigned(OnQuickEdit) then
    OnQuickEdit;
end;

function ColorBits: Integer;
begin
  if Assigned(OnColorBits) then
    Result := OnColorBits()
  else
    Result := 0;
end;

initialization
  TEventQueue.DoubleDelay := 8;
  TEventQueue.MouseReverse := False;
  InitCriticalSection(PostLock);
  SysCreate;

finalization
  SysDestroy;
  DoneCriticalSection(PostLock);

end.
