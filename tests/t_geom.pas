program t_geom;
{$I ../src/tvdefs.inc}
uses TvGeom;
{$I testlib.inc}

var
  R, S, T: TRect;
  Pt1, Pt2: TPoint;
begin
  R := TRect.Create(1, 2, 11, 7);
  Check((R.A.X = 1) and (R.A.Y = 2) and (R.B.X = 11) and (R.B.Y = 7), 'TRect.Create');

  T := R;
  Check((T = R), 'assignment and =');

  R.Move(3, -1);
  Check((R.A.X = 4) and (R.A.Y = 1) and (R.B.X = 14) and (R.B.Y = 6), 'Move');

  R.Grow(2, 1);
  Check((R.A.X = 2) and (R.A.Y = 0) and (R.B.X = 16) and (R.B.Y = 7), 'Grow');
  R.Grow(-2, -1);
  Check((R.A.X = 4) and (R.A.Y = 1) and (R.B.X = 14) and (R.B.Y = 6), 'Grow back');

  { half-open: A inside, B outside }
  R := TRect.Create(0, 0, 10, 5);
  Check(R.Contains(Point(0, 0)), 'Contains A');
  Check(R.Contains(Point(9, 4)), 'Contains B-1');
  Check(not R.Contains(Point(10, 4)), 'not Contains B.X');
  Check(not R.Contains(Point(9, 5)), 'not Contains B.Y');
  Check(not R.Contains(Point(-1, 0)), 'not Contains left');

  Check(not R.IsEmpty, 'not Empty');
  S := TRect.Create(3, 3, 3, 9);
  Check(S.IsEmpty, 'Empty (zero width)');
  S := TRect.Create(5, 5, 2, 9);
  Check(S.IsEmpty, 'Empty (inverted)');

  R := TRect.Create(0, 0, 10, 10);
  S := TRect.Create(5, 6, 20, 8);
  T := R;
  T.Intersect(S);
  Check((T.A.X = 5) and (T.A.Y = 6) and (T.B.X = 10) and (T.B.Y = 8), 'Intersect');

  S := TRect.Create(20, 20, 30, 30);
  T := R;
  T.Intersect(S);
  Check(T.IsEmpty, 'Intersect disjoint is Empty');

  S := TRect.Create(-5, 4, 6, 15);
  T := R;
  T.Union(S);
  Check((T.A.X = -5) and (T.A.Y = 0) and (T.B.X = 10) and (T.B.Y = 15), 'Union');

  Check(((Point(1, 2) + Point(10, 20)) = Point(11, 22)), 'PointAdd');
  Check(((Point(10, 20) - Point(1, 2)) = Point(9, 18)), 'PointSub');
  Check(not (Point(1, 2) = Point(2, 1)), 'PointEq false');

  { the operators of the point and of the rectangle }
  Pt1 := Point(3, 4);
  Pt2 := Point(3, 4);
  Check((Pt1 = Pt2) and not (Pt1 <> Pt2) and (Pt1 <> Point(4, 3)), 'TPoint = and <>');
  R := TRect.Create(Point(1, 2), Point(5, 6));
  Check((R = TRect.Create(1, 2, 5, 6)) and (R <> TRect.Create(1, 2, 5, 7)), 'TRect.Create of two points, = and <>');
  Finish;
end.
