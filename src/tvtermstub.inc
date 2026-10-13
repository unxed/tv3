{ Stub TvTermOs for non-Unix, non-Windows targets. }
function OsIsTerminal: Boolean;
begin
  Result := False;
end;
procedure OsRawOn;
begin
end;
procedure OsRawOff;
begin
end;
procedure OsWrite(P: PByte; Len: Integer);
begin
end;
function OsInputReady(TimeoutMs: Integer): Boolean;
begin
  Result := False;
end;
function OsRead(var Buf; Size: Integer): Integer;
begin
  Result := 0;
end;
procedure OsSize(out W, H: Integer);
begin
  W := 80;
  H := 25;
end;
procedure OsHandlersOn(AfterDeath: TOsHook);
begin
end;
procedure OsHandlersOff;
begin
end;
procedure OsExit(Code: Integer);
begin
  Halt(Code);
end;
function OsClipSet(const Text: AnsiString): Boolean;
begin
  Result := False;
end;
function OsClipGet(out Text: AnsiString): Boolean;
begin
  Text := '';
  Result := False;
end;
