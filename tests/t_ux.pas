program t_ux;
{$I ../src/tvdefs.inc}
uses TvGeom, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem, TvApp,
  TvDialog, TvCluster, TvInput, TvWindow, TvHist, TvList;
{$I testlib.inc}

function R(A, B, C, D: Integer): TRect;
begin
  Result := TRect.Create(A, B, C, D);
end;

procedure Key(V: TView; Code: Word; Mods: Word = 0);
var
  E: TEvent;
begin
  MakeKeyEvent(E, Code, Mods);
  V.HandleEvent(E);
end;

function Items(N: Integer): TCollection;
var
  C: TStringCollection;
  I: Integer;
  S: ShortString;
begin
  C := TStringCollection.Create(N, 5);
  for I := 0 to N - 1 do
  begin
    Str(I, S);
    C.AtInsert(C.Count, NewStr('Item ' + S));
  end;
  Result := C;
end;

var
  Lb: TListBox;
  Pre, Post: TInputLine;
  App: TApplication;
  Dlg, Dlg2: TDialog;
  Inp: TInputLine;
  Chk, Two: TCheckBoxes;
  Inp2: TInputLine;
  Rad: TRadioButtons;
  Bt1, Bt2: TButton;
  Hs: TInputLine;
  W1, W2: TWindow;
  Ev: TEvent;

begin
  CpSelect(866);
  MemInit(80, 25);
  App := TApplication.Create;
  Dlg := TDialog.Create(R(2, 2, 62, 22), 'ux');
  Inp := TInputLine.Create(R(2, 1, 30, 2), 20);
  Dlg.Insert(Inp);
  Chk := TCheckBoxes.Create(R(2, 3, 30, 6),
    TSItem.Create('~A~', TSItem.Create('~B~', TSItem.Create('~C~', nil))));
  Dlg.Insert(Chk);
  Two := TCheckBoxes.Create(R(2, 7, 40, 9),
    TSItem.Create('~D~', TSItem.Create('~E~', TSItem.Create('~F~', TSItem.Create('~G~', nil)))));
  Dlg.Insert(Two);
  Inp2 := TInputLine.Create(R(2, 10, 30, 11), 20);
  Dlg.Insert(Inp2);
  App.InsertWindow(Dlg);

  { Up on the first item leaves the group backwards, Down on the last one forwards }
  Chk.Select;
  Check(Dlg.Current = Chk, 'the group has the focus');
  Key(Chk, kbDown);
  Key(Chk, kbDown);
  Check(Chk.Sel = 2, 'Down walks the items');
  Key(Chk, kbDown);
  Check(Dlg.Current = Two, 'Down on the last item passes the focus to the next control');
  Chk.Select;
  Key(Chk, kbUp);
  Key(Chk, kbUp);
  Check(Chk.Sel = 0, 'Up walks back');
  Key(Chk, kbUp);
  Check(Dlg.Current = Inp, 'Up on the first item passes the focus to the previous control');

  { two columns of two rows: A C / B D style; Right at the end of a row goes to the next row }
  Two.Select;
  Check(Two.Sel = 0, 'the group starts at the first item');
  Key(Two, kbRight);
  Check(Two.Sel = 2, 'Right moves by a column');
  Key(Two, kbRight);
  Check(Two.Sel = 1, 'Right at the end of a row goes to the beginning of the next row');
  Key(Two, kbLeft);
  Check(Two.Sel = 2, 'Left at the beginning of a row goes to the end of the previous one');
  Key(Two, kbDown);
  Check(Two.Sel = 3, 'Down walks to the next item');
  Key(Two, kbDown);
  Check(Dlg.Current = Inp2, 'Down on the last item leaves the group');

  { the classic behaviour on request }
  UxNavBoundary := False;
  Chk.Select;
  Key(Chk, kbUp);
  Check(Dlg.Current = Chk, 'UxNavBoundary = False: Up on the first item wraps inside the group');
  UxNavBoundary := True;

  { tier 1: Tab walks the controls and wraps }
  Inp.Select;
  Key(Dlg, kbTab);
  Check(Dlg.Current = Chk, 'Tab goes to the next control');
  Key(Dlg, kbShiftTab);
  Key(Dlg, kbShiftTab);
  Check(Dlg.Current = Inp2, 'Shift+Tab on the first control wraps to the last');
  Key(Dlg, kbTab);
  Check(Dlg.Current = Inp, 'Tab on the last control wraps to the first');

  { a one-line field: Up and Down pass the focus, Left and Right stay for the cursor }
  Inp.Select;
  Key(Dlg, kbDown);
  Check(Dlg.Current = Chk, 'Down in an edit field goes to the next control');
  Inp2.Select;
  Key(Dlg, kbUp);
  Check(Dlg.Current = Two, 'Up in an edit field goes to the previous control');
  Inp2.Select;
  Key(Dlg, kbRight);
  Key(Dlg, kbLeft);
  Check(Dlg.Current = Inp2, 'Left and Right in an edit field are for the cursor');

  { Dlg2: a radio group, two buttons (no default), a field with a history }
  Dlg2 := TDialog.Create(R(2, 2, 62, 22), 'ux2');
  Rad := TRadioButtons.Create(R(2, 1, 30, 4), TSItem.Create('~A~', TSItem.Create('~B~', TSItem.Create('~C~', nil))));
  Dlg2.Insert(Rad);
  Hs := TInputLine.Create(R(2, 5, 30, 6), 20);
  Dlg2.Insert(Hs);
  Dlg2.Insert(THistory.Create(R(30, 5, 33, 6), Hs, 1));
  Bt1 := TButton.Create(R(2, 8, 12, 10), 'One', cmYes, bfNormal);
  Dlg2.Insert(Bt1);
  Bt2 := TButton.Create(R(14, 8, 24, 10), 'Two', cmNo, bfNormal);
  Dlg2.Insert(Bt2);
  App.InsertWindow(Dlg2);
  Rad.Select;

  { groups: the cursor and the selection are apart }
  Check(Rad.Value = 0, 'the first radio button is selected');
  Key(Rad, kbDown);
  Check((Rad.Sel = 1) and (Rad.Value = 0), 'Down moves the cursor of a radio group, the selection stays');
  Key(Rad, Ord(' '));
  Check(Rad.Value = 1, 'Space selects the radio button under the cursor');
  UxNavBoundary := False;
  Key(Rad, kbDown);
  Check(Rad.Value = 2, 'UxNavBoundary = False: the selection follows the cursor');
  UxNavBoundary := True;

  { a history field keeps Down for the list; Ctrl+Down is not taken by the dialog either }
  Hs.Select;
  Key(Dlg2, kbRight);
  Check(Dlg2.Current = Hs, 'a field with a history keeps its focus on Right');
  Check(Hs.KeepVertical, 'THistory tells its field to keep Up and Down');

  { a button is one item: every arrow key leaves it }
  Bt1.Select;
  Key(Dlg2, kbRight);
  Check(Dlg2.Current = Bt2, 'Right on a button goes to the next control');
  Key(Dlg2, kbLeft);
  Check(Dlg2.Current = Bt1, 'Left on a button goes to the previous control');
  Key(Dlg2, kbUp);
  Check(Dlg2.Current = Hs, 'Up on a button goes to the previous control');
  Bt1.Select;
  UxNavBoundary := False;
  Key(Dlg2, kbRight);
  Check(Dlg2.Current = Bt1, 'UxNavBoundary = False: the arrows stay on a button');
  UxNavBoundary := True;

  { Enter with no default button presses the first button that can act }
  TProgram.DeskTop.Delete(Dlg2);
  MemClear;
  MemKey(kbEnter);
  Check(TProgram.DeskTop.ExecView(Dlg2) = cmYes, 'Enter with no default button presses the first one');
  UxEnterButton := False;
  MemClear;
  MemKey(kbEnter);
  MemKey(kbEsc);
  Check(TProgram.DeskTop.ExecView(Dlg2) = cmCancel, 'UxEnterButton = False: Enter does nothing, Esc closes');
  UxEnterButton := True;
  MemClear;
  MemKey(kbEsc);
  Check(TProgram.DeskTop.ExecView(Dlg2) = cmCancel, 'Esc closes the dialog');
  Dlg2.Free;

  { a list of two columns: Left on the first item and Right on the last one leave it, Up and Down in the middle stay }
  Dlg2 := TDialog.Create(R(2, 2, 62, 22), 'ux3');
  Pre := TInputLine.Create(R(2, 1, 30, 2), 20);
  Dlg2.Insert(Pre);
  Lb := TListBox.Create(R(2, 3, 30, 6), 2, nil);
  Dlg2.Insert(Lb);
  Post := TInputLine.Create(R(2, 8, 30, 9), 20);
  Dlg2.Insert(Post);
  App.InsertWindow(Dlg2);
  Lb.NewList(Items(9));
  Lb.Select;
  Key(Dlg2, kbRight);
  Check((Dlg2.Current = Lb) and (Lb.Focused = 3), 'Right in a list of two columns moves by a column');
  Key(Dlg2, kbLeft);
  Key(Dlg2, kbLeft);
  Check(Dlg2.Current = Pre, 'Left on the first item leaves the list');
  Lb.Select;
  Key(Dlg2, kbEnd);
  Lb.FocusItem(8);
  Key(Dlg2, kbRight);
  Check(Dlg2.Current = Post, 'Right on the last item leaves the list');
  TProgram.DeskTop.Delete(Dlg2);
  Dlg2.Free;

  { tier 3: Alt+letter always, a plain letter when no text field has the focus }
  Dlg2 := TDialog.Create(R(2, 2, 62, 22), 'ux4');
  Pre := TInputLine.Create(R(2, 1, 30, 2), 20);
  Dlg2.Insert(Pre);
  Rad := TRadioButtons.Create(R(2, 3, 30, 6), TSItem.Create('~A~', TSItem.Create('~B~', nil)));
  Dlg2.Insert(Rad);
  Dlg2.Insert(TButton.Create(R(2, 8, 12, 10), '~G~o', cmYes, bfNormal));
  Dlg2.Insert(TButton.Create(R(14, 8, 24, 10), 'Close', cmNo, bfDefault));
  Rad.Select;
  MemClear;
  MemKey(Ord('g'));
  Check(TProgram.DeskTop.ExecView(Dlg2) = cmYes, 'a plain letter presses the button when no field is focused');
  Pre.Select;
  MemClear;
  MemKey(Ord('g'));
  MemKey(kbEnter);
  Check((TProgram.DeskTop.ExecView(Dlg2) = cmNo) and (Pre.Data^ = 'g'), 'in a text field the letter is typed and Enter presses the default button');
  Pre.Select;
  MemClear;
  MemKey(kbAltG, kbAltShift);
  Check(TProgram.DeskTop.ExecView(Dlg2) = cmYes, 'Alt+letter presses the button also from a text field');
  Dlg2.Free;

  { tier 0: Ctrl+Tab and Ctrl+Shift+Tab walk through the windows of the desktop }
  W1 := TWindow.Create(R(1, 1, 20, 8), 'one', 1);
  W2 := TWindow.Create(R(25, 1, 44, 8), 'two', 2);
  Dlg.Free;
  App.InsertWindow(W1);
  App.InsertWindow(W2);
  Check(TProgram.DeskTop.Current = W2, 'the last window inserted is the current one');
  MakeKeyEvent(Ev, kbCtrlTab, kbCtrlShift);
  App.HandleEvent(Ev);
  Check(TProgram.DeskTop.Current = W1, 'Ctrl+Tab goes to the next window');
  Check(Ev.What = evNothing, '... and the key is taken');
  MakeKeyEvent(Ev, kbCtrlTab, kbCtrlShift or kbShift);
  App.HandleEvent(Ev);
  Check(TProgram.DeskTop.Current = W2, 'Ctrl+Shift+Tab goes to the previous window');
  UxCtrlTab := False;
  MakeKeyEvent(Ev, kbCtrlTab, kbCtrlShift);
  App.HandleEvent(Ev);
  Check(TProgram.DeskTop.Current = W2, 'UxCtrlTab = False: the key is left to the application');
  UxCtrlTab := True;

  App.Free;
  Finish;
end.
