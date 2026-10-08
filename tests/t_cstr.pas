program t_cstr;
{ TvCStr: texts with '~' hot key marks. }
{$I ../src/tvdefs.inc}
uses TvCStr;
{$I testlib.inc}

var
  Long: AnsiString;
  Short: ShortString;
begin
  Check(StripTilde('~F~ile') = 'File', 'a hot key in the middle of the marks');
  Check(StripTilde('Save ~a~s...') = 'Save as...', 'a hot key inside the text');
  Check(StripTilde('plain') = 'plain', 'a text without marks');
  Check(StripTilde('') = '', 'the empty text');
  Check(StripTilde('~') = '', 'a lone mark');
  Check(StripTilde('a~b') = 'ab', 'an unclosed mark');
  Check(StripTilde('a~~b') = 'ab', 'two marks in a row');
  Check(StripTilde('x~y~z~w') = 'xyzw', 'three marks');
  Check(StripTilde(#$D0#$A4'~'#$D0#$B0'~') = #$D0#$A4#$D0#$B0, 'UTF-8 bytes are kept');
  Long := StringOfChar('~', 300) + 'end';
  Check(StripTilde(Long) = 'end', 'a long text');
  Short := '~O~pen';
  Short := StripTilde(Short);
  Check(Short = 'Open', 'a short string in and out');
  Finish;
end.
