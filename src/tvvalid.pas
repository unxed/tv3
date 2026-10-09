{ TvValid: input validators (for TInputLine): TValidator, TPXPictureValidator,
  TFilterValidator, TRangeValidator, TLookupValidator, TStringLookupValidator.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/validate.h, source/tvision/tvalidat.cpp, tvtext2.cpp (messages)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - strings are ShortStrings (the picture and the input are indexed from 0 inside the
      picture validator, as in the original, through small helper functions);
    - the error messages are variables (translations);
    - streams are not translated yet. }
unit TvValid;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvObjs, TvUtil, TvMsgBox;

const
  { validator status }
  vsOk     = 0;
  vsSyntax = 1;      { error in the syntax of a picture }

  { validator options }
  voFill     = $0001;
  voTransfer = $0002;
  voReserved = $00FC;

type
  TCharSet = set of Char;

  TVTransfer = (vtDataSize, vtSetData, vtGetData);
  TPicResult = (prComplete, prIncomplete, prEmpty, prError, prSyntax, prAmbiguous,
    prIncompNoFill);

  TValidator = class(TStreamable)
    Status: Word;
    Options: Word;
    constructor Create; overload;
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    procedure Error; virtual;
    function IsValidInput(var S: ShortString; SuppressFill: Boolean): Boolean; virtual;
    function IsValid(const S: ShortString): Boolean; virtual;
    function Transfer(var S: ShortString; Buffer: Pointer; Flag: TVTransfer): Word; virtual;
    function Validate(const S: ShortString): Boolean;
  end;

  TPXPictureValidator = class(TValidator)
    Pic: PStr;
    constructor Create(const APic: ShortString; AutoFill: Boolean);
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    destructor Destroy; override;
    procedure Error; override;
    function IsValidInput(var S: ShortString; SuppressFill: Boolean): Boolean; override;
    function IsValid(const S: ShortString): Boolean; override;
    function Picture(var Input: ShortString; AutoFill: Boolean): TPicResult; virtual;
  private
    Index, Jndex: Integer;
    function PicLen: Integer;
    function PicCh(I: Integer): Char;
    procedure Consume(Ch: Char; var Input: ShortString);
    procedure ToGroupEnd(var I: Integer; TermCh: Integer);
    function SkipToComma(TermCh: Integer): Boolean;
    function CalcTerm(TermCh: Integer): Integer;
    function Iteration(var Input: ShortString; InTerm: Integer): TPicResult;
    function Group(var Input: ShortString; InTerm: Integer): TPicResult;
    function CheckComplete(Rslt: TPicResult; TermCh: Integer): TPicResult;
    function Scan(var Input: ShortString; TermCh: Integer): TPicResult;
    function Process(var Input: ShortString; TermCh: Integer): TPicResult;
    function SyntaxCheck: Boolean;
  end;

  TFilterValidator = class(TValidator)
    ValidChars: PStr;
    constructor Create(const AValidChars: ShortString); overload;
    { as in the Pascal Turbo Vision: the valid characters as a set (the characters #1..#255 of it) }
    constructor Create(const AValidChars: TCharSet); overload;
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    destructor Destroy; override;
    procedure Error; override;
    function IsValidInput(var S: ShortString; SuppressFill: Boolean): Boolean; override;
    function IsValid(const S: ShortString): Boolean; override;
  end;

  TRangeValidator = class(TFilterValidator)
    Min, Max: LongInt;
    constructor Create(AMin, AMax: LongInt);
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    procedure Error; override;
    function IsValid(const S: ShortString): Boolean; override;
    function Transfer(var S: ShortString; Buffer: Pointer; Flag: TVTransfer): Word; override;
  end;

  TLookupValidator = class(TValidator)
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
  public
    function IsValid(const S: ShortString): Boolean; override;
    function Lookup(const S: ShortString): Boolean; virtual;
  end;

  TStringLookupValidator = class(TLookupValidator)
    Strings: TStringCollection;
    constructor Create(AStrings: TStringCollection);
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    destructor Destroy; override;
    procedure Error; override;
    function Lookup(const S: ShortString): Boolean; override;
    procedure NewStringList(AStrings: TStringCollection);
  end;

var
  { the stream classes }
  RValidator, RFilterValidator, RRangeValidator, RPXPictureValidator, RLookupValidator, RStringLookupValidator: TStreamableClass;
  ValidPictureError: ShortString = 'Error in picture format.'#10' %s';
  ValidFilterError: ShortString = 'Invalid character in input';
  ValidRangeError: ShortString = 'Value not in the range %d to %d';
  ValidLookupError: ShortString = 'Input is not in list of valid strings';

implementation

const
  ValidUnsignedChars = '+0123456789';
  ValidSignedChars = '+-0123456789';

function Upper(C: Char): Char;
begin
  if (C >= 'a') and (C <= 'z') then
    Result := Chr(Ord(C) - 32)
  else
    Result := C;
end;

{ --- TValidator -------------------------------------------------------------- }

constructor TValidator.Create;
begin
  Status := 0;
  Options := 0;
end;

procedure TValidator.Error;
begin
end;

function TValidator.IsValidInput(var S: ShortString; SuppressFill: Boolean): Boolean;
begin
  Result := True;
end;

function TValidator.IsValid(const S: ShortString): Boolean;
begin
  Result := True;
end;

function TValidator.Transfer(var S: ShortString; Buffer: Pointer; Flag: TVTransfer): Word;
begin
  Result := 0;
end;

function TValidator.Validate(const S: ShortString): Boolean;
begin
  if not IsValid(S) then
  begin
    Error;
    Result := False;
  end
  else
    Result := True;
end;

{ --- TPXPictureValidator ----------------------------------------------------- }

function IsNumber(Ch: Char): Boolean;
begin
  Result := (Ch >= '0') and (Ch <= '9');
end;

function IsLetter(Ch: Char): Boolean;
begin
  Ch := Chr(Ord(Ch) and $DF);
  Result := (Ch >= 'A') and (Ch <= 'Z');
end;

function IsSpecial(Ch: Char; const Special: ShortString): Boolean;
begin
  Result := Pos(Ch, Special) > 0;
end;

function IsComplete(R: TPicResult): Boolean;
begin
  Result := (R = prComplete) or (R = prAmbiguous);
end;

function IsIncomplete(R: TPicResult): Boolean;
begin
  Result := (R = prIncomplete) or (R = prIncompNoFill);
end;

constructor TPXPictureValidator.Create(const APic: ShortString; AutoFill: Boolean);
var
  Probe: ShortString;
begin
  inherited Create;
  Pic := NewStr(APic);
  if AutoFill then
    Options := Options or voFill;
  { a picture that is right gives prEmpty for an empty input }
  Probe := '';
  if Picture(Probe, False) <> prEmpty then
    Status := vsSyntax;
end;

destructor TPXPictureValidator.Destroy;
begin
  DisposeStr(Pic);
  Pic := nil;
  inherited Destroy;
end;

function TPXPictureValidator.PicLen: Integer;
begin
  if Pic = nil then
    Result := 0
  else
    Result := Length(Pic^);
end;

{ the picture is indexed from 0; past its end there is a NUL, as in a C string }
function TPXPictureValidator.PicCh(I: Integer): Char;
begin
  if (Pic = nil) or (I < 0) or (I >= Length(Pic^)) then
    Result := #0
  else
    Result := Pic^[I + 1];
end;

procedure TPXPictureValidator.Error;
begin
  if Pic <> nil then
    MessageBox(mfError or mfOKButton, ValidPictureError, [Pic^])
  else
    MessageBox(mfError or mfOKButton, ValidPictureError, ['']);
end;

function TPXPictureValidator.IsValidInput(var S: ShortString; SuppressFill: Boolean): Boolean;
var
  DoFill: Boolean;
begin
  DoFill := ((Options and voFill) <> 0) and not SuppressFill;
  Result := (Pic = nil) or (Picture(S, DoFill) <> prError);
end;

function TPXPictureValidator.IsValid(const S: ShortString): Boolean;
var
  Str: ShortString;
begin
  Str := S;
  Result := (Pic = nil) or (Picture(Str, False) = prComplete);
end;

{ Consume input }
procedure TPXPictureValidator.Consume(Ch: Char; var Input: ShortString);
begin
  Input[Jndex + 1] := Ch;
  Inc(Index);
  Inc(Jndex);
end;

{ Skip a character or a picture group }
procedure TPXPictureValidator.ToGroupEnd(var I: Integer; TermCh: Integer);
var
  Brackets, Braces: Integer;
begin
  Brackets := 0;
  Braces := 0;
  repeat
    if I = TermCh then
      Exit;
    case PicCh(I) of
      '[': Inc(Brackets);
      ']': Dec(Brackets);
      '{': Inc(Braces);
      '}': Dec(Braces);
      ';': Inc(I);       { the next character is taken literally }
    end;
    Inc(I);
  until (Brackets = 0) and (Braces = 0);
end;

{ Find a comma separator }
function TPXPictureValidator.SkipToComma(TermCh: Integer): Boolean;
begin
  repeat
    ToGroupEnd(Index, TermCh);
  until (Index = TermCh) or (PicCh(Index) = ',');
  if PicCh(Index) = ',' then
    Inc(Index);
  Result := Index < TermCh;
end;

{ Calculate the end of a group }
function TPXPictureValidator.CalcTerm(TermCh: Integer): Integer;
var
  K: Integer;
begin
  K := Index;
  ToGroupEnd(K, TermCh);
  Result := K;
end;

{ The next group is repeated X times }
function TPXPictureValidator.Iteration(var Input: ShortString; InTerm: Integer): TPicResult;
var
  Itr, K, L, TermCh: Integer;
  Rslt: TPicResult;
begin
  Itr := 0;
  Rslt := prError;
  Inc(Index);          { skip '*' }
  { retrieve number }
  while IsNumber(PicCh(Index)) do
  begin
    Itr := Itr * 10 + (Ord(PicCh(Index)) - Ord('0'));
    Inc(Index);
  end;
  K := Index;
  TermCh := CalcTerm(InTerm);
  { if Itr is 0 allow any number, otherwise enforce the number }
  if Itr <> 0 then
  begin
    for L := 1 to Itr do
    begin
      Index := K;
      Rslt := Process(Input, TermCh);
      if not IsComplete(Rslt) then
      begin
        { empty means incomplete since all are required }
        if Rslt = prEmpty then
          Rslt := prIncomplete;
        Exit(Rslt);
      end;
    end;
  end
  else
  begin
    repeat
      Index := K;
      Rslt := Process(Input, TermCh);
    until Rslt <> prComplete;
    if (Rslt = prEmpty) or (Rslt = prError) then
    begin
      Inc(Index);
      Rslt := prAmbiguous;
    end;
  end;
  Index := TermCh;
  Result := Rslt;
end;

{ Process a picture group }
function TPXPictureValidator.Group(var Input: ShortString; InTerm: Integer): TPicResult;
var
  Rslt: TPicResult;
  TermCh: Integer;
begin
  TermCh := CalcTerm(InTerm);
  Inc(Index);
  Rslt := Process(Input, TermCh - 1);
  if not IsIncomplete(Rslt) then
    Index := TermCh;
  Result := Rslt;
end;

function TPXPictureValidator.CheckComplete(Rslt: TPicResult; TermCh: Integer): TPicResult;
var
  J: Integer;
  Stat: Boolean;
begin
  J := Index;
  Stat := True;
  if IsIncomplete(Rslt) then
  begin
    { skip optional pieces }
    while Stat do
      case PicCh(J) of
        '[': ToGroupEnd(J, TermCh);
        '*':
          begin
            if not IsNumber(PicCh(J + 1)) then
              Inc(J);
            ToGroupEnd(J, TermCh);
          end;
      else
        Stat := False;
      end;
    if J = TermCh then
      Rslt := prAmbiguous;
  end;
  Result := Rslt;
end;

function TPXPictureValidator.Scan(var Input: ShortString; TermCh: Integer): TPicResult;
var
  Ch: Char;
  Rslt, RScan: TPicResult;
begin
  RScan := prError;
  Rslt := prEmpty;
  while (Index <> TermCh) and (PicCh(Index) <> ',') do
  begin
    if Jndex >= Length(Input) then
      Exit(CheckComplete(Rslt, TermCh));
    Ch := Input[Jndex + 1];
    case PicCh(Index) of
      '#':
        if not IsNumber(Ch) then
          Exit(prError)
        else
          Consume(Ch, Input);
      '?':
        if not IsLetter(Ch) then
          Exit(prError)
        else
          Consume(Ch, Input);
      '&':
        if not IsLetter(Ch) then
          Exit(prError)
        else
          Consume(Upper(Ch), Input);
      '!': Consume(Upper(Ch), Input);
      '@': Consume(Ch, Input);
      '*':
        begin
          Rslt := Iteration(Input, TermCh);
          if not IsComplete(Rslt) then
            Exit(Rslt);
          if Rslt = prError then
            Rslt := prAmbiguous;
        end;
      '{':
        begin
          Rslt := Group(Input, TermCh);
          if not IsComplete(Rslt) then
            Exit(Rslt);
        end;
      '[':
        begin
          Rslt := Group(Input, TermCh);
          if IsIncomplete(Rslt) then
            Exit(Rslt);
          if Rslt = prError then
            Rslt := prAmbiguous;
        end;
    else
      begin
        if PicCh(Index) = ';' then
          Inc(Index);
        if Upper(PicCh(Index)) <> Upper(Ch) then
        begin
          if Ch = ' ' then
            Ch := PicCh(Index)
          else
            Exit(RScan);
        end;
        Consume(PicCh(Index), Input);
      end;
    end;
    if Rslt = prAmbiguous then
      Rslt := prIncompNoFill
    else
      Rslt := prIncomplete;
  end;
  if Rslt = prIncompNoFill then
    Result := prAmbiguous
  else
    Result := prComplete;
end;

function TPXPictureValidator.Process(var Input: ShortString; TermCh: Integer): TPicResult;
var
  R, Failed: TPicResult;
  HadIncomplete: Boolean;
  StartI, StartJ, IncI, IncJ: Integer;
begin
  HadIncomplete := False;
  IncI := 0;
  IncJ := 0;
  StartI := Index;
  StartJ := Jndex;
  { the alternatives (separated by commas) are tried in turn }
  repeat
    R := Scan(Input, TermCh);
    { a complete match counts only if it gets past an earlier incomplete one }
    if (R = prComplete) and HadIncomplete and (Jndex < IncJ) then
    begin
      R := prIncomplete;
      Jndex := IncJ;
    end;
    if (R = prError) or (R = prIncomplete) then
    begin
      Failed := R;
      if (R = prIncomplete) and not HadIncomplete then
      begin
        HadIncomplete := True;
        IncI := Index;
        IncJ := Jndex;
      end;
      Index := StartI;
      Jndex := StartJ;
      if not SkipToComma(TermCh) then
      begin
        if HadIncomplete then
        begin
          Index := IncI;
          Jndex := IncJ;
          Exit(prIncomplete);
        end;
        Exit(Failed);
      end;
      StartI := Index;
    end;
  until (R <> prError) and (R <> prIncomplete);
  if HadIncomplete and (R = prComplete) then
    Result := prAmbiguous
  else
    Result := R;
end;

function TPXPictureValidator.SyntaxCheck: Boolean;
var
  I, N, Brackets, Braces: Integer;
begin
  N := PicLen;
  if (N = 0) or (PicCh(N - 1) = ';') then
    Exit(False);
  Brackets := 0;
  Braces := 0;
  I := 0;
  while I < N do
  begin
    case PicCh(I) of
      '[': Inc(Brackets);
      ']': Dec(Brackets);
      '{': Inc(Braces);
      '}': Dec(Braces);
      ';': Inc(I);
    end;
    Inc(I);
  end;
  Result := (Brackets = 0) and (Braces = 0);
end;

function TPXPictureValidator.Picture(var Input: ShortString; AutoFill: Boolean): TPicResult;
var
  Filled: Boolean;
begin
  if not SyntaxCheck then
    Exit(prSyntax);
  if Input = '' then
    Exit(prEmpty);
  Index := 0;
  Jndex := 0;
  Result := Process(Input, PicLen);
  if (Result <> prError) and (Jndex < Length(Input)) then
    Result := prError;
  if AutoFill and (Result = prIncomplete) then
  begin
    { the literal characters that follow are added to the input }
    Filled := False;
    while (Index < PicLen) and not IsSpecial(PicCh(Index), '#?&!@*{}[],') do
    begin
      if PicCh(Index) = ';' then
        Inc(Index);
      if Length(Input) < 255 then
        Input := Input + PicCh(Index);
      Inc(Index);
      Filled := True;
    end;
    Index := 0;
    Jndex := 0;
    if Filled then
      Result := Process(Input, PicLen);
  end;
  case Result of
    prAmbiguous: Result := prComplete;
    prIncompNoFill: Result := prIncomplete;
  end;
end;

{ --- TFilterValidator -------------------------------------------------------- }

constructor TFilterValidator.Create(const AValidChars: ShortString);
begin
  inherited Create;
  ValidChars := NewStr(AValidChars);
end;

constructor TFilterValidator.Create(const AValidChars: TCharSet);
var
  C: Char;
  T: ShortString;
begin
  T := '';
  for C := #1 to #255 do
    if C in AValidChars then
      T := T + C;
  ValidChars := NewStr(T);
end;

destructor TFilterValidator.Destroy;
begin
  DisposeStr(ValidChars);
  ValidChars := nil;
  inherited Destroy;
end;

function AllIn(const S: ShortString; Valid: PStr): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 1 to Length(S) do
    if (Valid = nil) or (Pos(S[I], Valid^) = 0) then
      Exit(False);
end;

function TFilterValidator.IsValid(const S: ShortString): Boolean;
begin
  Result := AllIn(S, ValidChars);
end;

function TFilterValidator.IsValidInput(var S: ShortString; SuppressFill: Boolean): Boolean;
begin
  Result := AllIn(S, ValidChars);
end;

procedure TFilterValidator.Error;
begin
  MessageBox(mfError or mfOKButton, ValidFilterError, []);
end;

{ --- TRangeValidator --------------------------------------------------------- }

{ the number at the start of S like sscanf("%ld"): blanks, a sign, digits }
function ScanLong(const S: ShortString; out Value: LongInt): Boolean;
var
  I: Integer;
  Neg: Boolean;
  V: Int64;
begin
  Result := False;
  Value := 0;
  I := 1;
  while (I <= Length(S)) and (S[I] in [' ', #9]) do
    Inc(I);
  Neg := False;
  if (I <= Length(S)) and (S[I] in ['+', '-']) then
  begin
    Neg := S[I] = '-';
    Inc(I);
  end;
  if (I > Length(S)) or not (S[I] in ['0'..'9']) then
    Exit;
  V := 0;
  while (I <= Length(S)) and (S[I] in ['0'..'9']) do
  begin
    V := V * 10 + (Ord(S[I]) - Ord('0'));
    if V > 2147483648 then
      V := 2147483648;
    Inc(I);
  end;
  if Neg then
    V := -V;
  if (V > High(LongInt)) or (V < Low(LongInt)) then
    Exit;
  Value := V;
  Result := True;
end;

constructor TRangeValidator.Create(AMin, AMax: LongInt);
begin
  if AMin >= 0 then
    inherited Create(ValidUnsignedChars)
  else
    inherited Create(ValidSignedChars);
  Min := AMin;
  Max := AMax;
end;

procedure TRangeValidator.Error;
begin
  MessageBox(mfError or mfOKButton, ValidRangeError, [Min, Max]);
end;

function TRangeValidator.IsValid(const S: ShortString): Boolean;
var
  Value: LongInt;
begin
  Result := False;
  if inherited IsValid(S) then
    if ScanLong(S, Value) then
      if (Value >= Min) and (Value <= Max) then
        Result := True;
end;

function TRangeValidator.Transfer(var S: ShortString; Buffer: Pointer; Flag: TVTransfer): Word;
var
  Value: LongInt;
begin
  if (Options and voTransfer) <> 0 then
  begin
    case Flag of
      vtDataSize: ;
      vtGetData:
        begin
          ScanLong(S, Value);
          PLongInt(Buffer)^ := Value;
        end;
      vtSetData:
        begin
          Str(PLongInt(Buffer)^, S);
        end;
    end;
    Result := SizeOf(LongInt);
  end
  else
    Result := 0;
end;

{ --- TLookupValidator / TStringLookupValidator ----------------------------------- }

function TLookupValidator.IsValid(const S: ShortString): Boolean;
begin
  Result := Lookup(S);
end;

function TLookupValidator.Lookup(const S: ShortString): Boolean;
begin
  Result := True;
end;

constructor TStringLookupValidator.Create(AStrings: TStringCollection);
begin
  inherited Create;
  Strings := AStrings;
end;

destructor TStringLookupValidator.Destroy;
begin
  NewStringList(nil);
  inherited Destroy;
end;

procedure TStringLookupValidator.Error;
begin
  MessageBox(mfError or mfOKButton, ValidLookupError, []);
end;

function TStringLookupValidator.Lookup(const S: ShortString): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Strings = nil then
    Exit;
  for I := 0 to Strings.Count - 1 do
    if PStr(Strings.At(I))^ = S then
      Exit(True);
end;

procedure TStringLookupValidator.NewStringList(AStrings: TStringCollection);
begin
  if Strings <> nil then
    Strings.Free;
  Strings := AStrings;
end;

{ --- streams ----------------------------------------------------------------- }

procedure TValidator.Write(Os: opstream);
begin
  Os.WriteWord(Options);
end;

function TValidator.Read(Ip: ipstream): Pointer;
begin
  Options := Ip.ReadWord;
  Status := 0;
  Result := Self;
end;

class function TValidator.Build: TStreamable;
begin
  Result := TValidator.Create(streamableInit);
end;

constructor TValidator.Create(AInit: TStreamableInit);
begin
  inherited Create;
end;

function TValidator.StreamableName: ShortString;
begin
  Result := 'TValidator';
end;

procedure TPXPictureValidator.Write(Os: opstream);
begin
  inherited Write(Os);
  Os.WriteString(Pic);
end;

function TPXPictureValidator.Read(Ip: ipstream): Pointer;
begin
  inherited Read(Ip);
  Pic := Ip.ReadString;
  Index := 0;
  Jndex := 0;
  Result := Self;
end;

class function TPXPictureValidator.Build: TStreamable;
begin
  Result := TPXPictureValidator.Create(streamableInit);
end;

constructor TPXPictureValidator.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TPXPictureValidator.StreamableName: ShortString;
begin
  Result := 'TPXPictureValidator';
end;

procedure TFilterValidator.Write(Os: opstream);
begin
  inherited Write(Os);
  Os.WriteString(ValidChars);
end;

function TFilterValidator.Read(Ip: ipstream): Pointer;
begin
  inherited Read(Ip);
  ValidChars := Ip.ReadString;
  Result := Self;
end;

class function TFilterValidator.Build: TStreamable;
begin
  Result := TFilterValidator.Create(streamableInit);
end;

constructor TFilterValidator.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TFilterValidator.StreamableName: ShortString;
begin
  Result := 'TFilterValidator';
end;

procedure TRangeValidator.Write(Os: opstream);
begin
  inherited Write(Os);
  Os.WriteBytes(Min, SizeOf(LongInt));
  Os.WriteBytes(Max, SizeOf(LongInt));
end;

function TRangeValidator.Read(Ip: ipstream): Pointer;
begin
  inherited Read(Ip);
  Ip.ReadBytes(Min, SizeOf(LongInt));
  Ip.ReadBytes(Max, SizeOf(LongInt));
  Result := Self;
end;

class function TRangeValidator.Build: TStreamable;
begin
  Result := TRangeValidator.Create(streamableInit);
end;

constructor TRangeValidator.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TRangeValidator.StreamableName: ShortString;
begin
  Result := 'TRangeValidator';
end;

class function TLookupValidator.Build: TStreamable;
begin
  Result := TLookupValidator.Create(streamableInit);
end;

constructor TLookupValidator.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TLookupValidator.StreamableName: ShortString;
begin
  Result := 'TLookupValidator';
end;

procedure TStringLookupValidator.Write(Os: opstream);
begin
  inherited Write(Os);
  Os.WritePointer(Strings);
end;

function TStringLookupValidator.Read(Ip: ipstream): Pointer;
begin
  inherited Read(Ip);
  Strings := TStringCollection(Ip.ReadPointer);
  Result := Self;
end;

class function TStringLookupValidator.Build: TStreamable;
begin
  Result := TStringLookupValidator.Create(streamableInit);
end;

constructor TStringLookupValidator.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TStringLookupValidator.StreamableName: ShortString;
begin
  Result := 'TStringLookupValidator';
end;

initialization
  RValidator := TStreamableClass.Create('TValidator', @TValidator.Build);
  RLookupValidator := TStreamableClass.Create('TLookupValidator', @TLookupValidator.Build);
  RPXPictureValidator := TStreamableClass.Create('TPXPictureValidator', @TPXPictureValidator.Build);
  RFilterValidator := TStreamableClass.Create('TFilterValidator', @TFilterValidator.Build);
  RRangeValidator := TStreamableClass.Create('TRangeValidator', @TRangeValidator.Build);
  RStringLookupValidator := TStreamableClass.Create('TStringLookupValidator', @TStringLookupValidator.Build);

end.
