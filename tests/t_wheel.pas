program t_wheel;
{$I ../src/tvdefs.inc}
uses TvGeom, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem, TvApp,
  TvDialog, TvWindow, TvList;
{$I testlib.inc}

{ X.4 of the UX guidelines: the wheel scrolls the view under the pointer, whatever has the focus }

function R(A, B, C, D: Integer): TRect;
begin
  Result := TRect.Create(A, B, C, D);
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

procedure Wheel(V: TView; X, Y: Integer; Dir: Byte);
var
  E: TEvent;
begin
  ClearEvent(E);
  E.What := evMouseWheel;
  E.Mouse.Where := V.MakeGlobal(Point(X, Y));
  E.Mouse.Wheel := Dir;
  TProgram.Application.HandleEvent(E);
end;

type
  { a view of an application that handles the wheel itself, after its parent class did }
  TOwnScr = class(TScroller)
    Got: Integer;
    constructor Create(const Bounds: TRect; AH, AV: TScrollBar);
    procedure HandleEvent(var Event: TEvent); override;
  end;

constructor TOwnScr.Create(const Bounds: TRect; AH, AV: TScrollBar);
begin
  inherited Create(Bounds, AH, AV);
  EventMask := EventMask or evMouseWheel;
end;

procedure TOwnScr.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evMouseWheel then
  begin
    Inc(Got);
    ClearEvent(Event);
  end;
end;

var
  Own: TOwnScr;
  App: TApplication;
  W1, W2: TWindow;
  B1, B2, LB: TScrollBar;
  S1, S2: TScroller;
  L: TListBox;
  Bar: TScrollBar;

begin
  CpSelect(866);
  MemInit(100, 30);
  App := TApplication.Create;
  W1 := TWindow.Create(R(1, 1, 30, 14), 'one', 1);
  B1 := W1.StandardScrollBar(sbVertical or sbHandleKeyboard);
  S1 := TScroller.Create(R(1, 1, 28, 12), nil, B1);
  S1.SetLimit(10, 100);
  W1.Insert(S1);
  W2 := TWindow.Create(R(40, 1, 70, 14), 'two', 2);
  B2 := W2.StandardScrollBar(sbVertical or sbHandleKeyboard);
  S2 := TScroller.Create(R(1, 1, 28, 12), nil, B2);
  S2.SetLimit(10, 100);
  W2.Insert(S2);
  App.InsertWindow(W1);
  App.InsertWindow(W2);
  Check(TProgram.DeskTop.Current = W2, 'the second window has the focus');

  Check(UxWheelUnderCursor, 'the switch is on by default');
  Wheel(S1, 5, 5, mwDown);
  Check(S1.Delta.Y = 3, 'the wheel over the unfocused window scrolls that window');
  Check(S2.Delta.Y = 0, '... and not the focused one');
  Check(TProgram.DeskTop.Current = W2, '... and does not move the focus');
  Wheel(S1, 5, 5, mwUp);
  Check(S1.Delta.Y = 0, 'the wheel up scrolls back');
  Wheel(S2, 5, 5, mwDown);
  Wheel(S2, 5, 5, mwDown);
  Check(S2.Delta.Y = 6, 'over the focused window it scrolls the focused one');
  Check(S1.Delta.Y = 0, '... and the other stays');
  Wheel(S1, 5, 5, mwUp);
  Check(S1.Delta.Y = 0, 'at the top the wheel up changes nothing');
  Wheel(S1, 0, 50, mwDown);   { off every window: the desktop background }
  Check(S1.Delta.Y = 0, 'the wheel over the background scrolls nothing');

  { a list }
  W1.Free;
  W1 := TWindow.Create(R(1, 1, 30, 14), 'list', 1);
  LB := W1.StandardScrollBar(sbVertical);
  L := TListBox.Create(R(1, 1, 28, 12), 1, LB);
  L.NewList(Items(40));
  W1.Insert(L);
  App.InsertWindow(W1);
  W2.Select;
  Check(TProgram.DeskTop.Current = W2, 'the focus is on the other window');
  Wheel(L, 3, 3, mwDown);
  Check(L.Focused = 3, 'the wheel over a list moves its cursor by three');
  Check(S2.Delta.Y = 6, '... the focused window did not scroll');
  Wheel(L, 3, 3, mwUp);
  Wheel(L, 3, 3, mwUp);
  Check(L.Focused = 0, 'the cursor stops at the first item');

  { the old way }
  UxWheelUnderCursor := False;
  Wheel(L, 3, 3, mwDown);
  Check(L.Focused = 0, 'UxWheelUnderCursor = False: the list under the pointer does not get it');
  Check(S2.Delta.Y = 9, '... the focused window does');
  UxWheelUnderCursor := True;

  { a view that takes the wheel itself still gets it, and the bars of its window do not move }
  W1.Free;
  W1 := TWindow.Create(R(1, 1, 30, 14), 'own', 1);
  B1 := W1.StandardScrollBar(sbVertical);
  Own := TOwnScr.Create(R(1, 1, 28, 12), nil, B1);
  Own.SetLimit(10, 100);
  W1.Insert(Own);
  App.InsertWindow(W1);
  W2.Select;
  Wheel(Own, 3, 3, mwDown);
  Check((Own.Got = 1) and (Own.Delta.Y = 0), 'a view that handles the wheel itself gets it under the pointer, the bar of the window stays');
  Wheel(Own, 27, 3, mwDown);
  Check(B1.Value = 3, 'the wheel over the scroll bar itself moves it');

  App.Free;
  Finish;
end.
