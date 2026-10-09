{ TvMem: the "memory" backend: the screen is a buffer in memory and the events come
  from a script. Used by the tests (and as a model for the other backends).

  Events are queued with MemKey, MemMouse and MemCommand;
  PollEvent takes them in order. When the queue is empty the clock advances by the
  timeout asked for (so timers can be tested) and no event is returned; if that
  happens more than MemMaxIdle times in a row the backend stops the program, so that
  a test with a wrong script cannot hang. }
unit TvMem;

{$I tvdefs.inc}

interface

uses
  TvCell, TvCodePg, TvColors, TvEvents, TvScreen, TvSys;

const
  MemMaxIdle = 500;

var
  MemClock: Int64 = 0;

{ Creates a screen of W x H cells and sets the hooks of TvSys. }
procedure MemInit(W, H: Integer);
procedure MemDone;

procedure MemKey(KeyCode: Word; ControlKeyState: Word = 0);
procedure MemMouse(What: Word; X, Y: Integer; Buttons: Byte = 1; Flags: Word = 0);
procedure MemEvent(const Event: TEvent);
procedure MemClear;
{ Events not yet taken. }
function MemPending: Integer;

{ The text of a screen row between two columns, as UTF-8 ('_' for an empty cell); code
  page characters are converted like the screen does. }
function MemText(Y, X0, X1: Integer): ShortString;
function MemAttr(X, Y: Integer): Byte;
function MemChar(X, Y: Integer): ShortString;
{ The cell is part of a shadow (it keeps the colors of what is below, darkened). }
function MemIsShadow(X, Y: Integer): Boolean;

implementation

const
  MaxQueue = 256;

var
  Queue: array[0..MaxQueue - 1] of TEvent;
  QHead, QTail, QCount: Integer;
  IdleCount: Integer;

procedure MemPoll(TimeoutMs: Integer; var Event: TEvent);
begin
  if QCount > 0 then
  begin
    Event := Queue[QHead];
    QHead := (QHead + 1) mod MaxQueue;
    Dec(QCount);
    IdleCount := 0;
  end
  else
  begin
    Event.What := evNothing;
    if TimeoutMs > 0 then
      Inc(MemClock, TimeoutMs)
    else
      Inc(MemClock);
    Inc(IdleCount);
    if IdleCount > MemMaxIdle then
    begin
      WriteLn('FAIL the program waits for an event that the script does not have');
      Halt(2);
    end;
  end;
end;

function MemClockFn: Int64;
begin
  Result := MemClock;
end;

procedure MemInit(W, H: Integer);
begin
  ScreenCreate(W, H);
  MemClear;
  MemClock := 0;
  OnPollEvent := @MemPoll;
  GetClockMs := @MemClockFn;
  OnSetVideoMode := nil;
end;

procedure MemDone;
begin
  OnPollEvent := nil;
  GetClockMs := nil;
  ScreenDestroy;
end;

procedure MemEvent(const Event: TEvent);
begin
  if QCount >= MaxQueue then
    Exit;
  Queue[QTail] := Event;
  QTail := (QTail + 1) mod MaxQueue;
  Inc(QCount);
end;

procedure MemKey(KeyCode: Word; ControlKeyState: Word);
var
  E: TEvent;
begin
  MakeKeyEvent(E, KeyCode, ControlKeyState);
  MemEvent(E);
end;

procedure MemMouse(What: Word; X, Y: Integer; Buttons: Byte; Flags: Word);
var
  E: TEvent;
begin
  ClearEvent(E);
  E.What := What;
  E.Mouse.Where.X := X;
  E.Mouse.Where.Y := Y;
  E.Mouse.Buttons := Buttons;
  E.Mouse.EventFlags := Flags;
  MemEvent(E);
end;

procedure MemClear;
begin
  QHead := 0;
  QTail := 0;
  QCount := 0;
  IdleCount := 0;
end;

function MemPending: Integer;
begin
  Result := QCount;
end;

function MemChar(X, Y: Integer): ShortString;
var
  Ch: TScreenCharacter;
  Buf: array[0..7] of Byte;
  B: Byte;
begin
  Ch := (TScreen.ScreenBuffer + (Y * TScreen.ScreenWidth + X))^.Character;
  { the second half of a wide character: its text is in the cell before }
  if ScIsWideTrail(Ch) then
    Exit('');
  Result := ScText(Ch);
  if (Result = '') or (Result = #0) then
    Exit('_');
  if Length(Result) <> 1 then
    Exit;
  B := Byte(Result[1]);
  if (B < $20) or (B >= $80) then
  begin
    { a single byte of the code page, shown as its character }
    SetLength(Result, CpToUtf8(B, @Buf[0]));
    Move(Buf[0], Result[1], Length(Result));
  end;
end;

function MemText(Y, X0, X1: Integer): ShortString;
var
  X: Integer;
begin
  Result := '';
  for X := X0 to X1 do
    Result := Result + MemChar(X, Y);
end;

function MemAttr(X, Y: Integer): Byte;
begin
  Result := AttrAsBIOSByte((TScreen.ScreenBuffer + (Y * TScreen.ScreenWidth + X))^.Attribute);
end;

function MemIsShadow(X, Y: Integer): Boolean;
begin
  Result := (AttrStyle((TScreen.ScreenBuffer + (Y * TScreen.ScreenWidth + X))^.Attribute) and slWindowShadow) <> 0;
end;

end.
