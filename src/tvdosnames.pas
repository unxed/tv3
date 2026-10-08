{ TvDosNames: the names of files at the border of a DOS that has the UTF-8 API (the provider DOS-UTF8/NAMES of AMIS: go2dos, DOSBox-X from October 2026, see TvDos).

  

  TvDos switches the provider on for the process (DosInit; TV_DOS_UTF8_NAMES=0 does not) and then sets NamesUtf8: the DOS takes and gives file names in UTF-8.
  A program with UTF-8 inside needs nothing more: its names are the names of the DOS. A program with a code page inside (its strings are bytes of the page
  of TvCodePg) turns its names at the border with these two functions: DosNameToUtf8 for a name that goes to the DOS, DosNameFromUtf8 for a name that comes from it.
  A character that the page cannot show (a Japanese one on cp866) comes as U+XXXX in braces (the form that DOSBox-X uses for the same names when the program
  does not ask for UTF-8), stays so inside the program, and goes back to the DOS as the character: copy, rename and delete work on such files.

  NameToDos and NameFromDos are the general pair, for a program of either kind (TvUtf8.Utf8Enabled tells which): the name goes from the program to the DOS,
  or comes back, in the form that the DOS and the program expect. They do nothing unless NamesMapped (TvDos sets it on DOS), so the code that calls them
  runs unchanged on every platform. The four cases:
    program UTF-8, DOS UTF-8        the name is as it is
    program UTF-8, DOS code page    a character of the page is a byte; a character that the page lacks is written as U+XXXX in braces when the provider is there
                                    (DOSBox-X shows and takes such names in this form), '_' otherwise; U+XXXX in braces that comes from the DOS is read as that character
    program page, DOS UTF-8         DosNameToUtf8 and DosNameFromUtf8 (above)
    program page, DOS page          the name is as it is

  The code does not depend on the DOS, so it is tested natively (tests/t_dosnam.pas). }
unit TvDosNames;

{$I tvdefs.inc}

interface

var
  { True when the DOS takes and gives names in UTF-8 (set by TvDos); the functions below do nothing while it is False }
  NamesUtf8: Boolean = False;

{ A name of the program (bytes of the page) as the DOS wants it. }
function DosNameToUtf8(const S: string): string;
{ A name from the DOS as the program wants it (bytes of the page). }
function DosNameFromUtf8(const S: string): string;

var
  { The names are mapped by NameToDos and NameFromDos (set by TvDos on a DOS target) }
  NamesMapped: Boolean = False;
  { The provider DOS-UTF8/NAMES is there (also when the program did not switch the mode on): U+XXXX in braces is the form of a character that the page lacks }
  NamesProvider: Boolean = False;

{ A name of the program as the DOS wants it, and a name of the DOS as the program wants it (see above). }
function NameToDos(const S: string): string;
function NameFromDos(const S: string): string;

implementation

uses
  SysUtils, TvCodePg, TvUtf8;

{ False: S is not valid UTF-8; Lost: it has a character that the page lacks }
{ Is there a character U+XXXX in braces at S[I]? Returns its code point and the length of the text }
function EscapeAt(const S: string; I: Integer; out CP: LongWord; out Len: Integer): Boolean;
var
  J, Digits: Integer;
begin
  Result := False;
  if (S[I] <> '{') or (Copy(S, I, 3) <> '{U+') then
    Exit;
  J := I + 3;
  while (J <= Length(S)) and (S[J] in ['0'..'9', 'A'..'F', 'a'..'f']) do
    Inc(J);
  Digits := J - (I + 3);
  if (J > Length(S)) or (S[J] <> '}') or (Digits < 4) or (Digits > 6) then
    Exit;
  CP := StrToInt('$' + Copy(S, I + 3, Digits));
  if CP > $10FFFF then
    Exit;
  Len := Digits + 4;
  Result := True;
end;

procedure AppendUtf8(var R: string; CP: LongWord);
var
  Buf: array[0..7] of Byte;
  N, J: Integer;
begin
  N := Utf8Encode(CP, @Buf[0]);
  for J := 0 to N - 1 do
    R := R + Chr(Buf[J]);
end;

function DosNameToUtf8(const S: string): string;
var
  I, Len: Integer;
  CP: LongWord;
begin
  Result := S;
  if not NamesUtf8 then
    Exit;
  Result := '';
  I := 1;
  while I <= Length(S) do
    if EscapeAt(S, I, CP, Len) then
    begin
      AppendUtf8(Result, CP);                    { U+XXXX in braces is the character }
      Inc(I, Len);
    end
    else if Byte(S[I]) < $80 then
    begin
      Result := Result + S[I];
      Inc(I);
    end
    else
    begin
      AppendUtf8(Result, CpToUnicode(Byte(S[I])));
      Inc(I);
    end;
end;

function DosNameFromUtf8(const S: string): string;
var
  I, Used, Len: Integer;
  CP, Dummy: LongWord;
  B: Byte;
begin
  Result := S;
  if not NamesUtf8 then
    Exit;
  Result := '';
  I := 1;
  while I <= Length(S) do
    if Byte(S[I]) < $80 then
    begin
      if EscapeAt(S, I, Dummy, Len) or (Copy(S, I, 3) = '{U+') then
        Result := Result + '{U+007B}'           { an opening brace that starts the text of an escape is itself escaped }
      else
        Result := Result + S[I];
      Inc(I);
    end
    else if Utf8Decode(@S[I], Length(S) - I + 1, CP, Used) then
    begin
      B := CpFromUnicode(CP);
      if B <> 0 then
        Result := Result + Chr(B)
      else
        Result := Result + '{U+' + IntToHex(CP, 4) + '}';   { a character that the page lacks is shown as the escape }
      Inc(I, Used);
    end
    else
    begin
      Result := Result + S[I];                  { not UTF-8: the byte stays }
      Inc(I);
    end;
end;

{ UTF-8 text of the program as bytes of the page; a character that the page lacks: U+XXXX in braces with a provider, else '_' }
function Utf8ToPage(const S: string): string;
var
  I, Used: Integer;
  CP: LongWord;
  B: Byte;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
    if Byte(S[I]) < $80 then
    begin
      if NamesProvider and (S[I] = '{') and (Copy(S, I, 3) = '{U+') then
        Result := Result + '{U+007B}'
      else
        Result := Result + S[I];
      Inc(I);
    end
    else if Utf8Decode(@S[I], Length(S) - I + 1, CP, Used) then
    begin
      B := CpFromUnicode(CP);
      if B <> 0 then
        Result := Result + Chr(B)
      else if NamesProvider then
        Result := Result + '{U+' + IntToHex(CP, 4) + '}'
      else
        Result := Result + '_';
      Inc(I, Used);
    end
    else
    begin
      Result := Result + S[I];                 { a stray byte of the program stays }
      Inc(I);
    end;
end;

{ Bytes of the page as UTF-8; U+XXXX in braces (4 to 6 hexadecimal digits) with a provider is the character of the code point }
function PageToUtf8(const S: string): string;
var
  I, J, N: Integer;
  Buf: array[0..7] of Byte;
  CP: LongWord;
  Digits: Integer;
  Hex: string;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if NamesProvider and (S[I] = '{') and (Copy(S, I, 3) = '{U+') then
    begin
      J := I + 3;
      while (J <= Length(S)) and (S[J] in ['0'..'9', 'A'..'F', 'a'..'f']) do
        Inc(J);
      Digits := J - (I + 3);
      if (J <= Length(S)) and (S[J] = '}') and (Digits >= 4) and (Digits <= 6) then
      begin
        Hex := Copy(S, I + 3, Digits);
        CP := StrToInt('$' + Hex);
        if CP <= $10FFFF then
        begin
          N := Utf8Encode(CP, @Buf[0]);
          for J := 0 to N - 1 do
            Result := Result + Chr(Buf[J]);
          I := I + 3 + Digits + 1;
          Continue;
        end;
      end;
    end;
    if Byte(S[I]) < $80 then
      Result := Result + S[I]
    else
    begin
      N := Utf8Encode(CpToUnicode(Byte(S[I])), @Buf[0]);
      for J := 0 to N - 1 do
        Result := Result + Chr(Buf[J]);
    end;
    Inc(I);
  end;
end;

function NameToDos(const S: string): string;
begin
  Result := S;
  if not NamesMapped then
    Exit;
  if Utf8Enabled then
  begin
    if not NamesUtf8 then
      Result := Utf8ToPage(S);
  end
  else
    Result := DosNameToUtf8(S);
end;

function NameFromDos(const S: string): string;
begin
  Result := S;
  if not NamesMapped then
    Exit;
  if Utf8Enabled then
  begin
    if not NamesUtf8 then
      Result := PageToUtf8(S);
  end
  else
    Result := DosNameFromUtf8(S);
end;

end.
