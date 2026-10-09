program t_format;
{ TvFormat: FormatStr. }
{$I ../src/tvdefs.inc}
uses SysUtils, TvFormat;
{$I testlib.inc}

var
  A: ShortString;

begin
  A := 'file';
  Check(FormatStr('%s=%d', ['n', 5]) = 'n=5', 'a string and a number');
  Check(FormatStr('name %s, %d items', [A, 42]) = 'name file, 42 items', 'a ShortString');
  Check(FormatStr('[%5d][%-4s]', [7, 'ab']) = '[    7][ab  ]', 'widths');
  Check(FormatStr('no items', []) = 'no items', 'a format without items');
  Check(FormatStr('', []) = '', 'the empty format');
  Check(Length(FormatStr('%s', [StringOfChar('a', 300)])) = 255, 'the result is cut at 255');
  Finish;
end.
