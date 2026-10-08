{ TvCStr: helpers for the texts of menus and controls that mark their hot key with '~'.

  MIT (see LICENSE). }
unit TvCStr;

{$I tvdefs.inc}

interface

{ S without any '~' (the text as the user sees it): '~F~ile' gives 'File'. }
function StripTilde(const S: AnsiString): AnsiString;

implementation

function StripTilde(const S: AnsiString): AnsiString;
var
  I, N: Integer;
begin
  SetLength(Result, Length(S));
  N := 0;
  for I := 1 to Length(S) do
    if S[I] <> '~' then
    begin
      Inc(N);
      Result[N] := S[I];
    end;
  SetLength(Result, N);
end;

end.
