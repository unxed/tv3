program t_objs;
{$I ../src/tvdefs.inc}
uses SysUtils, TvUtil, TvObjs;
{$I testlib.inc}

type
  TA = class;
  TA = class(TStreamable)
    A: Integer;
    B: array[0..9] of Byte;
    constructor Create;
  end;
  TB = class;
  TB = class(TA)
    C: Int64;
    D: TStreamable;
    constructor Create;
  end;

  { a streamable point }
  TPt = class;
  TPt = class(TStreamable)
    X, Y: Integer;
    constructor Create(AX, AY: Integer); overload;
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  end;

  { a collection of points: the items are written as pointers }
  TPtColl = class(TCollection)
    class function Build: TStreamable; static;
  protected
    function StreamableName: ShortString; override;
    function ReadItem(Ip: ipstream): Pointer; override;
    procedure WriteItem(Item: Pointer; Os: opstream); override;
  end;

  { a class that is not registered }
  TLost = class(TPt)
  protected
    function StreamableName: ShortString; override;
  end;

  { a collection that records its errors instead of stopping the program }
  TSafeColl = class(TCollection)
    LastCode, LastInfo, Errors: Integer;
    procedure Error(Code, Info: Integer); override;
    procedure FreeItem(Item: Pointer); override;
  end;

  TIntColl = class(TSortedCollection)
    function Compare(Key1, Key2: Pointer): Integer; override;
    procedure FreeItem(Item: Pointer); override;
  end;

  { a sorted collection that is not streamable }
  TIntNSColl = class(TNSSortedCollection)
    function Compare(Key1, Key2: Pointer): Integer; override;
    procedure FreeItem(Item: Pointer); override;
  end;


var
  Freed: Integer = 0;
  Sum: Integer = 0;

constructor TA.Create;
begin
  inherited Create;
end;

constructor TB.Create;
begin
  inherited Create;
end;

constructor TPt.Create(AX, AY: Integer);
begin
  inherited Create;
  X := AX;
  Y := AY;
end;

class function TPt.Build: TStreamable;
begin
  Result := TPt.Create(streamableInit);
end;

constructor TPt.Create(AInit: TStreamableInit);
begin
  inherited Create;
end;

function TPt.StreamableName: ShortString;
begin
  Result := 'TPt';
end;

procedure TPt.Write(Os: opstream);
begin
  Os.WriteBytes(X, SizeOf(Integer));
  Os.WriteBytes(Y, SizeOf(Integer));
end;

function TPt.Read(Ip: ipstream): Pointer;
begin
  Ip.ReadBytes(X, SizeOf(Integer));
  Ip.ReadBytes(Y, SizeOf(Integer));
  Result := Self;
end;

function TLost.StreamableName: ShortString;
begin
  Result := 'TLost';
end;

class function TPtColl.Build: TStreamable;
begin
  Result := TPtColl.Create(streamableInit);
end;

function TPtColl.StreamableName: ShortString;
begin
  Result := 'TPtColl';
end;

procedure TPtColl.WriteItem(Item: Pointer; Os: opstream);
begin
  Os.WritePointer(TStreamable(Item));
end;

function TPtColl.ReadItem(Ip: ipstream): Pointer;
begin
  Result := Ip.ReadPointer;
end;

var
  RPt, RPtColl: TStreamableClass;

procedure TSafeColl.Error(Code, Info: Integer);
begin
  LastCode := Code;
  LastInfo := Info;
  Inc(Errors);
end;

procedure TSafeColl.FreeItem(Item: Pointer);
begin
  { the items are numbers, not instances }
end;

procedure TIntColl.FreeItem(Item: Pointer);
begin
end;

function TIntColl.Compare(Key1, Key2: Pointer): Integer;
begin
  if PtrInt(Key1) < PtrInt(Key2) then
    Result := -1
  else if PtrInt(Key1) > PtrInt(Key2) then
    Result := 1
  else
    Result := 0;
end;

procedure TIntNSColl.FreeItem(Item: Pointer);
begin
end;

function TIntNSColl.Compare(Key1, Key2: Pointer): Integer;
begin
  Result := PtrInt(Key1) - PtrInt(Key2);
end;

function IsBig(Item: Pointer): Boolean;
begin
  Result := PtrInt(Item) > 50;
end;

procedure AddTo(Item: Pointer);
begin
  Inc(Sum, PtrInt(Item));
end;

const
  TmpName = 'T_OBJS.TMP';

var
  X: TB;
  M: TMemoryStream;
  Os: opstream;
  Ip: ipstream;
  OF_: ofpstream;
  IF_: ifpstream;
  F: fpstream;
  Buf: array[0..63] of Char;
  I: Integer;
  P: PStr;
  W: Word;
  Used0: PtrUInt;
  FreeObj: TStreamable;
  C: TSafeColl;
  IC: TIntColl;
  SC: TStringCollection;
  C2: TSafeColl;
  PC: TCollection;
  Pt: TPt;
  O, O2: TStreamable;
  PCC: TPtColl;
  Long: ShortString;

{ routines declared inside the caller, passed as @Name (Turbo Pascal style): they use the variables of the caller }
procedure NestedCheck(C: TCollection);
var
  Limit, Count, Total: Integer;

  function Over(P: Pointer): Boolean;
  begin
    Result := PtrInt(P) > Limit;
  end;

  procedure Add(P: Pointer);
  begin
    Inc(Count);
    Inc(Total, PtrInt(P));
  end;

begin
  Limit := 50;
  Check(C.FirstThat(@Over) = Pointer(60), 'FirstThat with a local function');
  Check(C.LastThat(@Over) = Pointer(70), 'LastThat with a local function');
  Limit := 1000;
  Check(C.FirstThat(@Over) = nil, 'the local function sees the changed variable of the caller');
  Count := 0;
  Total := 0;
  C.ForEach(@Add);
  Check((Count = C.Count) and (Total = 20 + 30 + 60 + 70), 'ForEach with a local procedure');
end;

procedure StreamSections;
var
  M: TMemoryStream;
  Os: opstream;
  Ip: ipstream;
  OF_: ofpstream;
  IF_: ifpstream;
  F: fpstream;
  Buf: array[0..63] of Char;
  I: Integer;
  P: PStr;
  Pt: TPt;
  O, O2: TStreamable;
  PCC: TPtColl;
  Long: ShortString;
begin
  { --- the bytes, the words and the strings of a stream -------------------------- }
  M := TMemoryStream.Create(0, 64);
  Os := opstream.Create(M);
  Os.WriteByte($41);
  Os.WriteWord($1234);
  I := -5;
  Os.WriteBytes(I, SizeOf(Integer));
  Os.WriteString('Привет');
  Os.WriteString(PStr(nil));
  FillChar(Long[1], 255, Ord('x'));
  Long[0] := #255;
  Os.WriteString(Long);
  Check((M.GetSize = 1 + 2 + 4 + 1 + Length('Привет') + 1 + 1 + 254) and (Os.TellP = M.GetSize), 'the sizes of the bytes, words and strings');
  Os.Free;
  M.Seek(0);
  Ip := ipstream.Create(M);
  Check((Ip.ReadByte = $41) and (Ip.ReadWord = $1234), 'ReadByte, ReadWord');
  Ip.ReadBytes(I, SizeOf(Integer));
  Check(I = -5, 'ReadBytes');
  P := Ip.ReadString;
  Check((P <> nil) and (P^ = 'Привет'), 'ReadString');
  DisposeStr(P);
  Check(Ip.ReadString = nil, 'the null string');
  P := Ip.ReadString;
  Check((P <> nil) and (Length(P^) = 254), 'a string is cut to 254 bytes');
  DisposeStr(P);
  Ip.SeekG(0);
  Check((Ip.TellG = 0) and (Ip.ReadByte = $41), 'SeekG and TellG');
  Ip.SeekG(-1, fsFromEnd);
  Check(Ip.ReadByte = Ord('x'), 'SeekG from the end');
  Ip.SeekG(7);
  Check((Ip.ReadString(@Buf[0], 4) = nil), 'ReadString into a buffer that is too small gives nil');
  Ip.SeekG(7);
  Check((Ip.ReadString(@Buf[0], SizeOf(Buf)) <> nil) and (StrPas(@Buf[0]) = 'Привет'), 'ReadString into a buffer');
  Ip.Free;
  M.Free;

  { --- objects: the prefix with the name, the pointers, the indexed objects ---------- }
  M := TMemoryStream.Create(0, 64);
  Os := opstream.Create(M);
  Pt := TPt.Create(3, -4);
  Os.WritePointer(Pt);
  Os.WritePointer(nil);
  Os.WritePointer(Pt);                         { written once: the second time it is an index }
  O := TPt.Create(3, -4);
  Os.WriteObject(O);
  O.Free;
  Os.Free;
  M.Seek(0);
  Check((PByte(M.Data)[0] = Ord(pstream.PointerTypes.ptObject)) and (PByte(M.Data)[1] = Ord('[')) and
    (PByte(M.Data)[2] = 3) and (PChar(M.Data)[3] = 'T'), 'a pointer to an object: ptObject, ''['', the name');
  Ip := ipstream.Create(M);
  O := TStreamable(Ip.ReadPointer);
  Check((O <> nil) and (O is TPt) and (TPt(O).X = 3) and (TPt(O).Y = -4), 'ReadPointer makes the object again');
  Check(Ip.ReadPointer = nil, 'ptNull');
  O2 := TStreamable(Ip.ReadPointer);
  Check(O2 = O, 'ptIndexed gives the object read before');
  Pt.X := 0;
  Ip.ReadObject(Pt);
  Check((Pt.X = 3) and (Pt.Y = -4), 'ReadObject reads into an object');
  Ip.Free;
  O.Free;
  Pt.Free;
  M.Free;

  { --- a collection of objects and a string collection -------------------------------- }
  PCC := TPtColl.Create(2, 2);
  Pt := TPt.Create(5, 6); PCC.Insert(Pt);
  PCC.Insert(Pt);
  Pt := TPt.Create(7, 8); PCC.Insert(Pt);
  M := TMemoryStream.Create(0, 64);
  Os := opstream.Create(M);
  Os.WritePointer(PCC);
  Os.Free;
  PCC.AtRemove(1);
  PCC.Free;
  M.Seek(0);
  Ip := ipstream.Create(M);
  PCC := TPtColl(Ip.ReadPointer);
  Ip.Free;
  M.Free;
  Check((PCC.Count = 3) and (TPt(PCC.At(2)).X = 7) and (TPt(PCC.At(0)).Y = 6) and (PCC.At(1) = PCC.At(0)),
    'a collection of objects through a stream; an object twice in it is read once');
  PCC.AtRemove(1);
  PCC.Free;

  { --- the file streams ---------------------------------------------------------------- }
  OF_ := ofpstream.Create('t_objs.tmp');
  Check(OF_.Good <> 0, 'ofpstream opens a new file');
  Pt := TPt.Create(11, 12);
  OF_.WritePointer(Pt);
  Pt.Free;
  OF_.Free;
  IF_ := ifpstream.Create('t_objs.tmp');
  O := TStreamable(IF_.ReadPointer);
  Check((O <> nil) and (TPt(O).X = 11), 'ifpstream reads it back');
  O.Free;
  IF_.Close;
  Check(IF_.RdBuf = nil, 'Close');
  IF_.Open('t_objs_missing.tmp');
  Check(IF_.Bad <> 0, 'opening a missing file sets badbit');
  IF_.Free;
  F := fpstream.Create('t_objs.tmp', stOpen);
  F.SeekP(0, fsFromEnd);
  Pt := TPt.Create(21, 22);
  F.WritePointer(Pt);
  Pt.Free;
  F.SeekG(0);
  O := TStreamable(F.ReadPointer);
  O2 := TStreamable(F.ReadPointer);
  Check((TPt(O).X = 11) and (TPt(O2).X = 21), 'fpstream reads and writes one file');
  O.Free;
  O2.Free;
  F.Free;
  DeleteFile('t_objs.tmp');

end;

{ reads one pointer from M; the error it raises, if any }
function ReadError(M: TMemoryStream; out Kind: pstream.StreamableError; out TypeName: ShortString;
  out Msg: AnsiString): Boolean;
var
  Ip: ipstream;
  O: Pointer;
begin
  Result := False;
  M.Seek(0);
  Ip := ipstream.Create(M);
  try
    O := Ip.ReadPointer;
    TObject(O).Free;
  except
    on E: EStreamableError do
    begin
      Result := True;
      Kind := E.Kind;
      TypeName := E.TypeName;
      Msg := E.Message;
    end;
  end;
  Ip.Free;
end;

{ writes T as a pointer; the error it raises, if any }
function WriteError(T: TStreamable; out TypeName: ShortString): Boolean;
var
  M: TMemoryStream;
  Os: opstream;
begin
  Result := False;
  M := TMemoryStream.Create(0, 64);
  Os := opstream.Create(M);
  try
    Os.WritePointer(T);
  except
    on E: EStreamableError do
    begin
      Result := (E.Kind = pstream.StreamableError.peNotRegistered);
      TypeName := E.TypeName;
    end;
  end;
  Os.Free;
  M.Free;
end;

procedure StreamErrors;
var
  M: TMemoryStream;
  Os: opstream;
  Pt: TPt;
  Kind: pstream.StreamableError;
  TypeName: ShortString;
  Msg: AnsiString;
  NS: TNSCollection;
  NSS: TIntNSColl;
begin
  { --- a stream that names a class that is not registered ----------------------------- }
  M := TMemoryStream.Create(0, 64);
  Os := opstream.Create(M);
  Pt := TPt.Create(1, 2);
  Os.WritePointer(Pt);
  Pt.Free;
  Os.Free;
  PChar(M.Data)[5] := 'x';                     { ptObject, '[', 3, 'TPt' -> 'TPx' }
  Check(ReadError(M, Kind, TypeName, Msg) and (Kind = pstream.StreamableError.peNotRegistered) and
    (TypeName = 'TPx') and (Pos('''TPx''', Msg) > 0), 'reading a class that is not registered raises EStreamableError');
  PByte(M.Data)[0] := 7;                       { no kind of pointer }
  Check(ReadError(M, Kind, TypeName, Msg) and (Kind = pstream.StreamableError.peInvalidType),
    'an unknown kind of pointer raises EStreamableError');
  M.Free;

  { --- writing an object of a class that is not registered ---------------------------- }
  Pt := TLost.Create(1, 2);
  Check(WriteError(Pt, TypeName) and (TypeName = 'TLost'), 'writing a class that is not registered raises EStreamableError');
  Pt.Free;
  NS := TNSCollection.Create(2, 2);
  Check(WriteError(NS, TypeName) and (TypeName = 'TNSCollection'), 'a TNSCollection is not streamable');
  NS.Free;

  { --- a sorted collection that is not streamable ------------------------------------- }
  NSS := TIntNSColl.Create(2, 2);
  NSS.Insert(Pointer(30));
  NSS.Insert(Pointer(10));
  NSS.Insert(Pointer(20));
  NSS.Insert(Pointer(10));
  Check((NSS.Count = 3) and (NSS.At(0) = Pointer(10)) and (NSS.At(2) = Pointer(30)) and (NSS.IndexOf(Pointer(20)) = 1),
    'TNSSortedCollection keeps its order and drops duplicates');
  NSS.Free;
end;

function StringCollThroughStream(SC: TStringCollection): TStringCollection;
var
  M: TMemoryStream;
  Os: opstream;
  Ip: ipstream;
begin
  { through a stream }
  M := TMemoryStream.Create(0, 64);
  Os := opstream.Create(M);
  Os.WritePointer(SC);
  Os.Free;
  SC.Free;
  M.Seek(0);
  Ip := ipstream.Create(M);
  Result := TStringCollection(Ip.ReadPointer);
  Ip.Free;
  M.Free;
  Check((Result.Count = 3) and (PStr(Result.At(2))^ = 'pear') and (PStr(Result.At(0))^ = 'apple'), 'a string collection through a stream');
end;

begin
  Used0 := GetFPCHeapStatus.CurrHeapUsed;

  { --- Free (DN): a call on nil does nothing, a call on an instance disposes it ----- }
  FreeObj := nil;
  FreeObj.Free;
  Check(True, 'Free on nil does nothing');
  FreeObj := TStreamable.Create;
  FreeObj.Free;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'Free disposes the instance');

  { --- registration by name ---------------------------------------------------- }
  RPt := TStreamableClass.Create('TPt', @TPt.Build);
  RPtColl := TStreamableClass.Create('TPtColl', @TPtColl.Build);
  { a warm-up: the RTL allocates some state at the first conversion of a string and the first output }
  M := TMemoryStream.Create(0, 64);
  Os := opstream.Create(M);
  Os.WriteString('Привет');
  Os.Free;
  M.Free;
  Check(True, 'the classes are registered');
  Used0 := GetFPCHeapStatus.CurrHeapUsed;      { the classes stay registered }

  StreamSections;

  { --- collections ----------------------------------------------------------------------- }
  C := TSafeColl.Create(2, 2);
  Check((C.Count = 0) and (C.Limit = 2) and (C.Delta = 2), 'a new collection');
  C.Insert(Pointer(10));
  C.Insert(Pointer(20));
  C.Insert(Pointer(30));
  Check((C.Count = 3) and (C.Limit = 4), 'the limit grows by Delta');
  C.AtInsert(1, Pointer(15));
  Check((C.At(1) = Pointer(15)) and (C.At(2) = Pointer(20)) and (C.Count = 4), 'AtInsert');
  Check(C.IndexOf(Pointer(30)) = 4 - 1, 'IndexOf');
  Check(C.IndexOf(Pointer(77)) = -1, 'IndexOf: not there');
  C.AtPut(0, Pointer(11));
  Check(C.At(0) = Pointer(11), 'AtPut');
  C.AtReplace(0, Pointer(12));
  Check(C.At(0) = Pointer(12), 'AtReplace replaces an item');
  C2 := TSafeColl.Create(2, 2);
  C2.AtReplace(3, Pointer(33));
  Check((C2.Count = 4) and (C2.At(3) = Pointer(33)) and (C2.At(1) = nil), 'AtReplace grows the collection with nils');
  C2.Free;
  C.Remove(Pointer(15));
  Check((C.Count = 3) and (C.At(1) = Pointer(20)), 'Delete');
  C.AtRemove(0);
  Check((C.Count = 2) and (C.At(0) = Pointer(20)), 'AtDelete');
  C.Insert(Pointer(60));
  C.Insert(Pointer(70));
  Check(C.FirstThat(@IsBig) = Pointer(60), 'FirstThat');
  Check(C.LastThat(@IsBig) = Pointer(70), 'LastThat');
  Check(C.FirstThat(@IsBig) <> nil, 'FirstThat finds something');
  Sum := 0;
  C.ForEach(@AddTo);
  Check(Sum = 20 + 30 + 60 + 70, 'ForEach');
  NestedCheck(C);
  C.AtPut(1, nil);
  C.Pack;
  Check((C.Count = 3) and (C.At(1) = Pointer(60)), 'Pack removes the nil items');
  C.At(10);
  Check((C.Errors = 1) and (C.LastCode = coIndexError) and (C.LastInfo = 10), 'At: index error');
  C.AtInsert(99, Pointer(1));
  Check(C.Errors = 2, 'AtInsert: index error');
  C.RemoveAll;
  Check(C.Count = 0, 'DeleteAll');
  C.Free;
  { a collection that cannot grow }
  C := TSafeColl.Create(1, 0);
  C.Insert(Pointer(1));
  C.Insert(Pointer(2));
  Check((C.Errors = 1) and (C.LastCode = coOverflow) and (C.Count = 1), 'a full collection with Delta 0: coOverflow');
  C.Free;

  { instances in a collection are freed by FreeAll and Destroy }
  PC := TCollection.Create(2, 2);
  for I := 1 to 5 do
  begin
    Pt := TPt.Create(I, I);
    PC.Insert(Pt);
  end;
  PC.AtFree(0);
  Check(PC.Count = 4, 'AtFree');
  PC.Free(PC.At(0));
  Check(PC.Count = 3, 'Free');
  PC.Free;

  { sorted }
  IC := TIntColl.Create(4, 4);
  IC.Insert(Pointer(30));
  IC.Insert(Pointer(10));
  IC.Insert(Pointer(20));
  IC.Insert(Pointer(20));
  Check((IC.Count = 3) and (IC.At(0) = Pointer(10)) and (IC.At(1) = Pointer(20)) and (IC.At(2) = Pointer(30)),
    'a sorted collection keeps its order and drops duplicates');
  Check(IC.IndexOf(Pointer(30)) = 2, 'sorted IndexOf');
  Check(IC.IndexOf(Pointer(25)) = -1, 'sorted IndexOf: not there');
  Check((not IC.Search(Pointer(25), I)) and (I = 2), 'Search: where it would go');
  Check(IC.Search(Pointer(10), I) and (I = 0), 'Search: found');
  IC.Duplicates := True;
  IC.Insert(Pointer(20));
  Check((IC.Count = 4) and (IC.At(1) = Pointer(20)) and (IC.At(2) = Pointer(20)), 'with Duplicates: both stay');
  IC.Free;

  { strings }
  SC := TStringCollection.Create(4, 4);
  P := NewStr('pear'); SC.Insert(P);
  P := NewStr('apple'); SC.Insert(P);
  P := NewStr('fig'); SC.Insert(P);
  P := NewStr('apple');
  if SC.Search(P, I) then DisposeStr(P) else SC.Insert(P);   { the collection takes what it keeps }
  Check(SC.Count = 3, 'duplicates are dropped');
  Check((PStr(SC.At(0))^ = 'apple') and (PStr(SC.At(1))^ = 'fig') and (PStr(SC.At(2))^ = 'pear'), 'sorted strings');
  P := NewStr('fig');
  Check((SC.IndexOf(P) = 1), 'IndexOf compares the contents');
  DisposeStr(P);
  SC := StringCollThroughStream(SC);
  SC.Free;

  StreamErrors;

  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
