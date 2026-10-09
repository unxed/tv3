{ TvSys: what the program needs from the system, as hooks set by a backend, and the event queue of tvision
  (TEventQueue) that reads them.

  See tv/DESIGN.md. A backend (memory for tests, DOS, terminal) sets the hooks
  before the application is created. Without a backend there are no events and the
  clock is the system tick counter. }
unit TvSys;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvEvents;

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
    { Waits at most TimeoutMs milliseconds (-1: for ever) for an event; at once when one is waiting. }
    class procedure WaitForEvents(TimeoutMs: Integer); static;
    { Text that comes as key events with kbPaste, one character each, before the events of the backend; CR and CR LF come as LF. }
    class procedure SetPasteText(const Text: AnsiString); static;
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
  TvKeys, TvUtf8;

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
  Result := Assigned(OnWindowMaxSize) and OnWindowMaxSize(Cols, Rows);
end;

procedure WindowMaximize(Maximize: Boolean);
begin
  if Assigned(OnWindowMaximize) then
    OnWindowMaximize(Maximize);
end;

procedure QuickEdit;
begin
  if Assigned(OnQuickEdit) then
    OnQuickEdit();
end;

function ColorBits: Integer;
begin
  if Assigned(OnColorBits) then
    Result := OnColorBits()
  else
    Result := 0;
end;

const
  EventQSize = 64;

var
  EventQ: array[0..EventQSize - 1] of TEvent;
  EventCount: Integer = 0;
  PasteText: AnsiString = '';
  PasteIndex: Integer = 1;
  { the last wait found nothing: GetMouseEvent and GetKeyEvent do not ask the backend again right after it (GetKeyEvent ends this) }
  WaitFoundNothing: Boolean = False;

function IsMouse(const Event: TEvent): Boolean;
begin
  Result := (Event.What and evMouse) <> 0;
end;

procedure TakeAt(I: Integer; var Event: TEvent);
begin
  Event := EventQ[I];
  if I < EventCount - 1 then
    Move(EventQ[I + 1], EventQ[I], (EventCount - 1 - I) * SizeOf(TEvent));
  Dec(EventCount);
end;

{ The next event of the backend into the queue; False when none came. When the queue is full the oldest mouse event goes (a loop that reads only the keys). }
function Fetch(TimeoutMs: Integer): Boolean;
var
  E, Dropped: TEvent;
  I: Integer;
begin
  ClearEvent(E);
  if Assigned(OnPollEvent) then
    OnPollEvent(TimeoutMs, E);
  Result := E.What <> evNothing;
  if not Result then
    Exit;
  if EventCount = EventQSize then
  begin
    I := 0;
    while (I < EventCount) and not IsMouse(EventQ[I]) do
      Inc(I);
    if I = EventCount then
      I := 0;
    TakeAt(I, Dropped);
  end;
  EventQ[EventCount] := E;
  Inc(EventCount);
end;

function FindEvent(Mouse: Boolean): Integer;
begin
  Result := 0;
  while (Result < EventCount) and (IsMouse(EventQ[Result]) <> Mouse) do
    Inc(Result);
  if Result = EventCount then
    Result := -1;
end;

function GetPasteEvent(var Event: TEvent): Boolean;
var
  N, I: Integer;
begin
  Result := PasteIndex <= Length(PasteText);
  if not Result then
    Exit;
  N := 1 + Utf8BytesLeft(Byte(PasteText[PasteIndex]));
  if PasteIndex + N - 1 > Length(PasteText) then
    N := Length(PasteText) - PasteIndex + 1;
  ClearEvent(Event);
  Event.What := evKeyDown;
  Event.KeyDown.ControlKeyState := kbPaste;
  for I := 0 to N - 1 do
    Event.KeyDown.Text[I] := PasteText[PasteIndex + I];
  Event.KeyDown.TextLength := N;
  Inc(PasteIndex, N);
  if PasteIndex > Length(PasteText) then
  begin
    PasteText := '';
    PasteIndex := 1;
  end;
end;

class procedure TEventQueue.GetMouseEvent(var Event: TEvent);
var
  I: Integer;
begin
  if (EventCount = 0) and not WaitFoundNothing then
    Fetch(0);
  I := FindEvent(True);
  if I >= 0 then
    TakeAt(I, Event)
  else
    ClearEvent(Event);
end;

class procedure TEventQueue.GetKeyEvent(var Event: TEvent);
var
  I, N: Integer;
begin
  if GetPasteEvent(Event) then
    Exit;
  I := FindEvent(False);
  N := 0;
  if WaitFoundNothing then
  begin
    WaitFoundNothing := False;
    N := 256;
  end;
  while (I < 0) and (N < 256) and Fetch(0) do
  begin
    if not IsMouse(EventQ[EventCount - 1]) then
      I := EventCount - 1;
    Inc(N);
  end;
  if I >= 0 then
    TakeAt(I, Event)
  else
    ClearEvent(Event);
end;

class procedure TEventQueue.WaitForEvents(TimeoutMs: Integer);
begin
  if (EventCount = 0) and (PasteIndex > Length(PasteText)) then
    WaitFoundNothing := not Fetch(TimeoutMs);
end;

class procedure TEventQueue.SetPasteText(const Text: AnsiString);
var
  I: Integer;
begin
  PasteText := '';
  I := 1;
  while I <= Length(Text) do
  begin
    if Text[I] = #13 then
    begin
      PasteText := PasteText + #10;
      if (I < Length(Text)) and (Text[I + 1] = #10) then
        Inc(I);
    end
    else
      PasteText := PasteText + Text[I];
    Inc(I);
  end;
  PasteIndex := 1;
end;

initialization
  TEventQueue.DoubleDelay := 8;
  TEventQueue.MouseReverse := False;
end.
