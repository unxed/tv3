program tvterm;
{ Demo of the terminal view (TvVtView): a window with a shell in it. tvterm [program [arguments]]; the default is $SHELL, else /bin/sh.
  Alt-X quits (also when the program of the window ends). Linux only. }
{$I ../src/tvdefs.inc}
uses SysUtils, TvGeom, TvEvents, TvKeys, TvViews, TvWindow, TvMenus, TvApp, TvUnix, TvVtView;

type
  TTermApp = class(TApplication)
    procedure InitMenuBar; override;
    procedure InitStatusLine; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure NewTerminal;
  end;

procedure TTermApp.InitMenuBar;
var
  R: TRect;
begin
  R := GetExtent;
  R.B.Y := R.A.Y + 1;
  MenuBar := TMenuBar.Create(R, TMenu.Create(TMenuItem.Create('~F~ile', kbNoKey, TMenu.Create(TMenuItem.Create('E~x~it', cmQuit, kbAltX, hcNoContext, 'Alt-X', nil)), hcNoContext, nil)));
end;

procedure TTermApp.InitStatusLine;
var
  R: TRect;
begin
  R := GetExtent;
  R.A.Y := R.B.Y - 1;
  StatusLine := TStatusLine.Create(R, TStatusDef.Create(0, $FFFF, TStatusItem.Create('~Alt-X~ Exit', kbAltX, cmQuit, TStatusItem.Create('~Shift-PgUp~ History', kbNoKey, 0, nil)), nil));
end;

{ the keys that are not for the terminal }
function OwnKey(const Event: TEvent): Boolean;
begin
  Result := (Event.KeyDown.KeyCode = kbAltX) or (Event.KeyDown.KeyCode = kbAltF3);
end;

procedure TTermApp.NewTerminal;
var
  W: TWindow;
  V: TVtView;
  R: TRect;
  Prog: AnsiString;
  Args: array of AnsiString;
  I: Integer;
begin
  R := DeskTop.GetExtent;
  W := TWindow.Create(R, 'Terminal', 1);
  R := W.GetExtent;
  R.Grow(-1, -1);
  if ParamCount >= 1 then
  begin
    Prog := ParamStr(1);
    SetLength(Args, ParamCount);
    for I := 1 to ParamCount do
      Args[I - 1] := ParamStr(I);
  end
  else
  begin
    Prog := GetEnvironmentVariable('SHELL');
    if Prog = '' then
      Prog := '/bin/sh';
    SetLength(Args, 1);
    Args[0] := Prog;
  end;
  V := TVtView.Create(R, Prog, Args, '');
  V.KeyFilter := @OwnKey;
  W.Insert(V);
  InsertWindow(W);
  V.Select;
end;

procedure TTermApp.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Message.Command = cmVtEnded) then
  begin
    Message(Self, evCommand, cmQuit, nil);
    ClearEvent(Event);
  end;
end;

var
  App: TTermApp;
begin
  if not UnixInit then
  begin
    Writeln('tvterm needs a terminal');
    Halt(1);
  end;
  App := TTermApp.Create;
  App.NewTerminal;
  App.Run;
  App.Free;
  UnixDone;
end.
