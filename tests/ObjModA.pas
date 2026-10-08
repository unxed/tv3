{ Test support for t_objmod: the ancestor class types live in their own unit. }
unit ObjModA;

{$I ../src/tvdefs.inc}

interface

uses
  TvGeom;

type
  TShape = class;
  TShape = class
    Name: ShortString;
    constructor Create(AName: ShortString);
    destructor Destroy; override;
    function Area: Integer; virtual;
    function Describe: ShortString; virtual;
    procedure Grow(var R: TRect); virtual;
  end;

  TShapeFactory = class
    class function MakeUnit: TShape; static;
  end;

var
  DoneCount: Integer = 0;

implementation

type
  TUnit = class;
  TUnit = class(TShape)
    function Area: Integer; override;
  end;

constructor TShape.Create(AName: ShortString);
begin
  inherited Create;
  Name := AName;
end;

destructor TShape.Destroy;
begin
  Inc(DoneCount);
  inherited Destroy;
end;

function TShape.Area: Integer;
begin
  Result := 0;
end;

function TShape.Describe: ShortString;
begin
  Result := 'shape:' + Name;
end;

procedure TShape.Grow(var R: TRect);
begin
end;

function TUnit.Area: Integer;
begin
  Result := 1;
end;

class function TShapeFactory.MakeUnit: TShape;
begin
  Result := TUnit.Create('unit');
end;

end.
