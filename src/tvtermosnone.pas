{ TvTermOsNone: the operating system calls of the terminal backend on a target without a terminal (DOS has its own backend, TvDos): nothing is a terminal.
  The backend of the facade TvTermOs (the code is the same as it was in TvTermOs, only the place is new).

  MIT, see tv/LICENSE. }
unit TvTermOsNone;

{$I tvdefs.inc}

interface

uses
  TvTermOsBase;

function BackendOsIsTerminal: Boolean;
procedure BackendOsRawOn;
procedure BackendOsRawOff;
procedure BackendOsWrite(P: PByte; Len: Integer);
function BackendOsInputReady(TimeoutMs: Integer): Boolean;
function BackendOsRead(var Buf; Size: Integer): Integer;
procedure BackendOsSize(out W, H: Integer);
function BackendOsClipSet(const Text: AnsiString): Boolean;
function BackendOsClipGet(out Text: AnsiString): Boolean;
procedure BackendOsHandlersOn(AfterDeath: TOsHook);
procedure BackendOsHandlersOff;
procedure BackendOsExit(Code: Integer);

implementation

uses
  SysUtils;
function BackendOsIsTerminal: Boolean;
begin
  Result := False;
end;
procedure BackendOsRawOn;
begin
end;
procedure BackendOsRawOff;
begin
end;
procedure BackendOsWrite(P: PByte; Len: Integer);
begin
end;
function BackendOsInputReady(TimeoutMs: Integer): Boolean;
begin
  Result := False;
end;
function BackendOsRead(var Buf; Size: Integer): Integer;
begin
  Result := 0;
end;
procedure BackendOsSize(out W, H: Integer);
begin
  W := 80;
  H := 25;
end;
procedure BackendOsHandlersOn(AfterDeath: TOsHook);
begin
end;
procedure BackendOsHandlersOff;
begin
end;
procedure BackendOsExit(Code: Integer);
begin
  Halt(Code);
end;
function BackendOsClipSet(const Text: AnsiString): Boolean;
begin
  Result := False;
end;
function BackendOsClipGet(out Text: AnsiString): Boolean;
begin
  Text := '';
  Result := False;
end;

end.
