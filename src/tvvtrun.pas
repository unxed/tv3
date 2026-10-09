{ TvVtRun: runs a program on the whole screen of the application with an emulator in between, and keeps what the program drew: the screen of the user (PLAN.md item 8.4).
  While the program runs, the screen of the application is replaced by the screen of the emulator, the keys and the mouse go to the program; when it ends the caller
  redraws its application (the screen is cleared and the size is read again). The emulator stays with the caller: the next program continues on the same screen, and
  VtShowScreen shows it again (the key Ctrl-O of Norton-like programs).

  The parts are TvVt (the screen), TvPty (the program), TvVtKeys (the keys). Linux only.

  A program with the far2l terminal extensions (TvVtExt) gets its keys, their releases and the mouse as their events; there is no dialog to ask the user,
  so its clipboard requests are refused (the program keeps its own clipboard) unless TV_VT_CLIPBOARD=allow. }
unit TvVtRun;

{$I tvdefs.inc}

interface

{$IFDEF LINUX}
uses
  TvVt;

{ Runs Prog (Args[0] is its name for itself) in the directory Cwd ('' = the current one) on the screen of the application; the text Echo (if not empty) is written to
  the emulator before the program starts (the command line, like the prompt of a shell). Pause: 0 goes back at once, 1 shows "Press Enter" after the program ended and waits for Enter, 2 does it only when the status is not 0. Emu is made (the size of the screen) when it is not yet (a zeroed variable: Cols = 0). Result: the exit status of the program, -1 when it could not be started. }
function VtRunScreen(var Emu: TVtEmu; const Prog: AnsiString; const Args: array of AnsiString; const Cwd, Echo: AnsiString; Pause: Integer): Integer;

{ Shows the screen of Emu until a key is pressed. }
procedure VtShowScreen(Emu: TVtEmu);
{$ENDIF}

implementation

{$IFDEF LINUX}
uses
  SysUtils, TvGeom, TvCell, TvEvents, TvKeys, TvSys, TvScreen, TvViews, TvPty, TvVtKeys, TvVtExt, TvClip;

type
  TRunHost = class(TVtExtHost)
  public
    function AskClipboard(const ClientId: AnsiString): TVtClipAnswer; override;
  end;

function TRunHost.AskClipboard(const ClientId: AnsiString): TVtClipAnswer;
begin
  if GetEnvironmentVariable('TV_VT_CLIPBOARD') = 'allow' then
    Result := vcaShare
  else
    Result := vcaRemote;
end;

{ Ctrl+V (not with Alt) or Shift+Ins (not with Ctrl or Alt): the program may read the clipboard for a while }
function PasteKey(const Ev: TEvent): Boolean;
begin
  if (Ev.KeyDown.ControlKeyState and kbAltShift) <> 0 then
    Result := False
  else if (Ev.KeyDown.ControlKeyState and kbCtrlShift) <> 0 then
    Result := EventVirtualKey(Ev) = Ord('V')
  else
    Result := Ev.KeyDown.KeyCode = kbShiftIns;
end;

{ OSC 52 of the program on the whole screen: it sets and reads the clipboard of the application }
procedure RunClip(Data: Pointer; const Text: AnsiString);
begin
  ClipboardSetText(Text);
end;

function RunClipGet(Data: Pointer; out Text: AnsiString): Boolean;
begin
  Text := ClipboardGetText;
  Result := True;
end;

procedure FitEmu(var Emu: TVtEmu);
begin
  if (TScreen.ScreenWidth > 0) and ((Emu.Cols <> TScreen.ScreenWidth) or (Emu.RowCount <> TScreen.ScreenHeight)) then
    Emu.Resize(TScreen.ScreenWidth, TScreen.ScreenHeight);
end;

procedure Blit(var Emu: TVtEmu; All: Boolean);
var
  X, Y, W: Integer;
begin
  W := TScreen.ScreenWidth;
  if (TScreen.ScreenBuffer = nil) or (W <= 0) then
    Exit;
  for Y := 0 to TScreen.ScreenHeight - 1 do
    if All or Emu.RowDirty(Y) then
    begin
      for X := 0 to W - 1 do
        TScreen.ScreenBuffer[Y * W + X] := Emu.CellAt(X, Y);
      ScreenWrite(0, Y, @TScreen.ScreenBuffer[Y * W], W);
    end;
  Emu.ClearDirty;
  if Emu.CursorVisible then
  begin
    SetCaretPosition(Emu.CursorX, Emu.CursorY);
    if Emu.Ext.CursorPercent > 0 then
      SetCaretSize(Emu.Ext.CursorPercent)
    else
      SetCaretSize(15);
  end
  else
    SetCaretSize(0);
end;

procedure ScreenAgain;
begin
  if Assigned(OnSetVideoMode) then
    OnSetVideoMode(TDisplay.smUpdate);
end;

function VtRunScreen(var Emu: TVtEmu; const Prog: AnsiString; const Args: array of AnsiString; const Cwd, Echo: AnsiString; Pause: Integer): Integer;
var
  Pty: TPty;
  Buf: array[0..8191] of Byte;
  Ev: TEvent;
  N, Total: Integer;
  S: AnsiString;
  Over, PasteOpen, All: Boolean;
  P: TPoint;
  B: Integer;
  Host: TRunHost;

  procedure Send(const T: AnsiString);
  begin
    if (T <> '') and not Over then
      Pty.Write(T[1], Length(T));
  end;

begin
  if Emu = nil then
    Emu := TVtEmu.Create(TScreen.ScreenWidth, TScreen.ScreenHeight, 2000);
  Pty := TPty.Create;
  FitEmu(Emu);
  Emu.OnClip := @RunClip;
  Emu.OnClipGet := @RunClipGet;
  Host := TRunHost.Create;
  Emu.Ext.Host := Host;
  if Echo <> '' then
    Emu.Feed(Echo + #13#10);
  if not Pty.Open(Emu.Cols, Emu.RowCount, Prog, Args, Cwd) then
  begin
    Emu.Ext.Host := nil;
    Host.Free;
    Pty.Free;
    Exit(-1);
  end;
  Over := False;
  PasteOpen := False;
  All := True;
  repeat
    { what the program wrote }
    Total := 0;
    repeat
      N := Pty.Read(Buf, SizeOf(Buf));
      if N < 0 then
      begin
        Over := True;
        Break;
      end;
      if N > 0 then
      begin
        Emu.Feed(@Buf[0], N);
        Inc(Total, N);
      end;
    until (N = 0) or (Total >= 65536);
    S := Emu.TakeReply;
    Send(S);
    KeyUpEvents := Emu.Win32Input or ((Emu.KittyFlags and 2) <> 0) or Emu.Ext.Active;
    Blit(Emu, All);
    All := False;
    if Over then
      Break;
    { what the user does }
    PollEvent(20, Ev);
    if Emu.Ext.Active then
      case Ev.What of
        evKeyDown, evKeyUp:
          begin
            if (Ev.What = evKeyDown) and PasteKey(Ev) then
              Emu.Ext.PasteGesture;
            Send(Emu.Ext.KeyEvent(Ev));
            Ev.What := evNothing;
          end;
        evMouseDown, evMouseMove, evMouseWheel:
          begin
            if (Ev.Mouse.Buttons and mbMiddleButton) <> 0 then
              Emu.Ext.PasteGesture;
            Send(Emu.Ext.MouseEvent(Ev.Mouse.Where.X, Ev.Mouse.Where.Y, Ev.Mouse.Buttons, Ev.Mouse.Wheel * Ord(Ev.What = evMouseWheel), Ev.What = evMouseMove,
              (Ev.Mouse.EventFlags and meDoubleClick) <> 0, Ev.KeyDown.ControlKeyState));
            Ev.What := evNothing;
          end;
        evMouseUp:
          begin
            Send(Emu.Ext.MouseEvent(Ev.Mouse.Where.X, Ev.Mouse.Where.Y, 0, 0, False, False, Ev.KeyDown.ControlKeyState));
            Ev.What := evNothing;
          end;
        evMouseAuto:
          Ev.What := evNothing;
      end;
    case Ev.What of
      evKeyDown:
        begin
          if (Ev.KeyDown.ControlKeyState and kbPaste) <> 0 then
          begin
            if Emu.BracketedPaste and not PasteOpen then
            begin
              PasteOpen := True;
              Send(#27'[200~');
            end;
          end
          else if PasteOpen then
          begin
            PasteOpen := False;
            Send(#27'[201~');
          end;
          Send(VtKeyBytes(Ev, Emu.AppCursor, Emu.Win32Input, Emu.KittyFlags));
        end;
      evKeyUp:
        if Emu.Win32Input or ((Emu.KittyFlags and 2) <> 0) then
          Send(VtKeyBytes(Ev, Emu.AppCursor, Emu.Win32Input, Emu.KittyFlags));
      evMouseDown, evMouseUp, evMouseMove, evMouseAuto, evMouseWheel:
        if Emu.MouseMode <> 0 then
        begin
          P := Ev.Mouse.Where;
          B := -1;
          if (Ev.Mouse.Buttons and mbLeftButton) <> 0 then B := 0
          else if (Ev.Mouse.Buttons and mbMiddleButton) <> 0 then B := 1
          else if (Ev.Mouse.Buttons and mbRightButton) <> 0 then B := 2;
          case Ev.What of
            evMouseDown, evMouseAuto: Send(VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, B, True, False, 0, Ev.KeyDown.ControlKeyState));
            evMouseUp: Send(VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, 0, False, False, 0, Ev.KeyDown.ControlKeyState));
            evMouseMove: Send(VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, B, False, True, 0, Ev.KeyDown.ControlKeyState));
            evMouseWheel:
              if (Ev.Mouse.Wheel and mwUp) <> 0 then
                Send(VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, 0, True, False, 1, Ev.KeyDown.ControlKeyState))
              else if (Ev.Mouse.Wheel and mwDown) <> 0 then
                Send(VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, 0, True, False, 2, Ev.KeyDown.ControlKeyState));
          end;
        end;
      evCommand:
        if Ev.Message.Command = cmScreenChanged then
        begin
          ScreenAgain;
          FitEmu(Emu);
          Pty.Resize(Emu.Cols, Emu.RowCount);
          All := True;
        end;
      evNothing:
        if PasteOpen then
        begin
          PasteOpen := False;
          Send(#27'[201~');
        end;
    end;
  until False;
  Pty.Wait(True);
  Result := Pty.ExitStatus;
  KeyUpEvents := False;
  Emu.Ext.Stop;
  Emu.Ext.Host := nil;
  Host.Free;
  Pty.Close;
  if (Pause = 1) or ((Pause = 2) and (Result <> 0)) then
  begin
    Emu.Feed(#13#10#27'[7m [ Process ended (' + Chr(48 + (Result div 100) mod 10) + Chr(48 + (Result div 10) mod 10) + Chr(48 + Result mod 10) +
      '): Press Enter ] '#27'[0m'#13#10);
    Blit(Emu, False);
    repeat
      PollEvent(100, Ev);
      if Ev.What = evCommand then
        if Ev.Message.Command = cmScreenChanged then
        begin
          ScreenAgain;
          FitEmu(Emu);
          Blit(Emu, True);
        end;
    until (Ev.What = evKeyDown) and ((Ev.KeyDown.KeyCode = kbEnter) or (Ev.KeyDown.KeyCode = kbEsc));
  end;
  SetCaretSize(0);
  { the terminal is taken again as after a shell: the state of the input parser is clean, the whole screen is drawn again by the caller }
  if Assigned(OnSuspend) and Assigned(OnResume) then
  begin
    OnSuspend;
    OnResume;
  end
  else
    ScreenAgain;
  Pty.Free;
end;

procedure VtShowScreen(Emu: TVtEmu);
var
  Ev: TEvent;
begin
  if (Emu = nil) or (Emu.Cols = 0) then
    Exit;
  FitEmu(Emu);
  Blit(Emu, True);
  repeat
    PollEvent(100, Ev);
    if (Ev.What = evCommand) and (Ev.Message.Command = cmScreenChanged) then
    begin
      ScreenAgain;
      FitEmu(Emu);
      Blit(Emu, True);
    end;
  until (Ev.What = evKeyDown) or (Ev.What = evMouseDown);
  SetCaretSize(0);
  ScreenAgain;
end;
{$ENDIF}

end.
