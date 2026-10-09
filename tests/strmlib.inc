{ Object streams in memory for the tests (needs TvObjs): Put writes a pointer to an object, Rewind turns the
  stream to reading from the start, Get reads a pointer to an object. }
type
  TTestStream = class
    Mem: TMemoryStream;
    Os: opstream;
    Ip: ipstream;
    constructor Create;
    destructor Destroy; override;
    procedure Put(P: TStreamable);
    procedure Rewind;
    function Get: TStreamable;
  end;

constructor TTestStream.Create;
begin
  inherited Create;
  Mem := TMemoryStream.Create(0, 1024);
  Os := opstream.Create(Mem);
end;

destructor TTestStream.Destroy;
begin
  Os.Free;
  Ip.Free;
  Mem.Free;
  inherited Destroy;
end;

procedure TTestStream.Put(P: TStreamable);
begin
  Os.WritePointer(P);
end;

procedure TTestStream.Rewind;
begin
  Os.Free;
  Os := nil;
  Ip.Free;
  Ip := nil;
  Mem.Seek(0);
  Ip := ipstream.Create(Mem);
end;

function TTestStream.Get: TStreamable;
begin
  Result := TStreamable(Ip.ReadPointer);
end;
