{ TvObjs: the base class of the streamable objects, the object streams and the collections:
  TStreamable, TStreamableClass, TStreamableTypes, TPWrittenObjects, TPReadObjects, pstream,
  ipstream, opstream, iopstream, fpbase, ifpstream, ofpstream, fpstream; TCollection,
  TSortedCollection, TStringCollection.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/tobjstrm.h, objects.h (the streams, the stream members of the collections)
    source/tvision/tobjstrm.cpp, tcollect.cpp, tsortcol.cpp, tstrcoll.cpp (read, write, build),
    nmcollct.cpp, nmscoll.cpp, nmstrcol.cpp, sstrcoll.cpp (names and registration)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/docs/API-NAMES.md):
    - sizes and counts are 32-bit (Integer);
    - TNSCollection and TNSSortedCollection are merged into TCollection and TSortedCollection;
    - the streambuf of a stream is a TStream of this unit, the filebuf of a file stream a TBufStream;
      the open modes are those of TDosStream (stOpenRead, stCreate ...), the seek directions those of
      FileSeek (fsFromBeginning, fsFromCurrent, fsFromEnd);
    - the operators << and >> of the streams are methods: WriteObject and ReadObject for an
      object, WritePointer and ReadPointer for a pointer to an object, WriteBytes and
      ReadBytes (WriteByte, WriteWord ...) for the other types;
    - a class has one base: iopstream is an ipstream with an opstream (it converts to it),
      ifpstream, ofpstream and fpstream have the members of fpbase.

  The byte streams TStream, TDosStream, TBufStream, TMemoryStream are tv3 additions: the buffers of
  the object streams and the files of dn. }
unit TvObjs;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvUtil;

const
  { Status of a stream: stOk, or the kind of the first failure (negative) }
  stPutError = -6; stGetError = -5;
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
  { the argument of the constructors that make an object to be read from a stream (StreamableInit of tvision) }
  TStreamableInit = (streamableInit);

  P_id_type = LongWord;

const
  P_id_notFound = High(LongWord);

type
  pstream = class;
  ipstream = class;
  opstream = class;

  TStreamable = class
  protected
    function StreamableName: ShortString; virtual; abstract;
    function Read(Ip: ipstream): Pointer; virtual; abstract;
    procedure Write(Os: opstream); virtual; abstract;
  end;

  { makes an object of a class, to be read from a stream (BUILDER) }
  TStreamableBuilder = function: TStreamable;

  { a class that can be read from a stream: its name and its builder; it registers itself }
  TStreamableClass = class
  private
    Name: ShortString;
    Build: TStreamableBuilder;
  public
    constructor Create(const N: ShortString; B: TStreamableBuilder; Unused: Integer = 0);
  end;

  TStream = class
    Status: Integer;
    ErrorInfo: Integer;
    procedure CopyFrom(S: TStream; Count: Int64);
    procedure Error(Code, Info: Integer); virtual;
    procedure Flush; virtual;
    function GetPos: Int64; virtual;
    function GetSize: Int64; virtual;
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
    constructor Create(ALimit, ADelta: Integer); overload;
    destructor Destroy; override;
    function At(Index: Integer): Pointer;
    procedure AtRemove(Index: Integer);
    procedure AtFree(Index: Integer);
    procedure AtInsert(Index: Integer; Item: Pointer);
    procedure AtPut(Index: Integer; Item: Pointer);
    { used by DN: AtPut that grows the collection with nils up to Index and frees the item that was there }
    procedure AtReplace(Index: Integer; Item: Pointer);
    procedure Remove(Item: Pointer);
    procedure RemoveAll;
    procedure Error(Code, Info: Integer); virtual;
    function FirstThat(Test: TNestedTestProc): Pointer;
    procedure ForEach(Action: TNestedActionProc);
    procedure Free; reintroduce; overload;
    procedure Free(Item: Pointer); overload;
    procedure FreeAll;
    procedure FreeItem(Item: Pointer); virtual;
    function IndexOf(Item: Pointer): Integer; virtual;
    procedure Insert(Item: Pointer); virtual;
    function LastThat(Test: TNestedTestProc): Pointer;
    procedure Pack;
    procedure SetLimit(ALimit: Integer); virtual;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function ReadItem(Ip: ipstream): Pointer; virtual; abstract;
    procedure WriteItem(Item: Pointer; Os: opstream); virtual; abstract;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  end;

  { Test: function(Item: Pointer): Boolean; Action: procedure(Item: Pointer): the
    functions are ordinary (not methods); Test and Action are passed as pointers. }
  TCollTestProc = function(Item: Pointer): Boolean;
  TCollActionProc = procedure(Item: Pointer);

  TSortedCollection = class(TCollection)
    Duplicates: Boolean;
    constructor Create(ALimit, ADelta: Integer); overload;
    function Compare(Key1, Key2: Pointer): Integer; virtual;
    function IndexOf(Item: Pointer): Integer; override;
    procedure Insert(Item: Pointer); override;
    function KeyOf(Item: Pointer): Pointer; virtual;
    function Search(Key: Pointer; var Index: Integer): Boolean; virtual;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  end;

  { the items are pointers to ShortStrings (PStr) }
  TStringCollection = class(TSortedCollection)
    function Compare(Key1, Key2: Pointer): Integer; override;
    procedure FreeItem(Item: Pointer); override;
    class function Build: TStreamable; static;
  protected
    function StreamableName: ShortString; override;
    function ReadItem(Ip: ipstream): Pointer; override;
    procedure WriteItem(Item: Pointer; Os: opstream); override;
  end;


  { the registry of the classes, sorted by name }
  TStreamableTypes = class(TSortedCollection)
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterType(D: TStreamableClass);
    function Lookup(const AName: ShortString): TStreamableClass;
    function KeyOf(Item: Pointer): Pointer; override;
    function Compare(Key1, Key2: Pointer): Integer; override;
    procedure FreeItem(Item: Pointer); override;
  end;

  { the objects written to an opstream, sorted by address, with their numbers }
  TPWrittenObjects = class(TSortedCollection)
  private
    CurId: P_id_type;
    constructor Create;
    procedure RegisterObject(Adr: Pointer);
    function Find(Adr: Pointer): P_id_type;
  public
    destructor Destroy; override;
    procedure RemoveAll;
    function KeyOf(Item: Pointer): Pointer; override;
    function Compare(Key1, Key2: Pointer): Integer; override;
  end;

  TPWObj = class
  private
    Address: Pointer;
    Ident: P_id_type;
    constructor Create(Adr: Pointer; Id: P_id_type);
  end;

  { the objects read from an ipstream, in the order of their numbers }
  TPReadObjects = class(TCollection)
  private
    CurId: P_id_type;
    constructor Create;
    procedure RegisterObject(Adr: Pointer);
    function Find(Id: P_id_type): Pointer;
  public
    destructor Destroy; override;
    procedure RemoveAll;
  end;

  pstream = class
  public type
    StreamableError = (peNotRegistered, peInvalidType);
    PointerTypes = (ptNull, ptIndexed, ptObject);
    openmode = Word;
    seekdir = Integer;            { fsFromBeginning, fsFromCurrent, fsFromEnd (SysUtils) }
  public const
    { the state bits (ios::goodbit ... of C++) }
    goodbit = 0;
    eofbit = 1;
    failbit = 2;
    badbit = 4;
  protected
    Bp: TStream;
    State: Integer;
    class var Types: TStreamableTypes;
    constructor Create; overload;
    procedure Error(E: StreamableError); overload;
    procedure Error(E: StreamableError; T: TStreamable); overload;
    procedure Init(Sbp: TStream);
    procedure SetState(B: Integer);
  public
    constructor Create(Sb: TStream); overload;
    destructor Destroy; override;
    function RdState: Integer;
    function Eof: Integer;
    function Fail: Integer;
    function Bad: Integer;
    function Good: Integer;
    procedure Clear(I: Integer = 0);
    function RdBuf: TStream;
    class procedure InitTypes; static;
    class procedure RegisterType(Ts: TStreamableClass); static;
  end;

  ipstream = class(pstream)
  private
    Objs: TPReadObjects;
  protected
    constructor Create; overload;
    function ReadPrefix: TStreamableClass;
    function ReadData(C: TStreamableClass; Mem: TStreamable): Pointer;
    procedure ReadSuffix;
    function Find(Id: P_id_type): Pointer;
    procedure RegisterObject(Adr: Pointer);
  public
    constructor Create(Sb: TStream); overload;
    destructor Destroy; override;
    function TellG: Int64;
    function SeekG(Pos: Int64): ipstream; overload;
    function SeekG(Off: Int64; Dir: pstream.seekdir): ipstream; overload;
    function ReadByte: Byte;
    procedure ReadBytes(var Data; Sz: SizeInt);
    function ReadWord: Word;
    { nil for the null string }
    function ReadString: PStr; overload;
    function ReadString(Buf: PChar; MaxLen: LongWord): PChar; overload;
    { >> of an object (TStreamable &) and of a pointer to an object (void *&) }
    procedure ReadObject(T: TStreamable);
    function ReadPointer: Pointer;
  end;

  opstream = class(pstream)
  private
    Objs: TPWrittenObjects;
  protected
    constructor Create; overload;
    procedure WritePrefix(T: TStreamable);
    procedure WriteData(T: TStreamable);
    procedure WriteSuffix(T: TStreamable);
    function Find(Adr: Pointer): P_id_type;
    procedure RegisterObject(Adr: Pointer);
  public
    constructor Create(Sb: TStream); overload;
    destructor Destroy; override;
    function TellP: Int64;
    function SeekP(Pos: Int64): opstream; overload;
    function SeekP(Off: Int64; Dir: pstream.seekdir): opstream; overload;
    function Flush: opstream;
    procedure WriteByte(Ch: Byte);
    procedure WriteBytes(const Data; Sz: SizeInt);
    procedure WriteWord(Sh: Word);
    { nil is the null string }
    procedure WriteString(Str: PStr); overload;
    procedure WriteString(const Str: ShortString); overload;
    { << of an object (TStreamable &) and of a pointer to an object (TStreamable *) }
    procedure WriteObject(T: TStreamable);
    procedure WritePointer(T: TStreamable);
  end;

  { an ipstream that writes too: its opstream part is Op (an iopstream converts to it) }
  iopstream = class(ipstream)
  protected
    Op: opstream;
    constructor Create; overload;
  public
    constructor Create(Sb: TStream); overload;
    destructor Destroy; override;
    function TellP: Int64;
    function SeekP(Pos: Int64): opstream; overload;
    function SeekP(Off: Int64; Dir: pstream.seekdir): opstream; overload;
    function Flush: opstream;
    procedure WriteByte(Ch: Byte);
    procedure WriteBytes(const Data; Sz: SizeInt);
    procedure WriteWord(Sh: Word);
    procedure WriteString(Str: PStr); overload;
    procedure WriteString(const Str: ShortString); overload;
    procedure WriteObject(T: TStreamable);
    procedure WritePointer(T: TStreamable);
  end;

  fpbase = class(pstream)
  private
    Buf: TBufStream;
  public
    constructor Create; overload;
    constructor Create(const AName: string; Omode: pstream.openmode); overload;
    destructor Destroy; override;
    procedure Open(const AName: string; Omode: pstream.openmode);
    procedure Close;
    function RdBuf: TStream;
  end;

  ifpstream = class(ipstream)
  private
    Buf: TBufStream;
  public
    constructor Create; overload;
    constructor Create(const AName: string; Omode: pstream.openmode = stOpenRead); overload;
    destructor Destroy; override;
    procedure Open(const AName: string; Omode: pstream.openmode = stOpenRead);
    procedure Close;
    function RdBuf: TStream;
  end;

  ofpstream = class(opstream)
  private
    Buf: TBufStream;
  public
    constructor Create; overload;
    constructor Create(const AName: string; Omode: pstream.openmode = stCreate); overload;
    destructor Destroy; override;
    procedure Open(const AName: string; Omode: pstream.openmode = stCreate);
    procedure Close;
    function RdBuf: TStream;
  end;

  fpstream = class(iopstream)
  private
    Buf: TBufStream;
  public
    constructor Create; overload;
    constructor Create(const AName: string; Omode: pstream.openmode); overload;
    destructor Destroy; override;
    procedure Open(const AName: string; Omode: pstream.openmode);
    procedure Close;
    function RdBuf: TStream;
  end;

type
  { the name of a file of the program into the name that the system takes (DN: DOS names on Unix) }
  TFileNameHook = function(const Name: string): string;

var
  { when set, TDosStream passes the names of its files through it }
  OnFileName: TFileNameHook = nil;

{ the opstream part of an iopstream }
operator :=(S: iopstream): opstream;

var
  RStringCollection: TStreamableClass;

implementation

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

const
  NullStringLen = 255;

{ --- TStreamableClass --------------------------------------------------------- }

constructor TStreamableClass.Create(const N: ShortString; B: TStreamableBuilder; Unused: Integer);
begin
  inherited Create;
  Name := N;
  Build := B;
  pstream.InitTypes;
  pstream.RegisterType(Self);
end;

{ --- TStreamableTypes --------------------------------------------------------- }

constructor TStreamableTypes.Create;
begin
  inherited Create(5, 5);
end;

destructor TStreamableTypes.Destroy;
begin
  RemoveAll;
  inherited Destroy;
end;

procedure TStreamableTypes.RegisterType(D: TStreamableClass);
begin
  Insert(D);
end;

function TStreamableTypes.Lookup(const AName: ShortString): TStreamableClass;
var
  Loc: Integer;
begin
  if Search(@AName, Loc) then
    Result := TStreamableClass(At(Loc))
  else
    Result := nil;
end;

function TStreamableTypes.KeyOf(Item: Pointer): Pointer;
begin
  Result := @TStreamableClass(Item).Name;
end;

function TStreamableTypes.Compare(Key1, Key2: Pointer): Integer;
begin
  if PShortString(Key1)^ < PShortString(Key2)^ then
    Result := -1
  else if PShortString(Key1)^ > PShortString(Key2)^ then
    Result := 1
  else
    Result := 0;
end;

procedure TStreamableTypes.FreeItem(Item: Pointer);
begin
  { the classes are not owned by the registry }
end;

{ --- TPWrittenObjects --------------------------------------------------------- }

constructor TPWrittenObjects.Create;
begin
  inherited Create(5, 5);
  CurId := 0;
end;

destructor TPWrittenObjects.Destroy;
begin
  inherited Destroy;
end;

procedure TPWrittenObjects.RemoveAll;
begin
  CurId := 0;
  FreeAll;
end;

procedure TPWrittenObjects.RegisterObject(Adr: Pointer);
var
  O: TPWObj;
begin
  O := TPWObj.Create(Adr, CurId);
  Inc(CurId);
  Insert(O);
end;

function TPWrittenObjects.Find(Adr: Pointer): P_id_type;
var
  Loc: Integer;
begin
  if Search(Adr, Loc) then
    Result := TPWObj(At(Loc)).Ident
  else
    Result := P_id_notFound;
end;

function TPWrittenObjects.KeyOf(Item: Pointer): Pointer;
begin
  Result := TPWObj(Item).Address;
end;

function TPWrittenObjects.Compare(Key1, Key2: Pointer): Integer;
begin
  if Key1 = Key2 then
    Result := 0
  else if PtrUInt(Key1) < PtrUInt(Key2) then
    Result := -1
  else
    Result := 1;
end;

constructor TPWObj.Create(Adr: Pointer; Id: P_id_type);
begin
  inherited Create;
  Address := Adr;
  Ident := Id;
end;

{ --- TPReadObjects ------------------------------------------------------------ }

constructor TPReadObjects.Create;
begin
  inherited Create(5, 5);
  CurId := 0;
end;

destructor TPReadObjects.Destroy;
begin
  inherited Destroy;
end;

procedure TPReadObjects.RemoveAll;
begin
  CurId := 0;
  inherited RemoveAll;
end;

procedure TPReadObjects.RegisterObject(Adr: Pointer);
begin
  AtInsert(Count, Adr);
  Assert(Integer(CurId) = Count - 1);
  Inc(CurId);
end;

function TPReadObjects.Find(Id: P_id_type): Pointer;
begin
  Result := At(Id);
end;

{ --- pstream ------------------------------------------------------------------ }

constructor pstream.Create(Sb: TStream);
begin
  inherited Create;
  Init(Sb);
end;

destructor pstream.Destroy;
begin
  inherited Destroy;
end;

class procedure pstream.InitTypes;
begin
  if Types = nil then
    Types := TStreamableTypes.Create;
end;

function pstream.RdState: Integer;
begin
  Result := State;
end;

function pstream.Eof: Integer;
begin
  Result := State and eofbit;
end;

function pstream.Fail: Integer;
begin
  Result := State and (failbit or badbit);
end;

function pstream.Bad: Integer;
begin
  Result := State and badbit;
end;

function pstream.Good: Integer;
begin
  Result := Ord(State = 0);
end;

procedure pstream.Clear(I: Integer);
begin
  State := I and $FF;
end;

class procedure pstream.RegisterType(Ts: TStreamableClass);
begin
  Types.RegisterType(Ts);
end;

function pstream.RdBuf: TStream;
begin
  Result := Bp;
end;

constructor pstream.Create;
begin
  inherited Create;
end;

procedure pstream.Error(E: StreamableError);
begin
  if E = peInvalidType then
    WriteLn(StdErr, 'pstream error: invalid type encountered')
  else if E = peNotRegistered then
    WriteLn(StdErr, 'pstream error: type not registered');
  Halt(3);
end;

procedure pstream.Error(E: StreamableError; T: TStreamable);
begin
  if E = peNotRegistered then
    WriteLn(StdErr, 'pstream error: type ''', T.StreamableName, ''' not registered')
  else
    Error(E);
  Halt(3);
end;

procedure pstream.Init(Sbp: TStream);
begin
  State := 0;
  Bp := Sbp;
end;

procedure pstream.SetState(B: Integer);
begin
  State := State or (B and $FF);
end;

{ --- ipstream ----------------------------------------------------------------- }

constructor ipstream.Create(Sb: TStream);
begin
  inherited Create;
  Objs := TPReadObjects.Create;
  Init(Sb);
end;

destructor ipstream.Destroy;
begin
  if Objs <> nil then
    Objs.RemoveAll;
  Objs.Free;
  inherited Destroy;
end;

{ the position after a seek of Off from Dir }
procedure SeekBuf(Bp: TStream; Off: Int64; Dir: pstream.seekdir);
begin
  case Dir of
    fsFromCurrent: Bp.Seek(Bp.GetPos + Off);
    fsFromEnd: Bp.Seek(Bp.GetSize + Off);
  else
    Bp.Seek(Off);
  end;
end;

function ipstream.TellG: Int64;
begin
  Result := Bp.GetPos;
end;

function ipstream.SeekG(Pos: Int64): ipstream;
begin
  Objs.RemoveAll;
  Bp.Seek(Pos);
  Result := Self;
end;

function ipstream.SeekG(Off: Int64; Dir: pstream.seekdir): ipstream;
begin
  Objs.RemoveAll;
  SeekBuf(Bp, Off, Dir);
  Result := Self;
end;

function ipstream.ReadByte: Byte;
begin
  Result := 0;
  Bp.Read(Result, 1);
end;

function ipstream.ReadWord: Word;
begin
  Result := 0;
  Bp.Read(Result, SizeOf(Word));
end;

procedure ipstream.ReadBytes(var Data; Sz: SizeInt);
begin
  if Sz > 0 then
    Bp.Read(Data, Sz);
end;

function ipstream.ReadString: PStr;
var
  Len: Byte;
begin
  Len := ReadByte;
  if Len = NullStringLen then
    Exit(nil);
  GetMem(Result, Len + 1);
  Result^[0] := Chr(Len);
  ReadBytes(Result^[1], Len);
end;

function ipstream.ReadString(Buf: PChar; MaxLen: LongWord): PChar;
var
  Len: Byte;
begin
  Assert(Buf <> nil);
  Len := ReadByte;
  if Len > MaxLen - 1 then
    Exit(nil);
  ReadBytes(Buf^, Len);
  Buf[Len] := #0;
  Result := Buf;
end;

procedure ipstream.ReadObject(T: TStreamable);
var
  Pc: TStreamableClass;
begin
  Pc := ReadPrefix;
  ReadData(Pc, T);
  ReadSuffix;
end;

function ipstream.ReadPointer: Pointer;
var
  Ch: Byte;
  Index: P_id_type;
  Pc: TStreamableClass;
begin
  Result := nil;
  Ch := ReadByte;
  case Ch of
    Ord(ptNull):
      Result := nil;
    Ord(ptIndexed):
    begin
      Index := ReadWord;
      Result := Find(Index);
      Assert(Result <> nil);
    end;
    Ord(ptObject):
    begin
      Pc := ReadPrefix;
      Result := ReadData(Pc, nil);
      ReadSuffix;
    end;
  else
    Error(peInvalidType);
  end;
end;

constructor ipstream.Create;
begin
  inherited Create;
  Objs := TPReadObjects.Create;
end;

function ipstream.ReadPrefix: TStreamableClass;
var
  Ch: Char;
  AName: array[0..127] of Char;
begin
  Ch := Chr(ReadByte);
  Assert(Ch = '[');
  if ReadString(@AName[0], SizeOf(AName)) = nil then
    AName[0] := #0;
  Result := Types.Lookup(StrPas(@AName[0]));
end;

function ipstream.ReadData(C: TStreamableClass; Mem: TStreamable): Pointer;
begin
  if Mem = nil then
  begin
    if C = nil then
      Error(peNotRegistered);
    Mem := C.Build();
  end;
  RegisterObject(Mem);
  Result := Mem.Read(Self);
end;

procedure ipstream.ReadSuffix;
var
  Ch: Char;
begin
  Ch := Chr(ReadByte);
  Assert(Ch = ']');
end;

function ipstream.Find(Id: P_id_type): Pointer;
begin
  Result := Objs.Find(Id);
end;

procedure ipstream.RegisterObject(Adr: Pointer);
begin
  Objs.RegisterObject(Adr);
end;

{ --- opstream ----------------------------------------------------------------- }

constructor opstream.Create;
begin
  inherited Create;
  Objs := TPWrittenObjects.Create;
end;

constructor opstream.Create(Sb: TStream);
begin
  inherited Create;
  Objs := TPWrittenObjects.Create;
  Init(Sb);
end;

destructor opstream.Destroy;
begin
  Objs.Free;
  inherited Destroy;
end;

function opstream.SeekP(Pos: Int64): opstream;
begin
  Objs.FreeAll;
  Bp.Seek(Pos);
  Result := Self;
end;

function opstream.SeekP(Off: Int64; Dir: pstream.seekdir): opstream;
begin
  Objs.FreeAll;
  SeekBuf(Bp, Off, Dir);
  Result := Self;
end;

function opstream.TellP: Int64;
begin
  Result := Bp.GetPos;
end;

function opstream.Flush: opstream;
begin
  Bp.Flush;
  Result := Self;
end;

procedure opstream.WriteByte(Ch: Byte);
begin
  Bp.Write(Ch, 1);
end;

procedure opstream.WriteBytes(const Data; Sz: SizeInt);
begin
  if Sz > 0 then
    Bp.Write(Data, Sz);
end;

procedure opstream.WriteWord(Sh: Word);
begin
  Bp.Write(Sh, SizeOf(Word));
end;

procedure opstream.WriteString(Str: PStr);
begin
  if Str = nil then
  begin
    WriteByte(NullStringLen);
    Exit;
  end;
  WriteString(Str^);
end;

procedure opstream.WriteString(const Str: ShortString);
var
  Len: Byte;
begin
  Len := Length(Str);
  if Len > NullStringLen - 1 then
    Len := NullStringLen - 1;
  WriteByte(Len);
  WriteBytes(Str[1], Len);
end;

procedure opstream.WriteObject(T: TStreamable);
begin
  WritePrefix(T);
  WriteData(T);
  WriteSuffix(T);
end;

procedure opstream.WritePointer(T: TStreamable);
var
  Index: P_id_type;
begin
  if T = nil then
    WriteByte(Ord(ptNull))
  else
  begin
    Index := Find(T);
    if Index <> P_id_notFound then
    begin
      WriteByte(Ord(ptIndexed));
      WriteWord(Index);
    end
    else
    begin
      WriteByte(Ord(ptObject));
      WriteObject(T);
    end;
  end;
end;

procedure opstream.WritePrefix(T: TStreamable);
begin
  WriteByte(Ord('['));
  WriteString(T.StreamableName);
end;

procedure opstream.WriteData(T: TStreamable);
begin
  if Types.Lookup(T.StreamableName) = nil then
    Error(peNotRegistered, T)
  else
  begin
    RegisterObject(T);
    T.Write(Self);
  end;
end;

procedure opstream.WriteSuffix(T: TStreamable);
begin
  WriteByte(Ord(']'));
end;

function opstream.Find(Adr: Pointer): P_id_type;
begin
  Result := Objs.Find(Adr);
end;

procedure opstream.RegisterObject(Adr: Pointer);
begin
  Objs.RegisterObject(Adr);
end;

{ --- iopstream ---------------------------------------------------------------- }

constructor iopstream.Create(Sb: TStream);
begin
  inherited Create(Sb);
  Op := opstream.Create(Sb);
end;

constructor iopstream.Create;
begin
  inherited Create;
  Op := opstream.Create;
end;

destructor iopstream.Destroy;
begin
  Op.Free;
  inherited Destroy;
end;

function iopstream.TellP: Int64;
begin
  Result := Op.TellP;
end;

function iopstream.SeekP(Pos: Int64): opstream;
begin
  Result := Op.SeekP(Pos);
end;

function iopstream.SeekP(Off: Int64; Dir: pstream.seekdir): opstream;
begin
  Result := Op.SeekP(Off, Dir);
end;

function iopstream.Flush: opstream;
begin
  Result := Op.Flush;
end;

procedure iopstream.WriteByte(Ch: Byte);
begin
  Op.WriteByte(Ch);
end;

procedure iopstream.WriteBytes(const Data; Sz: SizeInt);
begin
  Op.WriteBytes(Data, Sz);
end;

procedure iopstream.WriteWord(Sh: Word);
begin
  Op.WriteWord(Sh);
end;

procedure iopstream.WriteString(Str: PStr);
begin
  Op.WriteString(Str);
end;

procedure iopstream.WriteString(const Str: ShortString);
begin
  Op.WriteString(Str);
end;

procedure iopstream.WriteObject(T: TStreamable);
begin
  Op.WriteObject(T);
end;

procedure iopstream.WritePointer(T: TStreamable);
begin
  Op.WritePointer(T);
end;

operator :=(S: iopstream): opstream;
begin
  if S = nil then
    Result := nil
  else
    Result := S.Op;
end;

{ --- the file streams --------------------------------------------------------- }

{ opens Name with Omode into Buf: the state of a stream after the open of fpbase }
procedure OpenFile(S: pstream; var Buf: TBufStream; const AName: string; Omode: pstream.openmode);
begin
  if Buf <> nil then
    S.Clear(pstream.failbit)          { fail - already open }
  else
  begin
    Buf := TBufStream.Create(AName, Omode, 4096);
    if Buf.Status = stOk then
      S.Clear(pstream.goodbit)
    else
    begin
      FreeAndNil(Buf);
      S.Clear(pstream.badbit);
    end;
  end;
end;

procedure CloseFile(S: pstream; var Buf: TBufStream);
begin
  if Buf <> nil then
  begin
    FreeAndNil(Buf);
    S.Clear(pstream.goodbit);
  end
  else
    S.SetState(pstream.failbit);
end;

constructor fpbase.Create;
begin
  inherited Create;
  Init(nil);
end;

constructor fpbase.Create(const AName: string; Omode: pstream.openmode);
begin
  inherited Create;
  Init(nil);
  Open(AName, Omode);
end;

destructor fpbase.Destroy;
begin
  Buf.Free;
  inherited Destroy;
end;

procedure fpbase.Open(const AName: string; Omode: pstream.openmode);
begin
  OpenFile(Self, Buf, AName, Omode);
  Bp := Buf;
end;

procedure fpbase.Close;
begin
  CloseFile(Self, Buf);
  Bp := nil;
end;

function fpbase.RdBuf: TStream;
begin
  Result := Buf;
end;

constructor ifpstream.Create;
begin
  inherited Create;
  Init(nil);
end;

constructor ifpstream.Create(const AName: string; Omode: pstream.openmode);
begin
  inherited Create;
  Init(nil);
  Open(AName, Omode);
end;

destructor ifpstream.Destroy;
begin
  Buf.Free;
  inherited Destroy;
end;

procedure ifpstream.Open(const AName: string; Omode: pstream.openmode);
begin
  OpenFile(Self, Buf, AName, Omode);
  Bp := Buf;
end;

procedure ifpstream.Close;
begin
  CloseFile(Self, Buf);
  Bp := nil;
end;

function ifpstream.RdBuf: TStream;
begin
  Result := Buf;
end;

constructor ofpstream.Create;
begin
  inherited Create;
  Init(nil);
end;

constructor ofpstream.Create(const AName: string; Omode: pstream.openmode);
begin
  inherited Create;
  Init(nil);
  Open(AName, Omode);
end;

destructor ofpstream.Destroy;
begin
  Buf.Free;
  inherited Destroy;
end;

procedure ofpstream.Open(const AName: string; Omode: pstream.openmode);
begin
  OpenFile(Self, Buf, AName, Omode);
  Bp := Buf;
end;

procedure ofpstream.Close;
begin
  CloseFile(Self, Buf);
  Bp := nil;
end;

function ofpstream.RdBuf: TStream;
begin
  Result := Buf;
end;

constructor fpstream.Create;
begin
  inherited Create;
  Init(nil);
end;

constructor fpstream.Create(const AName: string; Omode: pstream.openmode);
begin
  inherited Create;
  Init(nil);
  Open(AName, Omode);
end;

destructor fpstream.Destroy;
begin
  Op.Free;
  Op := nil;
  Buf.Free;
  inherited Destroy;
end;

procedure fpstream.Open(const AName: string; Omode: pstream.openmode);
begin
  OpenFile(Self, Buf, AName, Omode);
  Bp := Buf;
  Op.Init(Buf);
  Op.State := State;
end;

procedure fpstream.Close;
begin
  CloseFile(Self, Buf);
  Bp := nil;
  Op.Init(nil);
end;

function fpstream.RdBuf: TStream;
begin
  Result := Buf;
end;


{ --- TCollection ------------------------------------------------------------- }

constructor TCollection.Create(ALimit, ADelta: Integer);
begin
  inherited Create;
  { the fields start at zero (nil items, no count, no limit) }
  Delta := ADelta;
  SetLimit(ALimit);
end;

constructor TCollection.Create(AInit: TStreamableInit);
begin
  inherited Create;
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

procedure TCollection.AtRemove(Index: Integer);
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
  AtRemove(Index);
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

procedure TCollection.Remove(Item: Pointer);
begin
  AtRemove(IndexOf(Item));
end;

procedure TCollection.RemoveAll;
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
  Remove(Item);
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

function TCollection.StreamableName: ShortString;
begin
  Result := 'TCollection';
end;

procedure TCollection.Write(Os: opstream);
var
  Idx: Integer;
begin
  Os.WriteBytes(Count, SizeOf(Integer));
  Os.WriteBytes(Limit, SizeOf(Integer));
  Os.WriteBytes(Delta, SizeOf(Integer));
  for Idx := 0 to Count - 1 do
    WriteItem(Items^[Idx], Os);
end;

function TCollection.Read(Ip: ipstream): Pointer;
var
  SavedLimit, Idx: Integer;
begin
  Ip.ReadBytes(Count, SizeOf(Integer));
  Ip.ReadBytes(SavedLimit, SizeOf(Integer));
  Ip.ReadBytes(Delta, SizeOf(Integer));
  SetLimit(SavedLimit);
  for Idx := 0 to Count - 1 do
    Items^[Idx] := ReadItem(Ip);
  Result := Self;
end;

{ --- TSortedCollection ------------------------------------------------------- }

constructor TSortedCollection.Create(ALimit, ADelta: Integer);
begin
  inherited Create(ALimit, ADelta);
  Duplicates := False;
end;

constructor TSortedCollection.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
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

function TSortedCollection.StreamableName: ShortString;
begin
  Result := 'TSortedCollection';
end;

procedure TSortedCollection.Write(Os: opstream);
var
  Temp: Integer;
begin
  inherited Write(Os);
  Temp := Ord(Duplicates);
  Os.WriteBytes(Temp, SizeOf(Integer));
end;

function TSortedCollection.Read(Ip: ipstream): Pointer;
var
  Temp: Integer;
begin
  inherited Read(Ip);
  Ip.ReadBytes(Temp, SizeOf(Integer));
  Duplicates := Temp <> 0;
  Result := Self;
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

class function TStringCollection.Build: TStreamable;
begin
  Result := TStringCollection.Create(streamableInit);
end;

function TStringCollection.StreamableName: ShortString;
begin
  Result := 'TStringCollection';
end;

procedure TStringCollection.WriteItem(Item: Pointer; Os: opstream);
begin
  Os.WriteString(PStr(Item));
end;

function TStringCollection.ReadItem(Ip: ipstream): Pointer;
begin
  Result := Ip.ReadString;
end;

initialization
  RStringCollection := TStreamableClass.Create('TStringCollection', @TStringCollection.Build);
end.
