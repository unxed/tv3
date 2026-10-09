program t_subptr;
{ A group that writes pointers to its OWN views after the views of the group (the way TDoubleWindow of DN keeps Separator and
  the panels): reading them back after the views gives the views of the group that was read. }
{$I ../src/tvdefs.inc}
uses TvGeom, TvEvents, TvScreen, TvObjs, TvUtil, TvViews, TvWindow, TvDialog;
{$I testlib.inc}
{$I strmlib.inc}

type
  TTwoGroup = class;
  TTwoGroup = class(TGroup)
    PtrA, PtrB: TView;       { two of the views of the group }
    PtrC: TView;               { not a view of the group }
    class function Build: TStreamable; static;
  protected
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  end;

class function TTwoGroup.Build: TStreamable;
begin
  Result := TTwoGroup.Create(streamableInit);
end;

function TTwoGroup.StreamableName: ShortString;
begin
  Result := 'TTwoGroup';
end;

function TTwoGroup.Read(Ip: ipstream): Pointer;
begin
  inherited Read(Ip);
  PtrA := TView(Ip.ReadPointer);
  PtrB := TView(Ip.ReadPointer);
  PtrC := TView(Ip.ReadPointer);
  Result := Self;
end;

procedure TTwoGroup.Write(Os: opstream);
begin
  inherited Write(Os);
  Os.WritePointer(PtrA);
  Os.WritePointer(PtrB);
  Os.WritePointer(PtrC);
end;

function R(A, B, C, D: Integer): TRect;
begin
  Result := TRect.Create(A, B, C, D);
end;

var
  RTwo: TStreamableClass;
  G, L: TTwoGroup;
  M: TTestStream;
  V1, V2, V3: TView;
begin
  ScreenCreate(80, 25);
  RTwo := TStreamableClass.Create('TTwoGroup', @TTwoGroup.Build);

  G := TTwoGroup.Create(R(0, 0, 40, 10));
  V1 := TStaticText.Create(R(1, 1, 10, 2), 'one');
  V2 := TStaticText.Create(R(1, 3, 10, 4), 'two');
  V3 := TStaticText.Create(R(1, 5, 10, 6), 'three');
  G.Insert(V1);
  G.Insert(V2);
  G.Insert(V3);
  G.PtrA := V3;               { not the first by the order of insertion }
  G.PtrB := V1;
  G.PtrC := nil;
  M := TTestStream.Create;
  M.Put(G);
  M.Rewind;
  L := TTwoGroup(M.Get);
  Check(L <> nil, 'the group is written and read');
  Check((L <> nil) and (L.PtrA <> nil) and (TStaticText(L.PtrA).Text^ = 'three'),
    'a pointer to a view of the group written after the views gives that view (PtrA)');
  Check((L <> nil) and (L.PtrB <> nil) and (TStaticText(L.PtrB).Text^ = 'one'), 'and the second pointer');
  Check((L <> nil) and (L.PtrC = nil), 'a nil pointer stays nil');
  Check((L <> nil) and (L.PtrA <> nil) and (L.PtrA.Owner = TGroup(L)) and (L.PtrB.Owner = TGroup(L)) and (L.PtrA <> V3) and (L.PtrB <> V1),
    'they are views of the group that was read, not of the one written');
  L.Free;
  G.Free;
  M.Free;
  ScreenDestroy;
  Finish;
end.
