program t_vtext;
{ The far2l terminal extensions, the terminal side (TvVtExt in the emulator TvVt): the replies against the worked examples of the specification
  (section 7), the clipboard (authorization, paste gestures, chunks, formats), the events of keys and the mouse, and a client of TvFar2l talking to it. }
{$I ../src/tvdefs.inc}
uses SysUtils, TvEvents, TvKeys, TvClip, TvSys, TvFar2l, TvVt, TvVtExt;
{$I testlib.inc}

const
  E = #27;
  Bel = #7;
  St = #27'\';
  Cid = '0123456789abcdef0123456789abcdef';

type
  TTestHost = class(TVtExtHost)
  public
    Answer: TVtClipAnswer;
    Asked: Integer;
    LastAsked: AnsiString;
    Titles: AnsiString;
    TitleCalls: Integer;
    NoteTitle, NoteText: AnsiString;
    Height: Integer;
    Maxed, Restored, Quick: Integer;
    function AskClipboard(const ClientId: AnsiString): TVtClipAnswer; override;
    procedure Notify(const Title, Text: AnsiString); override;
    function FKeyTitles(const T: array of AnsiString): Boolean; override;
    procedure CursorHeight(Percent: Integer); override;
    function ColorBits: Integer; override;
    function WindowMaxSize(out Cols, Rows: Integer): Boolean; override;
    procedure WindowMaximize(Maximize: Boolean); override;
    procedure QuickEdit; override;
  end;

function TTestHost.AskClipboard(const ClientId: AnsiString): TVtClipAnswer;
begin
  Inc(Asked);
  LastAsked := ClientId;
  Result := Answer;
end;

procedure TTestHost.Notify(const Title, Text: AnsiString);
begin
  NoteTitle := Title;
  NoteText := Text;
end;

function TTestHost.FKeyTitles(const T: array of AnsiString): Boolean;
var
  I: Integer;
begin
  Inc(TitleCalls);
  Titles := '';
  for I := 0 to High(T) do
    Titles := Titles + T[I] + '|';
  Result := True;
end;

procedure TTestHost.CursorHeight(Percent: Integer);
begin
  Height := Percent;
end;

function TTestHost.ColorBits: Integer;
begin
  Result := 24;
end;

function TTestHost.WindowMaxSize(out Cols, Rows: Integer): Boolean;
begin
  Cols := 200;
  Rows := 50;
  Result := True;
end;

procedure TTestHost.WindowMaximize(Maximize: Boolean);
begin
  if Maximize then Inc(Maxed) else Inc(Restored);
end;

procedure TTestHost.QuickEdit;
begin
  Inc(Quick);
end;

var
  TestNow: Int64 = 100000;

function TestClock: Int64;
begin
  Result := TestNow;
end;

{ a client of TvFar2l whose terminal is the emulator }
type
  TLoopClient = class(TF2lClient)
  protected
    procedure Send(const S: AnsiString); override;
    function WaitReply(Id: Byte; TimeoutMs: Integer; out Reply: TF2lStack): Boolean; override;
  public
    Emu: TVtEmu;
    Pending: AnsiString;
  end;

procedure TLoopClient.Send(const S: AnsiString);
begin
  Emu.Feed(S);
  Pending := Pending + Emu.TakeReply;
end;

function TLoopClient.WaitReply(Id: Byte; TimeoutMs: Integer; out Reply: TF2lStack): Boolean;
var
  P: Integer;
  Body: AnsiString;
begin
  Reply.Clear;
  Result := False;
  P := 1;
  while F2lNextApc(Pending, P, Body) do
  begin
    Delete(Pending, 1, P - 1);
    P := 1;
    if (F2lClassify(Body, Reply) = fbReply) and (Reply.PopU8 = Id) then
      Exit(True);
  end;
  Pending := '';
end;

var
  Emu: TVtEmu;
  H: TTestHost;
  Dir, R, Data: AnsiString;
  S, Rs: TF2lStack;
  Fmt, VFmt: LongWord;
  Ev: TEvent;
  Cl: TLoopClient;
  I: Integer;
  Avail: Boolean;

function Req(const Wire: AnsiString): AnsiString;
begin
  Emu.Feed(Wire);
  Result := Emu.TakeReply;
end;

{ a request built from a stack (the ID on top) }
function Ask(var A: TF2lStack): AnsiString;
begin
  Result := Req(F2lRequestSeq(A));
end;

{ the stack of the reply, its ID popped }
function ReplyOf(const Wire: AnsiString; Id: Byte; out Reply: TF2lStack): Boolean;
begin
  Result := (Copy(Wire, Length(Wire), 1) = Bel) and (F2lClassify(Copy(Wire, 3, Length(Wire) - 3), Reply) = fbReply) and (Reply.PopU8 = Id);
end;

procedure ClipReq(Sub: Char; Id: Byte);
begin
  S.PushU8(Ord(Sub));
  S.PushU8(Ord('c'));
  S.PushU8(Id);
end;

function OpenClip(const Client: AnsiString; Id: Byte): ShortInt;
begin
  S.Clear;
  S.PushStr(Client);
  ClipReq('o', Id);
  if not ReplyOf(Ask(S), Id, Rs) then
    Exit(-100);
  Result := ShortInt(Rs.PopU8);
end;

procedure CloseClip;
begin
  S.Clear;
  ClipReq('c', 0);
  Ask(S);
end;

function GetData(Format: LongWord; Id: Byte; out D: AnsiString): LongWord;
begin
  S.Clear;
  S.PushU32(Format);
  ClipReq('g', Id);
  D := '';
  if not ReplyOf(Ask(S), Id, Rs) then
    Exit($FFFFFFFE);
  Result := Rs.PopU32;
  if (Result <> $FFFFFFFF) and (Result > 0) then
    D := Rs.PopRaw(Result);
end;

begin
  Dir := GetTempDir + 'tv3-vtext-' + IntToStr(GetProcessID);
  ForceDirectories(Dir);
  DeleteFile(Dir + '/autheds');
  Emu := TVtEmu.Create(80, 25, 100);
  H := TTestHost.Create;
  Emu.Ext.Host := H;
  Emu.Ext.AuthedsPath := Dir + '/autheds';
  Emu.Ext.Now := @TestClock;

  { before far2l1 nothing is answered }
  Check(Req(E + '_far2l:dwE=' + Bel) = '', 'a request before the activation is ignored');
  Check(Req(E + '_far2l1' + St + E + '[5n') = E + '_far2lok' + Bel + E + '[0n', 'far2lok, before the answer to ESC [ 5 n');
  Check(Emu.Ext.Active, 'active');
  Check(Req(E + '_far2l1' + Bel) = E + '_far2lok' + Bel, 'far2l1 again: answered again (BEL accepted)');
  Check(Req(E + '_far2l_marker' + Bel) = '', 'another string that begins with far2l');
  Check(Req(E + '_far2l:' + Bel) = '', 'an empty request');

  { the examples of section 7 }
  Check(Req(E + '_far2l:MmgA' + Bel) = '', '7.1 cursor height: no reply (ID 0)');
  Check((Emu.Ext.CursorPercent = 50) and (H.Height = 50), 'the height is 50 percent');
  Check(Req(E + '_far2l:dwE=' + Bel) = E + '_far2lyAAyAAE=' + Bel, '7.2 GET_WINDOW_MAXSIZE: the reply of the example');
  Check(Req(E + '_far2l:T0sCAAAARG9uZQQAAABuAA==' + Bel) = '', '7.3 notification: no reply');
  Check((H.NoteTitle = 'Done') and (H.NoteText = 'OK'), 'the title is on top, then the text');
  Check(Req(E + '_far2l:AAAAAAAAAAAAAE1lbnUEAAAAAUhlbHAEAAAAAWYB' + Bel) = E + '_far2lAQE=' + Bel, '7.4 F-key titles: the reply of the example');
  Check(H.Titles = 'Help|Menu|' + StringOfChar('|', 10), 'F1 Help, F2 Menu, the rest none');
  H.Answer := vcaShare;
  Check(Req(E + '_far2l:MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWYgAAAAb2MB' + Bel) = E + '_far2lAwAAAAAAAAABAQ==' + Bel,
    '7.5 CLIP_OPEN: the reply of the example (status 1, features 3)');
  Check((H.Asked = 1) and (H.LastAsked = Cid), 'the user was asked about the client');
  R := Req(E + '_far2l:aGVsbG8FAAAAAQAAAHNjAg==' + Bel);
  Check(ReplyOf(R, 2, Rs) and (Rs.PopU8 = 1) and (Rs.PopU64 = VtClipDataId(cfText, 'hello')) and (Rs.Size = 0), '7.5 CLIP_SETDATA: status 1 and the data ID');
  Check(ClipboardGetText = 'hello', 'the clipboard of the application has the text');
  R := Req(E + '_far2l:AQAAAGdjAw==' + Bel);
  Check(ReplyOf(R, 3, Rs) and (Rs.PopU32 = 0) and (Rs.PopU64 = 0) and (Rs.Size = 0), '7.5 CLIP_GETDATA without a paste gesture: no data, ID 0');
  Emu.Ext.PasteGesture;
  R := Req(E + '_far2l:AQAAAGdjAw==' + Bel);
  Check(ReplyOf(R, 3, Rs) and (Rs.PopU32 = 5) and (Rs.PopRaw(5) = 'hello') and (Rs.PopU64 = VtClipDataId(cfText, 'hello')),
    'after the gesture: size, data, data ID');
  Check(Req(E + '_far2l:RkFSX1ZlcnRpY2FsQmxvY2tfVW5pY29kZRkAAAByYwQ=' + Bel) = E + '_far2lAMAAAAQ=' + Bel,
    '7.5 CLIP_REGISTER_FORMAT: the reply of the example');
  Check(Req(E + '_far2l:Y2MA' + Bel) = '', '7.5 CLIP_CLOSE with ID 0: no reply');
  Check(Req(E + '_far2l:Y2kF' + Bel) = E + '_far2l' + F2lBase64Encode(#0#0#0#0#0#0#0#0#0#0#0#0#5) + Bel, '7.6 IMAGE_CAPS: no capabilities');
  Check(Req(E + '_far2l:/wAA/wEAAAABAAAA/////wMAAgAAAAAAAAAAAGltZwMAAABzaQY=' + Bel) = E + '_far2lAAY=' + Bel, '7.6 IMAGE_SET: 0');
  Check(Req(E + '_far2l:BQD//////////2ltZwMAAAB0aQc=' + Bel) = E + '_far2lAAc=' + Bel, '7.6 IMAGE_TRANSFORM: 0');
  Check(Req(E + '_far2l:AQAAAAAAAAB4AA==' + Bel) = '', '7.7 features (compact input)');

  { every request with an ID is answered }
  S.Clear; S.PushU8(Ord('Z')); S.PushU8(9);
  Check(Ask(S) = E + '_far2lCQ==' + Bel, 'an unknown command: the ID alone');
  S.Clear; S.PushU8(Ord('n')); S.PushU8(7);
  Check(Ask(S) = E + '_far2lBw==' + Bel, 'a request that is too short: the ID alone');
  S.Clear; S.PushU8(Ord('e')); S.PushU8(8);
  Check((Ask(S) = E + '_far2lCA==' + Bel) and (H.Quick = 1), 'quick edit: the ID alone');
  S.Clear; S.PushU8(Ord('M')); S.PushU8(0);
  Ask(S);
  S.Clear; S.PushU8(Ord('m')); S.PushU8(0);
  Ask(S);
  Check((H.Maxed = 1) and (H.Restored = 1), 'maximize and restore');
  S.Clear; S.PushU8(Ord('p')); S.PushU8(10);
  Check(ReplyOf(Ask(S), 10, Rs) and (Rs.PopU8 = 24) and (Rs.PopU8 = 0) and (Rs.Size = 0), 'the palette: 24 bits, reserved 0');
  S.Clear; S.PushStr('F2'); S.PushU8(1); S.PushU8(0); S.PushU8(Ord('f')); S.PushU8(11);
  Check(ReplyOf(Ask(S), 11, Rs) and (H.Titles = '|F2|' + StringOfChar('|', 10)), 'F-key titles: F1 none, F2..F12 missing (a short stack)');

  { the size }
  S.Clear; S.PushU64(F2lFeatCompactInput or F2lFeatTerminalSize); S.PushU8(Ord('x')); S.PushU8(0);
  Check(Ask(S) = E + '_f2lUAAZAFM=' + Bel, 'the size feature: the size at once (example 7.8)');
  Emu.Resize(100, 30);
  Check(Emu.TakeReply = F2lSizeSeq(100, 30), 'and when the size changes');
  Emu.Resize(80, 25);
  Emu.TakeReply;
  S.Clear; S.PushU64(F2lFeatCompactInput); S.PushU8(Ord('x')); S.PushU8(0);
  Ask(S);
  Emu.Resize(90, 25);
  Check(Emu.TakeReply = '', 'features are replaced: no size events any more');
  Emu.Resize(80, 25);

  { the events of the keys and of the mouse }
  ClearEvent(Ev);
  MakeKeyEvent(Ev, Ord('a'), 0);
  Check(Emu.Ext.KeyEvent(Ev) = E + '_f2lQQAAYQBD' + Bel, 'a key press: the compact event of the example');
  Ev.What := evKeyUp;
  Check(Copy(Emu.Ext.KeyEvent(Ev), 1, 5) = E + '_f2l', 'a release');
  S.Clear; S.Data := F2lBase64Decode(Copy(Emu.Ext.KeyEvent(Ev), 6, 8));
  Check(Chr(S.PopU8) = 'c', 'is c');
  Check(Emu.Ext.MouseEvent(10, 5, mbLeftButton, 0, False, False, 0) = E + '_f2lCgAFAAEAAABt' + Bel, 'the left button: example 7.8');
  Check(Emu.Ext.MouseEvent(10, 5, 0, mwDown, False, False, 0) = E + '_f2lCgAFAAAA//8AAAAABAAAAE0=' + Bel, 'the wheel down: example 7.8');
  MakeKeyEvent(Ev, kbCtrlA, kbLeftCtrl);
  S.Clear; S.Data := F2lBase64Decode(Copy(Emu.Ext.KeyEvent(Ev), 6, MaxInt - 10));
  Check((Chr(S.PopU8) = 'C') and (S.PopU16 = 1) and ((S.PopU16 and $0C) <> 0) and (S.PopU8 = $41), 'Ctrl+A: the control character, Ctrl, VK_A');

  { the clipboard: the gesture window and its extensions }
  Check(OpenClip(Cid, 20) = 1, 'the client is remembered for the activation');
  Check(H.Asked = 1, 'not asked again');
  Check(OpenClip(Cid, 21) = 0, 'a second open fails');
  TestNow := 200000;
  Emu.Ext.PasteGesture;
  TestNow := 204000;
  Check(GetData(cfText, 22, Data) = 5, 'a read 4 s after the gesture');
  TestNow := 208000;
  Check(GetData(cfText, 23, Data) = 5, 'the read extended the time');
  TestNow := 212000;
  Check(GetData(cfText, 24, Data) = 5, 'twice');
  TestNow := 216000;
  Check(GetData(cfText, 25, Data) = 5, 'three times: allowed, not extended');
  TestNow := 217500;
  Check(GetData(cfText, 26, Data) = 0, 'then the time is over');
  S.Clear; S.PushU32(cfText); ClipReq('i', 27);
  Check(ReplyOf(Ask(S), 27, Rs) and (Rs.PopU64 = 0), 'CLIP_GETDATAID without the gesture: 0');
  Emu.Ext.PasteGesture;
  S.Clear; S.PushU32(cfText); ClipReq('i', 28);
  Check(ReplyOf(Ask(S), 28, Rs) and (Rs.PopU64 = VtClipDataId(cfText, 'hello')), 'with it: the ID');
  S.Clear; S.PushU32(cfText); ClipReq('a', 29);
  Check(ReplyOf(Ask(S), 29, Rs) and (Rs.PopU8 = 1), 'CLIP_ISAVAIL');
  { formats: the text, a registered one, UTF-32 }
  VFmt := ClipboardRegisterFormat(VerticalBlockFormat);
  S.Clear; ClipReq('e', 0); Ask(S);
  Check(ClipboardGetText = '', 'CLIP_EMPTY');
  S.Clear; S.PushRaw('vert'#0); S.PushU32(5); S.PushU32(cfText); ClipReq('s', 30);
  Check(ReplyOf(Ask(S), 30, Rs) and (Rs.PopU8 = 1), 'the text with a NUL');
  S.Clear; S.PushRaw(#0#0#0#0); S.PushU32(4); S.PushU32(VFmt); ClipReq('s', 31);
  Check(ReplyOf(Ask(S), 31, Rs) and (Rs.PopU8 = 1), 'the mark of a vertical block');
  Check((ClipboardGetText = 'vert') and ClipboardGetItem(VFmt, Data) and (Data = #0#0#0#0), 'both are on the clipboard');
  Check(GetData(cfUnicodeText, 32, Data) = 16, 'CF_UNICODETEXT: UTF-32');
  Check(F2lUtf32ToUtf8(Data) = 'vert', 'of the text');
  S.Clear; S.PushRaw(F2lUtf8ToUtf32('Жук')); S.PushU32(12); S.PushU32(cfUnicodeText); ClipReq('s', 33);
  Ask(S);
  Check(ClipboardGetText = 'Жук', 'CF_UNICODETEXT is set as text');
  Check(ClipboardGetItem(VFmt, Data), 'the other format stays');
  { chunks }
  SetLength(Data, 512);
  FillChar(Data[1], 512, Ord('x'));
  S.Clear; S.PushRaw(Copy(Data, 1, 256)); S.PushU16(1); ClipReq('S', 0);
  Check(Ask(S) = '', 'a chunk with ID 0: no reply');
  S.Clear; S.PushRaw(Copy(Data, 1, 256)); S.PushU16(1); ClipReq('S', 34);
  Check(Ask(S) = E + '_far2l' + F2lBase64Encode(#34) + Bel, 'a chunk with an ID: the ID alone');
  S.Clear; S.PushRaw('end'); S.PushU32(3); S.PushU32(cfText); ClipReq('s', 35);
  Check(ReplyOf(Ask(S), 35, Rs) and (Rs.PopU8 = 1) and (Rs.PopU64 = VtClipDataId(cfText, Data + 'end')), 'the chunks go before the data');
  Check(ClipboardGetText = Data + 'end', 'on the clipboard');
  S.Clear; S.PushRaw(Copy(Data, 1, 256)); S.PushU16(1); ClipReq('S', 0); Ask(S);
  S.Clear; S.PushU16(0); ClipReq('S', 0); Ask(S);
  S.Clear; S.PushRaw('only'); S.PushU32(4); S.PushU32(cfText); ClipReq('s', 36); Ask(S);
  Check(ClipboardGetText = 'only', 'a chunk of size 0 drops the chunks');
  CloseClip;
  S.Clear; S.PushU32(cfText); ClipReq('g', 37);
  Check(ReplyOf(Ask(S), 37, Rs) and (Rs.PopU32 = $FFFFFFFF) and (Rs.Size = 0), 'CLIP_GETDATA when it is not open: FFFFFFFF alone');
  S.Clear; S.PushRaw('x'); S.PushU32(1); S.PushU32(cfText); ClipReq('s', 38);
  Check(ReplyOf(Ask(S), 38, Rs) and (ShortInt(Rs.PopU8) = -1) and (Rs.Size = 0), 'CLIP_SETDATA when it is not open: -1');

  { the authorization }
  Check(OpenClip('short', 40) = 0, 'a client ID that is not valid: 0');
  H.Answer := vcaBlock;
  Check(OpenClip(Cid + 'b', 41) = 0, 'block: 0');
  Check(OpenClip(Cid + 'b', 42) = 0, 'the user is asked again');
  Check(H.Asked = 3, 'twice');
  H.Answer := vcaRemote;
  Check(OpenClip(Cid + 'r', 43) = -1, 'remote clipboard: -1');
  H.Answer := vcaAlways;
  Check(OpenClip(Cid + 'a', 44) = 1, 'share always: 1');
  CloseClip;
  Check(FileExists(Dir + '/autheds'), 'the client is written to the file');
  Req(E + '_far2l0' + Bel);
  Check(not Emu.Ext.Active and (H.Titles = ''), 'far2l0: off, the F-key titles are cleared');
  Check(Req(E + '_far2l:dwE=' + Bel) = '', 'requests after far2l0 are ignored');
  Req(E + '_far2l1' + St);
  H.Answer := vcaBlock;
  H.Asked := 0;
  Check(OpenClip(Cid + 'a', 45) = 1, 'a client of the file is let in without a question');
  CloseClip;
  Check(OpenClip(Cid, 46) = 0, 'a client shared for the last activation only is asked again');
  Check(H.Asked = 1, 'it was asked');
  Emu.Free;

  { the host identity is a part of the client }
  Emu := TVtEmu.Create(80, 25, 100);
  Emu.Ext.Host := H;
  Emu.Ext.AuthedsPath := Dir + '/autheds';
  Req(E + '_far2l#user@host' + Bel);
  Req(E + '_far2l#other' + Bel);
  Req(E + '_far2l1' + St);
  H.Answer := vcaShare;
  H.Asked := 0;
  Check((OpenClip(Cid + 'a', 1) = 1) and (H.Asked = 1) and (H.LastAsked = 'user@host:' + Cid + 'a'),
    'the first host identity goes before the ID: the file does not let it in');
  Emu.Ext.Host := nil;
  Emu.Free;

  { a client of TvFar2l against the server }
  Emu := TVtEmu.Create(80, 25, 100);
  H.Answer := vcaShare;
  Emu.Ext.Host := H;
  Emu.Ext.AuthedsPath := '';
  Emu.Ext.Now := @TestClock;
  Cl := TLoopClient.Create;
  Cl.Emu := Emu;
  Cl.ClientId := Cid;
  Cl.Send(F2lEnableSeq);
  Check(Cl.Pending = F2lAckSeq, 'the client: acknowledged');
  Cl.Pending := '';
  Cl.Activated;
  Fmt := Cl.ClipRegister(VerticalBlockFormat);
  Check(Fmt = VFmt, 'the same name, the same format');
  Check(Cl.ClipSet([cfUnicodeText, Fmt], ['Колонка', #0#0#0#0]), 'the client sets the text and the mark');
  Check((ClipboardGetText = 'Колонка') and ClipboardHasItem(VFmt), 'both are there');
  TestNow := 300000;
  Check(not Cl.ClipGet(cfText, Data), 'no gesture: no data');
  Emu.Ext.PasteGesture;
  Check(Cl.ClipGet(cfUnicodeText, Data) and (Data = 'Колонка'), 'with the gesture: the text');
  Check(Cl.ClipGet(Fmt, Data) and (Data = #0#0#0#0), 'and the mark');
  Check(Cl.ClipHas(Fmt, Avail) and Avail, 'CLIP_ISAVAIL');
  Check(Cl.WindowMaxSize(I, I) and (I = 50), 'the window');
  Check(Cl.ColorBits(10) = 24, 'the colors');
  Check(Cl.SetFKeyTitles(['a', 'b']) and (H.Titles = 'a|b|' + StringOfChar('|', 10)), 'the F-key titles');
  Cl.Free;
  Emu.Ext.Host := nil;
  Emu.Free;
  H.Free;

  DeleteFile(Dir + '/autheds');
  RemoveDir(Dir);
  Finish;
end.
