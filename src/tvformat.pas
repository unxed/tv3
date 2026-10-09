{ TvFormat: FormatStr, a text built from a format with % items and an array of parameter slots (the Drivers API);
  an overload takes an array of const and a format of SysUtils.Format.

  MIT (see LICENSE).

  Params is an array of slots of the size of a pointer (PtrInt), one slot for each % item in the order of the items.
  An item is '%', then '-' (align to the left), then '0' (fill a number with zeros), then a width (decimal digits),
  then the conversion:
    s  the slot is a pointer to a ShortString (nil: an empty text)
    d  a LongInt
    u  a LongWord
    x  a LongWord in hexadecimal, lower case digits; X: upper case digits
    c  a character
    %  a '%' (takes no slot)
  The numbers and the character are the low 32 bits and the low byte of the slot (the rest of a slot that a caller
  filled with a LongInt may hold anything): -1 is 4294967295 with u and ffffffff with x.
  The width is the least number of characters: a shorter text is filled with spaces on the left (with '-' on the right);
  a longer one is kept whole. With '0' (and without '-') d, u, x and X are filled with zeros after the sign.
  An item with another conversion, and a '%' at the end of the format, go into the result as they are and take no slot.
  The result is cut at 255 characters. }
unit TvFormat;

{$I tvdefs.inc}

interface

procedure FormatStr(var Result: ShortString; const Format: ShortString; var Params); overload;
{ SysUtils.Format with Args, cut at 255 characters. }
function FormatStr(const Fmt: ShortString; const Args: array of const): ShortString; overload;

implementation

uses
  SysUtils;

type
  TSlots = array[0..(MaxInt div SizeOf(PtrInt)) - 1] of PtrInt;
  PSlots = ^TSlots;

procedure FormatStr(var Result: ShortString; const Format: ShortString; var Params);
var
  Slots: PSlots;
  Next: Integer;
  Res: AnsiString;
  I, Start, Width: Integer;
  Left, Zero: Boolean;
  Conv: Char;
  Text, Sign: AnsiString;
  V: LongInt;
  P: PShortString;

  function Take: PtrInt;
  begin
    Result := Slots^[Next];
    Inc(Next);
  end;

begin
  Slots := @Params;
  Next := 0;
  Res := '';
  I := 1;
  while I <= Length(Format) do
  begin
    if Format[I] <> '%' then
    begin
      Res := Res + Format[I];
      Inc(I);
      Continue;
    end;
    Start := I;
    Inc(I);
    Left := False;
    Zero := False;
    Width := 0;
    if (I <= Length(Format)) and (Format[I] = '-') then
    begin
      Left := True;
      Inc(I);
    end;
    if (I <= Length(Format)) and (Format[I] = '0') then
    begin
      Zero := True;
      Inc(I);
    end;
    while (I <= Length(Format)) and (Format[I] in ['0'..'9']) do
    begin
      if Width < 1000 then
        Width := Width * 10 + Ord(Format[I]) - Ord('0');
      Inc(I);
    end;
    if I > Length(Format) then
    begin
      Res := Res + Copy(Format, Start, MaxInt);
      Break;
    end;
    Conv := Format[I];
    Inc(I);
    Sign := '';
    case Conv of
      '%':
        begin
          Res := Res + '%';
          Continue;
        end;
      's':
        begin
          P := PShortString(Pointer(Take));
          if P = nil then
            Text := ''
          else
            Text := P^;
          Zero := False;
        end;
      'c':
        begin
          Text := Chr(Byte(Take));
          Zero := False;
        end;
      'd':
        begin
          V := LongInt(Take);
          Text := IntToStr(V);
          if V < 0 then
          begin
            Sign := '-';
            Delete(Text, 1, 1);
          end;
        end;
      'u':
        Text := IntToStr(LongWord(Take));
      'x':
        Text := LowerCase(IntToHex(LongWord(Take), 1));
      'X':
        Text := IntToHex(LongWord(Take), 1);
    else
      begin
        Res := Res + Copy(Format, Start, I - Start);
        Continue;
      end;
    end;
    if Length(Sign) + Length(Text) < Width then
    begin
      if Left then
        Text := Sign + Text + StringOfChar(' ', Width - Length(Sign) - Length(Text))
      else if Zero then
        Text := Sign + StringOfChar('0', Width - Length(Sign) - Length(Text)) + Text
      else
        Text := StringOfChar(' ', Width - Length(Sign) - Length(Text)) + Sign + Text;
    end
    else
      Text := Sign + Text;
    Res := Res + Text;
  end;
  Result := Copy(Res, 1, 255);
end;

function FormatStr(const Fmt: ShortString; const Args: array of const): ShortString;
var
  S: AnsiString;
begin
  S := SysUtils.Format(Fmt, Args);
  if Length(S) > 255 then
    SetLength(S, 255);
  Result := S;
end;

end.
