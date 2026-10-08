{ TvWild: file masks with wild cards.

  MIT as the one matcher of dn and fpide.

  A mask has '*' (any text, also an empty one), '?' (one character; a character is a UTF-8 sequence while TvUtf8.Utf8Enabled, else a byte) and
  '[abc]', '[a-z]', '[!abc]' (a set of characters). The mask "*.*" means every name, as it does in DOS (a name without a dot too).
  A list is masks separated by ';' (or ','); after '|' come the masks of the names that are NOT wanted: "*.pas;*.inc|test*". An empty list
  matches nothing; a list that has only exclusions matches every name that is not excluded. Case is ignored by default. }
unit TvWild;

{$I tvdefs.inc}

interface

function WildMatch(const Name, Mask: AnsiString; CaseSensitive: Boolean = False): Boolean;
function WildMatchList(const Name, List: AnsiString; CaseSensitive: Boolean = False): Boolean;
{ True when the text has a wild card of a mask ('*', '?', '['). }
function HasWild(const S: AnsiString): Boolean;

implementation

uses
  SysUtils, TvUStr;

function HasWild(const S: AnsiString): Boolean;
begin
  Result := (Pos('*', S) > 0) or (Pos('?', S) > 0) or (Pos('[', S) > 0);
end;

{ Does the set at Mask[I] (after the '[') match the character at Name[J]? Sets Next to the byte after ']'. False for a broken set (it is a plain '['). }
function SetMatch(const Mask: AnsiString; I: Integer; const Name: AnsiString; J, NameLen: Integer; out Next: Integer; out Ok: Boolean): Boolean;
var
  Neg, Hit: Boolean;
  Lo, Hi: LongWord;
  CP: LongWord;
  K, N: Integer;
begin
  Ok := False;
  Result := False;
  K := I;
  Neg := (K <= Length(Mask)) and ((Mask[K] = '!') or (Mask[K] = '^'));
  if Neg then
    Inc(K);
  Hit := False;
  CP := U8CodePoint(Copy(Name, J, NameLen), 0);
  N := 0;
  while (K <= Length(Mask)) and ((Mask[K] <> ']') or (N = 0)) do
  begin
    Lo := U8CodePoint(Copy(Mask, K, 8), 0);
    Inc(K, U8CharBytes(Mask, K));
    Hi := Lo;
    if (K + 1 <= Length(Mask)) and (Mask[K] = '-') and (Mask[K + 1] <> ']') then
    begin
      Inc(K);
      Hi := U8CodePoint(Copy(Mask, K, 8), 0);
      Inc(K, U8CharBytes(Mask, K));
    end;
    if (CP >= Lo) and (CP <= Hi) then
      Hit := True;
    Inc(N);
  end;
  if K > Length(Mask) then
    Exit;                                       { no ']': not a set }
  Next := K + 1;
  Ok := True;
  Result := Hit <> Neg;
end;

function Match(const Name, Mask: AnsiString): Boolean;
var
  N, M: Integer;                                { positions in Name and Mask (1-based) }
  StarM, StarN: Integer;                        { where the last '*' was and where the name was then }
  Next: Integer;
  Ok, Hit: Boolean;
begin
  N := 1;
  M := 1;
  StarM := 0;
  StarN := 0;
  while N <= Length(Name) do
  begin
    if (M <= Length(Mask)) and (Mask[M] = '*') then
    begin
      StarM := M;
      StarN := N;
      Inc(M);
      Continue;
    end;
    Hit := False;
    if M <= Length(Mask) then
    begin
      if Mask[M] = '?' then
      begin
        Inc(N, U8CharBytes(Name, N));
        Inc(M);
        Hit := True;
      end
      else if Mask[M] = '[' then
      begin
        Hit := SetMatch(Mask, M + 1, Name, N, Length(Name) - N + 1, Next, Ok);
        if Ok then
        begin
          if Hit then
          begin
            Inc(N, U8CharBytes(Name, N));
            M := Next;
          end;
        end
        else if Name[N] = '[' then
        begin
          Hit := True;
          Inc(N);
          Inc(M);
        end;
      end
      else if Mask[M] = Name[N] then
      begin
        Inc(N);
        Inc(M);
        Hit := True;
      end;
    end;
    if not Hit then
    begin
      if StarM = 0 then
        Exit(False);
      Inc(StarN, U8CharBytes(Name, StarN));     { the star takes one more character }
      N := StarN;
      M := StarM + 1;
    end;
  end;
  while (M <= Length(Mask)) and (Mask[M] = '*') do
    Inc(M);
  Result := M > Length(Mask);
end;

function WildMatch(const Name, Mask: AnsiString; CaseSensitive: Boolean): Boolean;
begin
  if Mask = '*.*' then
    Exit(True);
  if CaseSensitive then
    Result := Match(Name, Mask)
  else
    Result := Match(U8Lower(Name), U8Lower(Mask));
end;

function WildMatchList(const Name, List: AnsiString; CaseSensitive: Boolean): Boolean;
var
  Inc_, Exc: AnsiString;
  P: Integer;
  Any: Boolean;

  function InAny(Masks: AnsiString): Boolean;
  var
    I, J: Integer;
    One: AnsiString;
  begin
    Result := False;
    I := 1;
    while I <= Length(Masks) + 1 do
    begin
      J := I;
      while (J <= Length(Masks)) and (Masks[J] <> ';') and (Masks[J] <> ',') do
        Inc(J);
      One := Trim(Copy(Masks, I, J - I));
      if (One <> '') and WildMatch(Name, One, CaseSensitive) then
        Exit(True);
      I := J + 1;
    end;
  end;

begin
  P := Pos('|', List);
  if P > 0 then
  begin
    Inc_ := Copy(List, 1, P - 1);
    Exc := Copy(List, P + 1, MaxInt);
  end
  else
  begin
    Inc_ := List;
    Exc := '';
  end;
  Any := Trim(Inc_) <> '';
  if Any then
    Result := InAny(Inc_)
  else
    Result := Exc <> '';                        { only exclusions: everything else is wanted }
  if Result and (Exc <> '') and InAny(Exc) then
    Result := False;
end;

end.
