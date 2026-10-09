{ TvInput: the input line (TInputLine) and the input box.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/dialogs.h (TInputLine), source/tvision/tinputli.cpp,
    msgbox.cpp (inputBox, inputBoxRect), tvtext1.cpp (the arrows)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the text is a ShortString (Data: PStr, MaxLen characters in the Pascal sense: the
      longest text, 1..255); only the limit in bytes exists, not the limits in columns or
      characters (ilMaxWidth, ilMaxChars);
    - InputLineOem: when set, the text typed or pasted (UTF-8) is converted to one byte
      of the current code page, so programs whose strings are OEM bytes (DOS) keep their
      data format; the clipboard is converted back;
    - paste is synchronous (TvClip): the first line of the clipboard is inserted;
    - streams are not translated yet. }
unit TvInput;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvGeom, TvColors, TvKeys, TvEvents, TvText, TvUtf8, TvCodePg, TvDrawBuf,
  TvObjs, TvUtil, TvClip, TvViews, TvDialog, TvMsgBox, TvApp, TvValid, TvWordNav;

type
  TInputLine = class;
  { Palette: 1 = passive, 2 = active, 3 = selected, 4 = arrows }
  TInputLine = class(TView)
    Data: PStr;
    MaxLen: Integer;
    CurPos: Integer;
    FirstPos: Integer;
    SelStart: Integer;
    SelEnd: Integer;
    Validator: TValidator;
    { used by DN: the characters at the edges when the text does not scroll (default: spaces) and own colors of the
      four palette entries (BIOS attributes in the low bytes; 0 = the palette of the dialog) }
    LC, RC: Char;
    C: array[1..4] of Word;
    { Up and Down in a dialog pass the focus to the previous and the next control (guidelines, tier 2: a one-line field has no vertical movement);
      True keeps them for the owner of the field (a history list opens on Down) }
    KeepVertical: Boolean;
    constructor Create(const Bounds: TRect; AMaxLen: Integer);
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    destructor Destroy; override;
    function DataSize: Integer; override;
    procedure Draw; override;
    procedure GetData(var Rec); override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure SelectAll(Enable: Boolean; Scroll: Boolean = True);
    procedure SetData(var Rec); override;
    procedure SetState(AState: Word; Enable: Boolean); override;
    function Valid(Command: Word): Boolean; override;
    procedure SetValidator(AValid: TValidator);
  private
    Anchor: Integer;
    OldData: PStr;
    OldCurPos, OldFirstPos, OldSelStart, OldSelEnd: Integer;
    function CanScroll(Delta: Integer): Boolean;
    function MouseDelta(var Event: TEvent): Integer;
    function MousePos(var Event: TEvent): Integer;
    function DisplayedPos(Pos: Integer): Integer;
    procedure DeleteSelect;
    procedure DeleteCurrent;
    procedure AdjustSelectBlock;
    procedure SaveState;
    procedure RestoreState;
    function CheckValid(NoAutoFill: Boolean): Boolean;
    function CanUpdateCommands: Boolean;
    procedure SetCmdState(Command: Word; Enable: Boolean);
    procedure UpdateCommands;
    procedure TypeText(KeyText: ShortString);
  end;

var
  { see the note at the top of the unit }
  InputLineOem: Boolean = False;

{ A dialog with a label and an input line; S is the text (changed unless Cancel). }
function InputBox(const Title, ALabel: ShortString; var S: ShortString; Limit: Byte): Word;
function InputBoxRect(const Bounds: TRect; const Title, ALabel: ShortString;
  var S: ShortString; Limit: Byte): Word;

var
  { stream records (see RView of TvViews) }
  RInputLine: TStreamableClass;

implementation

const
  ControlY = 25;
  RightArrow = $10;
  LeftArrow = $11;
  InputLinePalette = #$13#$13#$14#$15;
  PadKeys: array[0..5] of Byte = ($47, $4B, $4D, $4F, $73, $74);

{ a text typed (UTF-8) to the form the line keeps }
function ToLine(const S: ShortString): ShortString;
var
  I, Used: Integer;
  Cp: LongWord;
  B: Byte;
begin
  if not InputLineOem then
    Exit(S);
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if Byte(S[I]) < $80 then
    begin
      Result := Result + S[I];
      Inc(I);
    end
    else if Utf8Decode(@S[I], Length(S) - I + 1, Cp, Used) then
    begin
      B := CpFromUnicode(Cp);
      if B = 0 then
        B := Ord('?');
      Result := Result + Chr(B);
      Inc(I, Used);
    end
    else
    begin
      Result := Result + S[I];
      Inc(I);
    end;
  end;
end;

{ a position inside a UTF-8 sequence moves back to its start }
function ToCharStart(const S: ShortString; Pos: Integer): Integer;
begin
  Result := Pos;
  if InputLineOem then
    Exit;
  while (Result > 0) and (Result < Length(S)) and ((Byte(S[Result + 1]) and $C0) = $80) do
    Dec(Result);
end;

function PrevWord(const S: ShortString; Pos: Integer): Integer;
var
  I: Integer;
begin
  for I := Pos - 1 downto 1 do
    if (S[I + 1] <> ' ') and (S[I] = ' ') then
      Exit(I);
  Result := 0;
end;

function NextWord(const S: ShortString; Pos: Integer): Integer;
var
  I: Integer;
begin
  for I := Pos to Length(S) - 2 do
    if (S[I + 1] = ' ') and (S[I + 2] <> ' ') then
      Exit(I + 1);
  Result := Length(S);
end;

constructor TInputLine.Create(const Bounds: TRect; AMaxLen: Integer);
begin
  inherited Create(Bounds);
  LC := ' ';
  RC := ' ';
  if AMaxLen < 1 then
    AMaxLen := 1;
  if AMaxLen > 255 then
    AMaxLen := 255;
  MaxLen := AMaxLen;
  GetMem(Data, MaxLen + 1);
  GetMem(OldData, MaxLen + 1);
  Data^ := '';
  OldData^ := '';
  CurPos := 0;
  FirstPos := 0;
  SelStart := 0;
  SelEnd := 0;
  Validator := nil;
  State := State or sfCursorVis;
  Options := Options or ofSelectable or ofFirstClick;
end;

destructor TInputLine.Destroy;
begin
  FreeMem(Data);
  FreeMem(OldData);
  Data := nil;
  OldData := nil;
  if Validator <> nil then
    Validator.Free;
  Validator := nil;
  inherited Destroy;
end;

function TInputLine.CanScroll(Delta: Integer): Boolean;
begin
  if Delta < 0 then
    Result := FirstPos > 0
  else if Delta > 0 then
    Result := TText.Width(Data^) - FirstPos + 2 > Size.X
  else
    Result := False;
end;

function TInputLine.DataSize: Integer;
var
  DSize: Integer;
begin
  DSize := 0;
  if Validator <> nil then
    DSize := Validator.Transfer(Data^, nil, vtDataSize);
  if DSize = 0 then
    DSize := MaxLen + 1;
  Result := DSize;
end;

function TInputLine.DisplayedPos(Pos: Integer): Integer;
begin
  Result := TText.Width(@Data^[1], Pos);
end;

procedure TInputLine.Draw;
var
  B: TDrawBuffer;
  Color: TColorAttr;
  L, R: Integer;

  { an own color of DN, else the one of the palette }
  function Col(I: Integer): TColorAttr;
  begin
    if C[I] <> 0 then
      Result := TColorAttr(LongInt(Lo(C[I])))
    else
      Result := GetColor(I)[0];
  end;

begin
  if (State and sfFocused) <> 0 then
    Color := Col(2)
  else
    Color := Col(1);
  B := TDrawBuffer.Create(Size.X);
  B.MoveChar(0, Ord(' '), Color, Size.X);
  if Size.X > 1 then
    B.MoveStrS(1, Data^, Color, Size.X - 1, FirstPos);
  if CanScroll(-1) then
    B.MoveChar(0, LeftArrow, Col(4), 1)
  else
    B.MoveChar(0, Ord(LC), Color, 1);
  if CanScroll(1) then
    B.MoveChar(Size.X - 1, RightArrow, Col(4), 1)
  else
    B.MoveChar(Size.X - 1, Ord(RC), Color, 1);
  if GetState(sfSelected) then
  begin
    { the screen columns of the selection, inside the arrows }
    L := DisplayedPos(SelStart) - FirstPos + 1;
    R := DisplayedPos(SelEnd) - FirstPos;
    if R > Size.X - 2 then
      R := Size.X - 2;
    if L < 1 then
      L := 1;
    if R >= L then
      B.MoveChar(L, 0, Col(3), R - L + 1);
  end;
  WriteLine(0, 0, Size.X, Size.Y, B);
  B.Free;
  SetCursor(DisplayedPos(CurPos) - FirstPos + 1, 0);
end;

procedure TInputLine.GetData(var Rec);
begin
  if (Validator = nil) or (Validator.Transfer(Data^, @Rec, vtGetData) = 0) then
    Move(Data^, Rec, DataSize);
end;

function TInputLine.GetPalette: TPalette;
begin
  Result := TPalette.Create(InputLinePalette, Length(InputLinePalette));
end;

function TInputLine.MouseDelta(var Event: TEvent): Integer;
var
  Mouse: TPoint;
begin
  Mouse := MakeLocal(Event.Mouse.Where);
  if Mouse.X <= 0 then
    Result := -1
  else if Mouse.X >= Size.X - 1 then
    Result := 1
  else
    Result := 0;
end;

function TInputLine.MousePos(var Event: TEvent): Integer;
var
  X, Bytes, Cols: Integer;
begin
  X := MakeLocal(Event.Mouse.Where).X;
  if X < 1 then
    X := 1;
  X := X + FirstPos - 1;
  if X < 0 then
    X := 0;
  { the column is turned into the number of bytes before it }
  TText.Scroll(@Data^[1], Length(Data^), X, False, Bytes, Cols);
  Result := Bytes;
end;

procedure TInputLine.DeleteSelect;
begin
  if SelStart >= SelEnd then
    Exit;
  Delete(Data^, SelStart + 1, SelEnd - SelStart);
  CurPos := SelStart;
end;

procedure TInputLine.DeleteCurrent;
var
  CharLen, CharWidth: Integer;
begin
  if CurPos < Length(Data^) then
  begin
    SelStart := CurPos;
    TText.Next(@Data^[CurPos + 1], Length(Data^) - CurPos, CharLen, CharWidth);
    SelEnd := CurPos + CharLen;
    DeleteSelect;
  end;
end;

procedure TInputLine.AdjustSelectBlock;
begin
  if Anchor <= CurPos then
  begin
    SelStart := Anchor;
    SelEnd := CurPos;
  end
  else
  begin
    SelStart := CurPos;
    SelEnd := Anchor;
  end;
end;

procedure TInputLine.SaveState;
begin
  if Validator = nil then
    Exit;
  OldData^ := Data^;
  OldCurPos := CurPos;
  OldFirstPos := FirstPos;
  OldSelStart := SelStart;
  OldSelEnd := SelEnd;
end;

procedure TInputLine.RestoreState;
begin
  if Validator <> nil then
  begin
    Data^ := OldData^;
    CurPos := OldCurPos;
    FirstPos := OldFirstPos;
    SelStart := OldSelStart;
    SelEnd := OldSelEnd;
  end;
end;

function TInputLine.CheckValid(NoAutoFill: Boolean): Boolean;
var
  OldLen, NewLen: Integer;
  NewData: ShortString;
begin
  Result := True;
  if Validator <> nil then
  begin
    NewData := Data^;
    OldLen := Length(Data^);
    if not Validator.IsValidInput(NewData, NoAutoFill) then
    begin
      RestoreState;
      Result := False;
    end
    else
    begin
      NewLen := Length(NewData);
      if NewLen > MaxLen then
      begin
        SetLength(NewData, MaxLen);
        NewLen := MaxLen;
      end;
      Data^ := NewData;
      if (CurPos >= OldLen) and (NewLen > OldLen) then
        CurPos := NewLen;
    end;
  end;
end;

function TInputLine.CanUpdateCommands: Boolean;
begin
  Result := (State and (sfActive or sfSelected)) = (sfActive or sfSelected);
end;

procedure TInputLine.SetCmdState(Command: Word; Enable: Boolean);
var
  S: TCommandSet;
begin
  S := Default(TCommandSet);
  S := S + Command;
  if Enable and CanUpdateCommands then
    EnableCommands(S)
  else
    DisableCommands(S);
end;

procedure TInputLine.UpdateCommands;
begin
  SetCmdState(cmCut, SelStart < SelEnd);
  SetCmdState(cmCopy, SelStart < SelEnd);
  SetCmdState(cmPaste, True);
end;

{ inserts typed (or pasted) text at the cursor, as the keyboard does }
procedure TInputLine.TypeText(KeyText: ShortString);
begin
  KeyText := ToLine(KeyText);
  if Length(KeyText) = 0 then
    Exit;
  DeleteSelect;
  if (State and sfCursorIns) <> 0 then
    DeleteCurrent;
  if CheckValid(True) then
  begin
    if KeyText[1] in [#9, #13, #10] then
      KeyText[1] := ' ';     { tabs and line breaks become blanks }
    if Length(Data^) + Length(KeyText) <= MaxLen then
    begin
      if FirstPos > CurPos then
        FirstPos := CurPos;
      Insert(KeyText, Data^, CurPos + 1);
      Inc(CurPos, Length(KeyText));
    end;
    CheckValid(False);
  end;
end;

procedure TInputLine.HandleEvent(var Event: TEvent);
var
  Delta, W: Integer;
  Key: Word;
  Extend, Shifted: Boolean;
  Pasted: AnsiString;

  function WordLeft(Pos: Integer): Integer;
  begin
    if UxWordNav then
      Result := WordNavLeft(Data^, Pos, Shifted)
    else
      Result := PrevWord(Data^, Pos);
  end;

  function WordRight(Pos: Integer): Integer;
  begin
    if UxWordNav then
      Result := WordNavRight(Data^, Pos, Shifted)
    else
      Result := NextWord(Data^, Pos);
  end;

  { the selection (in UTF-8) to the clipboard }
  procedure CopySelection;
  var
    T: AnsiString;
  begin
    T := Copy(Data^, SelStart + 1, SelEnd - SelStart);
    if InputLineOem then
      T := OemToUtf8(T);
    ClipboardSetText(T);
  end;

  { the first line of a text is typed in }
  procedure PasteText(const T: AnsiString);
  var
    N: Integer;
  begin
    N := 1;
    while (N <= Length(T)) and (N <= 255) and not (T[N] in [#13, #10]) do
      Inc(N);
    TypeText(Copy(T, 1, N - 1));
  end;

  { the cursor is kept in view }
  procedure ShowCursorPos;
  begin
    W := DisplayedPos(CurPos);
    if FirstPos > W then
      FirstPos := W;
    if FirstPos < W - Size.X + 2 then
      FirstPos := W - Size.X + 2;
    DrawView;
  end;

begin
  inherited HandleEvent(Event);
  if (State and sfSelected) = 0 then
    Exit;
  case Event.What of
    evMouseDown:
      begin
        Delta := MouseDelta(Event);
        if CanScroll(Delta) then
        begin
          { on an arrow: the text scrolls while the button is held }
          while True do
          begin
            if CanScroll(Delta) then
            begin
              FirstPos := FirstPos + Delta;
              DrawView;
            end;
            if not MouseEvent(Event, evMouseAuto) then
              Break;
          end;
        end
        else if (Event.Mouse.EventFlags and meDoubleClick) <> 0 then
          SelectAll(True)
        else
        begin
          Anchor := MousePos(Event);
          repeat
            if Event.What = evMouseAuto then
            begin
              Delta := MouseDelta(Event);
              if CanScroll(Delta) then
                Inc(FirstPos, Delta);
            end;
            CurPos := MousePos(Event);
            AdjustSelectBlock;
            DrawView;
          until not MouseEvent(Event, evMouseMove or evMouseAuto);
        end;
        ClearEvent(Event);
      end;
    evKeyDown:
      begin
        { Up and Down leave the field (in a dialog), unless its owner wants them }
        if not KeepVertical and ((State and sfFocused) <> 0) and UxArrowPass(Self, Event, True) then
          Exit;
        if (Event.KeyDown.KeyCode = kbCtrlIns) or (Event.KeyDown.KeyCode = kbCtrlC) then
        begin
          CopySelection;
          ClearEvent(Event);
          Exit;
        end;
        SaveState;
        if (Event.KeyDown.ControlKeyState and kbPaste) <> 0 then
        begin
          { a pasted text comes as many key events: it is taken at once }
          if TextEvent(Event, Pasted) then
          begin
            PasteText(Pasted);
            SelStart := 0;
            SelEnd := 0;
            ShowCursorPos;
          end;
          if CanUpdateCommands then
            UpdateCommands;
          Exit;
        end;
        Key := CtrlToArrow(Event.KeyDown.KeyCode);
        Shifted := (Event.KeyDown.ControlKeyState and kbShift) <> 0;
        Extend := Shifted and (Pos(Chr(Hi(Key)), #$47#$4B#$4D#$4F#$73#$74) > 0);
        if Extend then
        begin
          { the end of the selection away from the cursor stays put }
          if CurPos = SelEnd then
            Anchor := SelStart
          else if SelStart = SelEnd then
            Anchor := CurPos
          else
            Anchor := SelEnd;
        end;
        case Key of
          kbLeft: Dec(CurPos, TText.Prev(@Data^[1], CurPos));
          kbRight:
            if CurPos < Length(Data^) then
            begin
              TText.Next(@Data^[CurPos + 1], Length(Data^) - CurPos, Delta, W);
              Inc(CurPos, Delta);
            end;
          kbCtrlLeft: CurPos := WordLeft(CurPos);
          kbCtrlRight: CurPos := WordRight(CurPos);
          kbHome: CurPos := 0;
          kbEnd: CurPos := Length(Data^);
          kbBack, kbCtrlBack, kbAltBack:
            begin
              if SelStart = SelEnd then
              begin
                if Key = kbBack then
                  SelStart := CurPos - TText.Prev(@Data^[1], CurPos)
                else
                  SelStart := WordLeft(CurPos);
                SelEnd := CurPos;
              end;
              DeleteSelect;
              CheckValid(True);
            end;
          kbDel:
            begin
              if SelStart = SelEnd then
                DeleteCurrent
              else
                DeleteSelect;
              CheckValid(True);
            end;
          kbCtrlDel:
            begin
              if SelStart = SelEnd then
              begin
                SelStart := CurPos;
                SelEnd := WordRight(CurPos);
              end;
              DeleteSelect;
              CheckValid(True);
            end;
          kbIns: SetState(sfCursorIns, (State and sfCursorIns) = 0);
        else
          if Event.KeyDown.TextLength > 0 then
            TypeText(EventText(Event))
          else if Event.KeyDown.CharScan.CharCode = ControlY then
          begin
            Data^ := '';
            CurPos := 0;
          end
          else
            Exit;
        end;
        if Extend then
          AdjustSelectBlock
        else
        begin
          SelStart := 0;
          SelEnd := 0;
        end;
        ShowCursorPos;
        ClearEvent(Event);
      end;
    evCommand:
      case Event.Message.Command of
        cmPaste:
          begin
            SaveState;
            PasteText(ClipboardGetText);
            SelStart := 0;
            SelEnd := 0;
            ShowCursorPos;
            ClearEvent(Event);
          end;
        cmCut, cmCopy:
          begin
            CopySelection;
            if Event.Message.Command = cmCut then
            begin
              SaveState;
              DeleteSelect;
              CheckValid(True);
              SelStart := 0;
              SelEnd := 0;
              DrawView;
            end;
            ClearEvent(Event);
          end;
      end;
  end;
  if CanUpdateCommands then
    UpdateCommands;
end;

procedure TInputLine.SelectAll(Enable: Boolean; Scroll: Boolean);
begin
  SelStart := 0;
  if Enable then
  begin
    CurPos := Length(Data^);
    SelEnd := CurPos;
  end
  else
  begin
    CurPos := 0;
    SelEnd := 0;
  end;
  if Scroll then
  begin
    FirstPos := DisplayedPos(CurPos) - Size.X + 2;
    if FirstPos < 0 then
      FirstPos := 0;
  end;
  DrawView;
  if CanUpdateCommands then
    UpdateCommands;
end;

procedure TInputLine.SetData(var Rec);
begin
  if (Validator = nil) or (Validator.Transfer(Data^, @Rec, vtSetData) = 0) then
  begin
    Move(Rec, Data^, DataSize - 1);
    if Length(Data^) > MaxLen then
      SetLength(Data^, MaxLen);
  end;
  SelectAll(True);
end;

procedure TInputLine.SetState(AState: Word; Enable: Boolean);
var
  UpdateBefore, UpdateAfter: Boolean;
begin
  UpdateBefore := CanUpdateCommands;
  inherited SetState(AState, Enable);
  UpdateAfter := CanUpdateCommands;
  if (AState = sfSelected) or ((AState = sfActive) and ((State and sfSelected) <> 0)) then
    SelectAll(Enable, False);
  if UpdateBefore <> UpdateAfter then
    UpdateCommands;
end;

procedure TInputLine.SetValidator(AValid: TValidator);
begin
  if Validator <> nil then
    Validator.Free;
  Validator := AValid;
end;

function TInputLine.Valid(Command: Word): Boolean;
begin
  Result := True;
  if Validator <> nil then
  begin
    if Command = cmValid then
      Result := Validator.Status = vsOk
    else if Command <> cmCancel then
      if not Validator.Validate(Data^) then
      begin
        Select;
        Result := False;
      end;
  end;
end;

{ --- input box --------------------------------------------------------------- }

function InputBoxRect(const Bounds: TRect; const Title, ALabel: ShortString;
  var S: ShortString; Limit: Byte): Word;
var
  Dlg: TDialog;
  Line: TInputLine;
  R: TRect;
  X: Integer;
begin
  Dlg := TDialog.Create(Bounds, Title);
  R := TRect.Create(Length(ALabel) + 4, 2, Dlg.Size.X - 3, 3);
  Line := TInputLine.Create(R, Limit);
  Dlg.Insert(Line);
  R := TRect.Create(2, 2, Length(ALabel) + 3, 3);
  Dlg.Insert(TLabel.Create(R, ALabel, Line));
  { OK and Cancel at the bottom right }
  X := Dlg.Size.X - 24;
  R := TRect.Create(X, Dlg.Size.Y - 4, X + 10, Dlg.Size.Y - 2);
  Dlg.Insert(TButton.Create(R, MsgBoxText.OkText, cmOK, bfDefault));
  R.Move(12, 0);
  Dlg.Insert(TButton.Create(R, MsgBoxText.CancelText, cmCancel, bfNormal));
  Dlg.SelectNext(False);
  Dlg.SetData(S);
  Result := TProgram.Application.ExecView(Dlg);
  if Result <> cmCancel then
    Dlg.GetData(S);
  Dlg.Free;
end;

function InputBox(const Title, ALabel: ShortString; var S: ShortString; Limit: Byte): Word;
var
  R: TRect;
  X, Y: Integer;
begin
  { 60 by 8 in the middle of the desktop }
  X := (TProgram.DeskTop.Size.X - 60) div 2;
  Y := (TProgram.DeskTop.Size.Y - 8) div 2;
  R := TRect.Create(X, Y, X + 60, Y + 8);
  Result := InputBoxRect(R, Title, ALabel, S, Limit);
end;

{ --- Streams ------------------------------------------------------------------ }

procedure TInputLine.Write(Os: opstream);
var
  N: Integer;
begin
  inherited Write(Os);
  Os.WriteBytes(MaxLen, SizeOf(Integer));
  N := MaxInt;                     { maxWidth and maxChars: tv3 limits the text by MaxLen only }
  Os.WriteBytes(N, SizeOf(Integer));
  Os.WriteBytes(N, SizeOf(Integer));
  Os.WriteBytes(CurPos, SizeOf(Integer));
  Os.WriteBytes(FirstPos, SizeOf(Integer));
  Os.WriteBytes(SelStart, SizeOf(Integer));
  Os.WriteBytes(SelEnd, SizeOf(Integer));
  Os.WriteString(Data);
  Os.WritePointer(Validator);
end;

function TInputLine.Read(Ip: ipstream): Pointer;
var
  N: Integer;
  Buf: array[0..256] of Char;
begin
  inherited Read(Ip);
  Ip.ReadBytes(MaxLen, SizeOf(Integer));
  Ip.ReadBytes(N, SizeOf(Integer));
  Ip.ReadBytes(N, SizeOf(Integer));
  Ip.ReadBytes(CurPos, SizeOf(Integer));
  Ip.ReadBytes(FirstPos, SizeOf(Integer));
  Ip.ReadBytes(SelStart, SizeOf(Integer));
  Ip.ReadBytes(SelEnd, SizeOf(Integer));
  if MaxLen < 1 then
    MaxLen := 1;
  if MaxLen > 255 then
    MaxLen := 255;
  GetMem(Data, MaxLen + 1);
  GetMem(OldData, MaxLen + 1);
  Data^ := '';
  OldData^ := '';
  if Ip.ReadString(@Buf[0], MaxLen + 1) <> nil then
    Data^ := StrPas(@Buf[0]);
  State := State or sfCursorVis;
  Validator := TValidator(Ip.ReadPointer);
  Anchor := -1;
  LC := ' ';
  RC := ' ';
  Result := Self;
end;

class function TInputLine.Build: TStreamable;
begin
  Result := TInputLine.Create(streamableInit);
end;

constructor TInputLine.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TInputLine.StreamableName: ShortString;
begin
  Result := 'TInputLine';
end;

initialization
  RInputLine := TStreamableClass.Create('TInputLine', @TInputLine.Build);

end.
