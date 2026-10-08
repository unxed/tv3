{ TvTermOs: what the terminal backend (TvUnix) needs from the operating system: the raw mode, the output, the wait for input, the size of
  the terminal, the end of the program. Unix: termios, poll, ioctl, signals. Windows (10 and newer; Wine): the console in the mode of
  virtual terminal sequences, in and out (so that the same sequences as on Unix are used: TvAnsi, TvTermIO); the input is read as
  console records (key events carry the characters of the sequences), a change of the size of the window is a record too.

  The code of a target is in TvTermOsUnix, TvTermOsWin or TvTermOsNone.

  MIT, see tv/LICENSE. }
unit TvTermOs;

{$I tvdefs.inc}

interface

uses
  TvTermOsBase;

type
  TOsHook = TvTermOsBase.TOsHook;

{ Both the input and the output are a terminal (a console). }
function OsIsTerminal: Boolean;
{ The raw mode (no echo, no line editing, no processing of the keys; the sequences of the terminal are on); the old state is kept. }
procedure OsRawOn;
{ The state that OsRawOn kept. }
procedure OsRawOff;
procedure OsWrite(P: PByte; Len: Integer);
{ True if a byte can be read within TimeoutMs. }
function OsInputReady(TimeoutMs: Integer): Boolean;
{ Reads up to Size bytes that are ready; <= 0 if there is nothing. }
function OsRead(var Buf; Size: Integer): Integer;
procedure OsSize(out W, H: Integer);
{ The system clipboard of the OS, text in UTF-8; False when the OS layer has none (Unix: the terminal has it, TvUnix uses OSC 52). Windows: CF_UNICODETEXT. }
function OsClipSet(const Text: AnsiString): Boolean;
function OsClipGet(out Text: AnsiString): Boolean;
{ Sets OsResizeFlag when the size of the terminal changes; ends the program with the terminal in order when it is killed. }
procedure OsHandlersOn(AfterDeath: TOsHook);
procedure OsHandlersOff;
{ Ends the program at once with the code (in a handler). }
procedure OsExit(Code: Integer);

var
  OsResizeFlag: LongInt absolute TvTermOsBase.OsResizeFlag;
  OsToldCols: LongInt absolute TvTermOsBase.OsToldCols;
  OsToldRows: LongInt absolute TvTermOsBase.OsToldRows;

implementation

uses
{$IFDEF UNIX}
  TvTermOsUnix
{$ELSE}
{$IFDEF WINDOWS}
  TvTermOsWin
{$ELSE}
  TvTermOsNone
{$ENDIF}
{$ENDIF}
  ;

function OsIsTerminal: Boolean;
begin
  Result := BackendOsIsTerminal;
end;

procedure OsRawOn;
begin
  BackendOsRawOn;
end;

procedure OsRawOff;
begin
  BackendOsRawOff;
end;

procedure OsWrite(P: PByte; Len: Integer);
begin
  BackendOsWrite(P, Len);
end;

function OsInputReady(TimeoutMs: Integer): Boolean;
begin
  Result := BackendOsInputReady(TimeoutMs);
end;

function OsRead(var Buf; Size: Integer): Integer;
begin
  Result := BackendOsRead(Buf, Size);
end;

procedure OsSize(out W, H: Integer);
begin
  BackendOsSize(W, H);
end;

function OsClipSet(const Text: AnsiString): Boolean;
begin
  Result := BackendOsClipSet(Text);
end;

function OsClipGet(out Text: AnsiString): Boolean;
begin
  Result := BackendOsClipGet(Text);
end;

procedure OsHandlersOn(AfterDeath: TOsHook);
begin
  BackendOsHandlersOn(AfterDeath);
end;

procedure OsHandlersOff;
begin
  BackendOsHandlersOff;
end;

procedure OsExit(Code: Integer);
begin
  BackendOsExit(Code);
end;

end.
