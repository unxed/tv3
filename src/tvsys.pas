{ TvSys: what the program needs from the system, as hooks set by a backend.

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

procedure PollEvent(TimeoutMs: Integer; var Event: TEvent);
{ The next key event of the system, without waiting (the loops that a person can stop with Esc: a compilation, a search, a copy). The events
  that come before it and are not keys (the mouse) are dropped; Event.What = evNothing when no key is waiting. }
procedure PollKeyEvent(var Event: TEvent);
function ClockMs: Int64;
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

procedure PollEvent(TimeoutMs: Integer; var Event: TEvent);
begin
  ClearEvent(Event);
  if Assigned(OnPollEvent) then
    OnPollEvent(TimeoutMs, Event);
end;

procedure PollKeyEvent(var Event: TEvent);
var
  N: Integer;
begin
  ClearEvent(Event);
  for N := 1 to 256 do
  begin
    PollEvent(0, Event);
    if (Event.What = evNothing) or ((Event.What and evKeyDown) <> 0) then
      Exit;
    ClearEvent(Event);
  end;
end;

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

function ClockMs: Int64;
begin
  if Assigned(GetClockMs) then
    Result := GetClockMs()
  else
    Result := GetTickCount64;
end;

end.
