{ TvObjs: the base class, streams (file, buffered file, memory) and collections of the
  Pascal Turbo Vision API (TStreamable, TStream, TDosStream, TBufStream, TMemoryStream,
  TCollection, TSortedCollection, TStringCollection) with the registry of streamable types.

  The interface (names, fields and the behavior of the methods) is
  the one that Pascal programs written for Turbo Vision use; the implementation is new,
  written from that behavior and with the collection semantics of magiblot/tvision
  (TNSCollection) in mind, not from any Borland or Free Pascal source.

  Differences from the Pascal Turbo Vision (see tv/DESIGN.md):
    - sizes and counts are 32-bit (Longint, Integer);
    - a streamable type is registered with a TStreamRec whose Load is a function that
      makes and loads an instance and whose Store is a procedure that stores one, instead
      of pointers to the constructor and to the method (calling a constructor through a
      pointer is not portable between the FPC targets); VmtLink holds the address of the
      VMT: PtrUInt(TypeOf(TFoo));
    - registering a type number twice is ignored. }
unit TvObjs;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvUtil;

const
  { Status of a stream: stOk, or the kind of the first failure (negative) }
  stPutError = -6; stGetError = -5;        { unregistered type in Put / Get }
  stWriteError = -4; stReadError = -3; stInitError = -2;
  stError = -1;                            { a generic failure }
  stOk = 0;

  { stream access modes }
  stCreate     = $3C00;
  stOpenRead   = $3D00;
  stOpenWrite  = $3D01;
  stOpen       = $3D02;

  { collection error codes }
  coIndexError = -1;
  coOverflow   = -2;

  MaxCollectionSize = MaxInt div SizeOf(Pointer);

type
  PStreamRec = ^TStreamRec;

  { Every class participating in the stream registry descends from TStreamable. }
  TStreamable = class
  end;

  TStream = class
    Status: Integer;
    ErrorInfo: Integer;
    procedure CopyFrom(S: TStream; Count: Int64);
    procedure Error(Code, Info: Integer); virtual;
    procedure Flush; virtual;
    function Get: TStreamable;
    function GetPos: Int64; virtual;
    function GetSize: Int64; virtual;
    procedure Put(P: TStreamable);
    procedure Read(var Buf; Count: Longint); virtual;
    function ReadStr: PStr;
    { Extensions of DN (the strings of more than 255 characters, zero-terminated strings, the end of the stream):
      long strings are a LongInt length and the characters, zero-terminated ones a Word length and the characters. }
    procedure ReadStrV(var S: ShortString);
    function ReadLongStr: PAnsiString;
    procedure ReadLongStrV(var S: AnsiString);
    procedure WriteLongStr(P: PAnsiString);
    function StrRead: PChar;
    procedure StrWrite(P: PChar);
    function Eof: Boolean;
    procedure Reset;
    procedure Seek(Pos: Int64); virtual;
    procedure Truncate; virtual;
    procedure Write(const Buf; Count: Longint); virtual;
    procedure WriteStr(P: PStr);
  end;

  TDosStream = class(TStream)
    Handle: THandle;
    FName: string;
    { used by DN: the position that the stream keeps itself and the size of the file (a viewer of a growing file reads
      the size again with SysFileSeek(Handle, 0, 2, StreamSize)) }
    Position, StreamSize: LongInt;
    constructor Create(const FileName: string; Mode: Word);
    destructor Destroy; override;
    { Open takes the name and the mode (Create does it); DoOpen opens the file; Close closes it (Open may follow). }
    procedure Open(const FileName: string; Mode: Word);
    procedure DoOpen(OpenMode: Word); virtual;
    procedure Close; virtual;
    procedure ReadBlock(var Buf; Count: Longint; var BytesRead: Word);
    function GetPos: Int64; override;
    function GetSize: Int64; override;
    procedure Read(var Buf; Count: Longint); override;
    procedure Seek(Pos: Int64); override;
    procedure Truncate; override;
    procedure Write(const Buf; Count: Longint); override;
  end;

  TBufStream = class(TDosStream)
    Buffer: PByte;
    BufSize: Longint;
    BufStart: Int64;       { file position of the first byte of the buffer }
    BufLen: Longint;       { valid bytes in the buffer }
    BufPos: Longint;       { current position in the buffer }
    Dirty: Boolean;        { the buffer has bytes not written yet }
    constructor Create(const FileName: string; Mode: Word; Size: Longint);
    destructor Destroy; override;
    procedure Close; override;
    procedure Flush; override;
    function GetPos: Int64; override;
    function GetSize: Int64; override;
    procedure Read(var Buf; Count: Longint); override;
    procedure Seek(Pos: Int64); override;
    procedure Truncate; override;
    procedure Write(const Buf; Count: Longint); override;
  private
    procedure FlushBuffer;
    procedure FillBuffer;
  end;

  TMemoryStream = class(TStream)
    Data: PByte;
    Size: Longint;
    Position: Longint;
    Capacity: Longint;
    BlockSize: Longint;
    constructor Create(ALimit: Longint; ABlockSize: Longint);
    destructor Destroy; override;
    function GetPos: Int64; override;
    function GetSize: Int64; override;
    procedure Read(var Buf; Count: Longint); override;
    procedure Seek(Pos: Int64); override;
    procedure Truncate; override;
    procedure Write(const Buf; Count: Longint); override;
  end;


  TLoadProc = function(S: TStream): TStreamable;
  TStoreProc = procedure(P: TStreamable; S: TStream);

  TStreamRec = record
    ObjType: Word;
    VmtLink: PtrUInt;      { PtrUInt(TypeOf(TFoo)) }
    Load: TLoadProc;
    Store: TStoreProc;
    Next: PStreamRec;
  end;

  TItemList = array[0..MaxCollectionSize - 1] of Pointer;
  PItemList = ^TItemList;

  { Routines declared inside another routine (Turbo Pascal lets one pass them as @Name to FirstThat, LastThat
    and ForEach) are procedure variables of the nested kind: a program that does that is compiled with
    {$modeswitch nestedprocvars} (tvdefs.inc has it); a plain function is accepted too. }
  TNestedTestProc = function(Item: Pointer): Boolean is nested;
  TNestedActionProc = procedure(Item: Pointer) is nested;

  TCollection = class(TStreamable)
    Items: PItemList;
    Count: Integer;
    Limit: Integer;
    Delta: Integer;
    constructor Create(ALimit, ADelta: Integer);
    constructor Load(S: TStream);
    destructor Destroy; override;
    function At(Index: Integer): Pointer;
    procedure AtDelete(Index: Integer);
    procedure AtFree(Index: Integer);
    procedure AtInsert(Index: Integer; Item: Pointer);
    procedure AtPut(Index: Integer; Item: Pointer);
    { used by DN: AtPut that grows the collection with nils up to Index and frees the item that was there }
    procedure AtReplace(Index: Integer; Item: Pointer);
    procedure Delete(Item: Pointer);
    procedure DeleteAll;
    procedure Error(Code, Info: Integer); virtual;
    function FirstThat(Test: TNestedTestProc): Pointer;
    procedure ForEach(Action: TNestedActionProc);
    procedure Free; reintroduce; overload;
    procedure Free(Item: Pointer); overload;
    procedure FreeAll;
    procedure FreeItem(Item: Pointer); virtual;
    function GetItem(S: TStream): Pointer; virtual;
    function IndexOf(Item: Pointer): Integer; virtual;
    procedure Insert(Item: Pointer); virtual;
    function LastThat(Test: TNestedTestProc): Pointer;
    procedure Pack;
    procedure PutItem(S: TStream; Item: Pointer); virtual;
    procedure SetLimit(ALimit: Integer); virtual;
    procedure Store(S: TStream); virtual;
  end;

  { Test: function(Item: Pointer): Boolean; Action: procedure(Item: Pointer): the
    functions are ordinary (not methods); Test and Action are passed as pointers. }
  TCollTestProc = function(Item: Pointer): Boolean;
  TCollActionProc = procedure(Item: Pointer);

  TSortedCollection = class(TCollection)
    Duplicates: Boolean;
    constructor Create(ALimit, ADelta: Integer);
    constructor Load(S: TStream);
    function Compare(Key1, Key2: Pointer): Integer; virtual;
    function IndexOf(Item: Pointer): Integer; override;
    procedure Insert(Item: Pointer); override;
    function KeyOf(Item: Pointer): Pointer; virtual;
    function Search(Key: Pointer; var Index: Integer): Boolean; virtual;
    procedure Store(S: TStream); override;
  end;

  { the items are pointers to ShortStrings (PStr) }
  TStringCollection = class(TSortedCollection)
    function Compare(Key1, Key2: Pointer): Integer; override;
    procedure FreeItem(Item: Pointer); override;
    function GetItem(S: TStream): Pointer; override;
    procedure PutItem(S: TStream; Item: Pointer); override;
  end;


procedure RegisterType(var S: TStreamRec);
{ DN: registers the record in place of the one that is registered for the same type number (RegisterType keeps the first). }
procedure ReRegisterType(var S: TStreamRec);
{ The record registered for a type number, nil if none. }
function FindStreamRec(ObjType: Word): PStreamRec;

type
  { the name of a file of the program into the name that the system takes (DN: DOS names on Unix) }
  TFileNameHook = function(const Name: string): string;

var
  { stream records of the collections: RegisterType(RCollection) (TCollection), RStringCollection }
  RCollection, RStringCollection: TStreamRec;
  { when set, TDosStream passes the names of its files through it }
  OnFileName: TFileNameHook = nil;

implementation

{ --- registry ---------------------------------------------------------------- }

var
  Registry: PStreamRec = nil;

function FindStreamRec(ObjType: Word): PStreamRec;
begin
  Result := Registry;
  while (Result <> nil) and (Result^.ObjType <> ObjType) do
    Result := Result^.Next;
end;

function FindByVmt(Vmt: PtrUInt): PStreamRec;
begin
  Result := Registry;
  while (Result <> nil) and (Result^.VmtLink <> Vmt) do
    Result := Result^.Next;
end;

procedure RegisterType(var S: TStreamRec);
var
  Link: ^PStreamRec;
begin
  { a class is registered once; another class with a number that is taken can still be written (Put finds it by its
    class), while Get keeps reading that number as the class registered first }
  if FindByVmt(S.VmtLink) <> nil then
    Exit;
  Link := @Registry;
  while Link^ <> nil do
    Link := @Link^^.Next;
  S.Next := nil;
  Link^ := @S;
end;

procedure ReRegisterType(var S: TStreamRec);
var
  Link: ^PStreamRec;
begin
  Link := @Registry;
  while Link^ <> nil do
  begin
    if Link^^.ObjType = S.ObjType then
    begin
      if Link^ <> @S then
      begin
        S.Next := Link^^.Next;
        Link^ := @S;
      end;
      Exit;
    end;
    Link := @Link^^.Next;
  end;
  S.Next := Registry;
  Registry := @S;
end;

{ --- TStream ----------------------------------------------------------------- }

procedure TStream.Error(Code, Info: Integer);
begin
  Status := Code;
  ErrorInfo := Info;
end;

procedure TStream.Flush;
begin
end;

function TStream.GetPos: Int64;
begin
  Error(stError, 0);
  Result := -1;
end;

function TStream.GetSize: Int64;
begin
  Error(stError, 0);
  Result := -1;
end;

procedure TStream.Read(var Buf; Count: Longint);
begin
  Error(stError, 0);
end;

procedure TStream.Seek(Pos: Int64);
begin
  Error(stError, 0);
end;

procedure TStream.Truncate;
begin
  Error(stError, 0);
end;

procedure TStream.Write(const Buf; Count: Longint);
begin
  Error(stError, 0);
end;

procedure TStream.Reset;
begin
  Status := stOk;
  ErrorInfo := 0;
end;

procedure TStream.CopyFrom(S: TStream; Count: Int64);
var
  Buf: array[0..4095] of Byte;
  N: Longint;
begin
  while (Count > 0) and (Status = stOk) and (S.Status = stOk) do
  begin
    N := Count;
    if N > SizeOf(Buf) then
      N := SizeOf(Buf);
    S.Read(Buf, N);
    if S.Status = stOk then
      Write(Buf, N);
    Dec(Count, N);
  end;
end;

function TStream.ReadStr: PStr;
var
  L: Byte;
  S: ShortString;
begin
  Result := nil;
  Read(L, 1);
  if (Status <> stOk) or (L = 0) then
    Exit;
  S[0] := Chr(L);
  Read(S[1], L);
  if Status = stOk then
    Result := NewStr(S);
end;

procedure TStream.ReadStrV(var S: ShortString);
var
  L: Byte;
begin
  S := '';
  Read(L, 1);
  if (Status <> stOk) or (L = 0) then
    Exit;
  SetLength(S, L);
  Read(S[1], L);
  if Status <> stOk then
    S := '';
end;

function TStream.ReadLongStr: PAnsiString;
var
  S: AnsiString;
begin
  Result := nil;
  ReadLongStrV(S);
  if Status = stOk then
  begin
    New(Result);
    Result^ := S;
  end;
end;

procedure TStream.ReadLongStrV(var S: AnsiString);
var
  L: Longint;
begin
  S := '';
  Read(L, SizeOf(L));
  if (Status <> stOk) or (L <= 0) then
    Exit;
  SetLength(S, L);
  Read(S[1], L);
  if Status <> stOk then
    S := '';
end;

procedure TStream.WriteLongStr(P: PAnsiString);
var
  L: Longint;
begin
  if P = nil then
    L := 0
  else
    L := Length(P^);
  Write(L, SizeOf(L));
  if L > 0 then
    Write(P^[1], L);
end;

function TStream.StrRead: PChar;
var
  L: Word;
begin
  Result := nil;
  Read(L, SizeOf(L));
  if (Status <> stOk) or (L = 0) then
    Exit;
  Result := StrAlloc(L + 1);
  Read(Result^, L);
  Result[L] := #0;
  if Status <> stOk then
  begin
    StrDispose(Result);
    Result := nil;
  end;
end;

procedure TStream.StrWrite(P: PChar);
var
  Len: Word;
begin
  Len := 0;
  if P <> nil then
    Len := StrLen(P);
  Write(Len, SizeOf(Len));
  if Len <> 0 then
    Write(P^, Len);
end;

function TStream.Eof: Boolean;
begin
  Result := GetPos >= GetSize;
end;

procedure TStream.WriteStr(P: PStr);
var
  L: Byte;
begin
  if P = nil then
    L := 0
  else
    L := Length(P^);
  Write(L, 1);
  if L > 0 then
    Write(P^[1], L);
end;

function TStream.Get: TStreamable;
var
  Id: Word;
  R: PStreamRec;
begin
  Result := nil;
  Read(Id, SizeOf(Id));
  if (Status <> stOk) or (Id = 0) then
    Exit;
  R := FindStreamRec(Id);
  if (R = nil) or not Assigned(R^.Load) then
  begin
    Error(stGetError, Id);
    Exit;
  end;
  Result := R^.Load(Self);
end;

procedure TStream.Put(P: TStreamable);
var
  Id: Word;
  R: PStreamRec;
begin
  if P = nil then
  begin
    Id := 0;
    Write(Id, SizeOf(Id));
    Exit;
  end;
  R := FindByVmt(PtrUInt(PPointer(P)^));
  if (R = nil) or not Assigned(R^.Store) then
  begin
    Error(stPutError, 0);
    Exit;
  end;
  Id := R^.ObjType;
  Write(Id, SizeOf(Id));
  R^.Store(P, Self);
end;

{ --- TDosStream -------------------------------------------------------------- }

constructor TDosStream.Create(const FileName: string; Mode: Word);
begin
  inherited Create;
  Handle := feInvalidHandle;
  Open(FileName, Mode);
end;

procedure TDosStream.Open(const FileName: string; Mode: Word);
begin
  FName := FileName;
  if Assigned(OnFileName) then
    FName := OnFileName(FileName);
  DoOpen(Mode);
end;

procedure TDosStream.DoOpen(OpenMode: Word);
begin
  case OpenMode of
    stCreate: Handle := FileCreate(FName);
    stOpenRead: Handle := FileOpen(FName, fmOpenRead or fmShareDenyNone);
    stOpenWrite: Handle := FileOpen(FName, fmOpenWrite or fmShareDenyNone);
  else
    Handle := FileOpen(FName, fmOpenReadWrite or fmShareDenyNone);
  end;
  if Handle = feInvalidHandle then
    Error(stInitError, 2)
  else
  begin
    Position := 0;
    StreamSize := FileSeek(Handle, 0, 2);
    FileSeek(Handle, 0, 0);
  end;
end;

procedure TDosStream.Close;
begin
  if Handle <> feInvalidHandle then
    FileClose(Handle);
  Handle := feInvalidHandle;
end;

procedure TDosStream.ReadBlock(var Buf; Count: Longint; var BytesRead: Word);
begin
  if Status <> stOk then
  begin
    BytesRead := 0;
    Exit;
  end;
  BytesRead := FileRead(Handle, Buf, Count);
end;

destructor TDosStream.Destroy;
begin
  if Handle <> feInvalidHandle then
    FileClose(Handle);
  Handle := feInvalidHandle;
  inherited Destroy;
end;

function TDosStream.GetPos: Int64;
begin
  if Status <> stOk then
    Exit(-1);
  Result := FileSeek(Handle, 0, 1);
end;

function TDosStream.GetSize: Int64;
var
  P: Int64;
begin
  if Status <> stOk then
    Exit(-1);
  P := FileSeek(Handle, 0, 1);
  Result := FileSeek(Handle, 0, 2);
  FileSeek(Handle, P, 0);
end;

procedure TDosStream.Read(var Buf; Count: Longint);
var
  N: Longint;
begin
  if Status <> stOk then
  begin
    FillChar(Buf, Count, 0);
    Exit;
  end;
  N := FileRead(Handle, Buf, Count);
  if N > 0 then
    Inc(Position, N);
  if N <> Count then
  begin
    if N < 0 then
      N := 0;
    FillChar((PByte(@Buf) + N)^, Count - N, 0);
    Error(stReadError, 0);
  end;
end;

procedure TDosStream.Seek(Pos: Int64);
begin
  if Status <> stOk then
    Exit;
  if Pos < 0 then
    Pos := 0;
  FileSeek(Handle, Pos, 0);
  Position := Pos;
end;

procedure TDosStream.Truncate;
begin
  if Status <> stOk then
    Exit;
  if not FileTruncate(Handle, FileSeek(Handle, 0, 1)) then
    Error(stError, 0)
  else
    StreamSize := Position;
end;

procedure TDosStream.Write(const Buf; Count: Longint);
begin
  if Status <> stOk then
    Exit;
  if FileWrite(Handle, Buf, Count) <> Count then
    Error(stWriteError, 0)
  else
  begin
    Inc(Position, Count);
    if Position > StreamSize then
      StreamSize := Position;
  end;
end;

{ --- TBufStream -------------------------------------------------------------- }

constructor TBufStream.Create(const FileName: string; Mode: Word; Size: Longint);
begin
  inherited Create(FileName, Mode);
  if Size < 16 then
    Size := 16;
  BufSize := Size;
  GetMem(Buffer, BufSize);
  BufStart := 0;
  BufLen := 0;
  BufPos := 0;
  Dirty := False;
end;

destructor TBufStream.Destroy;
begin
  if (Handle <> feInvalidHandle) and (Status = stOk) then
    Flush;
  if Buffer <> nil then
    FreeMem(Buffer);
  Buffer := nil;
  inherited Destroy;
end;

procedure TBufStream.FlushBuffer;
begin
  if Dirty and (BufLen > 0) then
  begin
    FileSeek(Handle, BufStart, 0);
    if FileWrite(Handle, Buffer^, BufLen) <> BufLen then
      Error(stWriteError, 0);
  end;
  Dirty := False;
end;

procedure TBufStream.FillBuffer;
var
  N: Longint;
begin
  { the buffer starts at the current position }
  BufStart := BufStart + BufPos;
  BufPos := 0;
  FileSeek(Handle, BufStart, 0);
  N := FileRead(Handle, Buffer^, BufSize);
  if N < 0 then
    N := 0;
  BufLen := N;
end;

procedure TBufStream.Flush;
begin
  if Status <> stOk then
    Exit;
  FlushBuffer;
end;

procedure TBufStream.Close;
begin
  Flush;
  inherited Close;
end;

function TBufStream.GetPos: Int64;
begin
  if Status <> stOk then
    Exit(-1);
  Result := BufStart + BufPos;
end;

function TBufStream.GetSize: Int64;
var
  P: Int64;
begin
  if Status <> stOk then
    Exit(-1);
  FlushBuffer;
  P := FileSeek(Handle, 0, 1);
  Result := FileSeek(Handle, 0, 2);
  FileSeek(Handle, P, 0);
end;

procedure TBufStream.Read(var Buf; Count: Longint);
var
  Dest: PByte;
  N: Longint;
begin
  if Status <> stOk then
  begin
    FillChar(Buf, Count, 0);
    Exit;
  end;
  Dest := @Buf;
  while Count > 0 do
  begin
    if BufPos >= BufLen then
    begin
      FlushBuffer;
      FillBuffer;
      if BufLen = 0 then
      begin
        FillChar(Dest^, Count, 0);
        Error(stReadError, 0);
        Exit;
      end;
    end;
    N := BufLen - BufPos;
    if N > Count then
      N := Count;
    Move((Buffer + BufPos)^, Dest^, N);
    Inc(BufPos, N);
    Inc(Dest, N);
    Dec(Count, N);
  end;
end;

procedure TBufStream.Seek(Pos: Int64);
begin
  if Status <> stOk then
    Exit;
  if Pos < 0 then
    Pos := 0;
  if (Pos >= BufStart) and (Pos <= BufStart + BufLen) then
    BufPos := Pos - BufStart
  else
  begin
    FlushBuffer;
    BufStart := Pos;
    BufPos := 0;
    BufLen := 0;
  end;
end;

procedure TBufStream.Truncate;
begin
  if Status <> stOk then
    Exit;
  FlushBuffer;
  if not FileTruncate(Handle, BufStart + BufPos) then
    Error(stError, 0);
  BufLen := BufPos;
end;

procedure TBufStream.Write(const Buf; Count: Longint);
var
  Src: PByte;
  N: Longint;
begin
  if Status <> stOk then
    Exit;
  Src := @Buf;
  while Count > 0 do
  begin
    if BufPos >= BufSize then
    begin
      { the buffer is full: write it and go on with the next window }
      FlushBuffer;
      Inc(BufStart, BufPos);
      BufPos := 0;
      BufLen := 0;
    end;
    if BufLen = 0 then
    begin
      { an empty window: it may cover bytes that are in the file already }
      FileSeek(Handle, BufStart, 0);
      N := FileRead(Handle, Buffer^, BufSize);
      if N < 0 then
        N := 0;
      BufLen := N;
    end;
    N := BufSize - BufPos;
    if N > Count then
      N := Count;
    Move(Src^, (Buffer + BufPos)^, N);
    Inc(BufPos, N);
    if BufPos > BufLen then
      BufLen := BufPos;
    Dirty := True;
    Inc(Src, N);
    Dec(Count, N);
  end;
end;

{ --- TMemoryStream ----------------------------------------------------------- }

constructor TMemoryStream.Create(ALimit: Longint; ABlockSize: Longint);
begin
  inherited Create;
  if ABlockSize < 1 then
    ABlockSize := 4096;
  BlockSize := ABlockSize;
  Data := nil;
  Size := 0;
  Position := 0;
  Capacity := 0;
  if ALimit > 0 then
  begin
    Capacity := ((ALimit + BlockSize - 1) div BlockSize) * BlockSize;
    GetMem(Data, Capacity);
  end;
end;

destructor TMemoryStream.Destroy;
begin
  if Data <> nil then
    FreeMem(Data);
  Data := nil;
  inherited Destroy;
end;

function TMemoryStream.GetPos: Int64;
begin
  if Status <> stOk then
    Exit(-1);
  Result := Position;
end;

function TMemoryStream.GetSize: Int64;
begin
  if Status <> stOk then
    Exit(-1);
  Result := Size;
end;

procedure TMemoryStream.Read(var Buf; Count: Longint);
var
  N: Longint;
begin
  if Status <> stOk then
  begin
    FillChar(Buf, Count, 0);
    Exit;
  end;
  N := Size - Position;
  if N < 0 then
    N := 0;
  if N >= Count then
  begin
    Move((Data + Position)^, Buf, Count);
    Inc(Position, Count);
  end
  else
  begin
    if N > 0 then
      Move((Data + Position)^, Buf, N);
    FillChar((PByte(@Buf) + N)^, Count - N, 0);
    Position := Size;
    Error(stReadError, 0);
  end;
end;

procedure TMemoryStream.Seek(Pos: Int64);
begin
  if Status <> stOk then
    Exit;
  if Pos < 0 then
    Pos := 0;
  Position := Pos;
end;

procedure TMemoryStream.Truncate;
begin
  if Status <> stOk then
    Exit;
  if Position < Size then
    Size := Position;
end;

procedure TMemoryStream.Write(const Buf; Count: Longint);
var
  NewCap: Longint;
begin
  if Status <> stOk then
    Exit;
  if Position + Count > Capacity then
  begin
    NewCap := ((Position + Count + BlockSize - 1) div BlockSize) * BlockSize;
    ReallocMem(Data, NewCap);
    Capacity := NewCap;
  end;
  { writing beyond the end leaves a gap of zeros }
  if Position > Size then
    FillChar((Data + Size)^, Position - Size, 0);
  Move(Buf, (Data + Position)^, Count);
  Inc(Position, Count);
  if Position > Size then
    Size := Position;
end;

{ --- TCollection ------------------------------------------------------------- }

constructor TCollection.Create(ALimit, ADelta: Integer);
begin
  inherited Create;
  { the fields start at zero (nil items, no count, no limit) }
  Delta := ADelta;
  SetLimit(ALimit);
end;

constructor TCollection.Load(S: TStream);
var
  N, L, D, K: Integer;
begin
  inherited Create;
  S.Read(N, SizeOf(Integer));
  S.Read(L, SizeOf(Integer));
  S.Read(D, SizeOf(Integer));
  Items := nil;
  Count := 0;
  Limit := 0;
  Delta := D;
  if L < N then
    L := N;
  SetLimit(L);
  for K := 1 to N do
  begin
    if S.Status <> stOk then
      Break;
    AtInsert(Count, GetItem(S));
  end;
end;

destructor TCollection.Destroy;
begin
  FreeAll;
  SetLimit(0);
  inherited Destroy;
end;

function TCollection.At(Index: Integer): Pointer;
begin
  if (Index < 0) or (Index >= Count) then
  begin
    Error(coIndexError, Index);
    Result := nil;
  end
  else
    Result := Items^[Index];
end;

procedure TCollection.AtDelete(Index: Integer);
var
  K: Integer;
begin
  if (Index < 0) or (Index >= Count) then
  begin
    Error(coIndexError, Index);
    Exit;
  end;
  { close the gap }
  for K := Index + 1 to Count - 1 do
    Items^[K - 1] := Items^[K];
  Dec(Count);
end;

procedure TCollection.AtFree(Index: Integer);
var
  Victim: Pointer;
begin
  if (Index < 0) or (Index >= Count) then
  begin
    Error(coIndexError, Index);
    Exit;
  end;
  Victim := Items^[Index];
  AtDelete(Index);
  FreeItem(Victim);
end;

procedure TCollection.AtInsert(Index: Integer; Item: Pointer);
begin
  if (Index < 0) or (Index > Count) then
    Error(coIndexError, Index)
  else
  begin
    if Count = Limit then
      SetLimit(Count + Delta);
    if Count = Limit then
    begin
      Error(coOverflow, Index);
      Exit;
    end;
    if Index < Count then
      Move(Items^[Index], Items^[Index + 1], (Count - Index) * SizeOf(Pointer));
    Items^[Index] := Item;
    Inc(Count);
  end;
end;

procedure TCollection.AtReplace(Index: Integer; Item: Pointer);
var
  Old: Pointer;
begin
  if Index < 0 then
  begin
    Error(coIndexError, Index);
    Exit;
  end;
  if Index >= Limit then
    SetLimit(Index + 1);
  if Index >= Limit then
  begin
    Error(coOverflow, Index);
    Exit;
  end;
  if Index >= Count then
  begin
    FillChar(Items^[Count], (Index + 1 - Count) * SizeOf(Pointer), 0);
    Count := Index + 1;
  end;
  Old := Items^[Index];
  Items^[Index] := Item;
  if (Old <> nil) and (Old <> Item) then
    FreeItem(Old);
end;

procedure TCollection.AtPut(Index: Integer; Item: Pointer);
begin
  if (Index < 0) or (Index >= Count) then
    Error(coIndexError, Index)
  else
    Items^[Index] := Item;
end;

procedure TCollection.Delete(Item: Pointer);
begin
  AtDelete(IndexOf(Item));
end;

procedure TCollection.DeleteAll;
begin
  Count := 0;
end;

procedure TCollection.Error(Code, Info: Integer);
begin
  RunError(212 - Code);
end;

function TCollection.FirstThat(Test: TNestedTestProc): Pointer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Test(Items^[I]) then
      Exit(Items^[I]);
  Result := nil;
end;

procedure TCollection.ForEach(Action: TNestedActionProc);
var
  I: Integer;
begin
  I := 0;
  while I < Count do
  begin
    Action(Items^[I]);
    Inc(I);
  end;
end;

function TCollection.LastThat(Test: TNestedTestProc): Pointer;
var
  I: Integer;
begin
  for I := Count - 1 downto 0 do
    if Test(Items^[I]) then
      Exit(Items^[I]);
  Result := nil;
end;

procedure TCollection.Free;
begin
  inherited Free;
end;

procedure TCollection.Free(Item: Pointer);
begin
  Delete(Item);
  FreeItem(Item);
end;

procedure TCollection.FreeAll;
var
  I: Integer;
begin
  for I := Count - 1 downto 0 do
    FreeItem(Items^[I]);
  Count := 0;
end;

procedure TCollection.FreeItem(Item: Pointer);
begin
  if Item <> nil then
    TStreamable(Item).Free;
end;

function TCollection.GetItem(S: TStream): Pointer;
begin
  Result := S.Get;
end;

function TCollection.IndexOf(Item: Pointer): Integer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Items^[I] = Item then
      Exit(I);
  Result := -1;
end;

procedure TCollection.Insert(Item: Pointer);
begin
  AtInsert(Count, Item);
end;

procedure TCollection.Pack;
var
  I, J: Integer;
begin
  J := 0;
  for I := 0 to Count - 1 do
    if Items^[I] <> nil then
    begin
      Items^[J] := Items^[I];
      Inc(J);
    end;
  Count := J;
end;

procedure TCollection.PutItem(S: TStream; Item: Pointer);
begin
  S.Put(TStreamable(Item));
end;

procedure TCollection.SetLimit(ALimit: Integer);
begin
  if ALimit < Count then
    ALimit := Count;
  if ALimit > MaxCollectionSize then
    ALimit := MaxCollectionSize;
  if ALimit = Limit then
    Exit;
  ReallocMem(Items, PtrUInt(ALimit) * SizeOf(Pointer));
  Limit := ALimit;
end;

procedure TCollection.Store(S: TStream);
var
  I: Integer;
begin
  S.Write(Count, SizeOf(Integer));
  S.Write(Limit, SizeOf(Integer));
  S.Write(Delta, SizeOf(Integer));
  for I := 0 to Count - 1 do
    PutItem(S, At(I));
end;

{ --- TSortedCollection ------------------------------------------------------- }

constructor TSortedCollection.Create(ALimit, ADelta: Integer);
begin
  inherited Create(ALimit, ADelta);
  Duplicates := False;
end;

constructor TSortedCollection.Load(S: TStream);
begin
  inherited Load(S);
  S.Read(Duplicates, SizeOf(Boolean));
end;

function TSortedCollection.Compare(Key1, Key2: Pointer): Integer;
begin
  { abstract }
  RunError(211);
  Result := 0;
end;

function TSortedCollection.IndexOf(Item: Pointer): Integer;
var
  Key: Pointer;
  I: Integer;
begin
  Result := -1;
  Key := KeyOf(Item);
  if not Search(Key, I) then
    Exit;
  if not Duplicates then
    Exit(I);
  { among equal keys, look for this very item }
  while (I < Count) and (Compare(Key, KeyOf(Items^[I])) = 0) do
  begin
    if Items^[I] = Item then
      Exit(I);
    Inc(I);
  end;
end;

procedure TSortedCollection.Insert(Item: Pointer);
var
  Where: Integer;
begin
  if Search(KeyOf(Item), Where) and not Duplicates then
    Exit;
  AtInsert(Where, Item);
end;

function TSortedCollection.KeyOf(Item: Pointer): Pointer;
begin
  Result := Item;
end;

function TSortedCollection.Search(Key: Pointer; var Index: Integer): Boolean;
var
  Lo, Hi, Mid, C: Integer;
begin
  { lower bound: the first item whose key is not less than Key }
  Result := False;
  Lo := 0;
  Hi := Count;
  while Lo < Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    C := Compare(KeyOf(Items^[Mid]), Key);
    if C < 0 then
      Lo := Mid + 1
    else
    begin
      if C = 0 then
        Result := True;
      Hi := Mid;
    end;
  end;
  Index := Lo;
end;

procedure TSortedCollection.Store(S: TStream);
begin
  inherited Store(S);
  S.Write(Duplicates, SizeOf(Boolean));
end;

{ --- TStringCollection ------------------------------------------------------- }

function TStringCollection.Compare(Key1, Key2: Pointer): Integer;
begin
  if PStr(Key1)^ < PStr(Key2)^ then
    Result := -1
  else if PStr(Key1)^ > PStr(Key2)^ then
    Result := 1
  else
    Result := 0;
end;

procedure TStringCollection.FreeItem(Item: Pointer);
begin
  DisposeStr(PStr(Item));
end;

function TStringCollection.GetItem(S: TStream): Pointer;
begin
  Result := S.ReadStr;
end;

procedure TStringCollection.PutItem(S: TStream; Item: Pointer);
begin
  S.WriteStr(PStr(Item));
end;

function BuildCollection(S: TStream): TStreamable;
begin
  Result := TStreamable(Pointer(TCollection.Load(S)));
end;

procedure StoreCollection(P: TStreamable; S: TStream);
begin
  TCollection(Pointer(P)).Store(S);
end;

function BuildStringCollection(S: TStream): TStreamable;
begin
  Result := TStreamable(Pointer(TStringCollection.Load(S)));
end;

procedure StoreStringCollection(P: TStreamable; S: TStream);
begin
  TStringCollection(Pointer(P)).Store(S);
end;


initialization
  RCollection.ObjType := 50;
  RCollection.VmtLink := PtrUInt(System.TClass(TCollection));
  RCollection.Load := @BuildCollection;
  RCollection.Store := @StoreCollection;
  RStringCollection.ObjType := 51;
  RStringCollection.VmtLink := PtrUInt(System.TClass(TStringCollection));
  RStringCollection.Load := @BuildStringCollection;
  RStringCollection.Store := @StoreStringCollection;

end.
