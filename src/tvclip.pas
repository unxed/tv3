{ TvClip: the clipboard of the program: text in UTF-8, an internal buffer, and hooks for
  the system clipboard of a backend (WinOldAp under DOS, OSC 52 or a library elsewhere).

  TClipboard.SetText keeps the text in the internal buffer and passes it to the system
  clipboard if the backend has one. ClipboardGetText asks the system clipboard first;
  when it has no text (or there is none) the internal buffer is returned, so that cut and
  paste work inside the program everywhere; TClipboard.RequestText gives the same text as
  the key events of a paste (TEventQueue.SetPasteText).

  Besides the text, the clipboard can hold several formats at once (ClipboardSetItems): HTML, the mark of a vertical block, formats that a program registers
  by name. The text formats (cfText, cfUnicodeText) carry UTF-8 here. A backend whose clipboard keeps formats (the far2l terminal extensions) takes them all
  through OnClipboardSetItems; elsewhere only the text goes to the system clipboard and the other formats stay in the program, valid as long as the text
  of the clipboard is the one that was set with them. }
unit TvClip;

{$I tvdefs.inc}
{$H+}

interface

uses
  TvCodePg, TvUtf8;

const
  { the standard formats (the numbers of Windows) }
  cfText = 1;
  cfUnicodeText = 13;
  cfHtml = 15;
  { the first number of the formats that are registered by name }
  cfFirstRegistered = $C000;
  { the format whose presence next to the text says that the text is a vertical (rectangular) block }
  VerticalBlockFormat = 'FAR_VerticalBlock_Unicode';

type
  TClipSetHook = function(const Text: AnsiString): Boolean;
  TClipGetHook = function(out Text: AnsiString): Boolean;

  TClipItem = record
    Format: LongWord;
    Data: AnsiString;
  end;

  { a backend that keeps several formats: True when it took them all }
  TClipSetItemsHook = function(const Items: array of TClipItem): Boolean;
  { True when the backend gave the data of a format that is not text }
  TClipGetItemHook = function(Format: LongWord; out Data: AnsiString): Boolean;
  { True when the backend could tell (Avail: the format is there) }
  TClipHasItemHook = function(Format: LongWord; out Avail: Boolean): Boolean;

var
  { set by a backend that has a system clipboard; Set returns False when it failed }
  OnClipboardSet: TClipSetHook = nil;
  OnClipboardGet: TClipGetHook = nil;
  OnClipboardSetItems: TClipSetItemsHook = nil;
  OnClipboardGetItem: TClipGetItemHook = nil;
  OnClipboardHasItem: TClipHasItemHook = nil;

type
  TClipboard = class
  public
    class procedure SetText(const Text: AnsiString); static;
    { The text of the clipboard comes as the key events of a paste (kbPaste), through TEventQueue.GetKeyEvent. }
    class procedure RequestText; static;
  end;

function ClipboardGetText: AnsiString;
{ True if the last TClipboard.SetText reached the system clipboard. }
function ClipboardIsSystem: Boolean;

function ClipItem(Format: LongWord; const Data: AnsiString): TClipItem;
{ Puts the items on the clipboard together (what was there goes); the first text item is the text of the clipboard. }
procedure ClipboardSetItems(const Items: array of TClipItem);
{ The data of a format; for cfText and cfUnicodeText the text (UTF-8). False: the format is not there. }
function ClipboardGetItem(Format: LongWord; out Data: AnsiString): Boolean;
function ClipboardHasItem(Format: LongWord): Boolean;
{ The number of a format of this name (cfFirstRegistered and up; the same name gets the same number). }
function ClipboardRegisterFormat(const Name: AnsiString): LongWord;
{ The name of a registered format; '' for the others. }
function ClipboardFormatName(Format: LongWord): AnsiString;

{ Conversions for backends whose clipboard is in the OEM code page (the current page of
  TvCodePg): UTF-8 -> bytes ('?' for what the page does not have) and back; bytes that
  are valid UTF-8 already are not touched by OemToUtf8 only if AllowUtf8 is set. }
function Utf8ToOem(const S: AnsiString): AnsiString;
function OemToUtf8(const S: AnsiString): AnsiString;
{ Every line break becomes CR LF (a lone LF or a lone CR too). }
function ToCrLf(const S: AnsiString): AnsiString;
{ Base64 (RFC 4648, with the padding): for OSC 52. }
function Base64Encode(const S: AnsiString): AnsiString;
{ The text of Base64 (the characters that do not belong to the alphabet are skipped; the URL alphabet is taken too). }
function Base64Decode(const S: AnsiString): AnsiString;
{ Every line break becomes LF. }
function ToLf(const S: AnsiString): AnsiString;

implementation

uses
  TvSys, TvScreen;

var
  Internal: AnsiString = '';
  LastWasSystem: Boolean = False;
  { the items of the last set (the text is Internal) }
  Items_: array of TClipItem;
  FormatNames: array of AnsiString;

procedure PutText(const Text: AnsiString);
begin
  Internal := Text;
  LastWasSystem := THardwareInfo.SetClipboardText(Text);
end;

class procedure TClipboard.SetText(const Text: AnsiString);
begin
  Items_ := nil;                      { the text alone: the formats of an earlier set are gone }
  PutText(Text);
end;

class procedure TClipboard.RequestText;
begin
  TEventQueue.SetPasteText(ClipboardGetText);
end;

function ClipItem(Format: LongWord; const Data: AnsiString): TClipItem;
begin
  Result.Format := Format;
  Result.Data := Data;
end;

function IsTextFormat(Format: LongWord): Boolean;
begin
  Result := (Format = cfText) or (Format = cfUnicodeText);
end;

procedure ClipboardSetItems(const Items: array of TClipItem);
var
  I: Integer;
  Text: AnsiString;
  HasText: Boolean;
begin
  SetLength(Items_, Length(Items));
  Text := '';
  HasText := False;
  for I := 0 to High(Items) do
  begin
    Items_[I] := Items[I];
    if IsTextFormat(Items[I].Format) and not HasText then
    begin
      Text := Items[I].Data;
      HasText := True;
    end;
  end;
  if Assigned(OnClipboardSetItems) and OnClipboardSetItems(Items) then
  begin
    Internal := Text;
    LastWasSystem := True;
    Exit;
  end;
  PutText(Text);
end;

{ the item of the last set, if the clipboard still has what was set then (its text is the same) }
function OwnItem(Format: LongWord; out Data: AnsiString): Boolean;
var
  I: Integer;
begin
  Data := '';
  for I := 0 to High(Items_) do
    if Items_[I].Format = Format then
    begin
      if ClipboardGetText <> Internal then
        Exit(False);
      Data := Items_[I].Data;
      Exit(True);
    end;
  Result := False;
end;

function ClipboardGetItem(Format: LongWord; out Data: AnsiString): Boolean;
begin
  if IsTextFormat(Format) then
  begin
    Data := ClipboardGetText;
    Exit(Data <> '');
  end;
  if Assigned(OnClipboardGetItem) and OnClipboardGetItem(Format, Data) then
    Exit(True);
  Result := OwnItem(Format, Data);
end;

function ClipboardHasItem(Format: LongWord): Boolean;
var
  Data: AnsiString;
begin
  if IsTextFormat(Format) then
    Exit(ClipboardGetText <> '');
  if Assigned(OnClipboardHasItem) and OnClipboardHasItem(Format, Result) and Result then
    Exit;
  Result := OwnItem(Format, Data);
end;

function ClipboardRegisterFormat(const Name: AnsiString): LongWord;
var
  I: Integer;
begin
  for I := 0 to High(FormatNames) do
    if FormatNames[I] = Name then
      Exit(cfFirstRegistered + LongWord(I));
  I := Length(FormatNames);
  SetLength(FormatNames, I + 1);
  FormatNames[I] := Name;
  Result := cfFirstRegistered + LongWord(I);
end;

function ClipboardFormatName(Format: LongWord): AnsiString;
begin
  if (Format >= cfFirstRegistered) and (Format - cfFirstRegistered < LongWord(Length(FormatNames))) then
    Result := FormatNames[Format - cfFirstRegistered]
  else
    Result := '';
end;

function ClipboardGetText: AnsiString;
var
  T: AnsiString;
begin
  if Assigned(OnClipboardGet) and OnClipboardGet(T) and (T <> '') then
    Exit(T);
  Result := Internal;
end;

function ClipboardIsSystem: Boolean;
begin
  Result := LastWasSystem;
end;

function Utf8ToOem(const S: AnsiString): AnsiString;
var
  I, Used, N: Integer;
  Cp: LongWord;
  B: Byte;
begin
  SetLength(Result, Length(S));
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if Byte(S[I]) < $80 then
    begin
      Inc(N);
      Result[N] := S[I];
      Inc(I);
    end
    else
    begin
      if Utf8Decode(@S[I], Length(S) - I + 1, Cp, Used) then
      begin
        B := CpFromUnicode(Cp);
        if B = 0 then
          B := Ord('?');
        Inc(I, Used);
      end
      else
      begin
        { not UTF-8: the byte is a character of the code page already }
        B := Byte(S[I]);
        Inc(I);
      end;
      Inc(N);
      Result[N] := Chr(B);
    end;
  end;
  SetLength(Result, N);
end;

function OemToUtf8(const S: AnsiString): AnsiString;
var
  I: Integer;
  Buf: array[0..7] of Byte;
  N: Integer;
  T: AnsiString;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    if Byte(S[I]) < $80 then
      Result := Result + S[I]
    else
    begin
      N := CpToUtf8(Byte(S[I]), @Buf[0]);
      SetLength(T, N);
      Move(Buf[0], T[1], N);
      Result := Result + T;
    end;
  end;
end;

function ToCrLf(const S: AnsiString): AnsiString;
var
  I, N: Integer;
begin
  SetLength(Result, Length(S) * 2);
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    case S[I] of
      #13:
        begin
          if (I < Length(S)) and (S[I + 1] = #10) then
            Inc(I);
          Inc(N); Result[N] := #13;
          Inc(N); Result[N] := #10;
        end;
      #10:
        begin
          Inc(N); Result[N] := #13;
          Inc(N); Result[N] := #10;
        end;
    else
      Inc(N);
      Result[N] := S[I];
    end;
    Inc(I);
  end;
  SetLength(Result, N);
end;

function ToLf(const S: AnsiString): AnsiString;
var
  I, N: Integer;
begin
  SetLength(Result, Length(S));
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = #13 then
    begin
      if (I < Length(S)) and (S[I + 1] = #10) then
        Inc(I);
      Inc(N);
      Result[N] := #10;
    end
    else
    begin
      Inc(N);
      Result[N] := S[I];
    end;
    Inc(I);
  end;
  SetLength(Result, N);
end;

function Base64Encode(const S: AnsiString): AnsiString;
const
  Digits: string[64] = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  I, N: Integer;
  A, B, C: Byte;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    N := Length(S) - I + 1;
    A := Byte(S[I]);
    if N > 1 then B := Byte(S[I + 1]) else B := 0;
    if N > 2 then C := Byte(S[I + 2]) else C := 0;
    Result := Result + Digits[(A shr 2) + 1] + Digits[(((A and 3) shl 4) or (B shr 4)) + 1];
    if N > 1 then
      Result := Result + Digits[(((B and 15) shl 2) or (C shr 6)) + 1]
    else
      Result := Result + '=';
    if N > 2 then
      Result := Result + Digits[(C and 63) + 1]
    else
      Result := Result + '=';
    Inc(I, 3);
  end;
end;

function Base64Decode(const S: AnsiString): AnsiString;
var
  I, Acc, Bits, V: Integer;
  C: Char;
begin
  Result := '';
  Acc := 0;
  Bits := 0;
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      'A'..'Z': V := Ord(C) - 65;
      'a'..'z': V := Ord(C) - 97 + 26;
      '0'..'9': V := Ord(C) - 48 + 52;
      '+', '-': V := 62;
      '/', '_': V := 63;
    else
      Continue;
    end;
    Acc := (Acc shl 6) or V;
    Inc(Bits, 6);
    if Bits >= 8 then
    begin
      Dec(Bits, 8);
      Result := Result + Chr((Acc shr Bits) and $FF);
      Acc := Acc and ((1 shl Bits) - 1);
    end;
  end;
end;

end.
