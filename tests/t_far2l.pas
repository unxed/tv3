program t_far2l;
{ The far2l terminal extensions, the client side: Base64, the stack, the APC strings against the worked examples of the specification (section 7),
  the requests of TF2lClient, the events and the replies in the input parser. }
{$I ../src/tvdefs.inc}
uses SysUtils, TvEvents, TvKeys, TvCodePg, TvClip, TvTermIO, TvFar2l;
{$I testlib.inc}

const
  E = #27;
  Bel = #7;
  St = #27'\';

{ the bytes of a stack in hex, bottom first, as the specification shows them }
function Hex(const S: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    if I > 1 then
      Result := Result + ' ';
    Result := Result + LowerCase(IntToHex(Byte(S[I]), 2));
  end;
end;

{ a request as the client writes it (ST) compared with an example (BEL) }
function SameRequest(const Sent, Example: AnsiString): Boolean;
begin
  Result := (Copy(Sent, Length(Sent) - 1, 2) = St) and (Copy(Sent, 1, Length(Sent) - 2) = Copy(Example, 1, Length(Example) - 1));
end;

{ --- a client whose terminal is a list of replies ----------------------------------------------------------------- }

type
  TScriptClient = class(TF2lClient)
  protected
    procedure Send(const S: AnsiString); override;
    function WaitReply(Id: Byte; TimeoutMs: Integer; out Reply: TF2lStack): Boolean; override;
  public
    Sent: array of AnsiString;
    Replies: array of AnsiString;
    Taken: Integer;
    procedure Answer(const Wire: AnsiString);
  end;

procedure TScriptClient.Send(const S: AnsiString);
begin
  SetLength(Sent, Length(Sent) + 1);
  Sent[High(Sent)] := S;
end;

procedure TScriptClient.Answer(const Wire: AnsiString);
begin
  SetLength(Replies, Length(Replies) + 1);
  Replies[High(Replies)] := Wire;
end;

function TScriptClient.WaitReply(Id: Byte; TimeoutMs: Integer; out Reply: TF2lStack): Boolean;
var
  Body: AnsiString;
begin
  Reply.Clear;
  Result := False;
  while Taken < Length(Replies) do
  begin
    Body := Copy(Replies[Taken], 3, Length(Replies[Taken]) - 3);
    Inc(Taken);
    if (F2lClassify(Body, Reply) = fbReply) and (Reply.PopU8 = Id) then
      Exit(True);
  end;
end;

{ --- the input parser ---------------------------------------------------------------------------------------- }

var
  Bytes: AnsiString;
  BytePos: Integer;
  Input: TTermInput;
  State: TInputState;

function Reader(TimeoutMs: Integer): Integer;
begin
  if BytePos <= Length(Bytes) then
  begin
    Result := Ord(Bytes[BytePos]);
    Inc(BytePos);
  end
  else
    Result := -1;
end;

function Parse(const S: AnsiString; var Ev: TEvent): Boolean;
begin
  Bytes := S;
  BytePos := 1;
  Input.Init(@Reader, 1);
  Result := ParseEvent(Input, Ev, State);
end;

var
  S: TF2lStack;
  Ev: TEvent;
  In_: TF2lInput;
  C: TScriptClient;
  T: AnsiString;
  Kind: TF2lBodyKind;
  Cols, Rows: Integer;
  Big: AnsiString;
  I: Integer;
begin
  CpSelect(cpIdCp866);
  FillChar(State, SizeOf(State), 0);

  { Base64 }
  Check(F2lBase64Encode('') = '', 'an empty stack is an empty string');
  Check(F2lBase64Encode('a') = 'YQ==', 'one byte: two pads');
  Check(F2lBase64Encode('ab') = 'YWI=', 'two bytes: one pad');
  Check(F2lBase64Encode('abc') = 'YWJj', 'three bytes: no pad');
  Check(F2lBase64Decode('YWJj') = 'abc', 'decoded');
  Check(F2lBase64Decode('YQ') = 'a', 'the padding is not required');
  Check(F2lBase64Decode('YQ==YWJj') = 'a', 'the decoder stops at =');
  Check(F2lBase64Decode('YW:Jj') = 'a', 'and at a character outside the alphabet');
  SetLength(Big, 1000);
  for I := 1 to Length(Big) do
    Big[I] := Chr(I * 7 mod 256);
  Check(F2lBase64Decode(F2lBase64Encode(Big)) = Big, 'all byte values come back');

  { the stack }
  S.Clear;
  S.PushU8($11); S.PushU16($2233); S.PushU32($44556677); S.PushU64($8899AABBCCDDEEFF);
  Check(Hex(S.Data) = '11 33 22 77 66 55 44 ff ee dd cc bb aa 99 88', 'little-endian, pushed at the end');
  Check(S.PopU64 = $8899AABBCCDDEEFF, 'popped from the end: 64 bits');
  Check(S.PopU32 = $44556677, '32 bits');
  Check(S.PopU16 = $2233, '16 bits');
  Check((S.PopU8 = $11) and not S.Bad and (S.Size = 0), '8 bits, empty');
  S.PopU8;
  Check(S.Bad, 'a pop from an empty stack is an error');
  S.Clear;
  S.PushStr('Done');
  Check(Hex(S.Data) = '44 6f 6e 65 04 00 00 00', 'a string: its bytes, then its length');
  Check((S.PopStr = 'Done') and not S.Bad, 'popped back');
  S.Clear;
  S.PushU32(100);
  S.PopStr;
  Check(S.Bad, 'a string longer than the stack is an error');
  S.Clear;
  S.PushU16($FFFF);
  Check(S.PopI16 = -1, 'int16');

  { 7.1: the cursor height }
  S.Clear;
  S.PushU8(50); S.PushU8(Ord('h')); S.PushU8(0);
  Check(Hex(S.Data) = '32 68 00', 'cursor height: the stack');
  Check(F2lRequestSeq(S) = E + '_far2l:MmgA' + St, 'cursor height: the request (ST)');
  { 7.2 }
  S.Clear;
  S.PushU8(Ord('w')); S.PushU8(1);
  Check(F2lRequestSeq(S) = E + '_far2l:dwE=' + St, 'max size: the request');
  S.Clear;
  S.PushU16(200); S.PushU16(50); S.PushU8(1);
  Check(F2lReplySeq(S) = E + '_far2lyAAyAAE=' + Bel, 'max size: the reply (BEL, no colon)');
  { 7.3 }
  S.Clear;
  S.PushStr('OK'); S.PushStr('Done'); S.PushU8(Ord('n')); S.PushU8(0);
  Check(Hex(S.Data) = '4f 4b 02 00 00 00 44 6f 6e 65 04 00 00 00 6e 00', 'notification: the stack');
  Check(F2lBase64Encode(S.Data) = 'T0sCAAAARG9uZQQAAABuAA==', 'notification: Base64');
  { 7.7 }
  S.Clear;
  S.PushU64(1); S.PushU8(Ord('x')); S.PushU8(0);
  Check(F2lBase64Encode(S.Data) = 'AQAAAAAAAAB4AA==', 'features');

  { the classification of what the terminal sends }
  Check(F2lClassify('far2lok', S) = fbAck, 'the acknowledgement');
  Kind := F2lClassify('far2lyAAyAAE=', S);
  Check((Kind = fbReply) and (Hex(S.Data) = 'c8 00 32 00 01'), 'a reply and its stack');
  Kind := F2lClassify('f2lUAAZAFM=', S);
  Check((Kind = fbEvent) and (Hex(S.Data) = '50 00 19 00 53'), 'an event and its stack');
  Kind := F2lClassify('f2l:UAAZAFM=', S);
  Check((Kind = fbEvent) and (S.Size = 0), 'a colon after f2l makes the payload empty');
  Check(F2lClassify('Gsomething', S) = fbOther, 'another APC string');

  { 7.8: the events, decoded }
  F2lClassify('f2lAQBBAB4AAAAAAGEAAABL', S);
  Check(F2lDecodeInput(S, In_) and (In_.Kind = fiKey) and In_.Down and (In_.Ch = $61) and (In_.Vk = $41) and (In_.Scan = $1E) and
    (In_.Repeat_ = 1) and (In_.KeyState = 0), 'K: the key press of a');
  F2lClassify('f2lQQAAYQBD', S);
  Check(F2lDecodeInput(S, In_) and (In_.Kind = fiKey) and In_.Down and (In_.Ch = $61) and (In_.Vk = $41) and (In_.Repeat_ = 1), 'C: compact');
  F2lClassify('f2lCgAFAAEAAABt', S);
  Check(F2lDecodeInput(S, In_) and (In_.Kind = fiMouse) and (In_.X = 10) and (In_.Y = 5) and (In_.Buttons = 1) and (In_.MouseFlags = 0),
    'm: the left button at 10, 5');
  F2lClassify('f2lCgAFAAAA//8AAAAABAAAAE0=', S);
  Check(F2lDecodeInput(S, In_) and (In_.MouseFlags = 4) and (In_.Buttons = $FFFF0000), 'M: the wheel down');
  F2lClassify('f2lUAAZAFM=', S);
  Check(F2lDecodeInput(S, In_) and (In_.Kind = fiSize) and (In_.Cols = 80) and (In_.Rows = 25), 'S: 80 by 25');
  F2lClassify('f2lAQ==', S);
  Check(not F2lDecodeInput(S, In_), 'an unknown event code');
  F2lClassify('f2lQQBD', S);
  Check(not F2lDecodeInput(S, In_), 'a truncated event');

  { 7.8: the events, built (the server side uses them) }
  Check(F2lKeySeq(True, $61, 0, $1E, $41, 1, False) = E + '_f2lAQBBAB4AAAAAAGEAAABL' + Bel, 'K built');
  Check(F2lKeySeq(True, $61, 0, $1E, $41, 1, True) = E + '_f2lQQAAYQBD' + Bel, 'C built when the client asked for it');
  Check(Copy(F2lKeySeq(True, $61, 0, 54, $10, 1, True), 1, 5) = E + '_f2l', 'the right Shift');
  Check(F2lKeySeq(True, $61, 0, 54, $10, 1, True) = F2lKeySeq(True, $61, 0, 54, $10, 1, False), 'the right Shift is never compact');
  Check(F2lKeySeq(True, $1F600, 0, 0, $E7, 1, True) = F2lKeySeq(True, $1F600, 0, 0, $E7, 1, False), 'nor a character above 16 bits');
  Check(F2lMouseSeq(0, 0, 1, 10, 5, True) = E + '_f2lCgAFAAEAAABt' + Bel, 'm built');
  Check(F2lMouseSeq(4, 0, $FFFF0000, 10, 5, True) = E + '_f2lCgAFAAAA//8AAAAABAAAAE0=' + Bel, 'the wheel down is never compact');
  Check(F2lSizeSeq(80, 25) = E + '_f2lUAAZAFM=' + Bel, 'S built');

  { the requests of the client against the examples }
  C := TScriptClient.Create;
  C.ClientId := '0123456789abcdef0123456789abcdef';
  C.Post(S, 'x');                                      { not active: nothing is sent }
  Check(Length(C.Sent) = 0, 'nothing is sent before the acknowledgement');
  C.Activated;
  C.SetCursorHeight(50);
  Check(C.Sent[0] = E + '_far2l:MmgA' + St, 'SetCursorHeight: example 7.1');
  C.Notify('Done', 'OK');
  Check(SameRequest(C.Sent[1], E + '_far2l:T0sCAAAARG9uZQQAAABuAA==' + Bel), 'Notify: example 7.3');
  C.SetFeatures(F2lFeatCompactInput);
  Check(SameRequest(C.Sent[2], E + '_far2l:AQAAAAAAAAB4AA==' + Bel), 'SetFeatures: example 7.7');
  { the clipboard: open (ID 1), empty (ID 0), set (ID 2), close (ID 0) }
  C.Sent := nil;
  C.Answer(E + '_far2lAwAAAAAAAAABAQ==' + Bel);
  C.Answer(E + '_far2liHdmVUQzIhEBAg==' + Bel);
  Check(C.ClipSet([cfText], ['hello']), 'ClipSet: success');
  Check(Length(C.Sent) = 4, 'four requests');
  Check(SameRequest(C.Sent[0], E + '_far2l:MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWYgAAAAb2MB' + Bel), 'CLIP_OPEN: example 7.5');
  T := F2lBase64Decode(Copy(C.Sent[1], 9, Length(C.Sent[1]) - 10));
  Check(Hex(T) = '65 63 00', 'CLIP_EMPTY with ID 0');
  Check(SameRequest(C.Sent[2], E + '_far2l:aGVsbG8FAAAAAQAAAHNjAg==' + Bel), 'CLIP_SETDATA: example 7.5');
  Check(SameRequest(C.Sent[3], E + '_far2l:Y2MA' + Bel), 'CLIP_CLOSE: example 7.5');
  { the data ID of the reply is cached: a read asks for the ID only and takes the cached data }
  C.Sent := nil;
  C.Answer(E + '_far2lAwAAAAAAAAABAw==' + Bel);       { open, ID 3: 1, features 3 }
  S.Clear; S.PushU64($1122334455667788); S.PushU8(4);
  C.Answer(F2lReplySeq(S));                            { the data ID, ID 4 }
  Check(C.ClipGet(cfText, T) and (T = 'hello'), 'ClipGet: the cache');
  T := F2lBase64Decode(Copy(C.Sent[1], 9, Length(C.Sent[1]) - 10));
  Check(Hex(T) = '01 00 00 00 69 63 04', 'CLIP_GETDATAID for CF_TEXT');
  Check(Length(C.Sent) = 3, 'and no CLIP_GETDATA');
  { another data ID: the data is read }
  C.Sent := nil;
  C.Answer(E + '_far2lAwAAAAAAAAABBQ==' + Bel);       { open, ID 5 }
  S.Clear; S.PushU64(7); S.PushU8(6);
  C.Answer(F2lReplySeq(S));                            { another ID, ID 6 }
  S.Clear; S.PushU64(7); S.PushRaw('world'); S.PushU32(5); S.PushU8(7);
  C.Answer(F2lReplySeq(S));                            { the data, ID 7 }
  Check(C.ClipGet(cfText, T) and (T = 'world'), 'a changed data ID: the data is read again');
  T := F2lBase64Decode(Copy(C.Sent[2], 9, Length(C.Sent[2]) - 10));
  Check(Hex(T) = '01 00 00 00 67 63 07', 'CLIP_GETDATA: example 7.5 with ID 7');
  { no data: an ID of 0 }
  C.Sent := nil;
  C.Answer(E + '_far2lAwAAAAAAAAABCA==' + Bel);       { open, ID 8 }
  S.Clear; S.PushU64(0); S.PushU8(9);
  C.Answer(F2lReplySeq(S));
  S.Clear; S.PushU64(0); S.PushU32(0); S.PushU8(10);
  C.Answer(F2lReplySeq(S));                            { CF_UNICODETEXT is tried then: nothing either }
  Check(not C.ClipGet(cfText, T), 'an ID of 0 is no data (or no paste gesture)');
  Check(Length(C.Sent) = 4, 'CF_UNICODETEXT was asked for');
  { a refusal for good: "use your own clipboard" }
  C.Sent := nil;
  S.Clear; S.PushU64(0); S.PushU8($FF); S.PushU8(11);
  C.Answer(F2lReplySeq(S));
  Check(not C.ClipSet([cfText], ['x']) and C.ClipDenied, 'status -1: the client keeps its own clipboard');
  C.Sent := nil;
  Check(not C.ClipSet([cfText], ['x']) and (Length(C.Sent) = 0), 'and does not ask again');
  C.Free;

  { a format registered, F-key titles, the window, the colors }
  C := TScriptClient.Create;
  C.Activated;
  for I := 1 to 3 do
    C.Post(S, 'x');                                    { IDs are not used by posts }
  C.Sent := nil;
  S.Clear; S.PushU32($C000); S.PushU8(1);
  C.Answer(F2lReplySeq(S));
  Check(C.ClipRegister('FAR_VerticalBlock_Unicode') = $C000, 'CLIP_REGISTER_FORMAT');
  Check(SameRequest(C.Sent[0], E + '_far2l:RkFSX1ZlcnRpY2FsQmxvY2tfVW5pY29kZRkAAAByYw' + 'E=' + Bel), 'its request (ID 1)');
  Check(C.ClipRegister('FAR_VerticalBlock_Unicode') = $C000, 'remembered');
  Check(Length(C.Sent) = 1, 'and not asked again');
  C.Sent := nil;
  C.Answer(E + '_far2lAQI=' + Bel);                   { success, ID 2 }
  Check(C.SetFKeyTitles(['Help', 'Menu']), 'F-key titles: the terminal shows them');
  Check(SameRequest(C.Sent[0], E + '_far2l:AAAAAAAAAAAAAE1lbnUEAAAAAUhlbHAEAAAAAWYC' + Bel), 'the request: example 7.4 with ID 2');
  Check(C.SetFKeyTitles(['Help', 'Menu']) and (Length(C.Sent) = 1), 'the same titles are not sent again');
  C.SetFKeyTitles(['Help', 'Edit']);
  T := F2lBase64Decode(Copy(C.Sent[1], 9, Length(C.Sent[1]) - 10));
  Check((Length(C.Sent) = 2) and (Copy(T, Length(T) - 1, 2) = 'f'#0), 'after a yes: ID 0');
  C.Sent := nil;
  C.Answer(E + '_far2lyAAyAAM=' + Bel);               { 200 by 50, ID 3 }
  Check(C.WindowMaxSize(Cols, Rows) and (Cols = 200) and (Rows = 50), 'GET_WINDOW_MAXSIZE: example 7.2');
  Check(C.WindowMaxSize(Cols, Rows) and (Length(C.Sent) = 1), 'cached');
  C.WindowMaximize(True);
  C.WindowMaximize(False);
  C.QuickEdit;
  Check((F2lBase64Decode(Copy(C.Sent[1], 9, 4)) = 'M'#0) and (F2lBase64Decode(Copy(C.Sent[2], 9, 4)) = 'm'#0) and
    (F2lBase64Decode(Copy(C.Sent[3], 9, 4)) = 'e'#0), 'maximize, restore, quick edit: ID 0');
  S.Clear; S.PushU8(0); S.PushU8(24); S.PushU8(4);
  C.Answer(F2lReplySeq(S));
  Check(C.ColorBits(100) = 24, 'GET_COLOR_PALETTE');
  Check(C.ColorBits(100) = 0, 'no reply: not known');
  C.Free;

  C := TScriptClient.Create;
  C.Activated;
  C.Answer(E + '_far2lAAE=' + Bel);                   { no, ID 1 }
  Check(not C.SetFKeyTitles(['Help']), 'F-key titles: the terminal does not show them');
  C.Sent := nil;
  Check(not C.SetFKeyTitles(['Other']) and (Length(C.Sent) = 0), 'not asked again in this activation');
  C.Deactivated;
  C.Activated;
  C.Answer(E + '_far2lAQI=' + Bel);
  Check(C.SetFKeyTitles(['Other']), 'asked anew after the next activation');
  C.Free;

  { UTF-32 of CF_UNICODETEXT }
  Check(Hex(F2lUtf8ToUtf32('aЖ')) = '61 00 00 00 16 04 00 00', 'UTF-8 to UTF-32');
  Check(F2lUtf32ToUtf8(F2lUtf8ToUtf32('a😀Ж') + #0#0#0#0'zz') = 'a😀Ж', 'and back, up to the zero');
  { the client ID }
  Check(F2lValidClientId('0123456789abcdef0123456789abcdef'), 'a client ID of 32 characters');
  Check(not F2lValidClientId('0123456789abcdef0123456789abcde'), 'too short');
  Check(not F2lValidClientId('0123456789ABCDEF0123456789abcdef'), 'capitals are not allowed');
  T := F2lNewClientId;
  Check((Length(T) = 64) and F2lValidClientId(T), 'a new client ID: 64 characters');
  Check(F2lNewClientId <> T, 'random');

  { the input parser: events become events }
  Check(Parse(E + '_f2lAQBBAB4AAAAAAGEAAABL' + Bel, Ev) and (Ev.What = evKeyDown) and (EventText(Ev) = 'a') and (Ev.KeyDown.VirtualKey = $41),
    'K: the key a');
  Check(Parse(E + '_f2lQQAAYQBD' + St, Ev) and (Ev.What = evKeyDown) and (EventText(Ev) = 'a'), 'C, ended by ST');
  Check(Parse(F2lKeySeq(True, 0, $08, $3B, $70, 1, True), Ev) and (Ev.KeyDown.KeyCode = kbCtrlF1), 'Ctrl+F1');
  Check(Parse(F2lKeySeq(True, Ord('A'), $10, $1E, $41, 1, True), Ev) and (EventText(Ev) = 'A'), 'Shift+A');
  Check(Parse(F2lKeySeq(True, 1, $08, $1E, $41, 1, True), Ev) and (Ev.KeyDown.KeyCode = kbCtrlA), 'Ctrl+A (the control character)');
  Check(Parse(F2lKeySeq(True, $1F600, 0, 0, $E7, 1, True), Ev) and (EventText(Ev) = '😀'), 'a character above U+FFFF');
  Check(Parse(F2lKeySeq(True, Ord('x'), 0, $2D, $58, 3, False), Ev) and ((Ev.KeyDown.KeyFlags and kfRepeat) <> 0) and (Ev.KeyDown.RepeatCount = 3),
    'a repeat count: kfRepeat');
  State.HeldVk := 0;
  Check(not Parse(F2lKeySeq(False, Ord('a'), 0, $1E, $41, 1, True), Ev), 'a release is dropped when nobody wants it');
  State.ReportKeyUp := True;
  Check(Parse(F2lKeySeq(False, Ord('a'), 0, $1E, $41, 1, True), Ev) and (Ev.What = evKeyUp), 'and is evKeyUp when it is wanted');
  State.ReportModUp := True;
  Check(Parse(F2lKeySeq(False, 0, 0, $1D, $11, 1, True), Ev) and (Ev.What = evKeyUp) and (Ev.KeyDown.KeyCode = 0), 'the release of Ctrl');
  State.ReportKeyUp := False;
  State.ReportModUp := False;
  Check(Parse(E + '_f2lCgAFAAEAAABt' + Bel, Ev) and (Ev.What = evMouse) and (Ev.Mouse.Where.X = 10) and (Ev.Mouse.Where.Y = 5) and
    (Ev.Mouse.Buttons = mbLeftButton), 'm: the left button');
  Check(Parse(F2lMouseSeq(0, 0, 0, 10, 5, True), Ev) and (Ev.What = evMouse) and (Ev.Mouse.Buttons = 0), 'its release');
  Check(Parse(E + '_f2lCgAFAAAA//8AAAAABAAAAE0=' + Bel, Ev) and (Ev.Mouse.Wheel = mwDown), 'M: the wheel down');
  Check(Parse(F2lMouseSeq(4, 0, $00010000, 1, 1, True), Ev) and (Ev.Mouse.Wheel = mwUp), 'the wheel up');
  Check(Parse(F2lMouseSeq(8, 0, $00010000, 1, 1, True), Ev) and (Ev.Mouse.Wheel = mwRight), 'the horizontal wheel');
  Check(Parse(F2lMouseSeq(0, $08, 4, 2, 3, True), Ev) and (Ev.Mouse.Buttons = mbMiddleButton) and ((Ev.KeyDown.ControlKeyState and kbCtrlShift) <> 0),
    'the middle button with Ctrl');
  Check(not Parse(E + '_f2lUAAZAFM=' + Bel, Ev) and (State.Far2lCols = 80) and (State.Far2lRows = 25), 'S: the size goes to the state');
  Check(not Parse(E + '_far2lok' + Bel, Ev) and State.Far2lAck, 'the acknowledgement (BEL)');
  State.Far2lAck := False;
  Check(not Parse(E + '_far2lok' + St, Ev) and State.Far2lAck, 'and ended by ST');
  Check(not Parse(E + '_far2lyAAyAAE=' + Bel, Ev) and State.Far2lHasReply and (Hex(State.Far2lReply) = 'c8 00 32 00 01'), 'a reply');
  Check(not Parse(E + '_f2lAQ==' + Bel, Ev), 'an unknown event is ignored');
  Check(not Parse(E + '_Gi=1;AAAA' + St, Ev), 'another APC string is skipped');
  Check(Parse(E + '_f2lQQAAYQBD' + Bel + 'b', Ev) and (EventText(Ev) = 'a') and Parse(Copy(Bytes, BytePos, MaxInt), Ev) and
    (EventText(Ev) = 'b'), 'the bytes after the string are the next key');
  State.Far2lReply := '';
  Finish;
end.
