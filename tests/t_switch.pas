program t_switch;
{$I ../src/tvdefs.inc}
uses SysUtils, TvGeom, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem, TvApp, TvSys,
  TvWindow, TvActions;
{$I testlib.inc}

{ 0.1 - 0.3 of the UX guidelines: the switcher of windows. The list and the commit on the release of Ctrl need key releases (TvSys.KeyUpAvailable); without
  them the switch is at once. }

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

procedure Press(Code, Mods: Word);
var
  E: TEvent;
begin
  MakeKeyEvent(E, Code, Mods);
  Application.HandleEvent(E);
end;

{ the release of Ctrl: what the backend makes of it }
procedure ReleaseCtrl(Held: Word = 0);
var
  E: TEvent;
begin
  ClearEvent(E);
  E.What := evKeyUp;
  E.KeyCode := 0;
  E.ControlKeyState := Held;
  Application.HandleEvent(E);
end;

function Screen: AnsiString;
var
  Y: Integer;
begin
  Result := '';
  for Y := 0 to 24 do
    Result := Result + MemText(Y, 0, 79) + #10;
end;

function Count(const Sub: AnsiString): Integer;
var
  S: AnsiString;
  P: Integer;
begin
  Result := 0;
  S := Screen;
  P := Pos(Sub, S);
  while P > 0 do
  begin
    Inc(Result);
    S := Copy(S, P + Length(Sub), MaxInt);
    P := Pos(Sub, S);
  end;
end;

var
  App: TApplication;
  W1, W2, W3: TWindow;
  I: Integer;
begin
  CpSelect(866);
  MemInit(80, 25);
  App := TApplication.Create;
  W1 := TWindow.Create(R(1, 1, 20, 8), 'alpha', 1);
  W2 := TWindow.Create(R(25, 1, 44, 8), 'bravo', 2);
  W3 := TWindow.Create(R(50, 1, 69, 8), 'charlie', 3);
  App.InsertWindow(W1);
  App.InsertWindow(W2);
  App.InsertWindow(W3);
  Check(DeskTop.Current = W3, 'the last window is the current one');

  { the windows from the top: three, two, one. Ctrl+Tab brings the one at the bottom up (the order of Turbo Vision: SelectNext(False)) }
  KeyUpAvailable := False;
  Press(kbCtrlTab, kbCtrlShift);
  Check(DeskTop.Current = W1, 'no key releases: Ctrl+Tab switches at once');
  Check(not DeskTop.SwitcherActive and not KeyUpForApp, '... and no list');
  Press(kbCtrlTab, kbCtrlShift or kbShift);
  Check(DeskTop.Current = W3, 'no key releases: Ctrl+Shift+Tab goes back at once');

  { with releases: the list, the choice at the release of Ctrl }
  KeyUpAvailable := True;
  Check(Count('charlie') = 1, 'the title is on the screen once (the frame)');
  Press(kbCtrlTab, kbCtrlShift);
  Check(DeskTop.SwitcherActive, 'key releases: Ctrl+Tab opens the list');
  Check(KeyUpForApp, '... and asks the backend for the releases of the modifiers');
  Check(DeskTop.Current = W3, '... the windows do not change yet');
  Check((Count('charlie') = 2) and (Count('alpha') = 2) and (Count('bravo') = 2), 'the list shows the titles of all windows');
  Press(kbCtrlTab, kbCtrlShift);
  Check(DeskTop.SwitcherActive and (DeskTop.Current = W3), 'a second Ctrl+Tab walks the list');
  ReleaseCtrl(kbCtrlShift);
  Check(DeskTop.SwitcherActive, 'the release of Shift (Ctrl still held) does nothing');
  ReleaseCtrl(0);
  Check(not DeskTop.SwitcherActive, 'the release of Ctrl closes the list');
  Check(not KeyUpForApp, '... and stops asking for the releases');
  Check(DeskTop.Current = W2, '... and the window two steps down is chosen');
  Check(Count('charlie') = 1, '... the list is gone from the screen');

  { once: the window at the bottom, as the immediate switch does }
  Press(kbCtrlTab, kbCtrlShift);
  ReleaseCtrl;
  Check(DeskTop.Current = W1, 'one Ctrl+Tab and the release bring the bottom window up');
  Press(kbCtrlTab, kbCtrlShift);
  ReleaseCtrl;
  Check(DeskTop.Current = W3, '... and the next one');

  { backwards: the list starts at the end }
  Press(kbCtrlTab, kbCtrlShift or kbShift);
  Check(DeskTop.SwitcherActive, 'Ctrl+Shift+Tab opens the list too');
  Press(kbCtrlTab, kbCtrlShift or kbShift);
  ReleaseCtrl;
  Check(DeskTop.Current = W2, '... two steps backwards');

  { Esc cancels }
  W3.Select;
  Press(kbCtrlTab, kbCtrlShift);
  Press(kbEsc, 0);
  Check(not DeskTop.SwitcherActive and (DeskTop.Current = W3), 'Esc closes the list and keeps the window');
  Check(not KeyUpForApp, '... and stops asking for the releases');

  { another input closes the list with the choice made; the key is not lost }
  Press(kbCtrlTab, kbCtrlShift);
  Press(Ord('x'), 0);
  Check(not DeskTop.SwitcherActive and (DeskTop.Current <> W3), 'another key closes the list and makes the choice');

  { the guard: the release never came }
  W3.Select;
  Press(kbCtrlTab, kbCtrlShift);
  SwitcherTimeoutMs := -1;
  DeskTop.SwitcherIdle;
  Check(not DeskTop.SwitcherActive and (DeskTop.Current <> W3), 'the list that waited too long closes with the choice made');
  SwitcherTimeoutMs := 8000;

  { the switch off: at once even with releases }
  UxSwitcher := False;
  W3.Select;
  Press(kbCtrlTab, kbCtrlShift);
  Check(not DeskTop.SwitcherActive and (DeskTop.Current <> W3), 'UxSwitcher = False: at once');
  UxSwitcher := True;

  { one window: nothing to choose }
  W1.Free; W2.Free;
  Press(kbCtrlTab, kbCtrlShift);
  Check(not DeskTop.SwitcherActive, 'with one window there is no list');

  { the key of the switcher is an action (TvActions) }
  W1 := TWindow.Create(R(1, 1, 20, 8), 'alpha', 1);
  App.InsertWindow(W1);
  ClearActions;
  RegisterAction('window.switch', '~S~witch', cmNext, kbCtrlTab);
  UseActionsForSwitcher;
  W3.Select;
  Press(kbCtrlTab, kbCtrlShift);
  Check(DeskTop.SwitcherActive, 'the action key opens the list');
  ReleaseCtrl;
  Check(DeskTop.Current = W1, '... and the release chooses');
  Check(BindActionKey('window.switch', kbAltF6), 'the key of the action is rebound');
  W3.Select;
  Press(kbCtrlTab, kbCtrlShift);
  Check(not DeskTop.SwitcherActive and (DeskTop.Current = W3), 'the old key does not start the switcher any more');
  Press(kbAltF6, kbAltShift);
  Check(DeskTop.SwitcherActive, 'the new key does');
  ReleaseCtrl(0);
  Check(not DeskTop.SwitcherActive and (DeskTop.Current = W1), '... and the release of Alt chooses');
  Press(kbAltF6, 0);
  Check(not DeskTop.SwitcherActive and (DeskTop.Current = W3), 'a key with no modifier to hold switches at once');
  OnSwitcherKey := nil;

  App.Free;
  Finish;
end.
