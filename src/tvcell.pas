{ TvCell: the screen cell. A cell holds the text of one column group (up to 15
  bytes of UTF-8, 1 or 2 columns wide) plus its color attribute.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/scrncell.h (TScreenCharacter, TScreenCell; the non-Borland variant)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  A TScreenCharacter stores one of:
    1. a single byte of ASCII or "extended ASCII" text (1 column);
    2. up to 15 bytes of UTF-8 text (1 or 2 columns in total, so it cannot
       consist of zero-width characters only);
    3. a marker for the trail of a double-width character: a double-width
       character occupies a cell followed by a cell holding the trail. If the
       trail is missing, or a trail is not preceded by a double-width character,
       the double-width character is being partially overlapped.
  Cells are plain data: all-zero bytes is a valid, empty cell (default colors,
  one NUL character), and cells can be moved and compared as raw memory.

  Differences from the C++ original (see tv/docs/API-NAMES.md):
    - a character of the code page above $7F (InitWithChar) is stored as its UTF-8;
    - a TStringView argument is a pointer and a length, getText gives a ShortString. }
unit TvCell;

{$I tvdefs.inc}

interface

uses
  TvColors;

type
  TScreenCharacter = packed record
  private
    const
      fWide     = $1;
      fTrail    = $2;
      fOverflow = $4;
    var
      FText: array[0..14] of Byte;
      { low nibble: the length of the text - 1 (there is always at least one byte, possibly NUL);
        high nibble: the flags }
      FMeta: Byte;
    function Flags: Byte; inline;
  public
    class operator :=(C: Byte): TScreenCharacter;
    procedure InitWithChar(C: Byte);
    { Mbc: the bytes of one character of UTF-8 (the first in the low byte) }
    procedure InitWithMultiByteChar(Mbc: LongWord; Wide: Boolean = False); overload;
    { Text is Len bytes of UTF-8 (1..4); anything else leaves an empty character. }
    procedure InitWithMultiByteChar(Text: PByte; Len: Integer; Wide: Boolean = False); overload;
    procedure InitAsWideCharTrail;
    function IsWide: Boolean; inline;
    function IsWideCharTrail: Boolean; inline;
    { Appends a zero-width character (UTF-8, Len bytes); when it does not fit, the
      overflow flag is set and the text is left unchanged. Precondition: the text is
      valid UTF-8. A NUL base character becomes a space first. }
    procedure AppendZeroWidthChar(Text: PByte; Len: Integer);
    { The text. Precondition: not a wide character trail. }
    function GetText: ShortString;
  end;

  TScreenCell = packed record
    Character: TScreenCharacter;
    Attribute: TColorAttr;
    constructor Create(const Ch: TScreenCharacter; Attr: TColorAttr);
    { from a DOS text mode word: the character in the low byte, the BIOS attribute above }
    class operator :=(Bios: Word): TScreenCell;
    class operator =(const A, B: TScreenCell): Boolean;
    class operator <>(const A, B: TScreenCell): Boolean;
  end;
  PScreenCell = ^TScreenCell;

implementation

uses
  TvCodePg;

{ --- TScreenCharacter -------------------------------------------------------- }

function TScreenCharacter.Flags: Byte;
begin
  Result := FMeta shr 4;
end;

class operator TScreenCharacter.:=(C: Byte): TScreenCharacter;
begin
  Result.InitWithChar(C);
end;

procedure TScreenCharacter.InitWithChar(C: Byte);
var
  Buf: array[0..7] of Byte;
  N: Integer;
begin
  if C >= $80 then
  begin
    N := CpToUtf8(C, @Buf[0]);
    InitWithMultiByteChar(@Buf[0], N, False);
    Exit;
  end;
  { a raw byte of the code page; TvText/TvUnix/TvDos turn it into its character when they write it. TODO(later): making the cell hold UTF-8 here
    left stray cells of a closed frame in a program that repaints with raw bytes (an acceptance run of the application): not understood yet }
  FillChar(Self, SizeOf(Self), 0);
  FText[0] := C;
end;

procedure TScreenCharacter.InitWithMultiByteChar(Mbc: LongWord; Wide: Boolean);
begin
  FillChar(Self, SizeOf(Self), 0);
  FText[0] := Byte(Mbc);
  FText[1] := Byte(Mbc shr 8);
  FText[2] := Byte(Mbc shr 16);
  FText[3] := Byte(Mbc shr 24);
  FMeta := Ord(Mbc > $000000FF) + Ord(Mbc > $0000FFFF) + Ord(Mbc > $00FFFFFF);
  if Wide then
    FMeta := FMeta or (fWide shl 4);
end;

procedure TScreenCharacter.InitWithMultiByteChar(Text: PByte; Len: Integer; Wide: Boolean);
var
  Flg: Byte;
begin
  FillChar(Self, SizeOf(Self), 0);
  if (Len > 0) and (Len <= 4) then
  begin
    Move(Text^, FText[0], Len);
    Flg := 0;
    if Wide then Flg := fWide;
    FMeta := (Flg shl 4) or (Len - 1);
  end;
end;

procedure TScreenCharacter.InitAsWideCharTrail;
begin
  FillChar(Self, SizeOf(Self), 0);
  FMeta := fTrail shl 4;
end;

function TScreenCharacter.IsWide: Boolean;
begin
  Result := (Flags and fWide) <> 0;
end;

function TScreenCharacter.IsWideCharTrail: Boolean;
begin
  Result := (Flags and fTrail) <> 0;
end;

procedure TScreenCharacter.AppendZeroWidthChar(Text: PByte; Len: Integer);
var
  Size: Integer;
begin
  if (Flags and fOverflow) <> 0 then
    Exit;
  Size := (FMeta and $0F) + 1;
  if (Len >= 1) and (Len <= SizeOf(FText) - Size) then
  begin
    if FText[0] = 0 then
      FText[0] := Ord(' ');
    Move(Text^, FText[Size], Len);
    FMeta := (FMeta and $F0) or (Size - 1 + Len);
  end
  else
    FMeta := FMeta or (fOverflow shl 4);
end;

function TScreenCharacter.GetText: ShortString;
var
  N: Integer;
begin
  N := (FMeta and $0F) + 1;
  SetLength(Result, N);
  Move(FText[0], Result[1], N);
end;

{ --- TScreenCell ------------------------------------------------------------- }

constructor TScreenCell.Create(const Ch: TScreenCharacter; Attr: TColorAttr);
begin
  Character := Ch;
  Attribute := Attr;
end;

class operator TScreenCell.:=(Bios: Word): TScreenCell;
begin
  Result.Character.InitWithChar(Byte(Bios));
  Result.Attribute := LongInt(Byte(Bios shr 8));
end;

class operator TScreenCell.=(const A, B: TScreenCell): Boolean;
begin
  Result := CompareByte(A, B, SizeOf(TScreenCell)) = 0;
end;

class operator TScreenCell.<>(const A, B: TScreenCell): Boolean;
begin
  Result := not (A = B);
end;

end.
