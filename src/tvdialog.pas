{ TvDialog: dialog windows and their simplest controls: TDialog, TStaticText, TLabel,
  TButton.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/dialogs.h (constants, class declarations)
    source/tvision/tdialog.cpp, tstatict.cpp, tlabel.cpp, tbutton.cpp, tvtext1.cpp
    (button shadows and markers, special characters)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - texts are ShortStrings (PStr for the fields); TStaticText.GetText fills a
      ShortString, so that descendants can give a text that changes;
    - the dialog palettes are built from the three ranges of indexes ($20, $40, $60);
    - streams are not translated yet. }
unit TvDialog;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvText, TvDrawBuf, TvScreen, TvObjs,
  TvUtil, TvTimer, TvViews, TvWindow, TvGlyphs;

const
  { the characters of the markers shown instead of colors on monochrome screens }
  SpecialChars: array[0..5] of Byte = (175, 174, 26, 27, 32, 32);
  { button flags }
  bfNormal    = $00;
  bfDefault   = $01;
  bfLeftJust  = $02;
  bfBroadcast = $04;
  bfGrabFocus = $08;

  { messages of the buttons and of the history }
  cmRecordHistory  = 60;
  cmGrabDefault    = 61;
  cmReleaseDefault = 62;

  { dialog palettes }
  dpBlueDialog = 0;
  dpCyanDialog = 1;
  dpGrayDialog = 2;

type
  TDialog = class;
  TStaticText = class;
  TLabel = class;
  TButton = class;

  { Palette: 32 entries, mapped to the application palette through the dialog palette
    of the application (see TvApp) }
  TDialog = class(TWindow)
    { used by DN: the controls of a dialog by number (the loader of its resources fills them; nil = none) }
    DirectLink: array[1..9] of TView;
    constructor Create(const Bounds: TRect; const ATitle: ShortString);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    function Valid(Command: Word): Boolean; override;
  end;

  { Palette: 1 = text. In the text, #3 at the start of a line centers it and #10 is a
    line break. }
  TStaticText = class(TView)
    Text: PStr;
    constructor Create(const Bounds: TRect; const AText: ShortString);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    destructor Destroy; override;
    procedure Draw; override;
    function GetPalette: TPalette; override;
    procedure GetText(var S: ShortString); virtual;
  end;

  { Palette: 1 = normal text, 2 = selected text, 3 = normal shortcut, 4 = selected
    shortcut }
  TLabel = class(TStaticText)
    Link: TView;
    Light: Boolean;
    constructor Create(const Bounds: TRect; const AText: ShortString; ALink: TView);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    destructor Destroy; override;
    procedure Draw; override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
  private
    procedure FocusLink(var Event: TEvent);
  end;

  { Palette: 1 = normal, 2 = default, 3 = selected, 4 = disabled, 5 = normal shortcut,
    6 = default shortcut, 7 = selected shortcut, 8 = shadow }
  TButton = class(TView)
    Title: PStr;
    Command: Word;
    Flags: Byte;
    AmDefault: Boolean;
    AnimationTimer: TTimerId;
    constructor Create(const Bounds: TRect; const ATitle: ShortString; ACommand: Word;
      AFlags: Word);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    destructor Destroy; override;
    procedure Draw; override;
    procedure DrawState(Down: Boolean);
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure MakeDefault(Enable: Boolean);
    procedure Press; virtual;
    procedure SetState(AState: Word; Enable: Boolean); override;
  private
    procedure DrawTitle(var B: TDrawBuffer; S, I: Integer; const CButton: TAttrPair;
      Down: Boolean);
  end;

var
  { stream records (see RView of TvViews) }
  RDialog, RStaticText, RLabel, RButton: TStreamRec;

var
  { UX guidelines of vtui, tier 2: an arrow key that has nowhere to go inside a group or a list (Up on the first item, Down on the last) passes the focus to the
    previous or the next control of the dialog instead of wrapping or being lost. False: the classic Turbo Vision behaviour. }
  UxNavBoundary: Boolean = True;
  { Enter in a dialog with no default button presses the first button that can act (in tab order). False: nothing happens, as in Turbo Vision. }
  UxEnterButton: Boolean = True;

{ True when V is inside a dialog and the guidelines are on. }
function UxInDialog(V: TView): Boolean;

{ Passes the focus to the previous (Forwards = False) or the next control when V is in a dialog and UxNavBoundary is on; True if it did. }
function UxPassFocus(V: TView; Forwards: Boolean): Boolean;

{ For a control that is a single item (a button): Up and Left pass the focus to the previous control, Down and Right to the next; the event is cleared.
  Vertical = True: only Up and Down (a one-line edit field keeps Left and Right for the cursor). True if the key was taken. }
function UxArrowPass(V: TView; var Event: TEvent; Vertical: Boolean = False): Boolean;

implementation

function UxInDialog(V: TView): Boolean;
var
  G: TGroup;
begin
  Result := False;
  if not UxNavBoundary or (V = nil) then
    Exit;
  G := V.Owner;
  while (G <> nil) and not (G is TDialog) do
    G := G.Owner;
  Result := G <> nil;
end;

function UxPassFocus(V: TView; Forwards: Boolean): Boolean;
begin
  Result := UxInDialog(V);
  if Result then
    V.Owner.SelectNext(not Forwards);
end;

function UxArrowPass(V: TView; var Event: TEvent; Vertical: Boolean): Boolean;
var
  Key: Word;
begin
  Result := False;
  if not UxInDialog(V) then
    Exit;
  Key := CtrlToArrow(Event.KeyCode);
  if Vertical and (Key <> kbUp) and (Key <> kbDown) then
    Exit;
  case Key of
    kbUp, kbLeft:
      Result := UxPassFocus(V, False);
    kbDown, kbRight:
      Result := UxPassFocus(V, True);
  end;
  if Result then
    ClearEvent(Event);
end;

const
  ButtonPalette = #$0A#$0B#$0C#$0D#$0E#$0E#$0E#$0F;
  StaticTextPalette = #$06;
  LabelPalette = #$07#$08#$09#$09;
  ButtonShadows: array[0..2] of LongWord = (glBlockLower, glBlockFull, glBlockUpper);
  AnimationDurationMs = 100;

function RangePalette(First: Byte): TPalette;
var
  S: ShortString;
  I: Integer;
begin
  SetLength(S, 32);
  for I := 1 to 32 do
    S[I] := Chr(First + I - 1);
  Result := MakePalette(S);
end;

var
  GrayDialog, BlueDialog, CyanDialog: TPalette;

{ --- TDialog ----------------------------------------------------------------- }

constructor TDialog.Create(const Bounds: TRect; const ATitle: ShortString);
begin
  inherited Create(Bounds, ATitle, wnNoNumber);
  GrowMode := 0;
  Flags := wfMove or wfClose;
  Palette := dpGrayDialog;
end;

function TDialog.GetPalette: TPalette;
begin
  case Palette of
    dpBlueDialog: Result := BlueDialog;
    dpCyanDialog: Result := CyanDialog;
  else
    Result := GrayDialog;
  end;
end;

function IsDefaultButton(P: TView; Args: Pointer): Boolean;
begin
  Result := (P is TButton) and TButton(P).AmDefault and ((P.State and sfDisabled) = 0);
end;

function IsActionButton(P: TView; Args: Pointer): Boolean;
begin
  Result := (P is TButton) and ((P.State and (sfDisabled or sfVisible)) = sfVisible) and ((P.Options and ofSelectable) <> 0);
end;

procedure TDialog.HandleEvent(var Event: TEvent);
var
  Btn: TView;

  { queues a new event with no InfoPtr }
  procedure Post(AWhat, ACommand: Word);
  var
    Ev: TEvent;
  begin
    FillChar(Ev, SizeOf(Ev), 0);
    Ev.What := AWhat;
    Ev.Command := ACommand;
    PutEvent(Ev);
  end;

begin
  inherited HandleEvent(Event);
  case Event.What of
    evKeyDown:
      if Event.KeyCode = kbEsc then
      begin
        ClearEvent(Event);
        Post(evCommand, cmCancel);
      end
      else if Event.KeyCode = kbEnter then
      begin
        Btn := nil;
        if UxEnterButton and (FirstThat(@IsDefaultButton, nil) = nil) and (Last <> nil) then
        begin
          { no default button: the first one that can act, in the order of Tab }
          Btn := Last;
          while not IsActionButton(Btn, nil) do
          begin
            Btn := Btn.Prev;
            if Btn = Last then
            begin
              Btn := nil;
              Break;
            end;
          end;
        end;
        ClearEvent(Event);
        if Btn = nil then
          Post(evBroadcast, cmDefault)
        else
          TButton(Btn).Press;
      end;
    evCommand:
      if ((Event.Command = cmOK) or (Event.Command = cmCancel) or (Event.Command = cmYes) or
        (Event.Command = cmNo)) and ((State and sfModal) <> 0) then
      begin
        EndModal(Event.Command);
        ClearEvent(Event);
      end;
  end;
end;

function TDialog.Valid(Command: Word): Boolean;
begin
  if Command = cmCancel then
    Result := True
  else
    Result := inherited Valid(Command);
end;

{ --- TStaticText ------------------------------------------------------------- }

constructor TStaticText.Create(const Bounds: TRect; const AText: ShortString);
begin
  inherited Create(Bounds);
  Text := NewStr(AText);
  GrowMode := GrowMode or gfFixed;
end;

destructor TStaticText.Destroy;
begin
  DisposeStr(Text);
  Text := nil;
  inherited Destroy;
end;

procedure TStaticText.GetText(var S: ShortString);
var
  I: Integer;
begin
  if Text = nil then
    S := ''
  else
    S := Text^;
  { Borland's Turbo Vision (and DN) end a line with #13, magiblot's with #10: both do here }
  for I := 1 to Length(S) do
    if S[I] = #13 then
      S[I] := #10;
end;

function TStaticText.GetPalette: TPalette;
begin
  Result := MakePalette(StaticTextPalette);
end;

procedure TStaticText.Draw;
var
  Color: TColorAttr;
  Center: Boolean;
  I, J, L, P, Y, Last, Width, CharLen, CharWidth, ScLen, ScWidth: Integer;
  B: TDrawBuffer;
  S: ShortString;
  Pt: PByte;
begin
  Color := GetColor(1).Lo;
  GetText(S);
  L := Length(S);
  Pt := @S[1];
  P := 0;
  Y := 0;
  Center := False;
  B := TDrawBuffer.Create(Size.X);
  while Y < Size.Y do
  begin
    B.MoveChar(0, Ord(' '), Color, Size.X);
    if P < L then
    begin
      if Pt[P] = 3 then
      begin
        Center := True;
        Inc(P);
      end;
      I := P;
      TextScroll(Pt + I, L - I, Size.X, False, ScLen, ScWidth);
      Last := I + ScLen;
      { take words while they fit }
      repeat
        J := P;
        while (P < L) and (Pt[P] = 32) do
          Inc(P);
        while (P < L) and (Pt[P] <> 32) and (Pt[P] <> 10) do
        begin
          TextNext(Pt + P, L - P, CharLen, CharWidth);
          Inc(P, CharLen);
        end;
      until not ((P < L) and (P < Last) and (Pt[P] <> 10));
      if P > Last then
      begin
        if J > I then
          P := J
        else
          P := Last;
      end;
      Width := TextWidth(Pt + I, P - I);
      if Center then
        J := (Size.X - Width) div 2
      else
        J := 0;
      B.MoveStr(J, Pt + I, L - I, Color, Width);
      while (P < L) and (Pt[P] = 32) do
        Inc(P);
      if (P < L) and (Pt[P] = 10) then
      begin
        Center := False;
        Inc(P);
      end;
    end;
    WriteLineD(0, Y, Size.X, 1, B);
    Inc(Y);
  end;
  B.Free;
end;

{ --- TLabel ------------------------------------------------------------------ }

constructor TLabel.Create(const Bounds: TRect; const AText: ShortString; ALink: TView);
begin
  inherited Create(Bounds, AText);
  Link := ALink;
  Light := False;
  Options := Options or ofPreProcess or ofPostProcess;
  EventMask := EventMask or evBroadcast;
end;

destructor TLabel.Destroy;
begin
  Link := nil;
  inherited Destroy;
end;

function TLabel.GetPalette: TPalette;
begin
  Result := MakePalette(LabelPalette);
end;

procedure TLabel.Draw;
var
  B: TDrawBuffer;
  Attrs: TAttrPair;
  Marker: Integer;
begin
  if Light then
  begin
    Attrs := GetColor($0402);
    Marker := 0;
  end
  else
  begin
    Attrs := GetColor($0301);
    Marker := 4;
  end;
  B := TDrawBuffer.Create(Size.X);
  B.MoveChar(0, Ord(' '), Attrs.Lo, Size.X);
  if Text <> nil then
    B.MoveCStrS(1, Text^, Attrs);
  if ShowMarkers then
    B.PutChar(0, SpecialChars[Marker]);
  WriteLineD(0, 0, Size.X, 1, B);
  B.Free;
end;

procedure TLabel.FocusLink(var Event: TEvent);
begin
  if (Link <> nil) and ((Link.Options and ofSelectable) <> 0) then
    Link.Focus;
  ClearEvent(Event);
end;

procedure TLabel.HandleEvent(var Event: TEvent);
var
  Hot: Char;
begin
  inherited HandleEvent(Event);
  case Event.What of
    evMouseDown:
      FocusLink(Event);
    evKeyDown:
      begin
        Hot := #0;
        if Text <> nil then
          Hot := HotKey(Text^);
        if (Event.KeyCode <> 0) and ((GetAltCode(Hot) = Event.KeyCode) or HotKeyAlt(Hot, Event) or
          ((Hot <> #0) and (Owner <> nil) and (Owner.Phase = phPostProcess) and
           (Hot = UpCaseCp(Chr(Event.CharCode))))) then
          FocusLink(Event);
      end;
    evBroadcast:
      if (Link <> nil) and ((Event.Command = cmReceivedFocus) or (Event.Command = cmReleasedFocus)) then
      begin
        Light := (Link.State and sfFocused) <> 0;
        DrawView;
      end;
  end;
end;

{ --- TButton ----------------------------------------------------------------- }

constructor TButton.Create(const Bounds: TRect; const ATitle: ShortString; ACommand: Word;
  AFlags: Word);
begin
  inherited Create(Bounds);
  Title := NewStr(ATitle);
  Command := ACommand;
  Flags := AFlags;
  AmDefault := (AFlags and bfDefault) <> 0;
  AnimationTimer := nil;
  Options := Options or ofSelectable or ofFirstClick or ofPreProcess or ofPostProcess;
  EventMask := EventMask or evBroadcast;
  if not CommandEnabled(ACommand) then
    State := State or sfDisabled;
end;

destructor TButton.Destroy;
begin
  DisposeStr(Title);
  Title := nil;
  KillTimer(AnimationTimer);
  inherited Destroy;
end;

function TButton.GetPalette: TPalette;
begin
  Result := MakePalette(ButtonPalette);
end;

procedure TButton.Draw;
begin
  DrawState(False);
end;

procedure TButton.DrawTitle(var B: TDrawBuffer; S, I: Integer; const CButton: TAttrPair;
  Down: Boolean);
var
  Indent, Marker: Integer;
begin
  Indent := 1;
  if (Flags and bfLeftJust) = 0 then
  begin
    Indent := (S - CStrLen(Title^) - 1) div 2;
    if Indent < 1 then
      Indent := 1;
  end;
  B.MoveCStrS(I + Indent, Title^, CButton);
  if ShowMarkers and not Down then
  begin
    if (State and sfSelected) <> 0 then
      Marker := 0
    else if AmDefault then
      Marker := 2
    else
      Marker := 4;
    B.PutChar(0, SpecialChars[Marker]);
    B.PutChar(S, SpecialChars[Marker + 1]);
  end;
end;

procedure TButton.DrawState(Down: Boolean);
var
  B: TDrawBuffer;
  CButton, CShadow: TAttrPair;
  Right, TitleRow, Row, Start: Integer;
  Bottom: LongWord;
begin
  if (State and sfDisabled) <> 0 then
    CButton := GetColor($0404)
  else if (State and (sfActive or sfSelected)) = (sfActive or sfSelected) then
    CButton := GetColor($0703)
  else if ((State and sfActive) <> 0) and AmDefault then
    CButton := GetColor($0602)
  else
    CButton := GetColor($0501);
  CShadow := GetColor(8);
  Right := Size.X - 1;
  TitleRow := Size.Y div 2 - 1;
  Bottom := Ord(' ');
  B := TDrawBuffer.Create(Size.X);
  for Row := 0 to Size.Y - 2 do
  begin
    B.MoveChar(0, Ord(' '), CButton.Lo, Size.X);
    B.PutAttribute(0, CShadow.Lo);
    if Down then
    begin
      { pressed: the face moves right by one column }
      B.PutAttribute(1, CShadow.Lo);
      Start := 2;
    end
    else
    begin
      B.PutAttribute(Right, CShadow.Lo);
      if not ShowMarkers then
      begin
        if Row = 0 then
          B.PutGlyph(Right, ButtonShadows[0])
        else
          B.PutGlyph(Right, ButtonShadows[1]);
        Bottom := ButtonShadows[2];
      end;
      Start := 1;
    end;
    if (Row = TitleRow) and (Title <> nil) then
      DrawTitle(B, Right, Start, CButton, Down);
    if ShowMarkers and not Down then
    begin
      B.PutChar(1, Ord('['));
      B.PutChar(Right - 1, Ord(']'));
    end;
    WriteLineD(0, Row, Size.X, 1, B);
  end;
  B.MoveChar(0, Ord(' '), CShadow.Lo, 2);
  B.MoveGlyph(2, Bottom, CShadow.Lo, Right - 1);
  WriteLineD(0, Size.Y - 1, Size.X, 1, B);
  B.Free;
end;

procedure TButton.HandleEvent(var Event: TEvent);
var
  Area: TRect;
  Hot: Char;
  Down, Inside: Boolean;

  procedure StartAnimation;
  begin
    DrawState(True);
    if AnimationTimer = nil then
      AnimationTimer := SetTimer(AnimationDurationMs);
    ClearEvent(Event);
  end;

begin
  { the part that reacts to the mouse: without the shadows }
  Area := GetExtent;
  Inc(Area.A.X);
  Dec(Area.B.X);
  Dec(Area.B.Y);
  if (Event.What = evMouseDown) and not Area.Contains(MakeLocal(Event.Where)) then
    ClearEvent(Event);
  if (Flags and bfGrabFocus) <> 0 then
    inherited HandleEvent(Event);
  Hot := #0;
  if Title <> nil then
    Hot := HotKey(Title^);
  case Event.What of
    evMouseDown:
      begin
        if (State and sfDisabled) = 0 then
        begin
          Inc(Area.B.X);
          Down := False;
          { follow the mouse until it is released: the button is down while the mouse is on it }
          repeat
            Inside := Area.Contains(MakeLocal(Event.Where));
            if Inside xor Down then
              DrawState(Inside);
            Down := Inside;
          until not MouseEvent(Event, evMouseMove);
          ClearEvent(Event);
          if Down then
          begin
            DrawState(False);
            Press;
          end;
        end
        else
          ClearEvent(Event);
      end;
    evKeyDown:
      if (Event.KeyCode <> 0) and ((Event.KeyCode = GetAltCode(Hot)) or HotKeyAlt(Hot, Event) or
        ((Owner <> nil) and (Owner.Phase = phPostProcess) and (Hot <> #0) and
         (Hot = UpCaseCp(Chr(Event.CharCode)))) or
        (((State and sfFocused) <> 0) and (Event.CharCode = Ord(' ')))) then
        StartAnimation
      else if (State and sfFocused) <> 0 then
        UxArrowPass(Self, Event);
    evBroadcast:
      case Event.Command of
        cmDefault:
          if AmDefault and ((State and sfDisabled) = 0) then
            StartAnimation;
        cmCommandSetChanged:
          begin
            Inside := CommandEnabled(Command);
            SetState(sfDisabled, not Inside);
            DrawView;
          end;
        cmGrabDefault, cmReleaseDefault:
          { the default button gives way while another button has the focus }
          if (Flags and bfDefault) <> 0 then
          begin
            AmDefault := Event.Command <> cmGrabDefault;
            DrawView;
          end;
        cmTimerExpired:
          if (AnimationTimer <> nil) and (Event.InfoPtr = AnimationTimer) then
          begin
            AnimationTimer := nil;
            DrawState(False);
            Press;
            ClearEvent(Event);
          end;
      end;
  end;
end;

procedure TButton.MakeDefault(Enable: Boolean);
var
  Cmd: Word;
begin
  if (Flags and bfDefault) = 0 then
  begin
    if Enable then
      Cmd := cmGrabDefault
    else
      Cmd := cmReleaseDefault;
    Message(Owner, evBroadcast, Cmd, Self);
    AmDefault := Enable;
    DrawView;
  end;
end;

procedure TButton.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if (AState and (sfSelected or sfActive)) <> 0 then
    DrawView;
  if (AState and sfFocused) <> 0 then
    MakeDefault(Enable);
end;

procedure TButton.Press;
var
  E: TEvent;
begin
  Message(Owner, evBroadcast, cmRecordHistory, nil);
  if (Flags and bfBroadcast) <> 0 then
    Message(Owner, evBroadcast, Command, Self)
  else
  begin
    ClearEvent(E);
    E.What := evCommand;
    E.Command := Command;
    E.InfoPtr := Self;
    PutEvent(E);
  end;
end;

{ --- Streams ------------------------------------------------------------------ }

{ DirectLink (DN) follows the views of the group in the stream: the numbers of the controls in the dialog (0 = none) }
constructor TDialog.Load(S: TStream);
var
  I: Integer;
begin
  inherited Load(S);
  for I := 1 to 9 do
    DirectLink[I] := ReadChildPtr(S);
end;

procedure TDialog.Store(S: TStream);
var
  I: Integer;
begin
  inherited Store(S);
  for I := 1 to 9 do
    PutSubViewPtr(S, DirectLink[I]);
end;

constructor TStaticText.Load(S: TStream);
begin
  inherited Load(S);
  Text := S.ReadStr;
end;

procedure TStaticText.Store(S: TStream);
begin
  inherited Store(S);
  S.WriteStr(Text);
end;

constructor TLabel.Load(S: TStream);
begin
  inherited Load(S);
  GetPeerViewPtr(S, Link);
  Light := False;
end;

procedure TLabel.Store(S: TStream);
begin
  inherited Store(S);
  PutPeerViewPtr(S, Link);
end;

type
  { what a button stores after its title }
  TButtonFields = packed record
    Cmd: Word;
    Flg: Byte;
    Def: LongInt;
  end;

constructor TButton.Load(S: TStream);
var
  F: TButtonFields;
begin
  inherited Load(S);
  Title := S.ReadStr;
  S.Read(F, SizeOf(F));
  Command := F.Cmd;
  Flags := F.Flg;
  AmDefault := F.Def <> 0;
  if CommandEnabled(Command) then
    State := State and not sfDisabled
  else
    State := State or sfDisabled;
  AnimationTimer := nil;
end;

procedure TButton.Store(S: TStream);
var
  F: TButtonFields;
begin
  inherited Store(S);
  S.WriteStr(Title);
  F.Cmd := Command;
  F.Flg := Flags;
  F.Def := Ord(AmDefault);
  S.Write(F, SizeOf(F));
end;

function BuildDialog(S: TStream): TStreamable;
begin
  Result := TStreamable(Pointer(TDialog.Load(S)));
end;

procedure StoreDialog(P: TStreamable; S: TStream);
begin
  TDialog(Pointer(P)).Store(S);
end;

function BuildStaticText(S: TStream): TStreamable;
begin
  Result := TStreamable(Pointer(TStaticText.Load(S)));
end;

procedure StoreStaticText(P: TStreamable; S: TStream);
begin
  TStaticText(Pointer(P)).Store(S);
end;

function BuildLabel(S: TStream): TStreamable;
begin
  Result := TStreamable(Pointer(TLabel.Load(S)));
end;

procedure StoreLabel(P: TStreamable; S: TStream);
begin
  TLabel(Pointer(P)).Store(S);
end;

function BuildButton(S: TStream): TStreamable;
begin
  Result := TStreamable(Pointer(TButton.Load(S)));
end;

procedure StoreButton(P: TStreamable; S: TStream);
begin
  TButton(Pointer(P)).Store(S);
end;


initialization
  RDialog.ObjType := 10;
  RDialog.VmtLink := PtrUInt(System.TClass(TDialog));
  RDialog.Load := @BuildDialog;
  RDialog.Store := @StoreDialog;
  RStaticText.ObjType := 18;
  RStaticText.VmtLink := PtrUInt(System.TClass(TStaticText));
  RStaticText.Load := @BuildStaticText;
  RStaticText.Store := @StoreStaticText;
  RLabel.ObjType := 19;
  RLabel.VmtLink := PtrUInt(System.TClass(TLabel));
  RLabel.Load := @BuildLabel;
  RLabel.Store := @StoreLabel;
  RButton.ObjType := 12;
  RButton.VmtLink := PtrUInt(System.TClass(TButton));
  RButton.Load := @BuildButton;
  RButton.Store := @StoreButton;
  GrayDialog := RangePalette($20);
  BlueDialog := RangePalette($40);
  CyanDialog := RangePalette($60);
end.
