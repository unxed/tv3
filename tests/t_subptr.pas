program t_subptr;
{ A group that stores a pointer to one of its OWN views after "inherited Store" and reads it back after "inherited Load" with
  GetSubViewPtr (the way TDoubleWindow of DN does: Separator, the panels). The pointer must be the loaded view at once;
  the bug it guards against: it stayed nil (the pointer went to the list of fixups of an enclosing group, which was gone), and a
  desktop saved with "Save desktop" could not be loaded ("Error reading desktop file"). }
{$I ../src/tvdefs.inc}
uses TvGeom, TvEvents, TvScreen, TvObjs, TvUtil, TvViews, TvWindow, TvDialog;
{$I testlib.inc}

type
  TTwoGroup = class;
  TTwoGroup = class(TGroup)
    PtrA, PtrB: TView;       { two of the views of the group }
    PtrC: TView;               { not a view of the group }
    constructor Load(S: TStream);
    procedure Store(S: TStream);
  end;

constructor TTwoGroup.Load(S: TStream);
begin
  inherited Load(S);
  GetSubViewPtr(S, PtrA);
  GetSubViewPtr(S, PtrB);
  GetSubViewPtr(S, PtrC);
end;

procedure TTwoGroup.Store(S: TStream);
begin
  inherited Store(S);
  PutSubViewPtr(S, PtrA);
  PutSubViewPtr(S, PtrB);
  PutSubViewPtr(S, PtrC);
end;

function BuildTwo(S: TStream): TStreamable;
begin
  Result := TTwoGroup.Load(S);
end;

procedure StoreTwo(P: TStreamable; S: TStream);
begin
  TTwoGroup(P).Store(S);
end;

function R(A, B, C, D: Integer): TRect;
begin
  Result := TRect.Create(A, B, C, D);
end;

var
  RTwo: TStreamRec;
  G, L: TTwoGroup;
  M: TMemoryStream;
  V1, V2, V3: TView;
  Outside: TView;
begin
  ScreenCreate(80, 25);
  RegisterType(RView);
  RegisterType(RGroup);
  RegisterType(RFrame);
  RegisterType(RWindow);
  RegisterType(RStaticText);
  RTwo.ObjType := 4701;
  RTwo.VmtLink := PtrUInt(System.TClass(TTwoGroup));
  RTwo.Load := @BuildTwo;
  RTwo.Store := @StoreTwo;
  RegisterType(RTwo);

  G := TTwoGroup.Create(R(0, 0, 40, 10));
  V1 := TStaticText.Create(R(1, 1, 10, 2), 'one');
  V2 := TStaticText.Create(R(1, 3, 10, 4), 'two');
  V3 := TStaticText.Create(R(1, 5, 10, 6), 'three');
  G.Insert(V1);
  G.Insert(V2);
  G.Insert(V3);
  G.PtrA := V3;               { not the first by the order of insertion: the index must not be 1 }
  G.PtrB := V1;
  G.PtrC := nil;
  Outside := TStaticText.Create(R(1, 7, 10, 8), 'outside');
  M := TMemoryStream.Create(0, 1024);
  M.Put(G);
  Check(M.Status = stOk, 'the group is stored');
  M.Seek(0);
  L := TTwoGroup(M.Get);
  Check((L <> nil) and (M.Status = stOk), 'the group is loaded');
  Check((L <> nil) and (L.PtrA <> nil) and (TStaticText(L.PtrA).Text^ = 'three'),
    'GetSubViewPtr after inherited Load gives the view of the group at once (PtrA)');
  Check((L <> nil) and (L.PtrB <> nil) and (TStaticText(L.PtrB).Text^ = 'one'), 'and the second pointer');
  Check((L <> nil) and (L.PtrC = nil), 'a nil pointer stays nil');
  Check((L <> nil) and (L.PtrA <> nil) and (L.PtrA.Owner = TGroup(L)) and (L.PtrB.Owner = TGroup(L)) and (L.PtrA <> V3) and (L.PtrB <> V1),
    'they are views of the loaded group, not of the stored one');
  L.Free;
  G.Free;
  Outside.Free;
  M.Free;
  ScreenDestroy;
  Finish;
end.
