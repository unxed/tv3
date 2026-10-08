{ TvVtView: a view of Turbo Vision with a terminal in it: a program on a pty (TvPty), its screen kept by the emulator (TvVt), the keys and the mouse turned into what
  the program expects (TvVtKeys) (PLAN.md item 8.3). Shift-PgUp, Shift-PgDn and the mouse wheel scroll the history when the program does not ask for the mouse.

  The view reads the program on a timer (cmTimerExpired of the
  program, every 20 ms); when the program ends it sends cmVtEnded to the application. Linux only for now (TvPty).

  A program that switches the far2l terminal extensions on (TvVtExt) gets the keys, their releases and the mouse as their events, the clipboard of the
  application after the user allowed it in the dialog "Clipboard access" (Ctrl+V, Shift+Ins and the middle button are the paste gestures that let it read),
  its notifications, window requests and F-key titles (shown only while the view is focused) go to TvSys, its cursor height is the cursor of the view. }
unit TvVtView;

{$I tvdefs.inc}

interface

{$IFDEF LINUX}
uses
  TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvViews, TvApp, TvTimer, TvClip, TvSys, TvVt, TvVtKeys, TvVtExt, TvPty, TvDialog;

const
  cmVtEnded = 5100;            { broadcast to the application: the program of the view (InfoPtr = the view) has ended }

type
  { True: the key is not for the terminal (the owner handles it: the hotkeys of the application) }
  TVtKeyFilter = function(const Event: TEvent): Boolean;

  TVtView = class;

  { what the far2l extensions of the program need from the view }
  TVtViewHost = class(TVtExtHost)
  public
    View: TVtView;
    function AskClipboard(const ClientId: AnsiString): TVtClipAnswer; override;
    function FKeyTitles(const Titles: array of AnsiString): Boolean; override;
    procedure CursorHeight(Percent: Integer); override;
  end;

  TVtView = class(TView)
    Emu: TVtEmu;
    Pty: TPty;
    Back: Integer;             { how many lines the view is scrolled back into the history (0: the live screen) }
    Ended: Boolean;
    KeyFilter: TVtKeyFilter;
    constructor Create(const Bounds: TRect; const Prog: AnsiString; const Args: array of AnsiString; const Cwd: AnsiString);
    destructor Destroy; override;
    procedure Draw; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure ChangeBounds(const Bounds: TRect); override;
    procedure SetState(AState: Word; Enable: Boolean); override;
    { reads what the program wrote; True when the screen changed }
    function Pump: Boolean;
    { sends bytes to the program }
    procedure SendBytes(const S: AnsiString);
    function Title: AnsiString;
  private
    Timer: TTimerId;
    PasteOpen: Boolean;
    Pumping: Boolean;
    Cells: array of TScreenCell;
    ExtHost: TVtViewHost;
    FKeys: array of AnsiString;       { the F-key titles of the program, shown while the view is focused }
    FKeysShown: Boolean;
    procedure ShowFKeys(Visible: Boolean);
    procedure PlaceCursor;
    procedure ClosePaste;
    procedure ScrollBack(Delta: Integer);
    procedure Mouse(var Event: TEvent);
    procedure CheckEnd;
  end;
{$ENDIF}

implementation

{$IFDEF LINUX}
uses
  SysUtils, BaseUnix, TvMsgBox, TvText;

{ the question of a client of the clipboard: four answers; Esc is the first (the client may ask again) }
function TVtViewHost.AskClipboard(const ClientId: AnsiString): TVtClipAnswer;
var
  D: TDialog;
  R: TRect;
  Cmd: Word;

  procedure Button(X, Y: Integer; const Title: ShortString; Command: Word);
  begin
    R.Assign(X, Y, X + 24, Y + 2);
    D.Insert(TButton.Create(R, Title, Command, bfNormal));
  end;

begin
  Result := vcaBlock;
  if (Application = nil) or (DeskTop = nil) then
    Exit;
  R.Assign(0, 0, 58, 11);
  R.Move((DeskTop.Size.X - 58) div 2, (DeskTop.Size.Y - 11) div 2);
  D := TDialog.Create(R, 'Clipboard access');
  R.Assign(3, 2, 55, 4);
  D.Insert(TStaticText.Create(R, 'Please choose how this terminal application may use clipboard'));
  Button(4, 5, '~B~lock attempt', cmCancel);
  Button(30, 5, '~R~emote clipboard', cmNo);
  Button(4, 7, '~S~hare clipboard', cmYes);
  Button(30, 7, 'Share clipboard ~a~lways', cmOK);
  D.SelectNext(False);
  Cmd := Application.ExecView(D);
  D.Free;
  case Cmd of
    cmNo: Result := vcaRemote;
    cmYes: Result := vcaShare;
    cmOK: Result := vcaAlways;
  end;
end;

function TVtViewHost.FKeyTitles(const Titles: array of AnsiString): Boolean;
var
  I: Integer;
  Any: Boolean;
begin
  Any := False;
  for I := 0 to High(Titles) do
    if Titles[I] <> '' then
      Any := True;
  if Any then
  begin
    SetLength(View.FKeys, Length(Titles));
    for I := 0 to High(Titles) do
      View.FKeys[I] := Titles[I];
  end
  else
    View.FKeys := nil;
  View.ShowFKeys(View.GetState(sfFocused));
  Result := Assigned(OnSetFKeyTitles);
end;

procedure TVtViewHost.CursorHeight(Percent: Integer);
begin
  View.PlaceCursor;
end;

procedure VtClipboard(Data: Pointer; const Text: AnsiString);
begin
  ClipboardSetText(Text);
end;

function VtClipboardGet(Data: Pointer; out Text: AnsiString): Boolean;
begin
  Text := ClipboardGetText;
  Result := True;
end;

constructor TVtView.Create(const Bounds: TRect; const Prog: AnsiString; const Args: array of AnsiString; const Cwd: AnsiString);
begin
  inherited Create(Bounds);
  Pty := TPty.Create;
  GrowMode := gfGrowHiX or gfGrowHiY;
  Options := Options or ofSelectable or ofFirstClick;
  EventMask := EventMask or evMouseWheel or evBroadcast or evKeyUp;
  Emu := TVtEmu.Create(Size.X, Size.Y, 2000);
  Emu.OnClip := @VtClipboard;
  Emu.OnClipGet := @VtClipboardGet;
  Emu.Data := Self;
  ExtHost := TVtViewHost.Create;
  ExtHost.View := Self;
  Emu.Ext.Host := ExtHost;
  Back := 0;
  Ended := False;
  KeyFilter := nil;
  PasteOpen := False;
  Timer := nil;
  if not Pty.Open(Size.X, Size.Y, Prog, Args, Cwd) then
    Ended := True
  else if Application <> nil then
    Timer := Application.SetTimer(20, 20);
end;

destructor TVtView.Destroy;
begin
  if (Timer <> nil) and (Application <> nil) then
    Application.KillTimer(Timer);
  KeyUpEvents := False;
  Emu.Ext.Stop;
  ShowFKeys(False);
  Emu.Ext.Host := nil;
  ExtHost.Free;
  Pty.Free;
  Emu.Free;
  Cells := nil;
  inherited Destroy;
end;

function TVtView.Title: AnsiString;
begin
  Result := Emu.Title;
end;

{ Row by row: a line of the history while the view is scrolled back above the live screen, then the rows of the emulator. }
procedure TVtView.Draw;
var
  Row, Col, Line, Hist: Integer;
begin
  if Length(Cells) < Size.X then
    SetLength(Cells, Size.X);
  Hist := Emu.HistoryCount;
  Line := -Back;                      { below 0: a line of the history, counted back from its end }
  for Row := 0 to Size.Y - 1 do
  begin
    if Line < 0 then
      for Col := 0 to Size.X - 1 do
        Cells[Col] := Emu.HistoryCell(Hist + Line, Col)
    else
      for Col := 0 to Size.X - 1 do
        Cells[Col] := Emu.CellAt(Col, Line);
    if Size.X > 0 then
      WriteLine(0, Row, Size.X, 1, @Cells[0]);
    Inc(Line);
  end;
  Emu.ClearDirty;
  PlaceCursor;
end;

{ the cursor of the program, on the live screen of the focused view; its height as the program asked (far2l extensions) }
procedure TVtView.PlaceCursor;
begin
  if (Back <> 0) or Ended or not Emu.CursorVisible or not GetState(sfFocused) then
  begin
    HideCursor;
    Exit;
  end;
  SetCursor(Emu.CursorX, Emu.CursorY);
  if Emu.Ext.CursorPercent >= 50 then
    BlockCursor
  else
    NormalCursor;
  ShowCursor;
end;

procedure TVtView.ShowFKeys(Visible: Boolean);
begin
  if Visible and (FKeys <> nil) then
  begin
    TvSys.SetFKeyTitles(FKeys);
    FKeysShown := True;
  end
  else if FKeysShown then
  begin
    TvSys.SetFKeyTitles([]);
    FKeysShown := False;
  end;
end;

procedure TVtView.SendBytes(const S: AnsiString);
begin
  if (Length(S) > 0) and not Ended then
    Pty.Write(S[1], Length(S));
end;

procedure TVtView.CheckEnd;
begin
  if not Ended and Pty.Wait(False) then
  begin
    Ended := True;
    Emu.Ext.Stop;
    if Application <> nil then
      Message(Application, evBroadcast, cmVtEnded, Self);
  end;
end;

function TVtView.Pump: Boolean;
var
  Buf: array[0..8191] of Byte;
  N, Total: Integer;
  Reply: AnsiString;
  Dirty: Boolean;
  Y: Integer;
begin
  Result := False;
  if Pumping or (Ended and not Pty.Running) then
    Exit;                              { the dialog of the clipboard runs inside a Feed: the timer must not feed again }
  Pumping := True;
  Total := 0;
  while Total < 65536 do
  begin
    N := Pty.Read(Buf, SizeOf(Buf));
    if N < 0 then
    begin
      CheckEnd;
      if not Ended then
        Ended := True;
      Break;
    end;
    if N = 0 then
      Break;
    Inc(Total, N);
    Emu.Feed(@Buf[0], N);
  end;
  Reply := Emu.TakeReply;
  if Reply <> '' then
    SendBytes(Reply);
  { a program in the win32 input mode, with the flag 2 of Kitty or with the far2l extensions wants the releases of the keys too }
  KeyUpEvents := Emu.Win32Input or ((Emu.KittyFlags and 2) <> 0) or Emu.Ext.Active;
  if not Ended then
    CheckEnd;
  Pumping := False;
  Dirty := False;
  for Y := 0 to Emu.RowCount - 1 do
    if Emu.RowDirty(Y) then
      Dirty := True;
  Result := Dirty;
end;

procedure TVtView.ScrollBack(Delta: Integer);
var
  Old: Integer;
begin
  Old := Back;
  Inc(Back, Delta);
  if Back > Emu.HistoryCount then
    Back := Emu.HistoryCount;
  if Back < 0 then
    Back := 0;
  if Back <> Old then
    DrawView;
end;

procedure TVtView.ClosePaste;
begin
  if PasteOpen then
  begin
    PasteOpen := False;
    SendBytes(#27'[201~');
  end;
end;

procedure TVtView.Mouse(var Event: TEvent);
var
  P: TPoint;
  B: Integer;
  S: AnsiString;
begin
  P := MakeLocal(Event.Where);
  if Emu.Ext.Active then
  begin
    if Event.What = evMouseAuto then
    begin
      ClearEvent(Event);
      Exit;
    end;
    if (Event.Buttons and mbMiddleButton) <> 0 then
      Emu.Ext.PasteGesture;
    if (Event.What = evMouseDown) and not GetState(sfFocused) then
      Select;
    if Event.What = evMouseUp then
      SendBytes(Emu.Ext.MouseEvent(P.X, P.Y, 0, 0, False, False, Event.ControlKeyState))
    else if Event.What = evMouseWheel then
      SendBytes(Emu.Ext.MouseEvent(P.X, P.Y, Event.Buttons, Event.Wheel, False, False, Event.ControlKeyState))
    else
      SendBytes(Emu.Ext.MouseEvent(P.X, P.Y, Event.Buttons, 0, Event.What = evMouseMove, (Event.EventFlags and meDoubleClick) <> 0,
        Event.ControlKeyState));
    ClearEvent(Event);
    Exit;
  end;
  if Emu.MouseMode = 0 then
  begin
    if (Event.What = evMouseWheel) then
    begin
      if (Event.Wheel and mwUp) <> 0 then
        ScrollBack(3)
      else if (Event.Wheel and mwDown) <> 0 then
        ScrollBack(-3);
      ClearEvent(Event);
    end
    else if Event.What = evMouseDown then
    begin
      Select;
      ClearEvent(Event);
    end;
    Exit;
  end;
  B := -1;
  if (Event.Buttons and mbLeftButton) <> 0 then B := 0
  else if (Event.Buttons and mbMiddleButton) <> 0 then B := 1
  else if (Event.Buttons and mbRightButton) <> 0 then B := 2;
  S := '';
  case Event.What of
    evMouseDown, evMouseAuto: S := VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, B, True, False, 0, Event.ControlKeyState);
    evMouseUp: S := VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, 0, False, False, 0, Event.ControlKeyState);
    evMouseMove: S := VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, B, False, True, 0, Event.ControlKeyState);
    evMouseWheel:
      if (Event.Wheel and mwUp) <> 0 then
        S := VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, 0, True, False, 1, Event.ControlKeyState)
      else if (Event.Wheel and mwDown) <> 0 then
        S := VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, 0, True, False, 2, Event.ControlKeyState);
  end;
  if (Event.What = evMouseDown) and not GetState(sfFocused) then
    Select;
  SendBytes(S);
  ClearEvent(Event);
end;

{ the paste gestures of the far2l extensions: Ctrl+V (with or without Shift, without Alt), Shift+Ins (without Ctrl and Alt) }
function IsPasteKey(const Event: TEvent): Boolean;
var
  M: Word;
begin
  M := Event.ControlKeyState;
  if (M and kbAltShift) <> 0 then
    Exit(False);
  if (M and kbCtrlShift) <> 0 then
    Result := (EventVirtualKey(Event) = Ord('V'))
  else
    Result := (Event.KeyCode = kbShiftIns) or ((Event.KeyCode = kbIns) and ((M and kbShift) <> 0));
end;

procedure TVtView.HandleEvent(var Event: TEvent);
var
  S: AnsiString;
begin
  inherited HandleEvent(Event);
  case Event.What of
    evKeyDown:
      begin
        if not GetState(sfFocused) then
          Exit;
        if Assigned(KeyFilter) and KeyFilter(Event) then
          Exit;
        if (Event.KeyCode = kbPgUp) and ((Event.ControlKeyState and kbShift) <> 0) then
        begin
          ScrollBack(Size.Y - 1);
          ClearEvent(Event);
          Exit;
        end;
        if (Event.KeyCode = kbPgDn) and ((Event.ControlKeyState and kbShift) <> 0) then
        begin
          ScrollBack(-(Size.Y - 1));
          ClearEvent(Event);
          Exit;
        end;
        if Emu.Ext.Active then
        begin
          if IsPasteKey(Event) then
            Emu.Ext.PasteGesture;
          SendBytes(Emu.Ext.KeyEvent(Event));
          if Back > 0 then
          begin
            Back := 0;
            DrawView;
          end;
          ClearEvent(Event);
          Exit;
        end;
        if (Event.ControlKeyState and kbPaste) <> 0 then
        begin
          if Emu.BracketedPaste and not PasteOpen then
          begin
            PasteOpen := True;
            SendBytes(#27'[200~');
          end;
        end
        else
          ClosePaste;
        S := VtKeyBytes(Event, Emu.AppCursor, Emu.Win32Input, Emu.KittyFlags);
        if S <> '' then
        begin
          SendBytes(S);
          if Back > 0 then
          begin
            Back := 0;
            DrawView;
          end;
        end;
        ClearEvent(Event);
      end;
    evKeyUp:
      begin
        if Emu.Ext.Active then
          SendBytes(Emu.Ext.KeyEvent(Event))
        else if Emu.Win32Input or ((Emu.KittyFlags and 2) <> 0) then
          SendBytes(VtKeyBytes(Event, Emu.AppCursor, Emu.Win32Input, Emu.KittyFlags));
        ClearEvent(Event);
      end;
    evMouseDown, evMouseUp, evMouseMove, evMouseAuto, evMouseWheel:
      Mouse(Event);
    evBroadcast:
      if (Event.Command = cmTimerExpired) and (Event.InfoPtr = Timer) then
      begin
        if Pump then
          DrawView;
        if PasteOpen then
          ClosePaste;
      end;
  end;
end;

procedure TVtView.ChangeBounds(const Bounds: TRect);
begin
  inherited ChangeBounds(Bounds);
  if (Size.X > 0) and (Size.Y > 0) then
  begin
    Emu.Resize(Size.X, Size.Y);
    if not Ended then
      Pty.Resize(Size.X, Size.Y);
  end;
  if Back > Emu.HistoryCount then
    Back := Emu.HistoryCount;
  DrawView;
end;

procedure TVtView.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if (AState and sfFocused) <> 0 then
  begin
    if Emu.FocusEvents and not Ended then
      if Enable then
        SendBytes(#27'[I')
      else
        SendBytes(#27'[O');
    ShowFKeys(Enable);
    DrawView;
  end;
end;
{$ENDIF}

end.
