program t_vstrm;
{ Streams of the views of dialogs: a dialog with its controls is stored and loaded back. }
{$I ../src/tvdefs.inc}
uses TvGeom, TvEvents, TvScreen, TvObjs, TvUtil, TvViews, TvWindow, TvDialog, TvInput, TvCluster, TvList;
{$I testlib.inc}
{$I strmlib.inc}

function R(A, B, C, D: Integer): TRect;
begin
  Result := TRect.Create(A, B, C, D);
end;

var
  D, L: TDialog;
  M: TTestStream;
  Inp: TInputLine;
  Lab: TLabel;
  Btn: TButton;
  Chk: TCheckBoxes;
  Lb: TListBox;
  Coll: TStringCollection;
  I: Integer;
  Inp2: TInputLine;
  Lab2: TLabel;
  Btn2: TButton;
  Chk2: TCheckBoxes;
  Lb2: TListBox;
  St2: TStaticText;
  P: TView;

procedure Find;
begin
  Inp2 := nil; Lab2 := nil; Btn2 := nil; Chk2 := nil; Lb2 := nil; St2 := nil;
  for I := 1 to 20 do
  begin
    P := L.At(I);
    if P = nil then
      Break;
    if P.ClassType = TInputLine then Inp2 := TInputLine(P);
    if P.ClassType = TLabel then Lab2 := TLabel(P);
    if P.ClassType = TButton then Btn2 := TButton(P);
    if P.ClassType = TCheckBoxes then Chk2 := TCheckBoxes(P);
    if P.ClassType = TListBox then Lb2 := TListBox(P);
    if P.ClassType = TStaticText then St2 := TStaticText(P);
  end;
end;

begin
  ScreenCreate(80, 25);

  D := TDialog.Create(R(0, 0, 50, 16), 'Options');
  Inp := TInputLine.Create(R(3, 3, 30, 4), 20);
  Inp.Data^ := 'abc';
  Inp.CurPos := 2;
  D.Insert(Inp);
  Lab := TLabel.Create(R(2, 2, 12, 3), '~N~ame', Inp);
  D.Insert(Lab);
  D.Insert(TStaticText.Create(R(3, 5, 40, 6), 'some text'));
  Btn := TButton.Create(R(3, 13, 13, 15), '~O~K', cmOK, bfDefault);
  D.Insert(Btn);
  Chk := TCheckBoxes.Create(R(3, 7, 20, 9), TSItem.Create('~A~', TSItem.Create('~B~', nil)));
  Chk.Value := 2;
  D.Insert(Chk);
  Coll := TStringCollection.Create(5, 5);
  Coll.Insert(NewStr('one'));
  Coll.Insert(NewStr('two'));
  Lb := TListBox.Create(R(25, 7, 45, 12), 1, nil);
  Lb.NewList(Coll);
  D.Insert(Lb);

  M := TTestStream.Create;
  M.Put(D);
  M.Rewind;
  L := TDialog(M.Get);
  Check(L <> nil, 'a dialog is written and read');
  Check((L <> nil) and (L.Title^ = 'Options') and (L.Size.X = 50), 'the window part');
  Find;
  Check(Inp2 <> nil, 'the input line');
  Check((Inp2 <> nil) and (Inp2.Data^ = 'abc') and (Inp2.MaxLen = 20),
    'the text and the length of the input line (Awaken selects all, as in Borland TV)');
  Check((Lab2 <> nil) and (Lab2.Link = TView(Inp2)), 'the label points to its input line');
  Check((Lab2 <> nil) and (Lab2.Text <> nil) and (Lab2.Text^ = '~N~ame'), 'the text of the label');
  Check((Btn2 <> nil) and (Btn2.Title^ = '~O~K') and (Btn2.Command = cmOK) and Btn2.AmDefault, 'the button');
  Check((Chk2 <> nil) and (Chk2.Value = 2) and (Chk2.Strings.Count = 2), 'the check boxes');
  Check((Lb2 <> nil) and (Lb2.List <> nil) and (Lb2.List.Count = 2) and (Lb2.Range = 2), 'the list box and its list');
  Check((St2 <> nil) and (St2.Text^ = 'some text'), 'the static text');
  Check((L <> nil) and (L.Frame <> nil), 'the frame');
  L.Free;
  D.Free;
  M.Free;
  ScreenDestroy;
  Finish;
end.
