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
  QueueSize = 64;
  {$IFDEF UNIX}
  FdCloExec = 1;
  {$ENDIF}

var
  MouseQueue: array[0..QueueSize - 1] of TEvent;
  MouseHead: Integer = 0;
  MouseCount: Integer = 0;

  KeyQueue: array[0..QueueSize - 1] of TEvent;
  KeyHead: Integer = 0;
  KeyCount: Integer = 0;

  PostQueue: array of TEvent;
  PostHead: Integer = 0;
  PostCount: Integer = 0;
  PostLock: TRTLCriticalSection;

  PasteBuf: AnsiString = '';
  PasteIndex: Integer = 0;
  PastePresent: Boolean = False;

  ShouldSkipLf: Boolean = False;
  WaitFoundNothing: Boolean = False;

  WakeSignaled: LongInt = 0;
  {$IFDEF UNIX}
  WakeReadFd: LongInt = -1;
  WakeWriteFd: LongInt = -1;
  {$ENDIF}
  {$IFDEF WINDOWS}
  WakeEvent: THandle = 0;
  {$ENDIF}

{ the wake-up handle }

procedure CreateWakeUpHandle;
{$IFDEF UNIX}
var
  Fds: TFilDes;
  I: Integer;
  Flags: LongInt;
begin
  if FpPipe(Fds) <> -1 then
  begin
    for I := 0 to 1 do
    begin
      FpFcntl(Fds[I], F_SETFD, FdCloExec);
      Flags := FpFcntl(Fds[I], F_GETFL);
      if Flags <> -1 then
        FpFcntl(Fds[I], F_SETFL, Flags or O_NONBLOCK);
    end;
    WakeReadFd := Fds[0];
    WakeWriteFd := Fds[1];
  end;
end;
{$ELSE}
{$IFDEF WINDOWS}
begin
  WakeEvent := CreateEvent(nil, False, False, nil);
end;
{$ELSE}
begin
end;
{$ENDIF}
{$ENDIF}

procedure SysSignal;
{$IFDEF UNIX}
var
  C: Char;
begin
  C := #0;
  if WakeWriteFd <> -1 then
    while FpWrite(WakeWriteFd, PChar(@C), 1) = 0 do
      ;
end;
{$ELSE}
{$IFDEF WINDOWS}
begin
  if WakeEvent <> 0 then
    SetEvent(WakeEvent);
end;
{$ELSE}
begin
end;
{$ENDIF}
{$ENDIF}

procedure SysClear;
{$IFDEF UNIX}
var
  Buf: array[0..15] of Char;
begin
  if WakeReadFd <> -1 then
    while FpRead(WakeReadFd, PChar(@Buf[0]), SizeOf(Buf)) > 0 do
      ;
end;
{$ELSE}
{$IFDEF WINDOWS}
begin
  if WakeEvent <> 0 then
    ResetEvent(WakeEvent);
end;
{$ELSE}
begin
end;
{$ENDIF}
{$ENDIF}

function TakeWakeUp: Boolean;
begin
  Result := InterLockedExchange(WakeSignaled, 0) <> 0;
  if Result then
    SysClear;
end;

procedure WaitOnWakeUpHandle(TimeoutMs: Integer);
{$IFDEF UNIX}
var
  Pfd: pollfd;
begin
  if WakeReadFd = -1 then
  begin
    if TimeoutMs > 0 then
      SysUtils.Sleep(TimeoutMs);
    Exit;
  end;
  Pfd.fd := WakeReadFd;
  Pfd.events := POLLIN;
  Pfd.revents := 0;
  if FpPoll(@Pfd, 1, TimeoutMs) > 0 then
  begin
    InterLockedExchange(WakeSignaled, 0);
    SysClear;
  end;
end;
{$ELSE}
{$IFDEF WINDOWS}
var
  Timeout: DWORD;
begin
  if WakeEvent = 0 then
  begin
    if TimeoutMs > 0 then
      SysUtils.Sleep(TimeoutMs);
    Exit;
  end;
  if TimeoutMs < 0 then
    Timeout := INFINITE
  else
    Timeout := DWORD(TimeoutMs);
  if WaitForSingleObject(WakeEvent, Timeout) = WAIT_OBJECT_0 then
    InterLockedExchange(WakeSignaled, 0);
end;
{$ELSE}
begin
end;
{$ENDIF}
{$ENDIF}

{ the queues }

function IsMouseEvent(const Ev: TEvent): Boolean; inline;
begin
  Result := (Ev.What and evMouse) <> 0;
end;

procedure PushMouse(const Ev: TEvent);
begin
  if MouseCount < QueueSize then
  begin
    MouseQueue[(MouseHead + MouseCount) mod QueueSize] := Ev;
    Inc(MouseCount);
  end;
end;

function PopMouse(var Ev: TEvent): Boolean;
begin
  Result := MouseCount > 0;
  if Result then
  begin
    Ev := MouseQueue[MouseHead];
    MouseHead := (MouseHead + 1) mod QueueSize;
    Dec(MouseCount);
  end;
end;

procedure PushKey(const Ev: TEvent);
begin
  if KeyCount < QueueSize then
  begin
    KeyQueue[(KeyHead + KeyCount) mod QueueSize] := Ev;
    Inc(KeyCount);
  end;
end;

function PopKey(var Ev: TEvent): Boolean;
begin
  Result := KeyCount > 0;
  if Result then
  begin
    Ev := KeyQueue[KeyHead];
    KeyHead := (KeyHead + 1) mod QueueSize;
    Dec(KeyCount);
  end;
end;

function PopPosted(var Ev: TEvent): Boolean;
begin
  EnterCriticalSection(PostLock);
  try
    Result := PostCount > 0;
    if Result then
    begin
      Ev := PostQueue[PostHead];
      Inc(PostHead);
      Dec(PostCount);
      if PostCount = 0 then
        PostHead := 0;
    end;
  finally
    LeaveCriticalSection(PostLock);
  end;
end;

function PostedWaiting: Boolean;
begin
  EnterCriticalSection(PostLock);
  try
    Result := PostCount > 0;
  finally
    LeaveCriticalSection(PostLock);
  end;
end;

function ReadBackend(var Ev: TEvent): Boolean;
begin
  ClearEvent(Ev);
  if Assigned(OnPollEvent) then
    OnPollEvent(0, Ev);
  Result := Ev.What <> evNothing;
end;

{ the paste text and the keys }

function GetPasteEvent(var Ev: TEvent): Boolean;
var
  Left, Len: Integer;
  P: PByte;
  CodePoint: LongWord;
begin
  if PastePresent then
  begin
    Left := Length(PasteBuf) - PasteIndex;
    if Left > 0 then
    begin
      P := PByte(@PasteBuf[PasteIndex + 1]);
      TvUtf8.Utf8Decode(P, Left, CodePoint, Len);
      if Len < 1 then
        Len := 1;
      if Len > Left then
        Len := Left;
      if Len > MaxCharSize then
        Len := MaxCharSize;
      ClearEvent(Ev);
      Ev.What := evKeyDown;
      Ev.KeyDown.KeyCode := 0;
      Ev.KeyDown.ControlKeyState := kbPaste;
      Move(P^, Ev.KeyDown.Text[0], Len);
      Ev.KeyDown.TextLength := Len;
      Inc(PasteIndex, Len);
      Exit(True);
    end;
    PasteBuf := '';
    PasteIndex := 0;
    PastePresent := False;
  end;
  Result := False;
end;

procedure GetKeyOrPasteEvent(var Ev: TEvent; NoPoll: Boolean);
var
  E: TEvent;
begin
  if GetPasteEvent(Ev) then
    Exit;
  if PopKey(Ev) then
    Exit;
  if not NoPoll then
    while ReadBackend(E) do
      if IsMouseEvent(E) then
        PushMouse(E)
      else
      begin
        Ev := E;
        Exit;
      end;
  if not PopPosted(Ev) then
    ClearEvent(Ev);
end;

{ TEventQueue }

class procedure TEventQueue.GetMouseEvent(var Event: TEvent);
var
  E: TEvent;
begin
  if (MouseCount = 0) and not WaitFoundNothing then
    while (KeyCount < QueueSize) and ReadBackend(E) do
      if IsMouseEvent(E) then
      begin
        PushMouse(E);
        Break;
      end
      else
        PushKey(E);
  if PopMouse(Event) then
  begin
    if MouseReverse and (Event.Mouse.Buttons <> 0) and (Event.Mouse.Buttons <> 3) then
      Event.Mouse.Buttons := Event.Mouse.Buttons xor 3;
  end
  else
    ClearEvent(Event);
end;

class procedure TEventQueue.GetKeyEvent(var Event: TEvent);
var
  NoPoll: Boolean;
begin
  NoPoll := WaitFoundNothing;
  WaitFoundNothing := False;

  GetKeyOrPasteEvent(Event, NoPoll);

  if ShouldSkipLf then
  begin
    ShouldSkipLf := False;
    if (Event.What = evKeyDown) and ((Event.KeyDown.ControlKeyState and kbPaste) <> 0) and
       (((Event.KeyDown.TextLength = 0) and (Event.KeyDown.CharScan.CharCode = 10)) or
        ((Event.KeyDown.TextLength = 1) and (Event.KeyDown.Text[0] = #10))) then
      GetKeyOrPasteEvent(Event, NoPoll);
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
  E: TEvent;
begin
  if TakeWakeUp then
    Exit;
  if (MouseCount > 0) or (KeyCount > 0) or PastePresent or PostedWaiting then
    Exit;
  if Assigned(OnPollEvent) then
  begin
    ClearEvent(E);
    OnPollEvent(TimeoutMs, E);
    if E.What = evNothing then
      WaitFoundNothing := True
    else if IsMouseEvent(E) then
      PushMouse(E)
    else
      PushKey(E);
    TakeWakeUp;
  end
  else
    WaitOnWakeUpHandle(TimeoutMs);
end;

class procedure TEventQueue.SetPasteText(const Text: AnsiString);
begin
  PasteBuf := Text;
  PasteIndex := 0;
  PastePresent := True;
end;

class procedure TEventQueue.WakeUp;
begin
  if InterLockedExchange(WakeSignaled, 1) = 0 then
    SysSignal;
end;

class procedure TEventQueue.PostEvent(const Event: TEvent);
var
  I: Integer;
begin
  EnterCriticalSection(PostLock);
  try
    if PostHead + PostCount >= Length(PostQueue) then
    begin
      if PostHead > 0 then
      begin
        for I := 0 to PostCount - 1 do
          PostQueue[I] := PostQueue[PostHead + I];
        PostHead := 0;
      end
      else
        SetLength(PostQueue, Length(PostQueue) * 2 + 16);
    end;
    PostQueue[PostHead + PostCount] := Event;
    Inc(PostCount);
  finally
    LeaveCriticalSection(PostLock);
  end;
  WakeUp;
end;

class function TEventQueue.WakeUpHandle: THandle;
begin
  {$IFDEF UNIX}
  Result := THandle(WakeReadFd);
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
  CreateWakeUpHandle;
end.
