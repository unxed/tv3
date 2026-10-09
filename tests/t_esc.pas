program t_esc;
{ UX guidelines: Esc closes the window or dialog. Every stock modal window of the library is run with Esc as its only input and has to end with cmCancel. }
{$I ../src/tvdefs.inc}
uses SysUtils, TvGeom, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem, TvApp,
  TvDialog, TvWindow, TvInput, TvMsgBox, TvFileDlg, TvChDir, TvColorSel, TvHist;
{$I testlib.inc}

var
  App: TApplication;
  Dlg: TDialog;
  S: ShortString;
  Groups: PColorGroup;
  Pal: TPalette;

begin
  CpSelect(866);
  MemInit(80, 25);
  App := TApplication.Create;

  MemClear;
  MemKey(kbEsc);
  Check(MessageBox('Text', mfInformation or mfOKButton) = cmCancel, 'a message box with OK only: Esc ends it');
  MemClear;
  MemKey(kbEsc);
  Check(MessageBox('Text', mfError or mfYesNoCancel) = cmCancel, 'a message box with Yes, No, Cancel: Esc ends it with cmCancel');
  MemClear;
  S := 'text';
  MemKey(kbEsc);
  Check((InputBox('Title', 'Name:', S, 20) = cmCancel) and (S = 'text'), 'an input box: Esc leaves the text');

  MemClear;
  MemKey(kbEsc);
  Dlg := TFileDialog.Create('*.pas', 'Open', '~N~ame', fdOpenButton or fdHelpButton, 1);
  Check(TProgram.DeskTop.ExecView(Dlg) = cmCancel, 'the file dialog: Esc ends it');
  Dlg.Free;
  MemClear;
  MemKey(kbEsc);
  Dlg := TChDirDialog.Create(cdNormal, 2);
  Check(TProgram.DeskTop.ExecView(Dlg) = cmCancel, 'the directory dialog: Esc ends it');
  Dlg.Free;

  Groups := nil;
  Pal := MakePalette(#$1F#$2E#$70);
  Dlg := TColorDialog.Create(Pal, ColorGroup('Group', ColorItem('Item', 1, nil), nil));
  MemClear;
  MemKey(kbEsc);
  Check(TProgram.DeskTop.ExecView(Dlg) = cmCancel, 'the color dialog: Esc ends it');
  Dlg.Free;

  App.Free;
  Finish;
end.
