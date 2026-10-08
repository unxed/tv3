{ TvFar2l: the far2l terminal extensions: the stack serializer, Base64, the APC strings, the input events, the client ID, and the client side of the requests.

  MIT (see LICENSE).

  Every message is an APC string (ESC _ body BEL or ESC _ body ESC \). A request of the client is "far2l:" and the Base64 of a stack, a reply of the terminal
  "far2l" and the Base64 of a stack, an event of the terminal "f2l" and the Base64 of a stack; "far2l1" switches the extensions on (the terminal answers
  "far2lok"), "far2l0" off. A stack is a byte array: a push appends, a pop takes from the end; numbers are little-endian, a string is its bytes and then its
  length (32 bits). The top of a request is its ID (0: no reply wanted) and then the letter of the command; the top of a reply is the ID of the request.

  TF2lClient is the client side (the program that runs in the terminal): it builds the requests and reads the replies, keeps what is known of the terminal
  (the clipboard: authorization, features, the data IDs of the cache; the support of F-key titles; the largest window). The transport is given by a
  descendant (TvUnix: the terminal; the tests: a terminal in memory). }
unit TvFar2l;

{$I tvdefs.inc}
{$H+}

interface

uses
  SysUtils, TvUtf8, TvAppDir;

const
  { the commands of the requests }
  f2rFeatures = 'x';
  f2rQuickEdit = 'e';
  f2rMaximize = 'M';
  f2rRestore = 'm';
  f2rCursorHeight = 'h';
  f2rMaxSize = 'w';
  f2rNotify = 'n';
  f2rFKeys = 'f';
  f2rPalette = 'p';
  f2rClipboard = 'c';
  f2rImage = 'i';
  { the sub-commands of the clipboard }
  f2cOpen = 'o';
  f2cClose = 'c';
  f2cEmpty = 'e';
  f2cIsAvail = 'a';
  f2cSetChunk = 'S';
  f2cSetData = 's';
  f2cGetData = 'g';
  f2cGetDataId = 'i';
  f2cRegister = 'r';
  { the sub-command of the images that asks for the capabilities }
  f2iCaps = 'c';
  { the codes of the events }
  f2eKeyDown = 'K';
  f2eKeyUp = 'k';
  f2eKeyDownCompact = 'C';
  f2eKeyUpCompact = 'c';
  f2eMouse = 'M';
  f2eMouseCompact = 'm';
  f2eSize = 'S';
  { the features of the client (x) }
  F2lFeatCompactInput = 1;
  F2lFeatTerminalSize = 2;
  { the features of the clipboard of the terminal (the reply to CLIP_OPEN) }
  F2lClipDataId = 1;
  F2lClipChunkedSet = 2;
  { the clipboard formats of the protocol }
  F2lCfText = 1;
  F2lCfUnicodeText = 13;
  F2lCfHtml = 15;
  { the piece of a chunked upload, and how many pieces go before one waits for a reply }
  F2lChunkSize = $4000;
  F2lChunksPerWait = 16;
  { how long a clipboard read is allowed after a paste gesture (ms), and how many reads may extend it }
  F2lGestureMs = 5000;
  F2lGestureExtends = 3;
  { the bytes of the activation, of the acknowledgement and of the deactivation }
  F2lEnableSeq = #27'_far2l1'#27'\';
  F2lAckSeq = #27'_far2lok'#7;
  F2lDisableSeq = #27'_far2l0'#27'\';
  { the files of the configuration directory }
  F2lClientIdFile = 'far2l-clipboard-id';
  F2lAuthedsFile = 'far2l-clipboard-autheds';

type
  { A stack of the serializer. A pop of more bytes than there are gives zeros and sets Bad. }
  TF2lStack = record
    Data: AnsiString;
    Bad: Boolean;
    procedure Clear;
    function Size: Integer;
    procedure PushRaw(const S: AnsiString);
    procedure PushU8(V: Byte);
    procedure PushU16(V: Word);
    procedure PushU32(V: LongWord);
    procedure PushU64(V: QWord);
    procedure PushStr(const S: AnsiString);
    function PopRaw(N: Integer): AnsiString;
    function PopU8: Byte;
    function PopI8: ShortInt;
    function PopU16: Word;
    function PopI16: SmallInt;
    function PopU32: LongWord;
    function PopU64: QWord;
    function PopStr: AnsiString;
  end;

  TF2lBodyKind = (fbOther, fbAck, fbReply, fbEvent);

  TF2lInputKind = (fiUnknown, fiKey, fiMouse, fiSize);

  { an input event of the terminal: the fields of KEY_EVENT_RECORD and MOUSE_EVENT_RECORD of Windows, or the size }
  TF2lInput = record
    Kind: TF2lInputKind;
    Code: Char;
    { keys }
    Down: Boolean;
    Ch: LongWord;            { the character (UTF-32) or 0 }
    KeyState: LongWord;      { dwControlKeyState }
    Scan, Vk, Repeat_: Word;
    { the mouse }
    MouseFlags: LongWord;    { 1 moved, 2 double click, 4 the wheel, 8 the horizontal wheel }
    Buttons: LongWord;       { 1 left, 2 right, 4 middle; for the wheel the high word is the signed delta }
    X, Y: SmallInt;
    { the size }
    Cols, Rows: Word;
  end;

{ Base64 with the standard alphabet and the padding; the decoder stops at the first character that is not of the alphabet (and at '=') }
function F2lBase64Encode(const S: AnsiString): AnsiString;
function F2lBase64Decode(const S: AnsiString): AnsiString;

{ the APC strings of a stack: a request (client), a reply and an event (terminal) }
function F2lRequestSeq(const S: TF2lStack): AnsiString;
function F2lReplySeq(const S: TF2lStack): AnsiString;
function F2lEventSeq(const S: TF2lStack): AnsiString;
{ What the body of an APC string (without ESC _ and the terminator) is for the client; the stack of a reply or an event is decoded into S. }
function F2lClassify(const Body: AnsiString; out S: TF2lStack): TF2lBodyKind;
{ The next APC string in Text from position P: its body; P goes past it. False when there is none (a string that is not complete is not taken). }
function F2lNextApc(const Text: AnsiString; var P: Integer; out Body: AnsiString): Boolean;

{ An event from its stack (the code on top). False: the code is unknown or the stack is too short. }
function F2lDecodeInput(var S: TF2lStack; out Ev: TF2lInput): Boolean;
{ The APC string of an event; Compact: the client asked for the compact form, which is used when nothing is lost. }
function F2lKeySeq(Down: Boolean; Ch, KeyState: LongWord; Scan, Vk, Repeat_: Word; Compact: Boolean): AnsiString;
function F2lMouseSeq(Flags, KeyState, Buttons: LongWord; X, Y: SmallInt; Compact: Boolean): AnsiString;
function F2lSizeSeq(Cols, Rows: Word): AnsiString;

{ UTF-8 and the UTF-32 (little-endian) of CF_UNICODETEXT; the conversion from UTF-32 stops at a zero character }
function F2lUtf8ToUtf32(const S: AnsiString): AnsiString;
function F2lUtf32ToUtf8(const S: AnsiString): AnsiString;

{ The configuration directory of tv: $TV_CONFIG_DIR, else the directory 'tv' of TvAppDir.ConfigDir (~/.config/tv on Linux; no trailing
  separator). }
function F2lConfigDir: AnsiString;
{ A client ID: 32 to 256 characters of 0-9, a-z, '-', '_'. }
function F2lValidClientId(const Id: AnsiString): Boolean;
{ A new client ID: the host name (other characters become '_'), '-', random letters and digits; 64 characters. }
function F2lNewClientId: AnsiString;
{ The client ID of this user: read from the file far2l-clipboard-id of the configuration directory; made and stored there when there is none. }
function F2lLoadClientId: AnsiString;

type
  TF2lClipCache = record
    Format: LongWord;
    Id: QWord;
    Data: AnsiString;
  end;

  TF2lClient = class
  private
    NextId: Byte;
    MaxKnown: Boolean;
    MaxCols, MaxRows: Integer;
    FKeysAsked, FKeysOk: Boolean;
    FKeysLast: AnsiString;
    FKeysSent: Boolean;
    Authorized: Boolean;
    ClipFeatures: QWord;
    Cache: array of TF2lClipCache;
    Registered: array of record Name: AnsiString; Id: LongWord; end;
    function NewId: Byte;
    function ClipOpen: Boolean;
    procedure ClipClose;
    function SetOne(Format: LongWord; const Data: AnsiString): Boolean;
    function GetOne(Format: LongWord; out Data: AnsiString): Boolean;
    procedure CachePut(Format: LongWord; Id: QWord; const Data: AnsiString);
    procedure CacheDrop(Format: LongWord);
    function CacheFind(Format: LongWord): Integer;
  protected
    { the bytes go to the terminal }
    procedure Send(const S: AnsiString); virtual; abstract;
    { waits up to TimeoutMs for the reply with this ID (the ID is popped already); False: none came }
    function WaitReply(Id: Byte; TimeoutMs: Integer; out Reply: TF2lStack): Boolean; virtual; abstract;
  public
    Active: Boolean;             { the terminal acknowledged the extensions }
    ClientId: AnsiString;        { taken from F2lLoadClientId when it is empty at the first open }
    ReplyMs: Integer;            { the wait for an ordinary reply }
    AuthMs: Integer;             { the wait for CLIP_OPEN until the client was let in once (the terminal may ask the user) }
    ClipDenied: Boolean;         { the terminal said "use your own clipboard": not asked again in this process }
    constructor Create;
    { the terminal acknowledged far2l1 / the extensions were switched off: what is known per activation is forgotten }
    procedure Activated;
    procedure Deactivated;
    { a request with an ID; True when the reply came (Reply holds its values) }
    function Call(var Args: TF2lStack; Cmd: Char; out Reply: TF2lStack; TimeoutMs: Integer = 0): Boolean;
    { a request without a reply (ID 0) }
    procedure Post(var Args: TF2lStack; Cmd: Char);
    procedure SetFeatures(Flags: QWord);
    procedure Notify(const Title, Text: AnsiString);
    { Titles[0] is F1; '' is no title; True when the terminal shows them }
    function SetFKeyTitles(const Titles: array of AnsiString): Boolean;
    function WindowMaxSize(out Cols, Rows: Integer): Boolean;
    procedure WindowMaximize(Maximize: Boolean);
    procedure QuickEdit;
    procedure SetCursorHeight(Percent: Integer);
    { the color depth in bits (4, 8, 24), 0 when there is no answer }
    function ColorBits(TimeoutMs: Integer): Integer;
    { The clipboard. The formats are those of the protocol (F2lCfText ...); the text formats are UTF-8 here: CF_UNICODETEXT goes as CF_TEXT, and is read
      from CF_UNICODETEXT (UTF-32) only when CF_TEXT has nothing. False: the clipboard of the terminal cannot be used (not let in, no answer). }
    function ClipSet(const Formats: array of LongWord; const Datas: array of AnsiString): Boolean;
    function ClipGet(Format: LongWord; out Data: AnsiString): Boolean;
    { Avail: the format is on the clipboard }
    function ClipHas(Format: LongWord; out Avail: Boolean): Boolean;
    { the ID of a format of this name in the terminal (remembered for the process); 0: failed }
    function ClipRegister(const Name: AnsiString): LongWord;
  end;

implementation

{$IFDEF UNIX}
uses
  Unix, BaseUnix;
{$ENDIF}

{ --- the stack ------------------------------------------------------------------------------------------------- }

procedure TF2lStack.Clear;
begin
  Data := '';
  Bad := False;
end;

function TF2lStack.Size: Integer;
begin
  Result := Length(Data);
end;

procedure TF2lStack.PushRaw(const S: AnsiString);
begin
  Data := Data + S;
end;

procedure PushLe(var S: TF2lStack; V: QWord; N: Integer);
var
  B: AnsiString;
  I: Integer;
begin
  SetLength(B, N);
  for I := 1 to N do
  begin
    B[I] := Chr(V and $FF);
    V := V shr 8;
  end;
  S.Data := S.Data + B;
end;

procedure TF2lStack.PushU8(V: Byte);
begin
  PushLe(Self, V, 1);
end;

procedure TF2lStack.PushU16(V: Word);
begin
  PushLe(Self, V, 2);
end;

procedure TF2lStack.PushU32(V: LongWord);
begin
  PushLe(Self, V, 4);
end;

procedure TF2lStack.PushU64(V: QWord);
begin
  PushLe(Self, V, 8);
end;

procedure TF2lStack.PushStr(const S: AnsiString);
begin
  PushRaw(S);
  PushU32(Length(S));
end;

function TF2lStack.PopRaw(N: Integer): AnsiString;
begin
  if (N < 0) or (N > Length(Data)) then
  begin
    Bad := True;
    Data := '';
    Exit('');
  end;
  Result := Copy(Data, Length(Data) - N + 1, N);
  SetLength(Data, Length(Data) - N);
end;

function PopLe(var S: TF2lStack; N: Integer): QWord;
var
  B: AnsiString;
  I: Integer;
begin
  Result := 0;
  if N > Length(S.Data) then
  begin
    S.Bad := True;
    S.Data := '';
    Exit;
  end;
  B := S.PopRaw(N);
  for I := N downto 1 do
    Result := (Result shl 8) or Byte(B[I]);
end;

function TF2lStack.PopU8: Byte;
begin
  Result := Byte(PopLe(Self, 1));
end;

function TF2lStack.PopI8: ShortInt;
begin
  Result := ShortInt(Byte(PopLe(Self, 1)));
end;

function TF2lStack.PopU16: Word;
begin
  Result := Word(PopLe(Self, 2));
end;

function TF2lStack.PopI16: SmallInt;
begin
  Result := SmallInt(Word(PopLe(Self, 2)));
end;

function TF2lStack.PopU32: LongWord;
begin
  Result := LongWord(PopLe(Self, 4));
end;

function TF2lStack.PopU64: QWord;
begin
  Result := PopLe(Self, 8);
end;

function TF2lStack.PopStr: AnsiString;
var
  N: LongWord;
begin
  N := PopU32;
  if Bad then
    Exit('');
  if N > LongWord(Length(Data)) then
  begin
    Bad := True;
    Data := '';
    Exit('');
  end;
  Result := PopRaw(Integer(N));
end;

{ --- Base64 ---------------------------------------------------------------------------------------------------- }

const
  B64: array[0..63] of Char = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function F2lBase64Encode(const S: AnsiString): AnsiString;
var
  I, N, O: Integer;
  V: LongWord;
begin
  N := Length(S);
  SetLength(Result, ((N + 2) div 3) * 4);
  O := 0;
  I := 1;
  while I + 2 <= N do
  begin
    V := (LongWord(Byte(S[I])) shl 16) or (LongWord(Byte(S[I + 1])) shl 8) or Byte(S[I + 2]);
    Result[O + 1] := B64[(V shr 18) and 63];
    Result[O + 2] := B64[(V shr 12) and 63];
    Result[O + 3] := B64[(V shr 6) and 63];
    Result[O + 4] := B64[V and 63];
    Inc(O, 4);
    Inc(I, 3);
  end;
  if I <= N then
  begin
    V := LongWord(Byte(S[I])) shl 16;
    if I + 1 <= N then
      V := V or (LongWord(Byte(S[I + 1])) shl 8);
    Result[O + 1] := B64[(V shr 18) and 63];
    Result[O + 2] := B64[(V shr 12) and 63];
    if I + 1 <= N then
      Result[O + 3] := B64[(V shr 6) and 63]
    else
      Result[O + 3] := '=';
    Result[O + 4] := '=';
  end;
end;

function F2lBase64Decode(const S: AnsiString): AnsiString;
var
  I, O, Bits: Integer;
  Acc: LongWord;
  V: Integer;
  C: Char;
begin
  SetLength(Result, (Length(S) * 3) div 4 + 3);
  O := 0;
  Acc := 0;
  Bits := 0;
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      'A'..'Z': V := Ord(C) - Ord('A');
      'a'..'z': V := Ord(C) - Ord('a') + 26;
      '0'..'9': V := Ord(C) - Ord('0') + 52;
      '+': V := 62;
      '/': V := 63;
    else
      Break;
    end;
    Acc := ((Acc shl 6) or LongWord(V)) and $FFFFFF;
    Inc(Bits, 6);
    if Bits >= 8 then
    begin
      Dec(Bits, 8);
      Inc(O);
      Result[O] := Chr((Acc shr Bits) and $FF);
    end;
  end;
  SetLength(Result, O);
end;

{ --- the APC strings ------------------------------------------------------------------------------------------- }

function F2lRequestSeq(const S: TF2lStack): AnsiString;
begin
  Result := #27'_far2l:' + F2lBase64Encode(S.Data) + #27'\';
end;

function F2lReplySeq(const S: TF2lStack): AnsiString;
begin
  Result := #27'_far2l' + F2lBase64Encode(S.Data) + #7;
end;

function F2lEventSeq(const S: TF2lStack): AnsiString;
begin
  Result := #27'_f2l' + F2lBase64Encode(S.Data) + #7;
end;

function F2lClassify(const Body: AnsiString; out S: TF2lStack): TF2lBodyKind;
begin
  S.Clear;
  if Copy(Body, 1, 3) = 'f2l' then
  begin
    S.Data := F2lBase64Decode(Copy(Body, 4, MaxInt));
    Exit(fbEvent);
  end;
  if Body = 'far2lok' then
    Exit(fbAck);
  if Copy(Body, 1, 5) = 'far2l' then
  begin
    S.Data := F2lBase64Decode(Copy(Body, 6, MaxInt));
    Exit(fbReply);
  end;
  Result := fbOther;
end;

function F2lNextApc(const Text: AnsiString; var P: Integer; out Body: AnsiString): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  Body := '';
  I := P;
  while I < Length(Text) do
  begin
    if (Text[I] = #27) and (Text[I + 1] = '_') then
    begin
      J := I + 2;
      while J <= Length(Text) do
      begin
        if Text[J] = #7 then
        begin
          Body := Copy(Text, I + 2, J - I - 2);
          P := J + 1;
          Exit(True);
        end;
        if (Text[J] = #27) and (J < Length(Text)) and (Text[J + 1] = '\') then
        begin
          Body := Copy(Text, I + 2, J - I - 2);
          P := J + 2;
          Exit(True);
        end;
        Inc(J);
      end;
      Exit;
    end;
    Inc(I);
  end;
end;

{ --- the events ------------------------------------------------------------------------------------------------ }

function F2lDecodeInput(var S: TF2lStack; out Ev: TF2lInput): Boolean;
var
  V: Word;
begin
  FillChar(Ev, SizeOf(Ev), 0);
  if S.Size = 0 then
    Exit(False);
  Ev.Code := Chr(S.PopU8);
  case Ev.Code of
    f2eKeyDown, f2eKeyUp:
      begin
        Ev.Kind := fiKey;
        Ev.Down := Ev.Code = f2eKeyDown;
        Ev.Ch := S.PopU32;
        Ev.KeyState := S.PopU32;
        Ev.Scan := S.PopU16;
        Ev.Vk := S.PopU16;
        Ev.Repeat_ := S.PopU16;
      end;
    f2eKeyDownCompact, f2eKeyUpCompact:
      begin
        Ev.Kind := fiKey;
        Ev.Down := Ev.Code = f2eKeyDownCompact;
        Ev.Ch := S.PopU16;
        Ev.KeyState := S.PopU16;
        Ev.Vk := S.PopU8;
        Ev.Repeat_ := 1;
      end;
    f2eMouse:
      begin
        Ev.Kind := fiMouse;
        Ev.MouseFlags := S.PopU32;
        Ev.KeyState := S.PopU32;
        Ev.Buttons := S.PopU32;
        Ev.Y := S.PopI16;
        Ev.X := S.PopI16;
      end;
    f2eMouseCompact:
      begin
        Ev.Kind := fiMouse;
        Ev.MouseFlags := S.PopU8;
        Ev.KeyState := S.PopU8;
        V := S.PopU16;
        Ev.Buttons := (V and $FF) or ((LongWord(V) and $FF00) shl 8);
        Ev.Y := S.PopI16;
        Ev.X := S.PopI16;
      end;
    f2eSize:
      begin
        Ev.Kind := fiSize;
        Ev.Rows := S.PopU16;
        Ev.Cols := S.PopU16;
      end;
  else
    Exit(False);
  end;
  Result := not S.Bad;
end;

function F2lKeySeq(Down: Boolean; Ch, KeyState: LongWord; Scan, Vk, Repeat_: Word; Compact: Boolean): AnsiString;
const
  RightShiftScan = 54;
var
  S: TF2lStack;
begin
  S.Clear;
  if Compact and (Repeat_ <= 1) and (Scan <> RightShiftScan) and (Ch < $10000) and (KeyState < $10000) and (Vk < $100) then
  begin
    S.PushU8(Vk);
    S.PushU16(KeyState);
    S.PushU16(Ch);
    if Down then S.PushU8(Ord(f2eKeyDownCompact)) else S.PushU8(Ord(f2eKeyUpCompact));
  end
  else
  begin
    S.PushU16(Repeat_);
    S.PushU16(Vk);
    S.PushU16(Scan);
    S.PushU32(KeyState);
    S.PushU32(Ch);
    if Down then S.PushU8(Ord(f2eKeyDown)) else S.PushU8(Ord(f2eKeyUp));
  end;
  Result := F2lEventSeq(S);
end;

function F2lMouseSeq(Flags, KeyState, Buttons: LongWord; X, Y: SmallInt; Compact: Boolean): AnsiString;
var
  S: TF2lStack;
begin
  S.Clear;
  S.PushU16(Word(X));
  S.PushU16(Word(Y));
  if Compact and ((Buttons and $FF00FF00) = 0) and (KeyState < $100) and (Flags < $100) then
  begin
    S.PushU16((Buttons and $FF) or ((Buttons shr 8) and $FF00));
    S.PushU8(KeyState);
    S.PushU8(Flags);
    S.PushU8(Ord(f2eMouseCompact));
  end
  else
  begin
    S.PushU32(Buttons);
    S.PushU32(KeyState);
    S.PushU32(Flags);
    S.PushU8(Ord(f2eMouse));
  end;
  Result := F2lEventSeq(S);
end;

function F2lSizeSeq(Cols, Rows: Word): AnsiString;
var
  S: TF2lStack;
begin
  S.Clear;
  S.PushU16(Cols);
  S.PushU16(Rows);
  S.PushU8(Ord(f2eSize));
  Result := F2lEventSeq(S);
end;

{ --- text ------------------------------------------------------------------------------------------------------ }

function F2lUtf8ToUtf32(const S: AnsiString): AnsiString;
var
  I, Used, N: Integer;
  Cp: LongWord;
begin
  SetLength(Result, Length(S) * 4);
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if not Utf8Decode(@S[I], Length(S) - I + 1, Cp, Used) or (Used < 1) then
    begin
      Cp := $FFFD;
      Used := 1;
    end;
    Result[N + 1] := Chr(Cp and $FF);
    Result[N + 2] := Chr((Cp shr 8) and $FF);
    Result[N + 3] := Chr((Cp shr 16) and $FF);
    Result[N + 4] := Chr((Cp shr 24) and $FF);
    Inc(N, 4);
    Inc(I, Used);
  end;
  SetLength(Result, N);
end;

function F2lUtf32ToUtf8(const S: AnsiString): AnsiString;
var
  I, N, K: Integer;
  Cp: LongWord;
  Buf: array[0..7] of Byte;
begin
  Result := '';
  SetLength(Result, Length(S));
  N := 0;
  I := 1;
  while I + 3 <= Length(S) do
  begin
    Cp := LongWord(Byte(S[I])) or (LongWord(Byte(S[I + 1])) shl 8) or (LongWord(Byte(S[I + 2])) shl 16) or (LongWord(Byte(S[I + 3])) shl 24);
    if Cp = 0 then
      Break;
    if (Cp > $10FFFF) or ((Cp >= $D800) and (Cp <= $DFFF)) then
      Cp := $FFFD;
    K := Utf8Encode(Cp, @Buf[0]);
    if N + K > Length(Result) then
      SetLength(Result, N + K + 64);
    Move(Buf[0], Result[N + 1], K);
    Inc(N, K);
    Inc(I, 4);
  end;
  SetLength(Result, N);
end;

{ --- the client ID --------------------------------------------------------------------------------------------- }

function F2lConfigDir: AnsiString;
begin
  Result := GetEnvironmentVariable('TV_CONFIG_DIR');
  if Result = '' then
    Result := AppDirPath(adConfig, 'tv');
  Result := ExcludeTrailingPathDelimiter(Result);
end;

function F2lValidClientId(const Id: AnsiString): Boolean;
var
  I: Integer;
begin
  Result := (Length(Id) >= 32) and (Length(Id) <= 256);
  if Result then
    for I := 1 to Length(Id) do
      if not (Id[I] in ['0'..'9', 'a'..'z', '-', '_']) then
        Exit(False);
end;

function HostName: AnsiString;
begin
  {$IFDEF UNIX}
  Result := GetHostName;
  {$ELSE}
  Result := GetEnvironmentVariable('COMPUTERNAME');
  {$ENDIF}
end;

function F2lNewClientId: AnsiString;
const
  Alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
var
  H, Rnd: AnsiString;
  I, F: Integer;
  C: Char;
begin
  H := LowerCase(HostName);
  if Length(H) > 30 then
    SetLength(H, 30);
  for I := 1 to Length(H) do
    if not (H[I] in ['0'..'9', 'a'..'z', '-', '_']) then
      H[I] := '_';
  Result := H + '-';
  SetLength(Rnd, 64 - Length(Result));
  FillChar(Rnd[1], Length(Rnd), 0);
  F := FileOpen('/dev/urandom', fmOpenRead);
  if F >= 0 then
  begin
    if FileRead(F, Rnd[1], Length(Rnd)) <> Length(Rnd) then
      FillChar(Rnd[1], Length(Rnd), 0);
    FileClose(F);
  end;
  Randomize;
  for I := 1 to Length(Rnd) do
  begin
    C := Alphabet[1 + ((Byte(Rnd[I]) + Random(256)) mod Length(Alphabet))];
    Rnd[I] := C;
  end;
  Result := Result + Rnd;
end;

function F2lLoadClientId: AnsiString;
var
  Dir, Name: AnsiString;
  T: TextFile;
begin
  Result := '';
  Dir := F2lConfigDir;
  Name := Dir + PathDelim + F2lClientIdFile;
  if FileExists(Name) then
  begin
    AssignFile(T, Name);
    {$I-}
    Reset(T);
    if IOResult = 0 then
    begin
      ReadLn(T, Result);
      CloseFile(T);
    end;
    {$I+}
    IOResult;
    Result := Trim(Result);
    if F2lValidClientId(Result) then
      Exit;
  end;
  Result := F2lNewClientId;
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  AssignFile(T, Name);
  {$I-}
  Rewrite(T);
  if IOResult = 0 then
  begin
    WriteLn(T, Result);
    CloseFile(T);
    {$IFDEF UNIX}
    FpChmod(Name, &600);
    {$ENDIF}
  end;
  {$I+}
  IOResult;
end;

{ --- the client ------------------------------------------------------------------------------------------------ }

constructor TF2lClient.Create;
begin
  inherited Create;
  NextId := 0;
  ReplyMs := 3000;
  AuthMs := 30000;
end;

procedure TF2lClient.Activated;
begin
  Active := True;
  MaxKnown := False;
  FKeysAsked := False;
  FKeysOk := False;
  FKeysLast := '';
  FKeysSent := False;
  Cache := nil;
end;

procedure TF2lClient.Deactivated;
begin
  Active := False;
  Cache := nil;
end;

function TF2lClient.NewId: Byte;
begin
  Inc(NextId);
  if NextId = 0 then
    NextId := 1;
  Result := NextId;
end;

function TF2lClient.Call(var Args: TF2lStack; Cmd: Char; out Reply: TF2lStack; TimeoutMs: Integer): Boolean;
var
  Id: Byte;
begin
  Reply.Clear;
  if not Active then
    Exit(False);
  if TimeoutMs <= 0 then
    TimeoutMs := ReplyMs;
  Id := NewId;
  Args.PushU8(Ord(Cmd));
  Args.PushU8(Id);
  Send(F2lRequestSeq(Args));
  Result := WaitReply(Id, TimeoutMs, Reply);
end;

procedure TF2lClient.Post(var Args: TF2lStack; Cmd: Char);
begin
  if not Active then
    Exit;
  Args.PushU8(Ord(Cmd));
  Args.PushU8(0);
  Send(F2lRequestSeq(Args));
end;

procedure TF2lClient.SetFeatures(Flags: QWord);
var
  A: TF2lStack;
begin
  A.Clear;
  A.PushU64(Flags);
  Post(A, f2rFeatures);
end;

procedure TF2lClient.Notify(const Title, Text: AnsiString);
var
  A: TF2lStack;
begin
  A.Clear;
  A.PushStr(Text);
  A.PushStr(Title);
  Post(A, f2rNotify);
end;

function TF2lClient.SetFKeyTitles(const Titles: array of AnsiString): Boolean;
var
  A, R: TF2lStack;
  I: Integer;
  Key: AnsiString;
  Any: Boolean;
begin
  if not Active or (FKeysAsked and not FKeysOk) then
    Exit(False);
  Key := '';
  Any := False;
  for I := 0 to 11 do
    if I <= High(Titles) then
    begin
      Key := Key + Titles[I] + #0;
      if Titles[I] <> '' then
        Any := True;
    end
    else
      Key := Key + #0;
  if FKeysSent and (Key = FKeysLast) then
    Exit(FKeysOk);
  A.Clear;
  for I := 11 downto 0 do
    if Any and (I <= High(Titles)) and (Titles[I] <> '') then
    begin
      A.PushStr(Titles[I]);
      A.PushU8(1);
    end
    else
      A.PushU8(0);
  if not FKeysAsked then
  begin
    FKeysAsked := True;
    FKeysOk := Call(A, f2rFKeys, R) and (R.PopU8 = 1) and not R.Bad;
  end
  else
    Post(A, f2rFKeys);
  FKeysSent := True;
  FKeysLast := Key;
  Result := FKeysOk;
end;

function TF2lClient.WindowMaxSize(out Cols, Rows: Integer): Boolean;
var
  A, R: TF2lStack;
  H, W: SmallInt;
begin
  Cols := 0;
  Rows := 0;
  if not Active then
    Exit(False);
  if not MaxKnown then
  begin
    A.Clear;
    if not Call(A, f2rMaxSize, R) then
      Exit(False);
    H := R.PopI16;
    W := R.PopI16;
    if R.Bad or (H <= 0) or (W <= 0) then
      Exit(False);
    MaxRows := H;
    MaxCols := W;
    MaxKnown := True;
  end;
  Cols := MaxCols;
  Rows := MaxRows;
  Result := True;
end;

procedure TF2lClient.WindowMaximize(Maximize: Boolean);
var
  A: TF2lStack;
begin
  A.Clear;
  if Maximize then
    Post(A, f2rMaximize)
  else
    Post(A, f2rRestore);
end;

procedure TF2lClient.QuickEdit;
var
  A: TF2lStack;
begin
  A.Clear;
  Post(A, f2rQuickEdit);
end;

procedure TF2lClient.SetCursorHeight(Percent: Integer);
var
  A: TF2lStack;
begin
  if Percent < 0 then
    Percent := 0;
  if Percent > 100 then
    Percent := 100;
  A.Clear;
  A.PushU8(Percent);
  Post(A, f2rCursorHeight);
end;

function TF2lClient.ColorBits(TimeoutMs: Integer): Integer;
var
  A, R: TF2lStack;
begin
  Result := 0;
  A.Clear;
  if Call(A, f2rPalette, R, TimeoutMs) then
  begin
    Result := R.PopU8;
    if R.Bad then
      Result := 0;
  end;
end;

{ the clipboard }

function TF2lClient.CacheFind(Format: LongWord): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Cache) do
    if Cache[I].Format = Format then
      Exit(I);
  Result := -1;
end;

procedure TF2lClient.CachePut(Format: LongWord; Id: QWord; const Data: AnsiString);
var
  I: Integer;
begin
  if Id = 0 then
  begin
    CacheDrop(Format);
    Exit;
  end;
  I := CacheFind(Format);
  if I < 0 then
  begin
    I := Length(Cache);
    SetLength(Cache, I + 1);
  end;
  Cache[I].Format := Format;
  Cache[I].Id := Id;
  Cache[I].Data := Data;
end;

procedure TF2lClient.CacheDrop(Format: LongWord);
var
  I: Integer;
begin
  I := CacheFind(Format);
  if I >= 0 then
  begin
    Cache[I] := Cache[High(Cache)];
    SetLength(Cache, Length(Cache) - 1);
  end;
end;

function TF2lClient.ClipOpen: Boolean;
var
  A, R: TF2lStack;
  Status: ShortInt;
  Wait: Integer;
begin
  Result := False;
  if not Active or ClipDenied then
    Exit;
  if ClientId = '' then
    ClientId := F2lLoadClientId;
  A.Clear;
  A.PushStr(ClientId);
  A.PushU8(Ord(f2cOpen));
  if Authorized then
    Wait := ReplyMs
  else
    Wait := AuthMs;
  if not Call(A, f2rClipboard, R, Wait) then
    Exit;
  Status := R.PopI8;
  if R.Bad then
    Exit;
  if Status = -1 then
    ClipDenied := True;
  if Status <> 1 then
    Exit;
  ClipFeatures := R.PopU64;
  if R.Bad then
    ClipFeatures := 0;
  Authorized := True;
  Result := True;
end;

procedure TF2lClient.ClipClose;
var
  A: TF2lStack;
begin
  A.Clear;
  A.PushU8(Ord(f2cClose));
  Post(A, f2rClipboard);
end;

function TF2lClient.SetOne(Format: LongWord; const Data: AnsiString): Boolean;
var
  A, R: TF2lStack;
  P, N, Count: Integer;
  Id: QWord;
begin
  P := 1;
  Count := 0;
  if ((ClipFeatures and F2lClipChunkedSet) <> 0) and (Length(Data) > F2lChunkSize) then
    while Length(Data) - P + 1 > F2lChunkSize do
    begin
      A.Clear;
      A.PushRaw(Copy(Data, P, F2lChunkSize));
      A.PushU16(F2lChunkSize shr 8);
      A.PushU8(Ord(f2cSetChunk));
      Inc(Count);
      if Count mod F2lChunksPerWait = 0 then
      begin
        if not Call(A, f2rClipboard, R) then
          Exit(False);
      end
      else
        Post(A, f2rClipboard);
      Inc(P, F2lChunkSize);
    end;
  N := Length(Data) - P + 1;
  A.Clear;
  A.PushRaw(Copy(Data, P, N));
  A.PushU32(N);
  A.PushU32(Format);
  A.PushU8(Ord(f2cSetData));
  if not Call(A, f2rClipboard, R) then
    Exit(False);
  Result := (R.PopI8 = 1) and not R.Bad;
  Id := 0;
  if Result and ((ClipFeatures and F2lClipDataId) <> 0) then
  begin
    Id := R.PopU64;
    if R.Bad then
      Id := 0;
  end;
  CachePut(Format, Id, Data);
end;

function TF2lClient.ClipSet(const Formats: array of LongWord; const Datas: array of AnsiString): Boolean;
var
  A: TF2lStack;
  I, J: Integer;
  F: LongWord;
  HasText: Boolean;
begin
  if not ClipOpen then
    Exit(False);
  A.Clear;
  A.PushU8(Ord(f2cEmpty));
  Post(A, f2rClipboard);
  Cache := nil;
  HasText := False;
  for I := 0 to High(Formats) do
    if Formats[I] = F2lCfText then
      HasText := True;
  Result := True;
  for I := 0 to High(Formats) do
  begin
    F := Formats[I];
    if F = F2lCfUnicodeText then
    begin
      if HasText then
        Continue;                  { the text goes once, as CF_TEXT }
      F := F2lCfText;
      HasText := True;
    end;
    J := I;
    if J > High(Datas) then
      Break;
    if not SetOne(F, Datas[J]) then
      Result := False;
  end;
  ClipClose;
end;

function TF2lClient.GetOne(Format: LongWord; out Data: AnsiString): Boolean;
var
  A, R: TF2lStack;
  I: Integer;
  Size: LongWord;
  Id: QWord;
begin
  Data := '';
  Result := False;
  I := CacheFind(Format);
  if (I >= 0) and ((ClipFeatures and F2lClipDataId) <> 0) then
  begin
    A.Clear;
    A.PushU32(Format);
    A.PushU8(Ord(f2cGetDataId));
    if Call(A, f2rClipboard, R) then
    begin
      Id := R.PopU64;
      if R.Bad then
        Id := 0;
      if Id = 0 then
        Exit(False);                { no data (or not allowed now) }
      if Id = Cache[I].Id then
      begin
        Data := Cache[I].Data;
        Exit(True);
      end;
    end;
    CacheDrop(Format);
  end;
  A.Clear;
  A.PushU32(Format);
  A.PushU8(Ord(f2cGetData));
  if not Call(A, f2rClipboard, R) then
    Exit;
  Size := R.PopU32;
  if R.Bad or (Size = $FFFFFFFF) or (Size = 0) or (Size > LongWord(R.Size)) then
    Exit;
  Data := R.PopRaw(Size);
  Id := 0;
  if (ClipFeatures and F2lClipDataId) <> 0 then
  begin
    Id := R.PopU64;
    if R.Bad then
      Id := 0;
  end;
  CachePut(Format, Id, Data);
  Result := True;
end;

function TF2lClient.ClipGet(Format: LongWord; out Data: AnsiString): Boolean;
begin
  Data := '';
  if not ClipOpen then
    Exit(False);
  if (Format = F2lCfText) or (Format = F2lCfUnicodeText) then
  begin
    Result := GetOne(F2lCfText, Data);
    if Result then
    begin
      while (Data <> '') and (Data[Length(Data)] = #0) do
        SetLength(Data, Length(Data) - 1);
      Result := Data <> '';
    end;
    if not Result then
    begin
      Result := GetOne(F2lCfUnicodeText, Data);
      if Result then
      begin
        Data := F2lUtf32ToUtf8(Data);
        Result := Data <> '';
      end;
    end;
  end
  else
    Result := GetOne(Format, Data);
  ClipClose;
end;

function TF2lClient.ClipHas(Format: LongWord; out Avail: Boolean): Boolean;
var
  A, R: TF2lStack;
begin
  Avail := False;
  if not ClipOpen then
    Exit(False);
  if Format = F2lCfUnicodeText then
    Format := F2lCfText;
  A.Clear;
  A.PushU32(Format);
  A.PushU8(Ord(f2cIsAvail));
  Result := Call(A, f2rClipboard, R);
  if Result then
  begin
    Avail := (R.PopI8 = 1) and not R.Bad;
    if not Avail then
      CacheDrop(Format);
  end;
  ClipClose;
end;

function TF2lClient.ClipRegister(const Name: AnsiString): LongWord;
var
  A, R: TF2lStack;
  I: Integer;
begin
  for I := 0 to High(Registered) do
    if Registered[I].Name = Name then
      Exit(Registered[I].Id);
  Result := 0;
  A.Clear;
  A.PushStr(Name);
  A.PushU8(Ord(f2cRegister));
  if Call(A, f2rClipboard, R) then
  begin
    Result := R.PopU32;
    if R.Bad then
      Result := 0;
  end;
  if Result <> 0 then
  begin
    I := Length(Registered);
    SetLength(Registered, I + 1);
    Registered[I].Name := Name;
    Registered[I].Id := Result;
  end;
end;

end.
