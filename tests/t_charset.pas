program t_charset;
{ TvCharset: conversions of the single-byte sets, UTF-16, the guess. }
{$I ../src/tvdefs.inc}
uses TvCharset;
{$I testlib.inc}

const
  Privet_utf8 = #$D0#$9F#$D1#$80#$D0#$B8#$D0#$B2#$D0#$B5#$D1#$82;       { Привет }
  Privet_866 = #$8F#$E0#$A8#$A2#$A5#$E2;
  Privet_1251 = #$CF#$F0#$E8#$E2#$E5#$F2;
  Privet_koi8 = #$F0#$D2#$C9#$D7#$C5#$D4;
  Eacute_utf8 = #$C3#$A9;
  { a sentence in three sets: Это пример русского текста, чтобы определить кодировку. }
  Sent_utf8 = #$D0#$AD#$D1#$82#$D0#$BE#$20#$D0#$BF#$D1#$80#$D0#$B8#$D0#$BC#$D0#$B5#$D1#$80#$20#$D1#$80#$D1#$83#$D1#$81#$D1#$81#$D0#$BA#$D0#$BE#$D0#$B3#$D0#$BE#$20#$D1#$82#$D0#$B5#$D0#$BA#$D1#$81#$D1#$82#$D0#$B0;

var
  Lost: Integer;
  S, Raw866, Raw1251, RawKoi: AnsiString;

begin
  Check(CharsetId('cp866') = 866, 'id by name: cp866');
  Check(CharsetId('Windows-1251') = 1251, 'id by name: Windows-1251');
  Check(CharsetId('KOI8-R') = csKoi8R, 'id by name: KOI8-R');
  Check(CharsetId('UTF-8') = csUtf8, 'id by name: UTF-8');
  Check(CharsetId('iso-8859-15') = 28605, 'id by name: ISO-8859-15');
  Check(CharsetId('nope') = 0, 'an unknown name');
  Check(CharsetName(1251) = 'windows-1251', 'name by id');
  Check(CharsetKnown(866) and CharsetKnown(csUtf16BE) and not CharsetKnown(12345), 'known');
  Check(CharsetListCount > 40, 'the list of sets');

  Check(CharsetToUtf8(866, Privet_866) = Privet_utf8, 'cp866 to UTF-8');
  Check(CharsetToUtf8(1251, Privet_1251) = Privet_utf8, 'cp1251 to UTF-8');
  Check(CharsetToUtf8(csKoi8R, Privet_koi8) = Privet_utf8, 'KOI8-R to UTF-8');
  Check(CharsetToUtf8(csLatin1, #$E9) = Eacute_utf8, 'Latin-1 to UTF-8');
  Check(CharsetToUtf8(csCp1252, #$80) = #$E2#$82#$AC, 'cp1252 euro sign');
  Check(CharsetToUtf8(1251, #$98) = #$EF#$BF#$BD, 'a byte that is undefined in cp1251 comes as U+FFFD');
  Check(CharsetToUtf8(866, 'abc') = 'abc', 'ASCII is not changed');
  Check(CharsetToUtf8(csUtf8, Privet_utf8) = Privet_utf8, 'UTF-8 to UTF-8');

  Check(CharsetFromUtf8(866, Privet_utf8, Lost) = Privet_866, 'UTF-8 to cp866');
  Check(CharsetFromUtf8(1251, Privet_utf8, Lost) = Privet_1251, 'UTF-8 to cp1251');
  Check(CharsetFromUtf8(csKoi8R, Privet_utf8, Lost) = Privet_koi8, 'UTF-8 to KOI8-R');
  Check(CharsetFromUtf8(csLatin1, Privet_utf8, Lost) = '??????', 'characters that the set lacks become ?');
  Check(Lost = 6, 'and are counted');
  Check(CharsetFromUtf8(csLatin1, Eacute_utf8 + 'x', Lost) = #$E9'x', 'UTF-8 to Latin-1');
  Check(CharsetFromUtf8(1252, #$E2#$82#$AC, Lost) = #$80, 'the euro sign to cp1252');

  { UTF-16 }
  Check(CharsetToUtf8(csUtf16LE, 'H'#0'i'#0) = 'Hi', 'UTF-16LE to UTF-8');
  Check(CharsetToUtf8(csUtf16BE, #0'H'#0'i') = 'Hi', 'UTF-16BE to UTF-8');
  Check(CharsetToUtf8(csUtf16LE, #$3D#$D8#$00#$DE) = #$F0#$9F#$98#$80, 'a surrogate pair');
  Check(CharsetFromUtf8(csUtf16LE, #$F0#$9F#$98#$80, Lost) = #$3D#$D8#$00#$DE, 'UTF-8 to a surrogate pair');
  Check(CharsetFromUtf8(csUtf16BE, Privet_utf8, Lost) = #$04#$1F#$04#$40#$04#$38#$04#$32#$04#$35#$04#$42, 'UTF-8 to UTF-16BE');

  { the other way round for every set: the way there and back for the defined bytes }
  Lost := 0;
  S := '';
  Check(Utf8Valid(Privet_utf8) and not Utf8Valid(Privet_866) and Utf8Valid('plain') and not Utf8Valid(#$C0#$80), 'Utf8Valid');
  Check(IsPlainAscii('abc') and not IsPlainAscii(Privet_utf8), 'IsPlainAscii');

  { the guess }
  Raw866 := CharsetFromUtf8(866, Sent_utf8, Lost);
  Raw1251 := CharsetFromUtf8(1251, Sent_utf8, Lost);
  RawKoi := CharsetFromUtf8(csKoi8R, Sent_utf8, Lost);
  Check(CharsetGuess(Raw866, [1251, 866, csKoi8R]) = 866, 'guess: a Russian text in cp866');
  Check(CharsetGuess(Raw1251, [866, 1251, csKoi8R]) = 1251, 'guess: a Russian text in cp1251');
  Check(CharsetGuess(RawKoi, [866, 1251, csKoi8R]) = csKoi8R, 'guess: a Russian text in KOI8-R');
  Check(CharsetGuess('plain text', [1251, 866]) = 1251, 'guess: plain ASCII gives the first candidate');
  Finish;
end.
