{ TvUtf8: UTF-8 decoding/encoding and display width of code points.

  Translated from magiblot/tvision @ b4831e2 (the parts of):
    include/tvision/internal/utf8.h   (Utf8BytesLeft, utf8To32, utf32To8)
    source/platform/ttext.cpp         (decode_utf8, mbtowc: the validating decoder)
  Display width: magiblot asks the C library (wcwidth) or the console; here it
  comes from tables generated from the Unicode database (tools/gen-width.py,
  tvwidth.inc), so it works the same on every platform, DOS included.
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Width of a code point: -1 for control characters, 0 for combining marks and
  format characters, 2 for East Asian Wide/Fullwidth, 1 otherwise. }
unit TvUtf8;

{$I tvdefs.inc}

interface

const
  MaxCharSize = 4;       { longest UTF-8 sequence }

{ Number of continuation bytes announced by a first byte (0 for ASCII and for
  bytes that cannot start a sequence). }
function Utf8BytesLeft(FirstByte: Byte): Integer; inline;

{ Decodes one character at P (at most Len bytes available). Returns True and
  sets CodePoint/Used when the bytes form a valid, shortest-form, non-surrogate
  sequence of at most U+10FFFF; otherwise False (Used := 1 for resynchronization,
  or the number of bytes that were present when the sequence is truncated). }
var
  { False: the bytes of the text are always the bytes of the current code page (a program whose strings are one-byte, such as DN: the
    bytes "ров" of CP866 are a valid UTF-8 character, which would be drawn as another one). True (the default): text that is valid
    UTF-8 is UTF-8 (TvText and TvUtil look at it). }
  Utf8Enabled: Boolean = True;

function Utf8Decode(P: PByte; Len: Integer; out CodePoint: LongWord; out Used: Integer): Boolean;

{ Encodes CodePoint; Buf must have room for MaxCharSize bytes. Returns the length. }
function Utf8Encode(CodePoint: LongWord; Buf: PByte): Integer;

function CharWidth(CodePoint: LongWord): Integer;

implementation

type
  TUnicodeRange = record
    Lo, Hi: LongWord;
  end;

const
  Utf8Accept = 0;
  Utf8Reject = 12;

  { The first 256 entries map a byte to its character class; the remaining
    108 map a state plus a character class to the next state. }
  Utf8d: array[0..363] of Byte = (
     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
     1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
     7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
     8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    10,3,3,3,3,3,3,3,3,3,3,3,3,4,3,3, 11,6,6,6,5,8,8,8,8,8,8,8,8,8,8,8,

     0,12,24,36,60,96,84,12,12,12,48,72, 12,12,12,12,12,12,12,12,12,12,12,12,
    12, 0,12,12,12,12,12, 0,12, 0,12,12, 12,24,12,12,12,12,12,24,12,24,12,12,
    12,12,12,12,12,12,12,24,12,12,12,12, 12,24,12,12,12,12,12,12,12,24,12,12,
    12,12,12,12,12,12,12,36,12,36,12,12, 12,36,12,12,12,12,12,36,12,36,12,12,
    12,36,12,12,12,12,12,12,12,12,12,12
  );

{$I tvwidth.inc}

function Utf8BytesLeft(FirstByte: Byte): Integer;
begin
  if (FirstByte and $E0) = $C0 then
    Result := 1
  else if (FirstByte and $F0) = $E0 then
    Result := 2
  else if (FirstByte and $F8) = $F0 then
    Result := 3
  else
    Result := 0;
end;

function DecodeUtf8Step(var State, CodeP: LongWord; B: Byte): LongWord; inline;
var
  CharType: LongWord;
begin
  CharType := Utf8d[B];
  if State <> Utf8Accept then
    CodeP := (B and $3F) or (CodeP shl 6)
  else
    CodeP := ($FF shr CharType) and B;
  State := Utf8d[256 + State + CharType];
  Result := State;
end;

function Utf8Decode(P: PByte; Len: Integer; out CodePoint: LongWord; out Used: Integer): Boolean;
var
  State, CodeP: LongWord;
  I: Integer;
begin
  CodePoint := 0;
  Used := 0;
  Result := False;
  if Len <= 0 then
    Exit;
  State := Utf8Accept;
  CodeP := 0;
  for I := 0 to Len - 1 do
    case DecodeUtf8Step(State, CodeP, P[I]) of
      Utf8Accept:
        begin
          CodePoint := CodeP;
          Used := I + 1;
          Exit(True);
        end;
      Utf8Reject:
        begin
          Used := 1;
          Exit;
        end;
    end;
  Used := Len;
end;

function Utf8Encode(CodePoint: LongWord; Buf: PByte): Integer;
begin
  if CodePoint <= $007F then
  begin
    Buf[0] := Byte(CodePoint);
    Buf[1] := 0;
    Buf[2] := 0;
    Buf[3] := 0;
    Result := 1;
  end
  else if CodePoint <= $07FF then
  begin
    Buf[0] := Byte(((CodePoint shr 6) and $1F) or $C0);
    Buf[1] := Byte((CodePoint and $3F) or $80);
    Buf[2] := 0;
    Buf[3] := 0;
    Result := 2;
  end
  else if CodePoint <= $FFFF then
  begin
    Buf[0] := Byte(((CodePoint shr 12) and $0F) or $E0);
    Buf[1] := Byte(((CodePoint shr 6) and $3F) or $80);
    Buf[2] := Byte((CodePoint and $3F) or $80);
    Buf[3] := 0;
    Result := 3;
  end
  else
  begin
    Buf[0] := Byte(((CodePoint shr 18) and $07) or $F0);
    Buf[1] := Byte(((CodePoint shr 12) and $3F) or $80);
    Buf[2] := Byte(((CodePoint shr 6) and $3F) or $80);
    Buf[3] := Byte((CodePoint and $3F) or $80);
    Result := 4;
  end;
end;

function InRanges(const Ranges: array of TUnicodeRange; CodePoint: LongWord): Boolean;
var
  Lo, Hi, Mid: Integer;
begin
  Lo := 0;
  Hi := High(Ranges);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if CodePoint < Ranges[Mid].Lo then
      Hi := Mid - 1
    else if CodePoint > Ranges[Mid].Hi then
      Lo := Mid + 1
    else
      Exit(True);
  end;
  Result := False;
end;

function CharWidth(CodePoint: LongWord): Integer;
begin
  if (CodePoint < $20) or ((CodePoint >= $7F) and (CodePoint <= $9F)) then
    Exit(-1);
  if InRanges(ZeroWidthRanges, CodePoint) then
    Exit(0);
  if InRanges(WideRanges, CodePoint) then
    Exit(2);
  Result := 1;
end;

end.
