program t_objmod;
{ Checks the class model used by the translation: virtual methods, constructors,
  destructors, inherited calls, overriding across units, references to a base
  type that hold descendants, and a record passed by var to virtual methods. }
{$I ../src/tvdefs.inc}
uses TvGeom, ObjModA;
{$I testlib.inc}

type
  { a descendant in another unit than its ancestors, with a new field and a
    new virtual method }
  TCircle = class;
  TCircle = class(TShape)
    Radius: Integer;
    constructor Create(AName: ShortString; ARadius: Integer);
    destructor Destroy; override;
    function Area: Integer; override;
    function Describe: ShortString; override;
    procedure Grow(var R: TRect); override;
  end;

  TSquare = class;
  TSquare = class(TShape)
    Side: Integer;
    constructor Create(AName: ShortString; ASide: Integer);
    function Area: Integer; override;
  end;

constructor TCircle.Create(AName: ShortString; ARadius: Integer);
begin
  inherited Create(AName);
  Radius := ARadius;
end;

destructor TCircle.Destroy;
begin
  Inc(DoneCount, 100);
  inherited Destroy;
end;

function TCircle.Area: Integer;
begin
  Result := 3 * Radius * Radius;
end;

function TCircle.Describe: ShortString;
begin
  Result := 'circle:' + inherited Describe;
end;

procedure TCircle.Grow(var R: TRect);
begin
  R.Grow(Radius, Radius);
end;

constructor TSquare.Create(AName: ShortString; ASide: Integer);
begin
  inherited Create(AName);
  Side := ASide;
end;

function TSquare.Area: Integer;
begin
  Result := Side * Side;
end;

var
  P: TShape;
  C: TCircle;
  S: TSquare;
  R: TRect;
  Items: array[0..2] of TShape;
  I, Total: Integer;
begin
  C := TCircle.Create('c1', 2);
  P := C;
  Check(P.Area = 12, 'virtual call through a base reference reaches the override');
  Check(P.Describe = 'circle:shape:c1', 'inherited call inside an override');
  Check(P.Name = 'c1', 'field set by the ancestor constructor');
  Check(C.Radius = 2, 'field of the descendant');

  S := TSquare.Create('s1', 3);
  P := S;
  Check(P.Area = 9, 'second descendant');
  Check(P.Describe = 'shape:s1', 'ancestor method for a descendant without override');

  R.Assign(5, 5, 10, 10);
  P := C;
  P.Grow(R);
  Check((R.A.X = 3) and (R.B.X = 12), 'record by var through a virtual method');
  P := S;
  P.Grow(R);
  Check((R.A.X = 3) and (R.B.X = 12), 'the ancestor Grow does nothing');

  DoneCount := 0;
  P := C;
  P.Free;
  Check(DoneCount = 101, 'Free calls the virtual destructor chain');
  S.Free;
  Check(DoneCount = 102, 'Free of the second descendant');

  C := TCircle.Create('a', 1);
  S := TSquare.Create('b', 4);
  Items[0] := C;
  Items[1] := S;
  Items[2] := TShapeFactory.MakeUnit;
  Total := 0;
  for I := 0 to 2 do
    Inc(Total, Items[I].Area);
  Check(Total = 3 + 16 + 1, 'polymorphic loop over base references');
  for I := 0 to 2 do
    Items[I].Free;
  Check(DoneCount = 102 + 100 + 3, 'all descendants are freed through the base reference');

  Check(TShape.InstanceSize > SizeOf(Pointer), 'classes with virtual methods carry a VMT pointer');
  Check(TCircle.ClassInfo <> TSquare.ClassInfo, 'class information differs for different types');

  Finish;
end.
