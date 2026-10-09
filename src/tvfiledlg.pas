{ TvFileDlg: the file dialog: TSortedListBox, TFileInputLine, TFileInfoPane, TFileList,
  TFileDialog.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/stddlg.h (class declarations, commands, flags)
    source/tvision/stddlg.cpp (TFileInputLine, TSortedListBox, TFileInfoPane),
    tfillist.cpp, tfildlg.cpp, tvtext2.cpp (texts)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - names and paths are ShortStrings (up to 255 characters, long names are shown as
      they are); the data record of the dialog is a ShortString;
    - the directory is read with TFileFinder (TvFiles); hidden and system files are not
      listed, as in the original;
    - FExpand does not change the case of the names, and keeps the separators of the
      system;
    - the "too many files" message is gone (a Pascal program stops on lack of memory);
    - streams are not translated yet. }
unit TvFileDlg;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvDrawBuf, TvObjs, TvUtil, TvViews, TvDialog,
  TvWindow, TvList, TvInput, TvHist, TvMsgBox, TvApp, TvFiles;

const
  { commands }
  cmFileOpen    = 1001;
  cmFileReplace = 1002;
  cmFileClear   = 1003;
  cmFileInit    = 1004;
  cmChangeDir   = 1005;
  cmRevert      = 1006;
  { messages }
  cmFileFocused       = 102;    { a new file was focused in the TFileList }
  cmFileDoubleClicked = 103;    { a file was selected in the TFileList }
  { options of TFileDialog: which buttons it has, and fdNoLoadDir to leave the list empty }
  fdNoLoadDir = $0100;
  fdHelpButton = $0010; fdClearButton = $0008;
  fdReplaceButton = $0004; fdOpenButton = $0002; fdOKButton = $0001;

  FilesText = '~F~iles';
  OpenText = '~O~pen';
  OKText = 'O~K~';
  ReplaceText = '~R~eplace';
  ClearText = '~C~lear';
  CancelText = 'Cancel';
  HelpText = '~H~elp';
  InvalidDriveText = 'Invalid drive or directory';
  InvalidFileText = 'Invalid file name';
  AmText = 'a';
  PmText = 'p';
  InfoPanePalette = #$1E;

var
  { by the month of a DOS date (1..12): 'Jan' .. 'Dec'; 0 is not a month ('') }
  MonthNames: array[0..12] of string[3];

type
  TFileInputLine = class;
  TSortedListBox = class;
  TFileList = class;
  TFileInfoPane = class;
  TFileDialog = class;

  { shows the name of the focused file of the list }
  TFileInputLine = class(TInputLine)
    constructor Create(const Bounds: TRect; AMaxLen: Integer);
    procedure HandleEvent(var Event: TEvent); override;
  end;

  { a list box over a sorted collection that finds an item by the typed characters }
  TSortedListBox = class(TListBox)
    ShiftState: Word;
    SearchPos: Integer;
    constructor Create(const Bounds: TRect; ANumCols: Integer; AScrollBar: TScrollBar);
    procedure HandleEvent(var Event: TEvent); override;
    function GetKey(const S: ShortString): Pointer; virtual;
    procedure NewList(AList: TCollection);   { DN passes a PCollection (the list must be sorted) }
    function SortedList: TSortedCollection;
  private
    KeyBuf: ShortString;
  end;

  TFileList = class(TSortedListBox)
    constructor Create(const Bounds: TRect; AScrollBar: TScrollBar);
    function DataSize: Integer; override;
    procedure FocusItem(Item: Integer); override;
    procedure GetData(var Rec); override;
    function GetKey(const S: ShortString): Pointer; override;
    function GetText(Item, MaxLen: Integer): ShortString; override;
    procedure SelectItem(Item: Integer); override;
    procedure SetData(var Rec); override;
    procedure ReadDirectory(const Dir, WildCard: ShortString);
    procedure ReadDirectoryMask(const AWildCard: ShortString);
  private
    KeyRec: TSearchRec;
  end;

  { Palette: 1 = text }
  TFileInfoPane = class(TView)
    FileBlock: TSearchRec;
    constructor Create(const Bounds: TRect);
    procedure Draw; override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
  end;

  TFileDialog = class(TDialog)
    FileName: TFileInputLine;
    FileList: TFileList;
    WildCard: ShortString;
    Directory: PStr;
    constructor Create(const AWildCard, ATitle, InputName: ShortString; AOptions: Word;
      HistId: Byte);
    destructor Destroy; override;
    function GetFileName: ShortString;
    procedure GetData(var Rec); override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure SetData(var Rec); override;
    procedure SizeLimits(out Min, Max: TPoint); override;
    function Valid(Command: Word): Boolean; override;
    procedure ReadDirectory;
  private
    function CheckDirectory(const S: ShortString): Boolean;
  end;

implementation

uses
  TvPath;

{ --- TFileInputLine ---------------------------------------------------------- }

constructor TFileInputLine.Create(const Bounds: TRect; AMaxLen: Integer);
begin
  inherited Create(Bounds, AMaxLen);
  EventMask := EventMask or evBroadcast;
end;

procedure TFileInputLine.HandleEvent(var Event: TEvent);
var
  Rec: PSearchRec;
  S: ShortString;
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Message.Command = cmFileFocused) and
    ((State and sfSelected) = 0) then
  begin
    Rec := PSearchRec(Event.Message.InfoPtr);
    S := Rec^.Name;
    if (Rec^.Attr and faDirectory) <> 0 then
      S := S + DirDelim + TFileDialog(Owner).WildCard;
    if Length(S) > MaxLen then
      SetLength(S, MaxLen);
    Data^ := S;
    SelectAll(False);
    DrawView;
  end;
end;

{ --- TSortedListBox ---------------------------------------------------------- }

constructor TSortedListBox.Create(const Bounds: TRect; ANumCols: Integer; AScrollBar: TScrollBar);
begin
  inherited Create(Bounds, ANumCols, AScrollBar);
  ShiftState := 0;
  SearchPos := -1;
  ShowCursor;
  SetCursor(1, 0);
end;

function TSortedListBox.SortedList: TSortedCollection;
begin
  Result := TSortedCollection(List);
end;

function TSortedListBox.GetKey(const S: ShortString): Pointer;
begin
  KeyBuf := S;
  Result := @KeyBuf;
end;

procedure TSortedListBox.NewList(AList: TCollection);
begin
  inherited NewList(AList);
  SearchPos := -1;
end;

function EqualPrefix(const S1, S2: ShortString; Count: Integer): Boolean;
var
  K: Integer;
  A, B: Char;
begin
  { the first Count characters, without regard to case; a string that ends early ends the comparison }
  for K := 1 to Count do
  begin
    A := #0;
    B := #0;
    if K <= Length(S1) then
      A := UpCase(S1[K]);
    if K <= Length(S2) then
      B := UpCase(S2[K]);
    if A <> B then
      Exit(False);
    if A = #0 then
      Break;
  end;
  Result := True;
end;

procedure TSortedListBox.HandleEvent(var Event: TEvent);
var
  Typed, Found: ShortString;
  WasFocused, OldPos, Item, Dot: Integer;
  Ch: Char;
begin
  WasFocused := Focused;
  inherited HandleEvent(Event);
  if (WasFocused <> Focused) or
    ((Event.What = evBroadcast) and (Event.Message.Command = cmReleasedFocus)) then
    SearchPos := -1;
  if (Event.What <> evKeyDown) or (Event.KeyDown.CharScan.CharCode = 0) then
    Exit;
  Ch := Chr(Event.KeyDown.CharScan.CharCode);
  Item := Focused;
  if Item < Range then
    Typed := GetText(Item, 255)
  else
    Typed := '';
  OldPos := SearchPos;
  if Event.KeyDown.KeyCode = kbBack then
  begin
    if SearchPos = -1 then
      Exit;
    Dec(SearchPos);
    if SearchPos = -1 then
      ShiftState := Event.KeyDown.ControlKeyState;
    SetLength(Typed, SearchPos + 1);
  end
  else if Ch = '.' then
  begin
    { the search goes on at the dot of the current name }
    Dot := Pos('.', Typed);
    SearchPos := Dot - 1;
  end
  else
  begin
    Inc(SearchPos);
    if SearchPos = 0 then
      ShiftState := Event.KeyDown.ControlKeyState;
    SetLength(Typed, SearchPos + 1);
    Typed[SearchPos + 1] := Ch;
  end;
  SortedList.Search(GetKey(Typed), Item);
  if Item >= Range then
    SearchPos := OldPos
  else
  begin
    Found := GetText(Item, 255);
    if not EqualPrefix(Typed, Found, SearchPos + 1) then
      SearchPos := OldPos
    else if Item = WasFocused then
      SetCursor(Cursor.X + (SearchPos - OldPos), Cursor.Y)
    else
    begin
      FocusItem(Item);
      SetCursor(Cursor.X + SearchPos + 1, Cursor.Y);
    end;
  end;
  if (SearchPos <> OldPos) or (Ch in ['A'..'Z', 'a'..'z']) then
    ClearEvent(Event);
end;

{ --- TFileList --------------------------------------------------------------- }

constructor TFileList.Create(const Bounds: TRect; AScrollBar: TScrollBar);
begin
  inherited Create(Bounds, 2, AScrollBar);
end;

function TFileList.DataSize: Integer;
begin
  Result := 0;
end;

procedure TFileList.GetData(var Rec);
begin
end;

procedure TFileList.SetData(var Rec);
begin
end;

procedure TFileList.FocusItem(Item: Integer);
begin
  inherited FocusItem(Item);
  Message(Owner, evBroadcast, cmFileFocused, List.At(Item));
end;

procedure TFileList.SelectItem(Item: Integer);
begin
  Message(Owner, evBroadcast, cmFileDoubleClicked, List.At(Item));
end;

function TFileList.GetKey(const S: ShortString): Pointer;
begin
  if ((ShiftState and kbShift) <> 0) or ((S <> '') and (S[1] = '.')) then
    KeyRec.Attr := faDirectory
  else
    KeyRec.Attr := 0;
  KeyRec.Name := S;
  Result := @KeyRec;
end;

function TFileList.GetText(Item, MaxLen: Integer): ShortString;
var
  F: PSearchRec;
begin
  F := PSearchRec(List.At(Item));
  Result := F^.Name;
  if Length(Result) > MaxLen then
    SetLength(Result, MaxLen);
  if (F^.Attr and faDirectory) <> 0 then
    Result := Result + DirDelim;
end;

procedure TFileList.ReadDirectory(const Dir, WildCard: ShortString);
begin
  ReadDirectoryMask(Dir + WildCard);
end;

procedure TFileList.ReadDirectoryMask(const AWildCard: ShortString);
var
  Finder: TFileFinder;
  FileList: TFileCollection;
  Path, Dir, Name, Ext, Rest, Mask: ShortString;
  P: Integer;
  Parent: TSearchRec;
  NoFile: TSearchRec;
begin
  FileList := TFileCollection.Create(5, 5);
  Finder := TFileFinder.Create;
  Path := FExpand(AWildCard);
  FSplit(Path, Dir, Name, Ext);
  { several masks, "*.pas;*.pp" (the IDE's file dialogs use them): each is searched in turn; a mask without
    ";" is searched as it is, as before }
  Rest := Name + Ext;
  repeat
    P := Pos(';', Rest);
    if P = 0 then
      Mask := Rest
    else
    begin
      Mask := Copy(Rest, 1, P - 1);
      Delete(Rest, 1, P);
    end;
    if (Mask <> '') or (P = 0) then
    begin
      if P = 0 then
        Mask := Mask;     { the last (or only) mask }
      if Finder.First(Dir + Mask, faReadOnly or faArchive) then
        repeat
          if (Finder.Rec.Attr and faDirectory) = 0 then
            FileList.Insert(NewSearchRec(Finder.Rec));
        until not Finder.Next;
      Finder.Close;
    end;
  until P = 0;
  if Finder.First(Dir + AllMask, faDirectory) then
    repeat
      if ((Finder.Rec.Attr and faDirectory) <> 0) and (Finder.Rec.Name[1] <> '.') then
        FileList.Insert(NewSearchRec(Finder.Rec));
    until not Finder.Next;
  Finder.Close;

  if not PathIsRoot(Dir) then         { not the root: there is a parent directory }
  begin
    if Finder.First(Dir + '..', faDirectory) then
    begin
      Parent := Finder.Rec;
      Parent.Name := '..';
    end
    else
    begin
      Parent.Name := '..';
      Parent.Size := 0;
      Parent.Time := $210000;
      Parent.Attr := faDirectory;
    end;
    Finder.Close;
    FileList.Insert(NewSearchRec(Parent));
  end;
  Finder.Free;

  NewList(FileList);
  if List.Count > 0 then
    Message(Owner, evBroadcast, cmFileFocused, List.At(0))
  else
  begin
    FillChar(NoFile, SizeOf(NoFile), 0);
    Message(Owner, evBroadcast, cmFileFocused, @NoFile);
  end;
end;

{ --- TFileInfoPane ----------------------------------------------------------- }

constructor TFileInfoPane.Create(const Bounds: TRect);
begin
  inherited Create(Bounds);
  EventMask := EventMask or evBroadcast;
  FileBlock.Name := '';
  FileBlock.Attr := 0;
  FileBlock.Time := 0;
  FileBlock.Size := 0;
end;

procedure TFileInfoPane.Draw;
var
  B: TDrawBuffer;
  Color: TColorAttr;
  Path, Buf: ShortString;
  Mon, Day, Year, Hour, Min: Integer;
  PM: Boolean;

  function Two(N: Integer): ShortString;
  begin
    Str(N, Result);
    if N < 10 then
      Result := '0' + Result;
  end;

begin
  Path := FExpand(TFileDialog(Owner).Directory^ + TFileDialog(Owner).WildCard);
  Color := GetColor($01).Lo;
  B := TDrawBuffer.Create(Size.X);
  B.MoveChar(0, Ord(' '), Color, Size.X);
  B.MoveStrS(1, Path, Color);
  WriteLine(0, 0, Size.X, 1, B);

  B.MoveChar(0, Ord(' '), Color, Size.X);
  B.MoveStrS(1, FileBlock.Name, Color);
  if FileBlock.Name <> '' then
  begin
    Str(FileBlock.Size, Buf);
    B.MoveStrS(Size.X - 38, Buf, Color);
    Min := (FileBlock.Time shr 5) and $3F;
    Hour := (FileBlock.Time shr 11) and $1F;
    Day := (FileBlock.Time shr 16) and $1F;
    Mon := (FileBlock.Time shr 21) and $0F;
    Year := ((FileBlock.Time shr 25) and $7F) + 1980;
    B.MoveStrS(Size.X - 22, MonthNames[Mon], Color);
    B.MoveStrS(Size.X - 18, Two(Day), Color);
    B.PutChar(Size.X - 16, Ord(','));
    Str(Year, Buf);
    B.MoveStrS(Size.X - 15, Buf, Color);
    PM := Hour >= 12;
    Hour := Hour mod 12;
    if Hour = 0 then
      Hour := 12;
    B.MoveStrS(Size.X - 9, Two(Hour), Color);
    B.PutChar(Size.X - 7, Ord(':'));
    B.MoveStrS(Size.X - 6, Two(Min), Color);
    if PM then
      B.MoveStrS(Size.X - 4, PmText, Color)
    else
      B.MoveStrS(Size.X - 4, AmText, Color);
  end;
  WriteLine(0, 1, Size.X, 1, B);
  B.MoveChar(0, 32, Color, Size.X);
  if Size.Y > 2 then
    WriteLine(0, 2, Size.X, Size.Y - 2, B);
  B.Free;
end;

function TFileInfoPane.GetPalette: TPalette;
begin
  Result := MakePalette(InfoPanePalette);
end;

procedure TFileInfoPane.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Message.Command = cmFileFocused) then
  begin
    FileBlock := PSearchRec(Event.Message.InfoPtr)^;
    DrawView;
  end;
end;

{ --- TFileDialog ------------------------------------------------------------- }

constructor TFileDialog.Create(const AWildCard, ATitle, InputName: ShortString; AOptions: Word;
  HistId: Byte);
var
  R, Bounds, Screen: TRect;
  Bar: TScrollBar;
  Opt: Word;

  procedure Put(V: TView; AGrowMode: Byte);
  begin
    Insert(V);
    V.GrowMode := AGrowMode;
  end;

  { a button in the column on the right; the first one is the default }
  procedure AddButton(const AText: ShortString; ACommand: Word; AFlags: Word);
  begin
    Put(TButton.Create(R, AText, ACommand, AFlags), gfGrowLoX or gfGrowHiX);
    R.Move(0, 3);
  end;

  procedure OptionalButton(Mask: Word; const AText: ShortString; ACommand: Word);
  begin
    if (AOptions and Mask) <> 0 then
    begin
      AddButton(AText, ACommand, Opt);
      Opt := bfNormal;
    end;
  end;

begin
  R := TRect.Create(15, 1, 64, 20);
  inherited Create(R, ATitle);
  Directory := NewStr('');
  Options := Options or ofCentered;
  Flags := Flags or wfGrow;
  WildCard := AWildCard;

  R := TRect.Create(3, 3, 31, 4);
  FileName := TFileInputLine.Create(R, 255);
  FileName.Data^ := WildCard;
  Put(FileName, gfGrowHiX);
  R := TRect.Create(2, 2, 3 + CStrLen(InputName), 3);
  Put(TLabel.Create(R, InputName, FileName), 0);
  R := TRect.Create(31, 3, 34, 4);
  Put(THistory.Create(R, FileName, HistId), gfGrowLoX or gfGrowHiX);
  R := TRect.Create(3, 14, 34, 15);
  Bar := TScrollBar.Create(R);
  Insert(Bar);
  R := TRect.Create(3, 6, 34, 14);
  FileList := TFileList.Create(R, Bar);
  Put(FileList, gfGrowHiX or gfGrowHiY);
  R := TRect.Create(2, 5, 8, 6);
  Put(TLabel.Create(R, FilesText, FileList), 0);

  Opt := bfDefault;
  R := TRect.Create(35, 3, 46, 5);
  OptionalButton(fdOpenButton, OpenText, cmFileOpen);
  OptionalButton(fdOKButton, OKText, cmFileOpen);
  OptionalButton(fdReplaceButton, ReplaceText, cmFileReplace);
  OptionalButton(fdClearButton, ClearText, cmFileClear);
  AddButton(CancelText, cmCancel, bfNormal);
  OptionalButton(fdHelpButton, HelpText, cmHelp);

  R := TRect.Create(1, 16, 48, 18);
  Put(TFileInfoPane.Create(R), gfGrowAll and not gfGrowLoX);
  SelectNext(False);

  { a larger default size on a larger screen }
  if TProgram.Application <> nil then
  begin
    Bounds := GetBounds;
    Screen := TProgram.Application.GetBounds;
    if TProgram.Application.Size.X > 90 then
      Bounds.Grow(15, 0)
    else if TProgram.Application.Size.X > 63 then
    begin
      Screen.Grow(-7, 0);
      Bounds.A.X := Screen.A.X;
      Bounds.B.X := Screen.B.X;
    end;
    if TProgram.Application.Size.Y > 34 then
      Bounds.Grow(0, 5)
    else if TProgram.Application.Size.Y > 25 then
    begin
      Screen.Grow(0, -3);
      Bounds.A.Y := Screen.A.Y;
      Bounds.B.Y := Screen.B.Y;
    end;
    Locate(Bounds);
  end;

  if (AOptions and fdNoLoadDir) = 0 then
    ReadDirectory;
end;

destructor TFileDialog.Destroy;
begin
  DisposeStr(Directory);
  Directory := nil;
  FileName := nil;
  FileList := nil;
  inherited Destroy;
end;

procedure TFileDialog.SizeLimits(out Min, Max: TPoint);
begin
  inherited SizeLimits(Min, Max);
  Min.X := 49;
  Min.Y := 19;
end;

{ The name typed by the user. On DOS and Windows the original cuts it at the first blank. Where a blank is a character of a file name (every
  other host) only the blanks at both ends are skipped. }
function Trim1(const S: ShortString): ShortString;
var
  First, Last: Integer;
begin
  First := 1;
  while (First <= Length(S)) and (S[First] <= ' ') do
    Inc(First);
  if PathHasDrives then
  begin
    Last := First;
    while (Last <= Length(S)) and (S[Last] > ' ') do
      Inc(Last);
    Dec(Last);
  end
  else
  begin
    Last := Length(S);
    while (Last >= First) and (S[Last] <= ' ') do
      Dec(Last);
  end;
  Result := Copy(S, First, Last - First + 1);
end;

function TFileDialog.GetFileName: ShortString;
var
  Buf, Dir, Name, Ext, TName, TExt: ShortString;
begin
  Buf := FExpandFrom(Trim1(FileName.Data^), Directory^);
  FSplit(Buf, Dir, Name, Ext);
  if (Name = '') and (Ext = '') then
  begin
    { a directory: the mask of the dialog is taken }
    FSplit(WildCard, Name, TName, TExt);
    Buf := Dir + TName + TExt;
  end;
  Result := Buf;
end;

procedure TFileDialog.GetData(var Rec);
begin
  ShortString(Rec) := GetFileName;
end;

procedure TFileDialog.HandleEvent(var Event: TEvent);
var
  Ok: TEvent;
begin
  inherited HandleEvent(Event);
  case Event.What of
    evCommand:
      if (Event.Message.Command = cmFileOpen) or (Event.Message.Command = cmFileReplace) or
        (Event.Message.Command = cmFileClear) then
      begin
        EndModal(Event.Message.Command);
        ClearEvent(Event);
      end;
    evBroadcast:
      if Event.Message.Command = cmFileDoubleClicked then
      begin
        { a double click on a file acts as the OK button }
        ClearEvent(Event);
        FillChar(Ok, SizeOf(Ok), 0);
        Ok.What := evCommand;
        Ok.Message.Command := cmOK;
        PutEvent(Ok);
      end;
  end;
end;

procedure TFileDialog.ReadDirectory;
begin
  DisposeStr(Directory);
  Directory := NewStr(GetCurDir);
  FileList.ReadDirectoryMask(WildCard);
end;

procedure TFileDialog.SetData(var Rec);
begin
  inherited SetData(Rec);
  if (ShortString(Rec) <> '') and IsWild(ShortString(Rec)) then
  begin
    Valid(cmFileInit);
    FileName.Select;
  end;
end;

function TFileDialog.CheckDirectory(const S: ShortString): Boolean;
begin
  if PathValid(S) then
    Result := True
  else
  begin
    MessageBox(mfError or mfOKButton, '%s: ''%s''', [InvalidDriveText, S]);
    FileName.Select;
    Result := False;
  end;
end;

function TFileDialog.Valid(Command: Word): Boolean;
var
  FName, Dir, Name, Ext, Mask: ShortString;
  Wild: Boolean;

  { show the directory Path in the list (and remember it) }
  procedure Enter(const Path: ShortString);
  begin
    DisposeStr(Directory);
    Directory := NewStr(Path);
    if Command <> cmFileInit then
      FileList.Select;
    FileList.ReadDirectory(Directory^, WildCard);
  end;

begin
  Result := True;
  if Command = 0 then
    Exit;
  Result := inherited Valid(Command);
  if not Result or (Command = cmCancel) or (Command = cmFileClear) then
    Exit;
  FName := GetFileName;
  Wild := IsWild(FName);
  if not Wild and not IsDir(FName) then
  begin
    { a file name: the result of the dialog }
    Result := ValidFileName(FName);
    if not Result then
      MessageBox(mfError or mfOKButton, '%s: ''%s''', [InvalidFileText, FName]);
    Exit;
  end;
  { a mask or a directory: the list shows it and the dialog stays }
  Result := False;
  Mask := WildCard;
  Dir := FName;
  if Wild then
  begin
    FSplit(FName, Dir, Name, Ext);
    Mask := Name + Ext;
  end;
  if not CheckDirectory(Dir) then
    Exit;
  if not EndsWithSep(Dir) then
    Dir := Dir + DirDelim;
  WildCard := Mask;
  Enter(Dir);
end;

procedure InitMonthNames;
const
  Abbrevs = 'JanFebMarAprMayJunJulAugSepOctNovDec';
var
  M: Integer;
begin
  MonthNames[0] := '';
  for M := 1 to 12 do
    MonthNames[M] := Copy(Abbrevs, M * 3 - 2, 3);
end;

initialization
  InitMonthNames;
end.
