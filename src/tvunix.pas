{ TvUnix: the terminal backend for Unix (the Linux console, xterm and the like): the screen is drawn with ANSI
  sequences, keys and the mouse come from the terminal, a change of the size of the terminal is an event.

  Translated from magiblot/tvision @ b4831e2 (the parts that matter without ncurses):
    source/platform/unixcon.cpp, linuxcon.cpp   (the raw mode of the terminal, the size, the start and the end),
    source/platform/sigwinch.cpp                (the change of the size),
    source/platform/dispbuff.cpp, ncurdisp.cpp  (the cells that changed are drawn: the shadow of the screen),
    source/platform/events.cpp, platform.cpp    (the wait for input, the mouse timers),
    source/platform/termio.cpp                  (the sequences that start and stop the reporting: in TvTermIO).
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - one thread: the wait for input and the drawing are in PollEvent;
    - the colors, the quirks of terminals and the keys are guessed from TERM and COLORTERM (TvAnsi, TvTermIO), not
      read from terminfo; TV_COLORS forces the colors, TV_MOUSE=0 switches the mouse off, TV_WIN32_INPUT=1|0 asks for the win32 input
      mode of the terminal or not (default: yes in Windows Terminal only), ESCDELAY is the time
      that an Esc waits for the rest of a sequence (ms, default 25);
    - added: the far2l terminal extensions (TvFar2l), asked for at the start and after a resume (TV_FAR2L=0 does not ask, TV_FAR2L=1 asks also
      where it is not asked by default: TERM linux, dumb or empty); while they are on, the keys and the mouse come as their events, the clipboard,
      the notifications, the F-key titles, the window requests, the cursor height and the color depth go through them;
    - not done yet: the suspend of the program (Ctrl+Z, a shell), GPM.

  Use: UnixInit before the application is created, UnixDone after it is destroyed. }
unit TvUnix;

{$I tvdefs.inc}

interface

{ Puts the terminal in the raw mode, creates the screen (the size of the terminal) and sets the hooks of TvSys,
  TvScreen. False if the input is not a terminal. }
function UnixInit: Boolean;
procedure UnixDone;
function UnixActive: Boolean;
{ The terminal is given back for a while (a program is run that uses it): the alternate screen is left and the mode of the
  terminal is restored; UnixResume takes the terminal again and the whole screen is drawn again at the next update. }
procedure UnixSuspend;
procedure UnixResume;

{ For tests: the bytes of the output that were not written yet, and writing them. }
procedure UnixFlush;

implementation

{$IF DEFINED(UNIX) OR DEFINED(WINDOWS)}

uses
  SysUtils, TvTermOs, TvGeom, TvCell, TvColors, TvScreen, TvEvents, TvSys, TvMouse, TvViews, TvTermIO, TvAnsi, TvCodePg, TvClip, TvClipCmd, TvFar2l;

const
  AutoSliceMs = 20;           { the wait between the checks of the mouse timers while a button is down }

var
  Active: Boolean = False;
  Cols, Rows: Integer;
  Writer: TAnsiWriter = nil;
  Shown: PScreenCell = nil;   { the cells that the terminal shows }
  Input: TTermInput;
  InState: TInputState;
  Osc52Known: Boolean = False;      { the terminal said (the probes) that it takes and gives the clipboard by OSC 52 }
  MState: TMouseState;
  MouseOn: Boolean = False;
  InBuf: array[0..1023] of Byte;
  InPos, InLen: Integer;
  { bytes that were read while an answer of the terminal was awaited and are not a part of it: the input takes them first }
  Held: AnsiString = '';
  HeldPos: Integer = 1;
  KittyUpSent: Boolean = False;       { the flag 2 (the events of the types of keys: repeat, release) of the keyboard protocol of Kitty is set }
  KittyModSent: Boolean = False;      { the flag 8 (all keys, also the modifiers, as escape codes) is set: only while TvSys.KeyUpForApp }

  Dirty: Boolean = False;     { cells were written after the last flush: the caret is hidden }
  CaretMoved: Boolean = True;
  CaretShape: Integer = -1;
  ExitProcSet: Boolean = False;

type
  { the client of the far2l extensions on this terminal: the requests are written to the output, the replies are read from the input (what else comes
    meanwhile is kept for UnixPollEvent) }
  TUnixF2l = class(TF2lClient)
  protected
    procedure Send(const S: AnsiString); override;
    function WaitReply(Id: Byte; TimeoutMs: Integer; out Reply: TF2lStack): Boolean; override;
  end;

var
  F2l: TUnixF2l = nil;
  F2lAsked: Boolean = False;          { far2l1 was sent and far2l0 not yet }
  F2lAckPending: Boolean = False;     { the acknowledgement came: the extensions are switched on at the next poll }
  F2lBits: Integer = 0;               { the color depth that the terminal told }
  FocusSeen: Boolean = False;         { a focus report came since the start }
  CaretHeightSent: Integer = -1;
  { the events that came while a reply was awaited (raw: the mouse reports go through TvMouse when they are taken) }
  Queued: array of TEvent;
  QueuedTake: Integer = 0;

function F2lOn: Boolean;
begin
  Result := (F2l <> nil) and F2l.Active;
end;

{ --- output ------------------------------------------------------------------------------------------------- }

procedure WriteAll(P: PByte; Len: Integer);
begin
  OsWrite(P, Len);
end;

procedure UnixFlush;
var
  Shape: Integer;
begin
  if not Active then
    Exit;
  if Dirty or CaretMoved then
  begin
    if CaretSize > 0 then
    begin
      Writer.SetCaretPosition(CaretX, CaretY);
      if F2lOn then
      begin
        { the height in percent (the request h) instead of the shapes of DECSCUSR }
        if CaretSize <> CaretHeightSent then
        begin
          CaretHeightSent := CaretSize;
          F2l.SetCursorHeight(CaretSize);
        end;
      end
      else
      begin
        Shape := 2;                       { steady block }
        if CaretSize < 50 then
          Shape := 4;                     { steady underline }
        if Shape <> CaretShape then
        begin
          Writer.WriteRaw(#27'[' + IntToStr(Shape) + ' q');
          CaretShape := Shape;
        end;
      end;
      Writer.WriteRaw(#27'[?25h');
    end
    else if not Dirty then
      Writer.WriteRaw(#27'[?25l');
    Dirty := False;
    CaretMoved := False;
  end;
  if Writer.Length > 0 then
  begin
    WriteAll(Writer.Data, Writer.Length);
    Writer.Clear;
  end;
end;

procedure BeginDraw;
begin
  if not Dirty then
  begin
    Writer.WriteRaw(#27'[?25l');
    Dirty := True;
  end;
end;

{ The UTF-8 of a cell. A cell keeps either UTF-8 already or one byte of the code page of the program (a control character or one from $80 up),
  which is turned into its UTF-8 here; an empty cell and a NUL are drawn as a space. }
function CellText(const Ch: TScreenCharacter): string;
var
  Code: Byte;
  Utf: array[0..7] of Byte;
begin
  Result := ScText(Ch);
  case Length(Result) of
    0: Result := ' ';
    1:
      begin
        Code := Ord(Result[1]);
        if Code = 0 then
          Result := ' '
        else if (Code < 32) or (Code > 127) then
          SetString(Result, PAnsiChar(@Utf[0]), CpToUtf8(Code, @Utf[0]));
      end;
  end;
end;

procedure DrawCell(CX, Y: Integer);
var
  Row, C: PScreenCell;
  Idx: Integer;
  Text: string;
begin
  Row := TScreen.ScreenBuffer + Y * Cols;
  C := Row + CX;
  Idx := Y * Cols + CX;
  if ScIsWideTrail(C^.Character) then
  begin
    if (CX > 0) and ScIsWide(Row[CX - 1].Character) then
      DrawCell(CX - 1, Y)               { the lead draws both }
    else
      Writer.WriteCell(CX, Y, ' ', C^.Attribute, False);   { a trail with no lead }
    Shown[Idx] := C^;
    Exit;
  end;
  { a wide character that was shown here, and this cell is not its trail any more: it is gone from the screen }
  if (CX > 0) and ScIsWide(Shown[Idx - 1].Character) and not ScIsWide(Row[CX - 1].Character) then
  begin
    Writer.WriteCell(CX - 1, Y, ' ', Shown[Idx - 1].Attribute, False);
    Shown[Idx - 1] := Row[CX - 1];
  end;
  if ScIsWide(C^.Character) then
  begin
    if (CX + 1 < Cols) and ScIsWideTrail(Row[CX + 1].Character) then
    begin
      Writer.WriteCell(CX, Y, CellText(C^.Character), C^.Attribute, True);
      Shown[Idx] := C^;
      Shown[Idx + 1] := Row[CX + 1];
      Exit;
    end;
    Writer.WriteCell(CX, Y, ' ', C^.Attribute, False);     { the trail is missing: the character is overlapped }
    Shown[Idx] := C^;
    Exit;
  end;
  Text := CellText(C^.Character);
  Writer.WriteCell(CX, Y, Text, C^.Attribute, False);
  Shown[Idx] := C^;
end;

procedure UnixScreenWrite(X, Y: Integer; Cells: PScreenCell; Count: Integer);
var
  I, CX, Idx: Integer;
  Row: PScreenCell;
  Differs: Boolean;
begin
  if (Y < 0) or (Y >= Rows) or (Shown = nil) then
    Exit;
  Row := TScreen.ScreenBuffer + Y * Cols;
  for I := 0 to Count - 1 do
  begin
    CX := X + I;
    if (CX < 0) or (CX >= Cols) then
      Continue;
    Idx := Y * Cols + CX;
    Differs := not CellEq(Row[CX], Shown[Idx]);
    { a wide lead is drawn again when its trail changed }
    if (not Differs) and ScIsWide(Row[CX].Character) and (CX + 1 < Cols) and not CellEq(Row[CX + 1], Shown[Idx + 1]) then
      Differs := True;
    if Differs then
    begin
      BeginDraw;
      DrawCell(CX, Y);
    end;
  end;
end;

procedure UnixCaretPosition(X, Y: Integer);
begin
  CaretMoved := True;
end;

procedure UnixCaretSize(Size: Integer);
begin
  CaretMoved := True;
end;

{ --- the clipboard ------------------------------------------------------------------------------------------ }

function Osc52Get(out Text: AnsiString): Boolean; forward;

{ The clipboard of the system (Windows) or of the terminal (OSC 52: most terminals take it, some ask the user or have it off; the Linux console
  prints it, so it is not sent there). TV_CLIPBOARD=0 turns the OSC 52 off. Reading the clipboard of a terminal is not done: it is not
  allowed in most of them; TvClip keeps the text of the program for the paste inside it. TV_OSC52_READ=1 asks the terminal for its clipboard (OSC 52
  with "?") when the text is read (the paste): see Osc52Get. }
function ClipSetHook(const Text: AnsiString): Boolean;
var
  Seq: AnsiString;
begin
  { the programs of the system (wl-copy, xsel, xclip, pbcopy, clip.exe of WSL), the terminal of the far2l extensions, the clipboard of Windows, then OSC 52 }
  if ClipCmdSet(Text) then
    Exit(True);
  if F2lOn and F2l.ClipSet([cfText], [Text]) then
    Exit(True);
  if OsClipSet(Text) then
    Exit(True);
  Result := False;
  if (GetEnvironmentVariable('TV_CLIPBOARD') = '0') or (GetEnvironmentVariable('TERM') = 'linux') or (Length(Text) > 74000) then
    Exit;
  Seq := #27']52;c;' + Base64Encode(Text) + #7;
  OsWrite(PByte(PAnsiChar(Seq)), Length(Seq));
  { the sequence is always sent; it counts as a success only for a terminal that said it can (the probes), else the text stays in the buffer of the program }
  Result := Osc52Known;
end;

function ClipGetHook(out Text: AnsiString): Boolean;
begin
  if ClipCmdGet(Text) then
    Exit(True);
  if F2lOn and F2l.ClipGet(cfText, Text) then
    Exit(True);
  if OsClipGet(Text) then
    Exit(True);
  Result := Osc52Get(Text);
end;

{ The number of a format in the terminal: the standard ones are the same, a registered one is registered there by its name (0: it could not be). }
function TermFormat(Format: LongWord): LongWord;
var
  Name: AnsiString;
begin
  Result := Format;
  if Format >= cfFirstRegistered then
  begin
    Name := ClipboardFormatName(Format);
    if Name = '' then
      Exit(0);
    Result := F2l.ClipRegister(Name);
  end;
end;

{ Several formats: only the terminal of the far2l extensions keeps them; a set of text alone goes the way of the text (ClipSetHook). }
function ClipSetItemsHook(const Items: array of TClipItem): Boolean;
var
  Formats: array of LongWord;
  Datas: array of AnsiString;
  I, N: Integer;
  F: LongWord;
  Other: Boolean;
begin
  Result := False;
  if not F2lOn then
    Exit;
  Other := False;
  for I := 0 to High(Items) do
    if (Items[I].Format <> cfText) and (Items[I].Format <> cfUnicodeText) then
      Other := True;
  if not Other then
    Exit;
  SetLength(Formats, Length(Items));
  SetLength(Datas, Length(Items));
  N := 0;
  for I := 0 to High(Items) do
  begin
    F := TermFormat(Items[I].Format);
    if F = 0 then
      Continue;
    Formats[N] := F;
    Datas[N] := Items[I].Data;
    Inc(N);
  end;
  SetLength(Formats, N);
  SetLength(Datas, N);
  Result := F2l.ClipSet(Formats, Datas);
end;

function ClipGetItemHook(Format: LongWord; out Data: AnsiString): Boolean;
var
  F: LongWord;
begin
  Data := '';
  Result := False;
  if not F2lOn then
    Exit;
  F := TermFormat(Format);
  if F <> 0 then
    Result := F2l.ClipGet(F, Data);
end;

function ClipHasItemHook(Format: LongWord; out Avail: Boolean): Boolean;
var
  F: LongWord;
begin
  Avail := False;
  Result := False;
  if not F2lOn then
    Exit;
  F := TermFormat(Format);
  if F <> 0 then
    Result := F2l.ClipHas(F, Avail);
end;

{ --- input -------------------------------------------------------------------------------------------------- }

{ True if a byte can be read within TimeoutMs. }
function InputReady(TimeoutMs: Integer): Boolean;
begin
  if HeldPos <= Length(Held) then
    Exit(True);
  if InPos < InLen then
    Exit(True);
  Result := OsInputReady(TimeoutMs);
end;

function RawRead(TimeoutMs: Integer): Integer;
var
  N: Integer;
begin
  if HeldPos <= Length(Held) then
  begin
    Result := Ord(Held[HeldPos]);
    Inc(HeldPos);
    if HeldPos > Length(Held) then
    begin
      Held := '';
      HeldPos := 1;
    end;
    Exit;
  end;
  if InPos >= InLen then
  begin
    if not InputReady(TimeoutMs) then
      Exit(-1);
    N := OsRead(InBuf, SizeOf(InBuf));
    if N <= 0 then
      Exit(-1);
    InPos := 0;
    InLen := N;
  end;
  Result := InBuf[InPos];
  Inc(InPos);
end;

function UnixClock: Int64;
begin
  Result := Int64(GetTickCount64);
end;

function WaitMs(const Name: string; Default: Integer): Integer;
begin
  Result := StrToIntDef(GetEnvironmentVariable(Name), Default);
end;

{ OSC 52 read (TV_OSC52_READ=1; off by default: most terminals refuse, some ask the user): sends ESC ] 52 ; c ; ? ESC \ and waits for the answer
  ESC ] 52 ; c ; <base64> BEL|ST (TV_OSC52_WAIT ms, 400 by default). What else arrives meanwhile is kept for the next read of the input. A terminal that
  does not answer is not asked again for a minute. }
var
  Osc52Cooldown: Int64 = 0;

function Osc52Get(out Text: AnsiString): Boolean;
var
  Stash, Body: AnsiString;
  Deadline: Int64;
  B, C, P: Integer;
const
  Query = #27']52;c;?'#27'\';
begin
  Result := False;
  Text := '';
  { a terminal that said it can (the probes) is asked; TV_OSC52_READ=1 asks any terminal, TV_OSC52_READ=0 none }
  if not ((GetEnvironmentVariable('TV_OSC52_READ') = '1') or (Osc52Known and (GetEnvironmentVariable('TV_OSC52_READ') <> '0'))) then
    Exit;
  if (GetEnvironmentVariable('TERM') = 'linux') or (UnixClock < Osc52Cooldown) then
    Exit;
  Stash := '';
  OsWrite(@Query[1], Length(Query));
  Deadline := UnixClock + WaitMs('TV_OSC52_WAIT', 400);
  while (not Result) and (UnixClock < Deadline) do
  begin
    B := RawRead(40);
    if B < 0 then
      Continue;
    if B <> 27 then
    begin
      Stash := Stash + Chr(B);
      Continue;
    end;
    C := RawRead(30);
    if C <> Ord(']') then
    begin
      Stash := Stash + #27;
      if C >= 0 then
        Stash := Stash + Chr(C);
      Continue;
    end;
    Body := '';
    repeat
      B := RawRead(300);
      if B = 27 then
      begin
        B := RawRead(300);
        if B = Ord('\') then
          Break;
        Body := Body + #27;
      end;
      if (B < 0) or (B = 7) then
        Break;
      Body := Body + Chr(B);
    until Length(Body) > 1048576;
    if Copy(Body, 1, 3) = '52;' then
    begin
      P := Pos(';', Copy(Body, 4, MaxInt));
      if P > 0 then
      begin
        Text := Base64Decode(Copy(Body, 3 + P + 1, MaxInt));
        Result := True;
      end;
    end
    else
      Stash := Stash + #27']' + Body + #7;
  end;
  if not Result then
    Osc52Cooldown := UnixClock + 60000;
  if Stash <> '' then
  begin
    Held := Stash + Copy(Held, HeldPos, MaxInt);
    HeldPos := 1;
  end;
end;

{ A desktop notification: a program of the desktop (notify-send, osascript). The application decides whether the window is in the background (AppFocused). }
procedure UnixNotify(const Title, Text: AnsiString);
begin
  if F2lOn then
    F2l.Notify(Title, Text)
  else
    NotifyCmd(Title, Text);
end;

procedure UnixFKeyTitles(const Titles: array of AnsiString);
begin
  if F2lOn then
    F2l.SetFKeyTitles(Titles);
end;

function UnixWindowMaxSize(out Cols, Rows: Integer): Boolean;
begin
  Cols := 0;
  Rows := 0;
  Result := F2lOn and F2l.WindowMaxSize(Cols, Rows);
end;

procedure UnixWindowMaximize(Maximize: Boolean);
begin
  if F2lOn then
    F2l.WindowMaximize(Maximize);
end;

procedure UnixQuickEdit;
begin
  if F2lOn then
    F2l.QuickEdit;
end;

function UnixColorBits: Integer;
begin
  if F2lOn and (F2lBits > 0) then
    Exit(F2lBits);
  case Writer.Capabilities.Colors of
    tcDirect: Result := 24;
    tcIndexed256: Result := 8;
    tcIndexed8, tcIndexed16: Result := 4;
  else
    Result := 0;
  end;
end;

{ --- the far2l extensions ----------------------------------------------------------------------------------- }

procedure TUnixF2l.Send(const S: AnsiString);
begin
  { what was drawn goes first, so that the requests keep their place among the output }
  if (Writer <> nil) and (Writer.Length > 0) then
  begin
    WriteAll(Writer.Data, Writer.Length);
    Writer.Clear;
  end;
  if S <> '' then
    WriteAll(PByte(PAnsiChar(S)), Length(S));
end;

procedure HandleStateFlags; forward;

procedure QueueRaw(const E: TEvent);
var
  N: Integer;
begin
  N := Length(Queued);
  SetLength(Queued, N + 1);
  Queued[N] := E;
end;

function TUnixF2l.WaitReply(Id: Byte; TimeoutMs: Integer; out Reply: TF2lStack): Boolean;
var
  Deadline: Int64;
  Raw: TEvent;
begin
  Reply.Clear;
  Deadline := UnixClock + TimeoutMs;
  repeat
    if Input.HasPending or InputReady(20) then
    begin
      InState.Far2lHasReply := False;
      if ParseEvent(Input, Raw, InState) then
        QueueRaw(Raw);
      HandleStateFlags;
      if InState.Far2lHasReply then
      begin
        InState.Far2lHasReply := False;
        Reply.Data := InState.Far2lReply;
        InState.Far2lReply := '';
        if Reply.PopU8 = Id then
          Exit(True);
        Reply.Clear;                      { a late reply to another request }
      end;
    end;
  until UnixClock >= Deadline;
  Result := False;
end;

{ asked for by default; not on the Linux console and the terminals without a name (TV_FAR2L=1 asks there too, TV_FAR2L=0 nowhere) }
function F2lWanted: Boolean;
var
  V, Term: string;
begin
  V := GetEnvironmentVariable('TV_FAR2L');
  if V = '0' then
    Exit(False);
  if V = '1' then
    Exit(True);
  Term := GetEnvironmentVariable('TERM');
  Result := (Term <> '') and (Term <> 'linux') and (Term <> 'dumb');
end;

{ far2l1 and the status query after it (its answer follows the acknowledgement of a terminal that has the extensions); the acknowledgement is taken by the
  input when it comes, nothing is waited for here }
procedure F2lAsk;
const
  Ask = F2lEnableSeq + #27'[5n';
begin
  F2lAckPending := False;
  if not F2lWanted then
    Exit;
  if F2l = nil then
  begin
    F2l := TUnixF2l.Create;
    F2l.AuthMs := StrToIntDef(GetEnvironmentVariable('TV_FAR2L_WAIT'), 30000);
  end;
  WriteAll(@Ask[1], Length(Ask));
  F2lAsked := True;
end;

{ the terminal acknowledged: the features, the colors it can show }
procedure F2lStart;
var
  Feat: QWord;
  Cap: TTermCap;
  Want: TTermCapColors;
begin
  F2lAckPending := False;
  if (F2l = nil) or F2l.Active then
    Exit;
  F2l.Activated;
  KeyUpAvailable := True;
  Feat := F2lFeatCompactInput;
  if GetEnvironmentVariable('TV_FAR2L_SIZE') = '1' then
    Feat := Feat or F2lFeatTerminalSize;
  F2l.SetFeatures(Feat);
  if not FocusSeen then
    AppFocused := False;                  { not known until the first focus report }
  CaretHeightSent := -1;
  CaretMoved := True;
  F2lBits := F2l.ColorBits(F2l.ReplyMs);
  if GetEnvironmentVariable('TV_COLORS') <> '' then
    Exit;
  case F2lBits of
    24: Want := tcDirect;
    8: Want := tcIndexed256;
    4: Want := tcIndexed16;
  else
    Exit;
  end;
  Cap := Writer.Capabilities;
  if Ord(Want) > Ord(Cap.Colors) then
  begin
    Cap.Colors := Want;
    Writer.SetCap(Cap);
    OsResizeFlag := 1;                    { the screen is made and drawn again with the new colors }
  end;
end;

procedure F2lStop;
begin
  if F2lAsked then
    WriteAll(PByte(PAnsiChar(F2lDisableSeq)), Length(F2lDisableSeq));
  F2lAsked := False;
  F2lAckPending := False;
  if F2l <> nil then
    F2l.Deactivated;
end;

{ What the parser noted in InState (the answers of the terminal to the probes, focus). }
procedure HandleStateFlags;
begin
  if InState.KittyReply then
    KeyUpAvailable := True;          { the terminal answered the query of the keyboard protocol of Kitty: the releases (flag 2) and the modifiers (flag 8) can be asked for }
  if InState.Osc52Full then
    Osc52Known := True;
  if InState.FocusEvent <> 0 then
  begin
    AppFocused := InState.FocusEvent = 1;
    InState.FocusEvent := 0;
    FocusSeen := True;
  end;
  if InState.Far2lAck then
  begin
    InState.Far2lAck := False;
    if F2lAsked then
      F2lAckPending := True;
  end;
  if InState.Far2lCols > 0 then
  begin
    if (InState.Far2lCols <> OsToldCols) or (InState.Far2lRows <> OsToldRows) then
    begin
      OsToldCols := InState.Far2lCols;
      OsToldRows := InState.Far2lRows;
      OsResizeFlag := 1;
    end;
    InState.Far2lCols := 0;
    InState.Far2lRows := 0;
  end;
end;

{ a raw event of the parser: a mouse report goes through TvMouse (which may make nothing of it); True when Event is to be given }
function DeliverRaw(const Raw: TEvent; var Event: TEvent): Boolean;
begin
  if Raw.What = evMouse then
  begin
    MState.Where := Raw.Mouse.Where;
    MState.Buttons := Raw.Mouse.Buttons;
    MState.Wheel := Raw.Mouse.Wheel;
    MState.ControlKeyState := Raw.KeyDown.ControlKeyState;
    MouseStep(MState, UnixClock, Event);
    MState.Wheel := 0;
    Result := Event.What <> evNothing;
  end
  else
  begin
    Event := Raw;
    Result := True;
  end;
end;

{ What the application wants of the key releases (TvSys.KeyUpEvents, KeyUpForApp) goes to the parser and to the terminal: the flag 2 of the keyboard protocol of
  Kitty (the types of key events) while the releases are wanted, the flag 8 (the modifiers too) only while the application wants those. It is done before the
  program waits for input, not after the input came: the terminal has to know before the key is released. }
procedure SyncKeyUpRequests;
begin
  InState.ReportKeyUp := KeyUpEvents or KeyUpForApp;
  InState.ReportModUp := KeyUpForApp;
  if (KeyUpEvents or KeyUpForApp or KeyRepeatInfo) <> KittyUpSent then
  begin
    KittyUpSent := KeyUpEvents or KeyUpForApp or KeyRepeatInfo;
    if KittyUpSent then
      OsWrite(@KittySetEventTypes[1], Length(KittySetEventTypes))
    else
      OsWrite(@KittyResetEventTypes[1], Length(KittyResetEventTypes));
  end;
  if KeyUpForApp <> KittyModSent then
  begin
    KittyModSent := KeyUpForApp;
    if KittyModSent then
      OsWrite(@KittySetAllKeys[1], Length(KittySetAllKeys))
    else
      OsWrite(@KittyResetAllKeys[1], Length(KittyResetAllKeys));
  end;
end;

procedure UnixPollEvent(TimeoutMs: Integer; var Event: TEvent);
var
  Start, Now_: Int64;
  Raw: TEvent;
  Wait: Integer;
begin
  UnixFlush;
  Start := UnixClock;
  repeat
    SyncKeyUpRequests;
    if F2lAckPending then
      F2lStart;
    if QueuedTake < Length(Queued) then
    begin
      Raw := Queued[QueuedTake];
      Inc(QueuedTake);
      if QueuedTake >= Length(Queued) then
      begin
        Queued := nil;
        QueuedTake := 0;
      end;
      if DeliverRaw(Raw, Event) then
        Exit;
      Continue;
    end;
    if OsResizeFlag <> 0 then
    begin
      OsResizeFlag := 0;
      ClearEvent(Event);
      Event.What := evCommand;
      Event.Message.Command := cmScreenChanged;
      Exit;
    end;
    { the timers of the mouse: the up that is pending, the auto repeat }
    if MouseOn then
    begin
      MState.Wheel := 0;
      MouseStep(MState, UnixClock, Event);
      if Event.What <> evNothing then
        Exit;
    end;
    if Input.HasPending or InputReady(0) then
    begin
      if ParseEvent(Input, Raw, InState) then
      begin
        HandleStateFlags;
        if DeliverRaw(Raw, Event) then
          Exit;
      end;
      HandleStateFlags;
      Continue;                          { the bytes were an answer or part of one: look again }
    end;
    if TimeoutMs = 0 then
      Break;
    Now_ := UnixClock;
    if TimeoutMs < 0 then
      Wait := 1000
    else
    begin
      Wait := TimeoutMs - Integer(Now_ - Start);
      if Wait <= 0 then
        Break;
    end;
    if (MState.Buttons <> 0) and (Wait > AutoSliceMs) then
      Wait := AutoSliceMs;               { a button is down: the timers of the mouse must be looked at }
    if Wait > 1000 then
      Wait := 1000;
    InputReady(Wait);
  until (TimeoutMs >= 0) and (UnixClock - Start >= TimeoutMs);
  ClearEvent(Event);
end;

{ --- the screen --------------------------------------------------------------------------------------------- }

procedure ReadSize(out W, H: Integer);
begin
  OsSize(W, H);
  if W < 20 then
    W := 20;
  if H < 5 then
    H := 5;
  if W > 1000 then
    W := 1000;
  if H > 1000 then
    H := 1000;
end;

procedure NewScreen;
var
  N: Integer;
begin
  ReadSize(Cols, Rows);
  ScreenCreate(Cols, Rows);
  if Shown <> nil then
    FreeMem(Shown);
  N := Cols * Rows * SizeOf(TScreenCell);
  GetMem(Shown, N);
  FillChar(Shown^, N, $FF);              { nothing is known: every cell will be drawn }
  Writer.ClearScreen;
  Writer.Reset;
  Dirty := False;
  CaretMoved := True;
  CaretShape := -1;
end;

procedure UnixSetVideoMode(Mode: Word);
begin
  { Mode is smUpdate when the size of the terminal changed: the screen is made again }
  NewScreen;
end;

{ the terminal is put back also when the program dies by a signal }
var
  Win32Input: Boolean = False;

{ The win32 input mode (every key combination, see TvTermIO): TV_WIN32_INPUT=1 asks for it, 0 does not; by default it is asked for only in Windows Terminal
  (the variable WT_SESSION), the one that is known to have it: a terminal that does not know the mode ignores the request, but one that knows it in
  another way (the keyboard protocol of Kitty is also asked for) could answer in a way that was not tested. TODO: ask the terminal (DECRQM 9001). }
function Win32InputWanted: Boolean;
var
  V: string;
begin
  V := GetEnvironmentVariable('TV_WIN32_INPUT');
  if V = '' then
    Result := GetEnvironmentVariable('WT_SESSION') <> ''
  else
    Result := V <> '0';
end;

procedure RestoreTerminal;
const
  Tail = #27'[0m'#27'[?25h'#27'[0 q'#27'[?7h'#27'[?1049l';
begin
  if not Active then
    Exit;
  F2lStop;
  if MouseOn then
    OsWrite(@SeqMouseOff[1], Length(SeqMouseOff));
  OsWrite(@SeqKeyModsOff[1], Length(SeqKeyModsOff));
  if Win32Input then
    OsWrite(@SeqWin32Off[1], Length(SeqWin32Off));
  OsWrite(@Tail[1], Length(Tail));
  OsRawOff;
end;

{ called when the program is killed (the terminal in order, then the end) }
procedure DeathHandler;
begin
  RestoreTerminal;
end;

procedure AtExitRestore;
begin
  if Active then
  begin
    RestoreTerminal;
    Active := False;
  end;
end;

function UnixActive: Boolean;
begin
  Result := Active;
end;

{ The questions about the clipboard of the terminal (as tvision does): alacritty and foot are asked to give the clipboard (OSC 52 with "?": it is not
  safe to print this to any terminal); the others: the capability read-clipboard of kitty (XTGETTCAP, DCS + q) and allowWindowOps of xterm (XTQALLOWED, OSC 60).
  The answers come with the input (TvTermIO sets InState.Osc52Full); SeqKeyModsOn that goes after the probes clears the screen of what a terminal that
  does not know them may show. }
function ClipProbeSeq: string;
var
  Term: string;
begin
  Result := '';
  Term := GetEnvironmentVariable('TERM');
  if (Term = '') or (Term = 'linux') or (GetEnvironmentVariable('TV_CLIPBOARD') = '0') then
    Exit;
  if (Pos('alacritty', Term) > 0) or (Pos('foot', Term) > 0) then
    Result := #27']52;;?'#7
  else
    Result := #27'P+q6b697474792d71756572792d636c6970626f6172645f636f6e74726f6c'#27'\'#27']60'#27'\';
end;

procedure UnixSuspend;
begin
  if not Active then
    Exit;
  UnixFlush;
  RestoreTerminal;
end;

procedure UnixResume;
var
  Seq: string;
begin
  if not Active then
    Exit;
  OsRawOn;
  Seq := #27'[?1049h'#27'[?7l';
  WriteAll(@Seq[1], Length(Seq));
  F2lAsk;
  Seq := ClipProbeSeq;
  if Seq <> '' then
    WriteAll(@Seq[1], Length(Seq));
  Seq := SeqKeyModsOn + KittyQuery;
  WriteAll(@Seq[1], Length(Seq));
  if Win32Input then
  begin
    Seq := SeqWin32On;
    WriteAll(@Seq[1], Length(Seq));
  end;
  if MouseOn then
  begin
    Seq := SeqMouseOn;
    WriteAll(@Seq[1], Length(Seq));
  end;
  KittyUpSent := False;                   { SeqKeyModsOn pushed fresh flags }
  KittyModSent := False;
  KeyUpAvailable := Win32Input;
  Queued := nil;
  QueuedTake := 0;
  InPos := 0;
  InLen := 0;
  InState.Far2lReply := '';               { the managed field before the record is zeroed }
  FillChar(InState, SizeOf(InState), 0);
  FillChar(MState, SizeOf(MState), 0);
  MouseQueueReset;
  NewScreen;                              { the size may have changed; nothing is known on the screen: all is drawn }
  Dirty := True;
end;

function UnixInit: Boolean;
var
  Seq, Delay: string;
  Ms: Integer;
begin
  Result := False;
  if Active then
    Exit(True);
  if not OsIsTerminal then
    Exit;
  OsRawOn;

  Writer := TAnsiWriter.Create(TermCapFromEnv);
  InPos := 0;
  InLen := 0;
  Delay := GetEnvironmentVariable('ESCDELAY');
  Ms := StrToIntDef(Delay, 25);
  Input.Init(@RawRead, Ms);
  FillChar(InState, SizeOf(InState), 0);
  FillChar(MState, SizeOf(MState), 0);
  MouseQueueReset;
  OsResizeFlag := 0;

  { the alternate screen, no wrapping at the end of a row }
  Seq := #27'[?1049h'#27'[?7l';
  WriteAll(@Seq[1], Length(Seq));
  Win32Input := Win32InputWanted;
  KeyUpAvailable := Win32Input;             { the win32 input mode reports every release }
  FocusSeen := False;
  F2lAsk;
  Seq := ClipProbeSeq;
  if Seq <> '' then
    WriteAll(@Seq[1], Length(Seq));
  Seq := SeqKeyModsOn + KittyQuery;
  WriteAll(@Seq[1], Length(Seq));
  if Win32Input then
  begin
    Seq := SeqWin32On;
    WriteAll(@Seq[1], Length(Seq));
  end;
  MouseOn := GetEnvironmentVariable('TV_MOUSE') <> '0';
  if MouseOn then
  begin
    Seq := SeqMouseOn;
    WriteAll(@Seq[1], Length(Seq));
  end;

  OsHandlersOn(@DeathHandler);
  if not ExitProcSet then
  begin
    AddExitProc(@AtExitRestore);
    ExitProcSet := True;
  end;

  Active := True;
  NewScreen;
  OnScreenWrite := @UnixScreenWrite;
  OnCaretPosition := @UnixCaretPosition;
  OnCaretSize := @UnixCaretSize;
  OnPollEvent := @UnixPollEvent;
  GetClockMs := @UnixClock;
  OnSetVideoMode := @UnixSetVideoMode;
  OnClipboardSet := @ClipSetHook;
  OnNotify := @UnixNotify;
  OnClipboardGet := @ClipGetHook;
  OnClipboardSetItems := @ClipSetItemsHook;
  OnClipboardGetItem := @ClipGetItemHook;
  OnClipboardHasItem := @ClipHasItemHook;
  OnSetFKeyTitles := @UnixFKeyTitles;
  OnWindowMaxSize := @UnixWindowMaxSize;
  OnWindowMaximize := @UnixWindowMaximize;
  OnQuickEdit := @UnixQuickEdit;
  OnColorBits := @UnixColorBits;
  Result := True;
end;

procedure UnixDone;
begin
  if not Active then
    Exit;
  UnixFlush;
  OnScreenWrite := nil;
  OnCaretPosition := nil;
  OnCaretSize := nil;
  OnNotify := nil;
  OnPollEvent := nil;
  GetClockMs := nil;
  OnSetVideoMode := nil;
  OnClipboardSet := nil;
  OnClipboardGet := nil;
  OnClipboardSetItems := nil;
  OnClipboardGetItem := nil;
  OnClipboardHasItem := nil;
  OnSetFKeyTitles := nil;
  OnWindowMaxSize := nil;
  OnWindowMaximize := nil;
  OnQuickEdit := nil;
  OnColorBits := nil;
  OsHandlersOff;
  RestoreTerminal;
  Active := False;
  FreeAndNil(F2l);
  Queued := nil;
  QueuedTake := 0;
  Writer.Free;
  if Shown <> nil then
    FreeMem(Shown);
  Shown := nil;
  ScreenDestroy;
end;

{$ELSE}

procedure UnixSuspend;
begin
end;

procedure UnixResume;
begin
end;

function UnixInit: Boolean;
begin
  Result := False;
end;

procedure UnixDone;
begin
end;

function UnixActive: Boolean;
begin
  Result := False;
end;

procedure UnixFlush;
begin
end;

{$ENDIF}

end.
