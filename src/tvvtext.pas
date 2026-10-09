{ TvVtExt: the terminal side of the far2l terminal extensions for the embedded terminal (TvVt): requests of the program answered, its events built.

  MIT (see LICENSE).

  TVtExtServer takes the body of an APC string that begins with "far2l" (TVtEmu gives it) and returns the bytes that go back to the program: the
  acknowledgement of far2l1, the reply to a request with an ID (every such request gets one: the ID alone for what is unknown or broken), the size event.
  What the server cannot do by itself goes to a TVtExtHost: the question to the user about the clipboard, the notification, the F-key titles, the window.
  The base host forwards to TvSys and refuses the clipboard; TvVtView and TvVtRun give their own.

  The clipboard is the clipboard of the application (TvClip) with its formats: a client is let in by the user (the answers of the dialog "Clipboard access"),
  for the activation or always (the file far2l-clipboard-autheds of the configuration directory); its data is read only within 5 s after a paste gesture
  of the user (PasteGesture: Ctrl+V, Shift+Ins, the middle button), a read extends that time, at most 3 times. Images: no capabilities. }
unit TvVtExt;

{$I tvdefs.inc}
{$H+}

interface

uses
  SysUtils, TvFar2l, TvClip, TvSys, TvScreen, TvEvents, TvKeys;

type
  { the answers of the user to a client that asks for the clipboard }
  TVtClipAnswer = (vcaBlock, vcaRemote, vcaShare, vcaAlways);

  TVtExtHost = class
  public
    { the user is asked whether the client (its ID) may use the clipboard; the base refuses (the client keeps its own clipboard) }
    function AskClipboard(const ClientId: AnsiString): TVtClipAnswer; virtual;
    procedure Notify(const Title, Text: AnsiString); virtual;
    { Titles[0] is F1; all empty: none. True when they can be shown. }
    function FKeyTitles(const Titles: array of AnsiString): Boolean; virtual;
    procedure CursorHeight(Percent: Integer); virtual;
    function ColorBits: Integer; virtual;
    function WindowMaxSize(out Cols, Rows: Integer): Boolean; virtual;
    procedure WindowMaximize(Maximize: Boolean); virtual;
    procedure QuickEdit; virtual;
  end;

  TVtClockFunc = function: Int64;

  TVtExtServer = class
  private
    FHost: TVtExtHost;
    OwnHost: TVtExtHost;
    Features: QWord;
    HostIdent: AnsiString;
    Cols, Rows: Integer;
    ClipIsOpen: Boolean;
    Shared: array of AnsiString;
    Chunks: AnsiString;
    Items: array of TClipItem;
    GestureAt: Int64;
    GestureSeen: Boolean;
    Extends: Integer;
    After: AnsiString;
    procedure SetHost(AHost: TVtExtHost);
    function Run(var S: TF2lStack): AnsiString;
    procedure RunClip(var S, R: TF2lStack);
    function Authorize(const Id: AnsiString): ShortInt;
    function AuthedInFile(const Id: AnsiString): Boolean;
    procedure AddAuthed(const Id: AnsiString);
    function ReadAllowed(Extend: Boolean): Boolean;
    function Store(Format: LongWord; const Data: AnsiString): Boolean;
    function Fetch(Format: LongWord; out Data: AnsiString): Boolean;
    procedure CloseClip;
  public
    Active: Boolean;              { between far2l1 and far2l0 }
    CursorPercent: Integer;       { the height of the cursor that the program asked for (h), -1: none }
    AuthedsPath: AnsiString;      { the file of the clients let in always }
    Now: TVtClockFunc;            { the clock of the paste gestures (THardwareInfo.GetTickCountMs) }
    constructor Create(ACols, ARows: Integer);
    destructor Destroy; override;
    { the body of an APC string (without ESC _ and the terminator); the bytes for the program }
    function Body(const B: AnsiString): AnsiString;
    { the terminal has a new size: the size event when the program asked for it }
    function Resized(ACols, ARows: Integer): AnsiString;
    { the extensions are left (the program ended, far2l0) }
    procedure Stop;
    { the user pasted (Ctrl+V, Shift+Ins, the middle button): the program may read the clipboard for a while }
    procedure PasteGesture;
    function CompactInput: Boolean;
    { the events of a key (press or release) and of the mouse; '' when the extensions are off }
    function KeyEvent(const Event: TEvent): AnsiString;
    { Buttons: mb*, Wheel: mw*; X, Y in the cells of the terminal }
    function MouseEvent(X, Y: Integer; Buttons, Wheel: Byte; Moved, Double: Boolean; Mods: Word): AnsiString;
    property Host: TVtExtHost read FHost write SetHost;
  end;

{ The data ID of the clipboard (never 0): a hash of the data with its length; a text counts up to its first NUL. }
function VtClipDataId(Format: LongWord; const Data: AnsiString): QWord;

implementation

{ --- the base host ---------------------------------------------------------------------------------------------- }

function TVtExtHost.AskClipboard(const ClientId: AnsiString): TVtClipAnswer;
begin
  Result := vcaRemote;
end;

procedure TVtExtHost.Notify(const Title, Text: AnsiString);
begin
  TvSys.Notify(Title, Text);
end;

function TVtExtHost.FKeyTitles(const Titles: array of AnsiString): Boolean;
begin
  TvSys.SetFKeyTitles(Titles);
  Result := Assigned(OnSetFKeyTitles);
end;

procedure TVtExtHost.CursorHeight(Percent: Integer);
begin
end;

function TVtExtHost.ColorBits: Integer;
begin
  Result := TvSys.ColorBits;
  if Result = 0 then
    Result := 4;
end;

function TVtExtHost.WindowMaxSize(out Cols, Rows: Integer): Boolean;
begin
  Result := TvSys.WindowMaxSize(Cols, Rows);
end;

procedure TVtExtHost.WindowMaximize(Maximize: Boolean);
begin
  TvSys.WindowMaximize(Maximize);
end;

procedure TVtExtHost.QuickEdit;
begin
  TvSys.QuickEdit;
end;

{ --- helpers --------------------------------------------------------------------------------------------------- }

function VtClipDataId(Format: LongWord; const Data: AnsiString): QWord;
var
  N, I: Integer;
begin
  N := Length(Data);
  if Format = cfText then
  begin
    I := Pos(#0, Data);
    if I > 0 then
      N := I - 1;
  end;
  Result := QWord($CBF29CE484222325) xor QWord(N);
  for I := 1 to N do
    Result := (Result xor Byte(Data[I])) * QWord($100000001B3);
  if Result = 0 then
    Result := 1;
end;

function DefaultNow: Int64;
begin
  Result := THardwareInfo.GetTickCountMs;
end;

const
  ServerClipFeatures = F2lClipDataId or F2lClipChunkedSet;
  StatusOk = 1;
  StatusFail = 0;
  StatusClosed = -1;

{ --- the server ------------------------------------------------------------------------------------------------ }

constructor TVtExtServer.Create(ACols, ARows: Integer);
begin
  inherited Create;
  OwnHost := TVtExtHost.Create;
  FHost := OwnHost;
  Cols := ACols;
  Rows := ARows;
  CursorPercent := -1;
  AuthedsPath := F2lConfigDir + PathDelim + F2lAuthedsFile;
  Now := @DefaultNow;
end;

destructor TVtExtServer.Destroy;
begin
  OwnHost.Free;
  inherited Destroy;
end;

procedure TVtExtServer.SetHost(AHost: TVtExtHost);
begin
  if AHost = nil then
    FHost := OwnHost
  else
    FHost := AHost;
end;

function TVtExtServer.CompactInput: Boolean;
begin
  Result := (Features and F2lFeatCompactInput) <> 0;
end;

function TVtExtServer.Body(const B: AnsiString): AnsiString;
var
  S: TF2lStack;
  I: Integer;
begin
  Result := '';
  if (Length(B) < 6) or (Copy(B, 1, 5) <> 'far2l') then
    Exit;
  case B[6] of
    '1':
      begin
        Active := True;
        Result := F2lAckSeq;
      end;
    '0':
      Stop;
    '#':
      if HostIdent = '' then
      begin
        HostIdent := Copy(B, 7, 256);
        for I := 1 to Length(HostIdent) do
          if HostIdent[I] < ' ' then
            HostIdent[I] := ' ';
      end;
    ':':
      if Active and (Length(B) > 6) then
      begin
        S.Clear;
        S.Data := F2lBase64Decode(Copy(B, 7, MaxInt));
        if S.Size > 0 then
          Result := Run(S);
      end;
  end;
end;

function TVtExtServer.Resized(ACols, ARows: Integer): AnsiString;
begin
  Result := '';
  if (ACols = Cols) and (ARows = Rows) then
    Exit;
  Cols := ACols;
  Rows := ARows;
  if Active and ((Features and F2lFeatTerminalSize) <> 0) then
    Result := F2lSizeSeq(Cols, Rows);
end;

procedure TVtExtServer.Stop;
begin
  if not Active then
    Exit;
  Active := False;
  CloseClip;
  Features := 0;
  Shared := nil;
  CursorPercent := -1;
  FHost.FKeyTitles([]);
end;

{ one request: the ID and the command on top }
function TVtExtServer.Run(var S: TF2lStack): AnsiString;
var
  R: TF2lStack;
  Id: Byte;
  Cmd: Char;
  Titles: array[0..11] of AnsiString;
  T1, T2: AnsiString;
  I, W, H: Integer;
begin
  Result := '';
  After := '';
  Id := S.PopU8;
  Cmd := Chr(S.PopU8);
  R.Clear;
  if not S.Bad then
    case Cmd of
      f2rFeatures:
        begin
          Features := S.PopU64;
          if not S.Bad and ((Features and F2lFeatTerminalSize) <> 0) then
            After := F2lSizeSeq(Cols, Rows);
        end;
      f2rQuickEdit:
        FHost.QuickEdit;
      f2rMaximize, f2rRestore:
        FHost.WindowMaximize(Cmd = f2rMaximize);
      f2rCursorHeight:
        begin
          I := S.PopU8;
          if not S.Bad then
          begin
            if I > 100 then
              I := 100;
            CursorPercent := I;
            FHost.CursorHeight(I);
          end;
        end;
      f2rMaxSize:
        begin
          if not FHost.WindowMaxSize(W, H) or (W <= 0) or (H <= 0) then
          begin
            W := Cols;
            H := Rows;
          end;
          R.PushU16(Word(W));
          R.PushU16(Word(H));
        end;
      f2rNotify:
        begin
          T1 := S.PopStr;
          T2 := S.PopStr;
          if not S.Bad then
            FHost.Notify(T1, T2);
        end;
      f2rFKeys:
        begin
          for I := 0 to 11 do
          begin
            Titles[I] := '';
            if S.Size = 0 then
              Continue;
            if S.PopU8 <> 0 then
              Titles[I] := S.PopStr;
          end;
          if not S.Bad then
            R.PushU8(Ord(FHost.FKeyTitles(Titles)));
        end;
      f2rPalette:
        begin
          R.PushU8(0);
          R.PushU8(FHost.ColorBits);
        end;
      f2rClipboard:
        RunClip(S, R);
      f2rImage:
        if Chr(S.PopU8) = f2iCaps then
        begin
          R.PushU64(0);              { no capabilities, no cell size }
          R.PushU16(0);
          R.PushU16(0);
        end
        else
          R.PushU8(0);
    end;
  if S.Bad then
    R.Clear;                         { a request that was too short: the ID alone }
  if Id <> 0 then
  begin
    R.PushU8(Id);
    Result := F2lReplySeq(R);
  end;
  Result := Result + After;
end;

procedure TVtExtServer.RunClip(var S, R: TF2lStack);
var
  Sub: Char;
  Id, Data: AnsiString;
  Fmt, Size: LongWord;
  N: Word;
  St: ShortInt;
  Ok: Boolean;
begin
  Sub := Chr(S.PopU8);
  if S.Bad then
    Exit;
  case Sub of
    f2cOpen:
      begin
        Id := S.PopStr;
        Chunks := '';
        if S.Bad then
          Exit;
        if not F2lValidClientId(Id) or ClipIsOpen then
          St := StatusFail
        else
        begin
          if HostIdent <> '' then
            Id := HostIdent + ':' + Id;
          St := Authorize(Id);
          if St = StatusOk then
          begin
            ClipIsOpen := True;
            Items := nil;
          end;
        end;
        R.PushU64(ServerClipFeatures);
        R.PushU8(Byte(St));
      end;
    f2cClose:
      begin
        if ClipIsOpen then St := StatusOk else St := StatusClosed;
        CloseClip;
        R.PushU8(Byte(St));
      end;
    f2cEmpty:
      if ClipIsOpen then
      begin
        Items := nil;
        ClipboardSetItems([]);
        R.PushU8(StatusOk);
      end
      else
        R.PushU8(Byte(StatusClosed));
    f2cIsAvail:
      begin
        Fmt := S.PopU32;
        if not S.Bad then
          R.PushU8(Ord(ClipboardHasItem(Fmt)));
      end;
    f2cSetChunk:
      begin
        N := S.PopU16;
        Data := S.PopRaw(Integer(N) shl 8);
        if S.Bad or not ClipIsOpen then
          Exit;
        if N = 0 then
          Chunks := ''
        else
          Chunks := Chunks + Data;
      end;
    f2cSetData:
      begin
        Fmt := S.PopU32;
        Size := S.PopU32;
        if S.Bad then
          Exit;
        Data := S.PopRaw(Integer(Size));
        if S.Bad then
          Exit;
        if not ClipIsOpen then
        begin
          R.PushU8(Byte(StatusClosed));
          Exit;
        end;
        Data := Chunks + Data;
        Chunks := '';
        Ok := Store(Fmt, Data);
        if Ok then
        begin
          R.PushU64(VtClipDataId(Fmt, Data));
          R.PushU8(StatusOk);
        end
        else
          R.PushU8(StatusFail);
      end;
    f2cGetData:
      begin
        Fmt := S.PopU32;
        if S.Bad then
          Exit;
        if not ClipIsOpen then
          R.PushU32($FFFFFFFF)
        else if ReadAllowed(True) and Fetch(Fmt, Data) then
        begin
          R.PushU64(VtClipDataId(Fmt, Data));
          R.PushRaw(Data);
          R.PushU32(Length(Data));
        end
        else
        begin
          R.PushU64(0);
          R.PushU32(0);
        end;
      end;
    f2cGetDataId:
      begin
        Fmt := S.PopU32;
        if S.Bad then
          Exit;
        if ClipIsOpen and ReadAllowed(False) and Fetch(Fmt, Data) then
          R.PushU64(VtClipDataId(Fmt, Data))
        else
          R.PushU64(0);
      end;
    f2cRegister:
      begin
        Id := S.PopStr;
        if not S.Bad then
          R.PushU32(ClipboardRegisterFormat(Id));
      end;
  end;
end;

procedure TVtExtServer.CloseClip;
begin
  ClipIsOpen := False;
  Chunks := '';
  Items := nil;
  Extends := 0;
end;

function TVtExtServer.Authorize(const Id: AnsiString): ShortInt;
var
  I: Integer;
begin
  for I := 0 to High(Shared) do
    if Shared[I] = Id then
      Exit(StatusOk);
  if AuthedInFile(Id) then
    Exit(StatusOk);
  case FHost.AskClipboard(Id) of
    vcaRemote: Exit(StatusClosed);
    vcaShare: ;
    vcaAlways: AddAuthed(Id);
  else
    Exit(StatusFail);
  end;
  I := Length(Shared);
  SetLength(Shared, I + 1);
  Shared[I] := Id;
  Result := StatusOk;
end;

function TVtExtServer.AuthedInFile(const Id: AnsiString): Boolean;
var
  T: TextFile;
  Line: AnsiString;
begin
  Result := False;
  if (AuthedsPath = '') or not FileExists(AuthedsPath) then
    Exit;
  AssignFile(T, AuthedsPath);
  {$I-}
  Reset(T);
  {$I+}
  if IOResult <> 0 then
    Exit;
  while not Eof(T) and not Result do
  begin
    ReadLn(T, Line);
    Result := Trim(Line) = Id;
  end;
  CloseFile(T);
end;

procedure TVtExtServer.AddAuthed(const Id: AnsiString);
var
  T: TextFile;
begin
  if AuthedsPath = '' then
    Exit;
  ForceDirectories(ExtractFileDir(AuthedsPath));
  AssignFile(T, AuthedsPath);
  {$I-}
  if FileExists(AuthedsPath) then
    Append(T)
  else
    Rewrite(T);
  {$I+}
  if IOResult <> 0 then
    Exit;
  WriteLn(T, Id);
  CloseFile(T);
end;

procedure TVtExtServer.PasteGesture;
begin
  GestureSeen := True;
  GestureAt := Now();
  Extends := 0;
end;

function TVtExtServer.ReadAllowed(Extend: Boolean): Boolean;
var
  T: Int64;
begin
  Result := False;
  if not GestureSeen then
    Exit;
  T := Now();
  if T - GestureAt > F2lGestureMs then
    Exit;
  if Extend and (Extends < F2lGestureExtends) then
  begin
    GestureAt := T;
    Inc(Extends);
  end;
  Result := True;
end;

{ the clipboard of the application gets every format this client set since it opened (SetClipboardData keeps the other formats); the two text
  formats are one text (UTF-8) }
function TVtExtServer.Store(Format: LongWord; const Data: AnsiString): Boolean;
var
  D: AnsiString;
  I: Integer;
begin
  D := Data;
  case Format of
    cfText:
      begin
        I := Pos(#0, D);
        if I > 0 then
          SetLength(D, I - 1);
      end;
    cfUnicodeText:
      begin
        D := F2lUtf32ToUtf8(D);
        Format := cfText;
      end;
  end;
  I := 0;
  while (I < Length(Items)) and (Items[I].Format <> Format) do
    Inc(I);
  if I = Length(Items) then
    SetLength(Items, I + 1);
  Items[I] := ClipItem(Format, D);
  ClipboardSetItems(Items);
  Result := True;
end;

function TVtExtServer.Fetch(Format: LongWord; out Data: AnsiString): Boolean;
begin
  case Format of
    cfText:
      Result := ClipboardGetItem(cfText, Data) and (Data <> '');
    cfUnicodeText:
      begin
        Result := ClipboardGetItem(cfText, Data) and (Data <> '');
        if Result then
          Data := F2lUtf8ToUtf32(Data);
      end;
  else
    Result := ClipboardGetItem(Format, Data);
  end;
  if not Result then
    Data := '';
end;

{ --- the events ------------------------------------------------------------------------------------------------ }

function TVtExtServer.KeyEvent(const Event: TEvent): AnsiString;
var
  Hi, Lo: Word;
  Ch: LongWord;
  Cs: Word;
  Rep: Word;
begin
  Result := '';
  if not Active then
    Exit;
  Ch := 0;
  case EventUtf16(Event, Hi, Lo) of
    1: Ch := Lo;
    2: Ch := $10000 + ((LongWord(Hi) - $D800) shl 10) + (LongWord(Lo) - $DC00);
  end;
  Cs := EventWin32State(Event);
  { Ctrl with a letter gives the control character (as a console of Windows does) }
  if ((Cs and (wkLeftCtrl or wkRightCtrl)) <> 0) and ((Cs and (wkLeftAlt or wkRightAlt)) = 0) then
    case Ch of
      Ord('a')..Ord('z'): Ch := Ch - Ord('a') + 1;
      Ord('@')..Ord('_'): Ch := Ch - Ord('@');
    end;
  Rep := Event.KeyDown.RepeatCount;
  if Rep = 0 then
    Rep := 1;
  Result := F2lKeySeq(Event.What <> evKeyUp, Ch, Cs, EventScanCode(Event), EventVirtualKey(Event), Rep, CompactInput);
end;

function TVtExtServer.MouseEvent(X, Y: Integer; Buttons, Wheel: Byte; Moved, Double: Boolean; Mods: Word): AnsiString;
const
  WheelUp = LongWord($0001) shl 16;
  WheelDown = LongWord($FFFF) shl 16;
var
  Flags, State, Ks: LongWord;
begin
  Result := '';
  if not Active then
    Exit;
  State := 0;
  if (Buttons and mbLeftButton) <> 0 then State := State or 1;
  if (Buttons and mbRightButton) <> 0 then State := State or 2;
  if (Buttons and mbMiddleButton) <> 0 then State := State or 4;
  Flags := 0;
  if Moved then Flags := Flags or 1;
  if Double then Flags := Flags or 2;
  if (Wheel and (mwUp or mwDown)) <> 0 then
  begin
    Flags := Flags or 4;
    if (Wheel and mwUp) <> 0 then State := State or WheelUp else State := State or WheelDown;
  end
  else if (Wheel and (mwLeft or mwRight)) <> 0 then
  begin
    Flags := Flags or 8;
    if (Wheel and mwRight) <> 0 then State := State or WheelUp else State := State or WheelDown;
  end;
  Ks := 0;
  if (Mods and kbShift) <> 0 then Ks := Ks or wkShift;
  if (Mods and kbCtrlShift) <> 0 then Ks := Ks or wkLeftCtrl;
  if (Mods and kbAltShift) <> 0 then Ks := Ks or wkLeftAlt;
  Result := F2lMouseSeq(Flags, Ks, State, X, Y, CompactInput);
end;

end.
