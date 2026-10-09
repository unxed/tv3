{ TvText: measuring and drawing text made of UTF-8 (with a code page fallback)
  in screen cells.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/ttext.h, source/platform/ttext.cpp (TText)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Text is Len bytes at a PByte. Invalid UTF-8 bytes count as one character of
  width 1 and are shown through the current code page (TvCodePg).
  A cell holds one printable character (width 1 or 2) and the zero-width
  characters appended to it. A double-width character takes a cell and a trail
  cell after it (when there is room for the trail).
  Not translated yet: equalsIgnoreCase (needs case tables), the UTF-32 variants,
  drawStrEx with a callback (Attr: PColorAttr, nil = keep the attributes). }
unit TvText;

{$I tvdefs.inc}

interface

uses
  TvColors, TvCell;

type
  TText = class
  public
    { Length and width of the character at Text (Len bytes available). False when
      Len = 0. Width is 0 for combining and format characters. }
    class function Next(Text: PByte; Len: Integer; out CharLen, CharWidth: Integer): Boolean; static;

    class function Width(Text: PByte; Len: Integer): Integer; static; overload;
    class function Width(const S: ShortString): Integer; static; overload;

    { Length in bytes of the character that ends at Index (Index > 0), 0 for Index = 0.
      Tolerates invalid characters. }
    class function Prev(Text: PByte; Index: Integer): Integer; static;

    { Skips characters worth Count columns: ALength is the number of bytes skipped,
      AWidth the columns they take. With IncludeIncomplete, a double-width character
      that does not fit entirely is skipped too (AWidth > Count then). }
    class procedure Scroll(Text: PByte; Len, Count: Integer; IncludeIncomplete: Boolean;
      out ALength, AWidth: Integer); static;

    { Writes one character of Text at Text[J] into Cells[I] (CellCount cells). I and J
      advance by the cells and bytes used. A zero-width character is appended to the
      previous cell and I does not advance. Attr, when not nil, is set in the cells
      written. False when nothing was consumed. }
    class function DrawOne(Cells: PScreenCell; CellCount: Integer; var I: Integer;
      Text: PByte; TextLen: Integer; var J: Integer; Attr: PColorAttr): Boolean; static;

    { Writes Text starting at Cells[Indent], skipping the first TextIndent columns of
      the text (a double-width character cut in the middle becomes a space). Returns
      the number of cells filled. }
    class function DrawStr(Cells: PScreenCell; CellCount, Indent: Integer;
      Text: PByte; TextLen, TextIndent: Integer; Attr: PColorAttr): Integer; static; overload;
    class function DrawStr(Cells: PScreenCell; CellCount, Indent: Integer;
      const S: ShortString; TextIndent: Integer; Attr: PColorAttr): Integer; static; overload;
    { DrawStr for text that is UTF-8 whatever TvUtf8.Utf8Enabled is (a component
      that keeps its text in UTF-8 inside a program with a code page). }
    class function DrawStrUtf8(Cells: PScreenCell; CellCount, Indent: Integer;
      Text: PByte; TextLen, TextIndent: Integer; Attr: PColorAttr): Integer; static;

    { Fills Cells with a byte character, setting Attr when not nil. }
    class procedure DrawChar(Cells: PScreenCell; CellCount: Integer; Ch: Byte; Attr: PColorAttr); static;

    { Code page conversion of the first character of Text: the byte for ASCII, else the
      byte of the current code page (0 if there is none). }
    class function ToCodePage(Text: PByte; Len: Integer): Byte; static;
  end;

implementation

uses
  TvUtf8, TvCodePg;

type
  TCellArray = array[0..MaxInt div SizeOf(TScreenCell) - 1] of TScreenCell;
  PCellArray = ^TCellArray;

{ length and width, as in ttext.cpp mbstat/nextImpl: only valid multi-byte
  characters get their own width; everything else is one column. Utf8 False:
  every byte is a character. }
function NextImpl(Text: PByte; Len: Integer; Utf8: Boolean; out CharLen, CharWidth: Integer): Boolean;
var
  CP: LongWord;
  Used, W: Integer;
begin
  CharLen := 0;
  CharWidth := 0;
  if Len <= 0 then
    Exit(False);
  Result := True;
  if Utf8 and Utf8Decode(Text, Len, CP, Used) and (Used > 1) then
  begin
    W := TvUtf8.CharWidth(CP);
    CharLen := Used;
    if W = 0 then
      CharWidth := 0
    else if W < 1 then
      CharWidth := 1
    else
      CharWidth := W;
  end
  else
  begin
    CharLen := 1;
    CharWidth := 1;
  end;
end;

class function TText.Next(Text: PByte; Len: Integer; out CharLen, CharWidth: Integer): Boolean;
begin
  Result := NextImpl(Text, Len, Utf8Enabled, CharLen, CharWidth);
end;

class function TText.Width(Text: PByte; Len: Integer): Integer;
var
  I, L, W: Integer;
begin
  Result := 0;
  I := 0;
  while TText.Next(Text + I, Len - I, L, W) do
  begin
    Inc(I, L);
    Inc(Result, W);
  end;
end;

class function TText.Width(const S: ShortString): Integer;
begin
  if Length(S) = 0 then
    Exit(0);
  Result := TText.Width(@S[1], Length(S));
end;

class function TText.Prev(Text: PByte; Index: Integer): Integer;
var
  Lead, I, Used: Integer;
  CP: LongWord;
begin
  if Index <= 0 then
    Exit(0);
  if not Utf8Enabled then
    Exit(1);
  { read backwards until a valid character that ends exactly at Index is found;
    this tolerates invalid characters }
  Lead := Index;
  if Lead > MaxCharSize then
    Lead := MaxCharSize;
  for I := 1 to Lead do
    if Utf8Decode(Text + Index - I, I, CP, Used) then
    begin
      if Used = I then
        Exit(I)
      else
        Exit(1);
    end;
  Result := 1;
end;

procedure ScrollImpl(Text: PByte; Len, Count: Integer; IncludeIncomplete, Utf8: Boolean;
  out ALength, AWidth: Integer);
var
  I, W, I2, W2, L, CW: Integer;
begin
  ALength := 0;
  AWidth := 0;
  if Count <= 0 then
    Exit;
  I := 0;
  W := 0;
  while True do
  begin
    I2 := I;
    W2 := W;
    if not NextImpl(Text + I, Len - I, Utf8, L, CW) then
      Break;
    Inc(I, L);
    Inc(W, CW);
    if W = Count then
      Break;
    if W > Count then
    begin
      if not IncludeIncomplete then
      begin
        I := I2;
        W := W2;
      end;
      Break;
    end;
  end;
  ALength := I;
  AWidth := W;
end;

class procedure TText.Scroll(Text: PByte; Len, Count: Integer; IncludeIncomplete: Boolean;
  out ALength, AWidth: Integer);
begin
  ScrollImpl(Text, Len, Count, IncludeIncomplete, Utf8Enabled, ALength, AWidth);
end;

function IsZeroWidthJoiner(P: PByte; Len: Integer): Boolean;
begin
  Result := (Len = 3) and (P[0] = $E2) and (P[1] = $80) and (P[2] = $8D);
end;

{ ttext.cpp drawOneImpl: returns the bytes consumed and the cells advanced }
procedure DrawOneImpl(Cells: PCellArray; CellCount, I: Integer;
  Text: PByte; TextLen, J: Integer; Utf8: Boolean; out Len, Width: Integer);
var
  CP: LongWord;
  Used, W, K: Integer;
  Buf: array[0..3] of Byte;
  N: Integer;
  Wide, Trail: Boolean;
begin
  Len := 0;
  Width := 0;
  if J >= TextLen then
    Exit;
  Text := Text + J;
  if Utf8 and Utf8Decode(Text, TextLen - J, CP, Used) and (Used > 1) then
  begin
    W := CharWidth(CP);
    if W < 0 then
    begin
      if I < CellCount then
      begin
        Buf[0] := $EF; Buf[1] := $BF; Buf[2] := $BD;      { U+FFFD }
        Cells^[I].Character.InitWithMultiByteChar(@Buf[0], 3, False);
        Len := Used;
        Width := 1;
      end;
    end
    else if W = 0 then
    begin
      { append to the previous cell, if present }
      if (I > 0) and not IsZeroWidthJoiner(Text, Used) then
      begin
        K := I - 1;
        while Cells^[K].Character.IsWideCharTrail and (K > 0) do
          Dec(K);
        Cells^[K].Character.AppendZeroWidthChar(Text, Used);
      end;
      Len := Used;
      Width := 0;
    end
    else if I < CellCount then
    begin
      Wide := W > 1;
      Cells^[I].Character.InitWithMultiByteChar(Text, Used, Wide);
      Trail := Wide and (I + 1 < CellCount);
      if Trail then
        Cells^[I + 1].Character.InitAsWideCharTrail;
      Len := Used;
      Width := 1;
      if Trail then
        Inc(Width);
    end;
  end
  else if I < CellCount then
  begin
    { one byte: ASCII, or invalid UTF-8 shown through the code page. Control
      characters are converted here since combining characters may be appended
      to them later. }
    if (Text[0] < $20) or (Text[0] >= $7F) then
    begin
      N := CpToUtf8(Text[0], @Buf[0]);
      Cells^[I].Character.InitWithMultiByteChar(@Buf[0], N, False);
    end
    else
      Cells^[I].Character.InitWithChar(Text[0]);
    Len := 1;
    Width := 1;
  end;
end;

function DrawOneWith(Cells: PScreenCell; CellCount: Integer; var I: Integer;
  Text: PByte; TextLen: Integer; var J: Integer; Attr: PColorAttr; Utf8: Boolean): Boolean;
var
  Len, CellsUsed: Integer;
begin
  DrawOneImpl(PCellArray(Cells), CellCount, I, Text, TextLen, J, Utf8, Len, CellsUsed);
  if (CellsUsed > 0) and (Attr <> nil) then
    PCellArray(Cells)^[I].Attribute := Attr^;
  if (CellsUsed > 1) and (Attr <> nil) then
    PCellArray(Cells)^[I + 1].Attribute := Attr^;
  Inc(I, CellsUsed);
  Inc(J, Len);
  Result := Len <> 0;
end;

class function TText.DrawOne(Cells: PScreenCell; CellCount: Integer; var I: Integer;
  Text: PByte; TextLen: Integer; var J: Integer; Attr: PColorAttr): Boolean;
begin
  Result := DrawOneWith(Cells, CellCount, I, Text, TextLen, J, Attr, Utf8Enabled);
end;

function DrawStrImpl(Cells: PScreenCell; CellCount, Indent: Integer;
  Text: PByte; TextLen, TextIndent: Integer; Attr: PColorAttr; Utf8: Boolean): Integer;
var
  I, J, LeadWidth, Skipped: Integer;
begin
  I := Indent;
  J := 0;
  if TextIndent > 0 then
  begin
    ScrollImpl(Text, TextLen, TextIndent, True, Utf8, Skipped, LeadWidth);
    J := Skipped;
    if (LeadWidth > TextIndent) and (I < CellCount) then
    begin
      (PCellArray(Cells)^[I].Character).InitWithChar(Ord(' '));
      if Attr <> nil then
        PCellArray(Cells)^[I].Attribute := Attr^;
      Inc(I);
    end;
  end;
  while DrawOneWith(Cells, CellCount, I, Text, TextLen, J, Attr, Utf8) do ;
  Result := I - Indent;
end;

class function TText.DrawStr(Cells: PScreenCell; CellCount, Indent: Integer;
  Text: PByte; TextLen, TextIndent: Integer; Attr: PColorAttr): Integer;
begin
  Result := DrawStrImpl(Cells, CellCount, Indent, Text, TextLen, TextIndent, Attr, Utf8Enabled);
end;

class function TText.DrawStrUtf8(Cells: PScreenCell; CellCount, Indent: Integer;
  Text: PByte; TextLen, TextIndent: Integer; Attr: PColorAttr): Integer;
begin
  Result := DrawStrImpl(Cells, CellCount, Indent, Text, TextLen, TextIndent, Attr, True);
end;

class function TText.DrawStr(Cells: PScreenCell; CellCount, Indent: Integer;
  const S: ShortString; TextIndent: Integer; Attr: PColorAttr): Integer;
begin
  if Length(S) = 0 then
    Exit(0);
  Result := TText.DrawStr(Cells, CellCount, Indent, @S[1], Length(S), TextIndent, Attr);
end;

class procedure TText.DrawChar(Cells: PScreenCell; CellCount: Integer; Ch: Byte; Attr: PColorAttr);
var
  I: Integer;
begin
  for I := 0 to CellCount - 1 do
  begin
    (PCellArray(Cells)^[I].Character).InitWithChar(Ch);
    if Attr <> nil then
      PCellArray(Cells)^[I].Attribute := Attr^;
  end;
end;

class function TText.ToCodePage(Text: PByte; Len: Integer): Byte;
var
  CP: LongWord;
  Used: Integer;
begin
  if Len <= 0 then
    Exit(0);
  { ASCII is not converted }
  if Text[0] <= $7F then
    Exit(Text[0]);
  if Utf8Decode(Text, Len, CP, Used) then
    Result := CpFromUnicode(CP)
  else
    Result := 0;
end;

end.
