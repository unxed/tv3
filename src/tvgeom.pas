{ TvGeom: points and rectangles.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision geometry header (TPoint, TRect).
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  A TRect is half-open: A is inside, B is outside. It is empty when B is not
  below and to the right of A. }
unit TvGeom;

{$I tvdefs.inc}

interface

type
  TPoint = record
    X, Y: Integer;
    class operator +(const P1, P2: TPoint): TPoint;
    class operator -(const P1, P2: TPoint): TPoint;
    class operator =(const P1, P2: TPoint): Boolean;
    class operator <>(const P1, P2: TPoint): Boolean;
  end;
  PPoint = ^TPoint;

  TRect = record
    A, B: TPoint;
    constructor Create(AX, AY, BX, BY: Integer); overload;
    constructor Create(const P1, P2: TPoint); overload;
    procedure Move(ADX, ADY: Integer);
    procedure Grow(ADX, ADY: Integer);
    procedure Intersect(const R: TRect);
    procedure Union(const R: TRect);
    function Contains(const P: TPoint): Boolean;
    function IsEmpty: Boolean;
    class operator =(const R1, R2: TRect): Boolean;
    class operator <>(const R1, R2: TRect): Boolean;
  end;
  PRect = ^TRect;

{ A point with the coordinates AX, AY (the brace initializer of a point). }
function Point(AX, AY: Integer): TPoint; inline;

implementation

function Point(AX, AY: Integer): TPoint;
begin
  Result.X := AX;
  Result.Y := AY;
end;

procedure TRect.Move(ADX, ADY: Integer);
begin
  Inc(A.X, ADX);
  Inc(B.X, ADX);
  Inc(A.Y, ADY);
  Inc(B.Y, ADY);
end;

procedure TRect.Grow(ADX, ADY: Integer);
begin
  Dec(A.X, ADX);
  Inc(B.X, ADX);
  Dec(A.Y, ADY);
  Inc(B.Y, ADY);
end;

procedure TRect.Intersect(const R: TRect);
begin
  if R.A.X > A.X then A.X := R.A.X;
  if R.A.Y > A.Y then A.Y := R.A.Y;
  if R.B.X < B.X then B.X := R.B.X;
  if R.B.Y < B.Y then B.Y := R.B.Y;
end;

procedure TRect.Union(const R: TRect);
begin
  if R.A.X < A.X then A.X := R.A.X;
  if R.A.Y < A.Y then A.Y := R.A.Y;
  if R.B.X > B.X then B.X := R.B.X;
  if R.B.Y > B.Y then B.Y := R.B.Y;
end;

function TRect.Contains(const P: TPoint): Boolean;
begin
  { A is inside, B is outside }
  Result := (A.X <= P.X) and (A.Y <= P.Y) and (P.X < B.X) and (P.Y < B.Y);
end;

function TRect.IsEmpty: Boolean;
begin
  Result := (B.X <= A.X) or (B.Y <= A.Y);
end;

class operator TPoint.+(const P1, P2: TPoint): TPoint;
begin
  Result.X := P1.X + P2.X;
  Result.Y := P1.Y + P2.Y;
end;

class operator TPoint.-(const P1, P2: TPoint): TPoint;
begin
  Result.X := P1.X - P2.X;
  Result.Y := P1.Y - P2.Y;
end;

class operator TPoint.=(const P1, P2: TPoint): Boolean;
begin
  Result := (P1.X = P2.X) and (P1.Y = P2.Y);
end;

class operator TPoint.<>(const P1, P2: TPoint): Boolean;
begin
  Result := not (P1 = P2);
end;

constructor TRect.Create(AX, AY, BX, BY: Integer);
begin
  A.X := AX;
  A.Y := AY;
  B.X := BX;
  B.Y := BY;
end;

constructor TRect.Create(const P1, P2: TPoint);
begin
  A := P1;
  B := P2;
end;

class operator TRect.=(const R1, R2: TRect): Boolean;
begin
  Result := (R1.A = R2.A) and (R1.B = R2.B);
end;

class operator TRect.<>(const R1, R2: TRect): Boolean;
begin
  Result := not (R1 = R2);
end;

end.
