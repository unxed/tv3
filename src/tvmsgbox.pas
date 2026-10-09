{ TvMsgBox: message boxes.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/msgbox.h, source/tvision/msgbox.cpp (messageBox, messageBoxRect),
    tvtext2.cpp (the texts of the buttons and titles)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the texts of the buttons and of the titles are ShortString class variables of MsgBoxText
      (translations: set them before the first box is shown);
    - the formatted variants take a Pascal format string and an array of const
      (SysUtils.Format: %s, %d, ...), not printf;
    - inputBox is in TvInput (it needs the input line). }
unit TvMsgBox;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvGeom, TvEvents, TvText, TvViews, TvDialog, TvApp, TvFormat;

const
  mfWarning      = $0000;     { display a warning box }
  mfError        = $0001;     { display an error box }
  mfInformation  = $0002;     { display an information box }
  mfConfirmation = $0003;     { display a confirmation box }

  mfYesButton    = $0100;     { put a Yes button into the dialog }
  mfNoButton     = $0200;
  mfOKButton     = $0400;
  mfCancelButton = $0800;

  mfYesNoCancel  = mfYesButton or mfNoButton or mfCancelButton;
  mfOKCancel     = mfOKButton or mfCancelButton;

type
  MsgBoxText = class
  public
    class var YesText, NoText, OkText, CancelText: ShortString;
    class var WarningText, ErrorText, InformationText, ConfirmText: ShortString;
  end;

function MessageBox(const Msg: ShortString; AOptions: Word): Word; overload;
function MessageBox(AOptions: Word; const Fmt: ShortString; const Args: array of const): Word; overload;
function MessageBoxRect(const R: TRect; const Msg: ShortString; AOptions: Word): Word; overload;
function MessageBoxRect(const R: TRect; AOptions: Word; const Fmt: ShortString;
  const Args: array of const): Word; overload;

implementation

function MessageBoxRect(const R: TRect; const Msg: ShortString; AOptions: Word): Word;
const
  ButtonCommands: array[0..3] of Word = (cmYes, cmNo, cmOK, cmCancel);
var
  Dialog: TDialog;
  Buttons: array[0..3] of TButton;
  Count, I, X: Integer;
  T: TRect;

  function ButtonText(Index: Integer): ShortString;
  begin
    case Index of
      0: Result := MsgBoxText.YesText;
      1: Result := MsgBoxText.NoText;
      2: Result := MsgBoxText.OkText;
    else
      Result := MsgBoxText.CancelText;
    end;
  end;

  function TitleText: ShortString;
  begin
    case AOptions and 3 of
      mfWarning: Result := MsgBoxText.WarningText;
      mfError: Result := MsgBoxText.ErrorText;
      mfInformation: Result := MsgBoxText.InformationText;
    else
      Result := MsgBoxText.ConfirmText;
    end;
  end;

begin
  Dialog := TDialog.Create(R, TitleText);
  T := TRect.Create(3, 2, Dialog.Size.X - 2, Dialog.Size.Y - 3);
  Dialog.Insert(TStaticText.Create(T, Msg));

  { create the buttons first, to center the row they make }
  Count := 0;
  X := -2;
  T := TRect.Create(0, 0, 10, 2);
  for I := 0 to 3 do
    if AOptions and ($0100 shl I) <> 0 then
    begin
      Buttons[Count] := TButton.Create(T, ButtonText(I), ButtonCommands[I], bfNormal);
      Inc(X, Buttons[Count].Size.X + 2);
      Inc(Count);
    end;

  X := (Dialog.Size.X - X) div 2;
  for I := 0 to Count - 1 do
  begin
    Dialog.Insert(Buttons[I]);
    Buttons[I].MoveTo(X, Dialog.Size.Y - 3);
    Inc(X, Buttons[I].Size.X + 2);
  end;
  Dialog.SelectNext(False);

  Result := TProgram.Application.ExecView(Dialog);
  Dialog.Free;
end;

function MakeRect(const Text: ShortString): TRect;
var
  Width: Integer;
begin
  Result := TRect.Create(0, 0, 40, 9);
  Width := TText.Width(Text);
  if Width > (Result.B.X - 7) * (Result.B.Y - 6) then
    Result.B.Y := Width div (Result.B.X - 7) + 6 + 1;
  Result.Move((TProgram.DeskTop.Size.X - Result.B.X) div 2, (TProgram.DeskTop.Size.Y - Result.B.Y) div 2);
end;

function MessageBox(const Msg: ShortString; AOptions: Word): Word;
begin
  Result := MessageBoxRect(MakeRect(Msg), Msg, AOptions);
end;

function MessageBox(AOptions: Word; const Fmt: ShortString; const Args: array of const): Word;
var
  Msg: ShortString;
begin
  Msg := FormatStr(Fmt, Args);
  Result := MessageBoxRect(MakeRect(Msg), Msg, AOptions);
end;

function MessageBoxRect(const R: TRect; AOptions: Word; const Fmt: ShortString;
  const Args: array of const): Word;
begin
  Result := MessageBoxRect(R, FormatStr(Fmt, Args), AOptions);
end;

initialization
  MsgBoxText.YesText := '~Y~es';
  MsgBoxText.NoText := '~N~o';
  MsgBoxText.OkText := 'O~K~';
  MsgBoxText.CancelText := '~C~ancel';
  MsgBoxText.WarningText := 'Warning';
  MsgBoxText.ErrorText := 'Error';
  MsgBoxText.InformationText := 'Information';
  MsgBoxText.ConfirmText := 'Confirm';
end.
