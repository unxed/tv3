{ TvFormat: FormatStr, a text built from a format of SysUtils.Format and an array of const.

  MIT (see LICENSE). }
unit TvFormat;

{$I tvdefs.inc}

interface

{ SysUtils.Format with Args, cut at 255 characters. }
function FormatStr(const Fmt: ShortString; const Args: array of const): ShortString;

implementation

uses
  SysUtils;

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
