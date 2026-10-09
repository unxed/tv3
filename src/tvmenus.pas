{ TvMenus: menus (menu bar, menu box, popup menu).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/menus.h
    source/tvision/tmnuview.cpp (TMenuItem, TMenu, TMenuView), tmenubar.cpp,
    tmenubox.cpp, tmenupop.cpp, menu.cpp (TSubMenu, operator+)
  Borland disclaimer and MIT notice: COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/docs/API-NAMES.md):
    - names are pointers to ShortStrings (nil name = separator line; an empty name
      given to a constructor is the null name of tvision); the union of TMenuItem
      (param, subMenu) is two fields;
    - the operators + are operators of the unit;
    - the Hint method of the status line returns a ShortString;
    - streams are not translated yet. }
unit TvMenus;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvDrawBuf, TvScreen, TvObjs, TvViews, TvUtil, TvText, TvGlyphs, TvXlat, TvSys;
{$WARN 3018 OFF}  { "Constructor should be public": Create(streamableInit) is protected, as in tvision }

type
  TMenu = class;

  TMenuItem = class
    Next: TMenuItem;
    Name: PStr;          { nil for a separator line }
    Command: Word;       { 0 for an item with a submenu }
    Disabled: Boolean;
    KeyCode: TKey;
    HelpCtx: Word;
    { the union of tvision: Param for an entry with a command (the key name shown at the right, or nil),
      SubMenu for an entry with Command = 0 }
    Param: PStr;
    SubMenu: TMenu;
    constructor Create(const AName: ShortString; ACommand: Word; AKey: TKey; AHelpCtx: Word = hcNoContext;
      const P: ShortString = ''; ANext: TMenuItem = nil); overload;
    constructor Create(const AName: ShortString; AKey: TKey; ASubMenu: TMenu; AHelpCtx: Word = hcNoContext;
      ANext: TMenuItem = nil); overload;
    destructor Destroy; override;
    procedure Append(ANext: TMenuItem);
  end;

  TSubMenu = class(TMenuItem)
    constructor Create(const Nm: ShortString; AKey: TKey; AHelpCtx: Word = hcNoContext);
  end;

  TMenu = class
    Items: TMenuItem;        { the entries, linked by Next }
    Deflt: TMenuItem;        { the entry highlighted when the menu opens }
    constructor Create; overload;
    constructor Create(ItemList: TMenuItem); overload;
    constructor Create(ItemList, TheDefault: TMenuItem); overload;
    destructor Destroy; override;
  end;

  TMenuView = class;
  TMenuBar = class;
  TMenuBox = class;
  TMenuPopup = class;
  TStatusLine = class;
  TStatusItem = class;
  TStatusDef = class;

  { Palette: 1 = normal text, 2 = disabled text, 3 = hot key of normal text,
    4 = selected, 5 = disabled selected, 6 = hot key of selected }
  TMenuView = class(TView)
    ParentMenu: TMenuView;
    Menu: TMenu;
    Current: TMenuItem;
    PutClickEventOnExit: Boolean;
    { set by a drop-down that Esc closed: the menu bar stays active (UxMenuEsc) }
    SubClosedByEsc: Boolean;
    constructor Create(const Bounds: TRect; AMenu: TMenu; AParent: TMenuView); overload;
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    function Execute: Word; override;
    function FindItem(const Shortcut: ShortString): TMenuItem;
    function GetItemRect(Item: TMenuItem): TRect; virtual;
    function GetHelpCtx: Word; override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    function HotKey(Key: TKey): TMenuItem;
    function NewSubView(const Bounds: TRect; AMenu: TMenu;
      AParentMenu: TMenuView): TMenuView; virtual;
  private
    procedure NextItem;
    procedure PrevItem;
    procedure TrackKey(FindNext: Boolean);
    function AtEnd(Forward: Boolean): Boolean;
    function MouseInOwner(var E: TEvent): Boolean;
    function MouseInMenus(var E: TEvent): Boolean;
    procedure TrackMouse(var E: TEvent; var MouseActive: Boolean);
    function TopMenu: TMenuView;
    function UpdateMenu(AMenu: TMenu): Boolean;
    procedure DoASelect(var Event: TEvent);
    function FindHotKey(P: TMenuItem; Key: TKey): TMenuItem;
    function FindAltShortcut(const Event: TEvent): TMenuItem;
    class procedure WriteMenu(Os: opstream; AMenu: TMenu); static;
    class function ReadMenu(Ip: ipstream): TMenu; static;
  end;

  TMenuBar = class(TMenuView)
    constructor Create(const Bounds: TRect; AMenu: TMenu); overload;
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
  public
    destructor Destroy; override;
    procedure Draw; override;
    function GetItemRect(Item: TMenuItem): TRect; override;
  end;

  TMenuBox = class(TMenuView)
    constructor Create(const Bounds: TRect; AMenu: TMenu; AParentMenu: TMenuView); overload;
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
  public
    procedure Draw; override;
    function GetItemRect(Item: TMenuItem): TRect; override;
  private
    procedure FrameLine(var B: TDrawBuffer; N: Integer; const CNormal, Color: TColorAttr);
  end;

  TMenuPopup = class(TMenuBox)
    constructor Create(const Bounds: TRect; AMenu: TMenu; AParentMenu: TMenuView); overload;
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
  public
    destructor Destroy; override;
    function Execute: Word; override;
    procedure HandleEvent(var Event: TEvent); override;
  end;

  TStatusItem = class
    Next: TStatusItem;
    Text: PStr;          { nil: a hidden item, only its key works }
    KeyCode: TKey;
    Command: Word;
    constructor Create(const AText: ShortString; AKey: TKey; Cmd: Word; ANext: TStatusItem = nil);
    destructor Destroy; override;
  end;

  { the items shown for the help contexts Min..Max }
  TStatusDef = class
    Next: TStatusDef;
    Min, Max: Word;
    Items: TStatusItem;
    constructor Create(AMin, AMax: Word; SomeItems: TStatusItem = nil; ANext: TStatusDef = nil);
  end;

  { Palette: 1 = normal text, 2 = disabled text, 3 = hot key of normal text,
    4 = selected, 5 = disabled selected, 6 = hot key of selected }
  TStatusLine = class(TView)
    Items: TStatusItem;
    Defs: TStatusDef;
    constructor Create(const Bounds: TRect; ADefs: TStatusDef); overload;
    class function Build: TStreamable; static;
  protected
    constructor Create(AInit: TStreamableInit); overload;
    function StreamableName: ShortString; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
  public
    destructor Destroy; override;
    procedure Draw; override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    function Hint(AHelpCtx: Word): ShortString; virtual;
    procedure Update; override;
  private
    class procedure WriteItems(Os: opstream; Ts: TStatusItem); static;
    class procedure WriteDefs(Os: opstream; Td: TStatusDef); static;
    class function ReadItems(Ip: ipstream): TStatusItem; static;
    class function ReadDefs(Ip: ipstream): TStatusDef; static;
    procedure DrawSelect(Selected: TStatusItem);
    procedure FindItems;
    function ItemMouseIsIn(Mouse: TPoint): TStatusItem;
  end;

function NewLine: TMenuItem;

{ the operators + of tvision that chain the items of a menu and of the status line }
operator +(S: TSubMenu; I: TMenuItem): TSubMenu;
operator +(S1, S2: TSubMenu): TSubMenu;
operator +(I1, I2: TMenuItem): TMenuItem;
operator +(S1: TStatusDef; S2: TStatusItem): TStatusDef;
operator +(S1, S2: TStatusDef): TStatusDef;

var
  { the stream classes }
  RMenuView, RMenuBar, RMenuBox, RMenuPopup, RStatusLine: TStreamableClass;
  { UX guidelines of vtui, menus: Esc closes an open drop-down but keeps the menu bar active, a second Esc leaves the bar (in Turbo Vision one Esc leaves both).
    False: the classic behaviour. }
  UxMenuEsc: Boolean = True;
  { Left and Right in the active menu bar open the drop-down of the item they move to. False: the item is only highlighted (Turbo Vision). }
  UxMenuAutoOpen: Boolean = True;
  { A held arrow stops at the first / last item of a menu (and of a menu bar) instead of going round (the guidelines' SetMenuLoopScroll(false)); a single press
    still wraps. It needs to know which keys are auto repeats (TEvent.KeyFlags: the win32 input mode, the keyboard protocol of Kitty);
    elsewhere a held arrow wraps as before. False: always wraps. }
  UxMenuHeldStop: Boolean = True;

implementation

{ --- menu data --------------------------------------------------------------- }

constructor TMenuItem.Create(const AName: ShortString; ACommand: Word; AKey: TKey; AHelpCtx: Word;
  const P: ShortString; ANext: TMenuItem);
begin
  inherited Create;
  if AName = '' then
    Name := nil              { the null name of tvision: a separator line }
  else
    Name := NewStr(AName);
  Command := ACommand;
  Disabled := not TView.CommandEnabled(Command);
  KeyCode := AKey;
  HelpCtx := AHelpCtx;
  if P = '' then
    Param := nil
  else
    Param := NewStr(P);
  Next := ANext;
end;

constructor TMenuItem.Create(const AName: ShortString; AKey: TKey; ASubMenu: TMenu; AHelpCtx: Word;
  ANext: TMenuItem);
begin
  inherited Create;
  if AName = '' then
    Name := nil              { the null name of tvision: a separator line }
  else
    Name := NewStr(AName);
  Command := 0;
  Disabled := not TView.CommandEnabled(Command);
  KeyCode := AKey;
  HelpCtx := AHelpCtx;
  SubMenu := ASubMenu;
  Next := ANext;
end;

destructor TMenuItem.Destroy;
begin
  DisposeStr(Name);
  if Command = 0 then
    SubMenu.Free
  else
    DisposeStr(Param);
  inherited Destroy;
end;

procedure TMenuItem.Append(ANext: TMenuItem);
begin
  Next := ANext;
end;

function NewLine: TMenuItem;
begin
  Result := TMenuItem.Create('', 0, TKey.Create(0), hcNoContext, '', nil);
end;

constructor TSubMenu.Create(const Nm: ShortString; AKey: TKey; AHelpCtx: Word);
begin
  inherited Create(Nm, AKey, TMenu.Create, AHelpCtx);
end;

constructor TMenu.Create;
begin
  inherited Create;
  Items := nil;
  Deflt := nil;
end;

constructor TMenu.Create(ItemList: TMenuItem);
begin
  inherited Create;
  Items := ItemList;
  Deflt := ItemList;
end;

constructor TMenu.Create(ItemList, TheDefault: TMenuItem);
begin
  inherited Create;
  Items := ItemList;
  Deflt := TheDefault;
end;

destructor TMenu.Destroy;
var
  Temp: TMenuItem;
begin
  while Items <> nil do
  begin
    Temp := Items;
    Items := Items.Next;
    Temp.Free;
  end;
  inherited Destroy;
end;

operator +(S: TSubMenu; I: TMenuItem): TSubMenu;
var
  Sub: TSubMenu;
  Cur: TMenuItem;
begin
  Sub := S;
  while Sub.Next <> nil do
    Sub := TSubMenu(Sub.Next);
  if Sub.SubMenu.Items = nil then
  begin
    Sub.SubMenu.Items := I;
    Sub.SubMenu.Deflt := I;
  end
  else
  begin
    Cur := Sub.SubMenu.Items;
    while Cur.Next <> nil do
      Cur := Cur.Next;
    Cur.Next := I;
  end;
  Result := S;
end;

operator +(S1, S2: TSubMenu): TSubMenu;
var
  Cur: TMenuItem;
begin
  Cur := S1;
  while Cur.Next <> nil do
    Cur := Cur.Next;
  Cur.Next := S2;
  Result := S1;
end;

operator +(I1, I2: TMenuItem): TMenuItem;
var
  Cur: TMenuItem;
begin
  Cur := I1;
  while Cur.Next <> nil do
    Cur := Cur.Next;
  Cur.Next := I2;
  Result := I1;
end;

operator +(S1: TStatusDef; S2: TStatusItem): TStatusDef;
var
  Def: TStatusDef;
  Cur: TStatusItem;
begin
  Def := S1;
  while Def.Next <> nil do
    Def := Def.Next;
  if Def.Items = nil then
    Def.Items := S2
  else
  begin
    Cur := Def.Items;
    while Cur.Next <> nil do
      Cur := Cur.Next;
    Cur.Next := S2;
  end;
  Result := S1;
end;

operator +(S1, S2: TStatusDef): TStatusDef;
var
  Cur: TStatusDef;
begin
  Cur := S1;
  while Cur.Next <> nil do
    Cur := Cur.Next;
  Cur.Next := S2;
  Result := S1;
end;

{ --- TMenuView --------------------------------------------------------------- }

const
  MenuViewPalette = #2#3#4#5#6#7;

type
  TMenuAction = (doNothing, doSelect, doReturn);

{ the colors of the entries of a menu or of the status line }
type
  TMenuColors = record
    Normal, Selected, Disabled, SelDisabled: TAttrPair;
  end;

function GetMenuColors(V: TView): TMenuColors;
begin
  Result.Disabled := V.GetColor($0202);
  Result.SelDisabled := V.GetColor($0505);
  Result.Normal := V.GetColor($0301);
  Result.Selected := V.GetColor($0604);
end;

function ItemColor(const C: TMenuColors; Enabled, Chosen: Boolean): TAttrPair;
begin
  if not Enabled then
  begin
    if Chosen then
      Result := C.SelDisabled
    else
      Result := C.Disabled;
  end
  else if Chosen then
    Result := C.Selected
  else
    Result := C.Normal;
end;

{ a name of the menu bar or the status line: a blank on both sides }
procedure PutLabel(B: TDrawBuffer; X: Integer; const S: ShortString; const Color: TAttrPair);
begin
  B.MoveChar(X, Ord(' '), Color[0], 1);
  B.MoveCStrS(X + 1, S, Color);
  B.MoveChar(X + 1 + CStrLen(S), Ord(' '), Color[0], 1);
end;

function IsLine(P: TMenuItem): Boolean; inline;
begin
  Result := P.Name = nil;
end;

{ an entry whose command can be given now }
function Usable(P: TMenuItem): Boolean;
begin
  Result := Assigned(P) and TView.CommandEnabled(P.Command);
end;

procedure SetCommand(var Event: TEvent; Command: Word);
begin
  Event.What := evCommand;
  Event.Message.Command := Command;
  Event.Message.InfoPtr := nil;
end;

{ turns the event into a command and puts it back for the owner of V }
procedure PostCommand(V: TView; var Event: TEvent; Command: Word);
begin
  SetCommand(Event, Command);
  V.PutEvent(Event);
  V.ClearEvent(Event);
end;

constructor TMenuView.Create(const Bounds: TRect; AMenu: TMenu; AParent: TMenuView);
begin
  inherited Create(Bounds);
  ParentMenu := AParent;
  Menu := AMenu;
  Current := nil;
  PutClickEventOnExit := True;
  EventMask := EventMask or evBroadcast;
end;

procedure TMenuView.TrackMouse(var E: TEvent; var MouseActive: Boolean);
var
  Mouse: TPoint;
begin
  { the entry under the mouse, or nil }
  Mouse := MakeLocal(E.Mouse.Where);
  Current := Menu.Items;
  while Assigned(Current) and not GetItemRect(Current).Contains(Mouse) do
    Current := Current.Next;
  if Assigned(Current) then
    MouseActive := True;
end;

procedure TMenuView.NextItem;
begin
  Current := Current.Next;
  if Current = nil then
    Current := Menu.Items;
end;

procedure TMenuView.PrevItem;
var
  Stop, P: TMenuItem;
begin
  { the entry before the current one; before the first comes the last }
  if Current = Menu.Items then
    Stop := nil
  else
    Stop := Current;
  P := Menu.Items;
  while P.Next <> Stop do
    P := P.Next;
  Current := P;
end;

{ the current item is the last (Forward) or the first one that can be moved to }
function TMenuView.AtEnd(Forward: Boolean): Boolean;
var
  P: TMenuItem;
begin
  Result := False;
  if (Current = nil) or (Menu = nil) then
    Exit;
  if Forward then
  begin
    P := Current.Next;
    while (P <> nil) and (P.Name = nil) do
      P := P.Next;
    Result := P = nil;
  end
  else
  begin
    Result := True;
    P := Menu.Items;
    while (P <> nil) and (P <> Current) do
    begin
      if P.Name <> nil then
        Exit(False);
      P := P.Next;
    end;
  end;
end;

procedure TMenuView.TrackKey(FindNext: Boolean);
begin
  if Current = nil then
  begin
    Current := Menu.Items;
    if not FindNext then
      PrevItem;
    if Current.Name <> nil then
      Exit;
  end;
  repeat
    if FindNext then
      NextItem
    else
      PrevItem;
  until Current.Name <> nil;
end;

function TMenuView.MouseInOwner(var E: TEvent): Boolean;
var
  Mouse: TPoint;
  R: TRect;
begin
  if ParentMenu = nil then
    Result := False
  else
  begin
    Mouse := ParentMenu.MakeLocal(E.Mouse.Where);
    R := ParentMenu.GetItemRect(ParentMenu.Current);
    Result := R.Contains(Mouse);
  end;
end;

function TMenuView.MouseInMenus(var E: TEvent): Boolean;
var
  P: TMenuView;
begin
  P := ParentMenu;
  while P <> nil do
  begin
    if P.MouseInView(E.Mouse.Where) then
      Exit(True);
    P := P.ParentMenu;
  end;
  Result := False;
end;

function TMenuView.TopMenu: TMenuView;
var
  P: TMenuView;
begin
  P := Self;
  while P.ParentMenu <> nil do
    P := P.ParentMenu;
  Result := P;
end;

function TMenuView.Execute: Word;
var
  E: TEvent;
  Action: TMenuAction;
  AutoSelect, FirstEvent, MouseActive, IsBar, SaveRepeatInfo: Boolean;
  ItemShown, LastTargetItem, P: TMenuItem;
  Target: TMenuView;
  R: TRect;
  Res: Word;

  { an arrow key: move to the next / previous entry; a held key stops at the end }
  procedure Step(Forwards: Boolean);
  begin
    if UxMenuHeldStop and ((E.KeyDown.KeyFlags and kfRepeat) <> 0) and AtEnd(Forwards) then
      Exit;
    TrackKey(Forwards);
  end;

  { a key that is not a movement: a hot letter of this menu, an Alt+letter of
    the bar, or a hot key of any entry }
  procedure OtherKey;
  var
    Alt: Boolean;
    X: TEvent;
  begin
    Alt := GetAltCharStr(E) <> '';
    if Alt then
    begin
      Target := TopMenu;
      P := Target.FindAltShortcut(E);
    end
    else
    begin
      Target := Self;
      P := FindItem(EventText(E));
    end;
    if P = nil then
    begin
      { a letter of another keyboard layout: the Latin letter of the same key }
      X := E;
      if Alt then
      begin
        if XlatModded(X) then
          P := Target.FindAltShortcut(X);
      end
      else if XlatPlain(X) then
        P := FindItem(EventText(X));
    end;
    if P = nil then
    begin
      { a hot key anywhere in the menu tree gives its command at once }
      P := TopMenu.HotKey(EventKey(E));
      if Usable(P) then
      begin
        Action := doReturn;
        Res := P.Command;
      end;
    end
    else if Target <> Self then
    begin
      { an Alt+letter of the bar: this menu closes unless it is that entry's }
      if (ParentMenu <> Target) or (ParentMenu.Current <> P) then
        Action := doReturn;
    end
    else
    begin
      Current := P;
      Action := doSelect;
      AutoSelect := AutoSelect or IsBar;
    end;
  end;

  procedure MouseDown;
  begin
    if MouseInView(E.Mouse.Where) or MouseInOwner(E) then
    begin
      TrackMouse(E, MouseActive);
      if IsBar then
        { a press opens the entry, unless it closes the one it just opened }
        AutoSelect := (Current = nil) or (Current <> LastTargetItem)
      else if not FirstEvent and MouseInOwner(E) then
        { a press on the parent entry closes this menu }
        Action := doReturn;
    end
    else
    begin
      { a click outside closes the menu; the view under it gets the click }
      if PutClickEventOnExit then
        PutEvent(E);
      Action := doReturn;
    end;
  end;

  procedure MouseUp;
  begin
    TrackMouse(E, MouseActive);
    if MouseInOwner(E) then
      Current := Menu.Deflt
    else if Current <> nil then
    begin
      if Current.Name <> nil then
        if Current <> LastTargetItem then
          Action := doSelect
        else if IsBar then
          Action := doReturn
        else
          { released over the entry whose submenu was just closed: the next release opens it }
          LastTargetItem := nil;
    end
    else if MouseActive and not MouseInView(E.Mouse.Where) then
      Action := doReturn
    else if not IsBar then
    begin
      { released over a margin or a separator }
      Current := Menu.Deflt;
      if Current = nil then
        Current := Menu.Items;
    end;
  end;

  procedure MouseMove;
  begin
    if E.Mouse.Buttons = 0 then
      Exit;
    TrackMouse(E, MouseActive);
    if not (MouseInView(E.Mouse.Where) or MouseInOwner(E)) and MouseInMenus(E) then
      Action := doReturn
    else if IsBar and MouseActive and (Current <> LastTargetItem) then
      AutoSelect := True;
  end;

  procedure KeyDown;
  begin
    case E.KeyDown.KeyCode of
      kbUp, kbDown:
        if not IsBar then
          Step(E.KeyDown.KeyCode = kbDown)
        else if E.KeyDown.KeyCode = kbDown then
          AutoSelect := True;
      kbLeft, kbRight:
        if IsBar then
        begin
          Step(E.KeyDown.KeyCode = kbRight);
          if UxMenuAutoOpen then
            AutoSelect := True;
        end
        else if ParentMenu <> nil then
          Action := doReturn;
      kbHome, kbEnd:
        if not IsBar then
        begin
          { the first or the last entry that is not a line }
          Current := nil;
          TrackKey(E.KeyDown.KeyCode = kbHome);
        end;
      kbEnter:
        begin
          Action := doSelect;
          AutoSelect := AutoSelect or IsBar;
        end;
      kbEsc:
        begin
          if (ParentMenu <> nil) and (ParentMenu.Size.Y = 1) then
          begin
            { a drop-down of the bar: without UxMenuEsc the Esc goes on to
              the bar, which closes too }
            if UxMenuEsc then
            begin
              ParentMenu.SubClosedByEsc := True;
              ClearEvent(E);
            end;
          end
          else
            ClearEvent(E);
          Action := doReturn;
        end;
    else
      OtherKey;
    end;
  end;

  procedure OpenSubMenu;
  begin
    if (E.What and (evMouseDown or evMouseMove)) <> 0 then
      PutEvent(E);
    { below the entry, down to the bottom right corner of the owner }
    R := GetItemRect(Current);
    R.Move(Origin.X, Origin.Y);
    R.A.Y := R.B.Y;
    R.B := Owner.Size;
    if IsBar then
      Dec(R.A.X);
    Target := TopMenu.NewSubView(R, Current.SubMenu, Self);
    Res := Owner.ExecView(Target);
    Target.Free;
    LastTargetItem := Current;
    Menu.Deflt := Current;
    if SubClosedByEsc then
    begin
      SubClosedByEsc := False;
      AutoSelect := False;
    end;
  end;

begin
  IsBar := Size.Y = 1;
  AutoSelect := False;
  FirstEvent := True;
  MouseActive := False;
  ItemShown := nil;
  LastTargetItem := nil;
  SubClosedByEsc := False;
  Res := 0;
  Current := Menu.Deflt;
  SaveRepeatInfo := KeyRepeatInfo;
  if UxMenuHeldStop then
    KeyRepeatInfo := True;
  try
    repeat
      Action := doNothing;
      GetEvent(E);
      case E.What of
        evMouseDown: MouseDown;
        evMouseUp: MouseUp;
        evMouseMove: MouseMove;
        evKeyDown: KeyDown;
        evCommand:
          if E.Message.Command = cmMenu then
          begin
            AutoSelect := False;
            LastTargetItem := nil;
            if ParentMenu <> nil then
              Action := doReturn;
          end
          else
            Action := doReturn;
      end;

      if LastTargetItem <> Current then
        LastTargetItem := nil;
      if ItemShown <> Current then
      begin
        ItemShown := Current;
        DrawView;
      end;

      if ((Action = doSelect) or ((Action = doNothing) and AutoSelect)) and
        (Current <> nil) and (Current.Name <> nil) then
      begin
        if (Current.Command = 0) and not Current.Disabled then
          OpenSubMenu
        else if Action = doSelect then
          Res := Current.Command;
      end;

      if Res <> 0 then
        if CommandEnabled(Res) then
        begin
          ClearEvent(E);
          Action := doReturn;
        end
        else
          Res := 0;
      FirstEvent := False;
    until Action = doReturn;
  finally
    KeyRepeatInfo := SaveRepeatInfo;
  end;

  { the event that ended a submenu goes on to its parent }
  if (E.What = evCommand) or ((E.What <> evNothing) and Assigned(ParentMenu)) then
    PutEvent(E);
  if Assigned(Current) then
  begin
    Menu.Deflt := Current;
    Current := nil;
    DrawView;
  end;
  Result := Res;
end;

function TMenuView.FindItem(const Shortcut: ShortString): TMenuItem;
var
  Hot: ShortString;
begin
  Result := Menu.Items;
  while Result <> nil do
  begin
    if (Result.Name <> nil) and not Result.Disabled then
    begin
      Hot := HotKeyStr(Result.Name^);
      if (Hot <> '') and TText.EqualsIgnoreCase(Shortcut, Hot) then
        Exit;
    end;
    Result := Result.Next;
  end;
end;

function TMenuView.FindAltShortcut(const Event: TEvent): TMenuItem;
var
  C: Char;
begin
  Result := nil;
  { first the text of the event, then the character of the key code }
  if Event.KeyDown.TextLength > 0 then
    Result := FindItem(GetAltCharStr(Event));
  if Result = nil then
  begin
    C := GetAltChar(Event.KeyDown.KeyCode);
    if C <> #0 then
      Result := FindItem(C);
  end;
end;

function TMenuView.GetItemRect(Item: TMenuItem): TRect;
begin
  Result := TRect.Create(0, 0, 0, 0);
end;

function TMenuView.GetHelpCtx: Word;
var
  C: TMenuView;
begin
  C := Self;
  while (C <> nil) and ((C.Current = nil) or (C.Current.HelpCtx = hcNoContext) or
    (C.Current.Name = nil)) do
    C := C.ParentMenu;
  if C <> nil then
    Result := C.Current.HelpCtx
  else
    Result := HelpCtx;
end;

function TMenuView.GetPalette: TPalette;
begin
  Result := TPalette.Create(MenuViewPalette, Length(MenuViewPalette));
end;

function TMenuView.UpdateMenu(AMenu: TMenu): Boolean;
var
  P: TMenuItem;
  Enabled: Boolean;
begin
  Result := False;
  if AMenu = nil then
    Exit;
  P := AMenu.Items;
  while Assigned(P) do
  begin
    if not IsLine(P) then
      if P.Command <> 0 then
      begin
        Enabled := CommandEnabled(P.Command);
        if P.Disabled = Enabled then
        begin
          P.Disabled := not Enabled;
          Result := True;
        end;
      end
      else if UpdateMenu(P.SubMenu) then
        Result := True;
    P := P.Next;
  end;
end;

procedure TMenuView.DoASelect(var Event: TEvent);
var
  Chosen: Word;
begin
  { the menu reads the event again in its own loop }
  PutEvent(Event);
  Chosen := Owner.ExecView(Self);
  if (Chosen <> 0) and CommandEnabled(Chosen) then
  begin
    Event.What := evCommand;
    Event.Message.Command := Chosen;
    Event.Message.InfoPtr := nil;
    PutEvent(Event);
  end;
  ClearEvent(Event);
end;

procedure TMenuView.HandleEvent(var Event: TEvent);
var
  P: TMenuItem;
begin
  if Menu = nil then
    Exit;
  case Event.What of
    evMouseDown:
      DoASelect(Event);
    evCommand:
      if Event.Message.Command = cmMenu then
        DoASelect(Event);
    evKeyDown:
      if FindAltShortcut(Event) <> nil then
        DoASelect(Event)
      else
      begin
        P := HotKey(EventKey(Event));
        if Usable(P) then
          PostCommand(Self, Event, P.Command);
      end;
    evBroadcast:
      if (Event.Message.Command = cmCommandSetChanged) and UpdateMenu(Menu) then
        DrawView;
  end;
end;

function TMenuView.FindHotKey(P: TMenuItem; Key: TKey): TMenuItem;
var
  T: TMenuItem;
begin
  while P <> nil do
  begin
    if P.Name <> nil then
    begin
      if P.Command = 0 then
      begin
        T := FindHotKey(P.SubMenu.Items, Key);
        if T <> nil then
          Exit(T);
      end
      else if (not P.Disabled) and (P.KeyCode.Code <> kbNoKey) and (P.KeyCode = Key) then
        Exit(P);
    end;
    P := P.Next;
  end;
  Result := nil;
end;

function TMenuView.HotKey(Key: TKey): TMenuItem;
begin
  Result := FindHotKey(Menu.Items, Key);
end;

function TMenuView.NewSubView(const Bounds: TRect; AMenu: TMenu;
  AParentMenu: TMenuView): TMenuView;
var
  B: TMenuBox;
begin
  B := TMenuBox.Create(Bounds, AMenu, AParentMenu);
  Result := B;
end;

{ --- TMenuBar ---------------------------------------------------------------- }

constructor TMenuBar.Create(const Bounds: TRect; AMenu: TMenu);
begin
  inherited Create(Bounds, AMenu, nil);
  GrowMode := gfGrowHiX;
  Options := Options or ofPreProcess;
end;

destructor TMenuBar.Destroy;
begin
  Menu.Free;
  Menu := nil;
  inherited Destroy;
end;

procedure TMenuBar.Draw;
var
  B: TDrawBuffer;
  C: TMenuColors;
  P: TMenuItem;
  X, W: Integer;
begin
  C := GetMenuColors(Self);
  B := TDrawBuffer.Create(Size.X);
  try
    B.MoveChar(0, Ord(' '), C.Normal[0], Size.X);
    P := nil;
    if Menu <> nil then
      P := Menu.Items;
    X := 1;
    while Assigned(P) do
    begin
      if not IsLine(P) then
      begin
        W := CStrLen(P.Name^) + 2;
        { an entry that does not fit is not drawn }
        if X + W - 2 < Size.X then
          PutLabel(B, X, P.Name^, ItemColor(C, not P.Disabled, P = Current));
        Inc(X, W);
      end;
      P := P.Next;
    end;
    WriteBuf(0, 0, Size.X, 1, B);
  finally
    B.Free;
  end;
end;

function TMenuBar.GetItemRect(Item: TMenuItem): TRect;
var
  P: TMenuItem;
begin
  { the entries follow each other from column 1, each with a blank on both sides }
  Result := TRect.Create(1, 0, 1, 1);
  P := Menu.Items;
  while Assigned(P) do
  begin
    Result.A.X := Result.B.X;
    if not IsLine(P) then
      Result.B.X := Result.A.X + CStrLen(P.Name^) + 2;
    if P = Item then
      Break;
    P := P.Next;
  end;
end;

{ --- TMenuBox ---------------------------------------------------------------- }

const
  { frame pieces of a menu box (glyphs, TvGlyphs; 32 is a blank): top 0, bottom 5, side 10, separator 15 }
  MenuFrameGlyphs: array[0..19] of LongWord = (
    32, glLightDR, glLightH, glLightDL, 32, 32, glLightUR, glLightH, glLightUL, 32,
    32, glLightV, 32, glLightV, 32, 32, glLightVR, glLightH, glLightVL, 32);

{ the columns an entry needs: frame, margins, name, and the arrow or the key name }
function EntryWidth(P: TMenuItem): Integer;
begin
  Result := CStrLen(P.Name^) + 6;
  if P.Command = 0 then
    Inc(Result, 3)
  else if P.Param <> nil then
    Inc(Result, CStrLen(P.Param^) + 2);
end;

{ Lo..Hi becomes Len long, from Lo if there is room, else ending at Hi }
procedure FitSpan(var Lo, Hi: Integer; Len: Integer);
begin
  if Lo + Len < Hi then
    Hi := Lo + Len
  else
    Lo := Hi - Len;
end;

function MenuBoxRect(const Bounds: TRect; AMenu: TMenu): TRect;
var
  P: TMenuItem;
  Width, Height: Integer;
begin
  Width := 10;
  Height := 2;      { the top and bottom lines }
  P := nil;
  if AMenu <> nil then
    P := AMenu.Items;
  while Assigned(P) do
  begin
    Inc(Height);
    if not IsLine(P) and (EntryWidth(P) > Width) then
      Width := EntryWidth(P);
    P := P.Next;
  end;
  Result := Bounds;
  FitSpan(Result.A.X, Result.B.X, Width);
  FitSpan(Result.A.Y, Result.B.Y, Height);
end;

constructor TMenuBox.Create(const Bounds: TRect; AMenu: TMenu; AParentMenu: TMenuView);
begin
  inherited Create(MenuBoxRect(Bounds, AMenu), AMenu, AParentMenu);
  State := State or sfShadow;
  Options := Options or ofPreProcess;
end;

procedure TMenuBox.FrameLine(var B: TDrawBuffer; N: Integer; const CNormal, Color: TColorAttr);
begin
  B.MoveGlyph(0, MenuFrameGlyphs[N], CNormal, 1);
  B.MoveGlyph(1, MenuFrameGlyphs[N + 1], CNormal, 1);
  B.MoveGlyph(2, MenuFrameGlyphs[N + 2], Color, Size.X - 4);
  B.MoveGlyph(Size.X - 2, MenuFrameGlyphs[N + 3], CNormal, 1);
  B.MoveGlyph(Size.X - 1, MenuFrameGlyphs[N + 4], CNormal, 1);
end;

procedure TMenuBox.Draw;
var
  B: TDrawBuffer;
  C: TMenuColors;
  Color: TAttrPair;
  P: TMenuItem;
  Y: Integer;
begin
  C := GetMenuColors(Self);
  B := TDrawBuffer.Create(Size.X);
  try
    FrameLine(B, 0, C.Normal[0], C.Normal[0]);
    WriteBuf(0, 0, Size.X, 1, B);
    Y := 0;
    P := nil;
    if Menu <> nil then
      P := Menu.Items;
    while Assigned(P) do
    begin
      Inc(Y);
      if IsLine(P) then
        FrameLine(B, 15, C.Normal[0], C.Normal[0])
      else
      begin
        Color := ItemColor(C, not P.Disabled, P = Current);
        FrameLine(B, 10, C.Normal[0], Color[0]);
        B.MoveCStrS(3, P.Name^, Color);
        if P.Command = 0 then
          B.PutGlyph(Size.X - 4, glTriRight)
        else if P.Param <> nil then
          B.MoveCStrS(Size.X - 3 - CStrLen(P.Param^), P.Param^, Color);
      end;
      WriteBuf(0, Y, Size.X, 1, B);
      P := P.Next;
    end;
    FrameLine(B, 5, C.Normal[0], C.Normal[0]);
    WriteBuf(0, Y + 1, Size.X, 1, B);
  finally
    B.Free;
  end;
end;

function TMenuBox.GetItemRect(Item: TMenuItem): TRect;
var
  P: TMenuItem;
  Row: Integer;
begin
  { one row per entry, below the top frame line }
  P := Menu.Items;
  Row := 1;
  while Assigned(P) and (P <> Item) do
  begin
    P := P.Next;
    Inc(Row);
  end;
  Result := TRect.Create(2, Row, Size.X - 2, Row + 1);
end;

{ --- TMenuPopup -------------------------------------------------------------- }

constructor TMenuPopup.Create(const Bounds: TRect; AMenu: TMenu; AParentMenu: TMenuView);
begin
  inherited Create(Bounds, AMenu, AParentMenu);
  PutClickEventOnExit := False;
end;

destructor TMenuPopup.Destroy;
begin
  Menu.Free;
  Menu := nil;
  inherited Destroy;
end;

function TMenuPopup.Execute: Word;
begin
  { the default entry is not highlighted: it would look ugly }
  Menu.Deflt := nil;
  Result := inherited Execute;
end;

procedure TMenuPopup.HandleEvent(var Event: TEvent);
var
  P: TMenuItem;
  C: Char;
begin
  if Event.What = evKeyDown then
  begin
    { Ctrl+hot letter, or the hot key of an entry }
    C := GetCtrlChar(Event.KeyDown.KeyCode);
    if C = #0 then
      P := nil
    else
      P := FindItem(C);
    if P = nil then
      P := HotKey(TKey.Create(Event.KeyDown.KeyCode));
    if Usable(P) then
      PostCommand(Self, Event, P.Command)
    else if GetAltChar(Event.KeyDown.KeyCode) <> #0 then
      { the menu bar must not see Alt keys while the popup is open }
      ClearEvent(Event);
  end;
  inherited HandleEvent(Event);
end;

{ --- status line ------------------------------------------------------------- }

{ the separator between the items and the hint: a vertical line and a space }
function HintSeparator: ShortString;
begin
  Result := GlyphStr(glLightV) + ' ';
end;

{ --- TStatusItem, TStatusDef ------------------------------------------------------ }

constructor TStatusItem.Create(const AText: ShortString; AKey: TKey; Cmd: Word; ANext: TStatusItem);
begin
  inherited Create;
  Next := ANext;
  if AText = '' then
    Text := nil              { the null text of tvision: a hidden item, only its key works }
  else
    Text := NewStr(AText);
  KeyCode := AKey;
  Command := Cmd;
end;

destructor TStatusItem.Destroy;
begin
  DisposeStr(Text);
  inherited Destroy;
end;

constructor TStatusDef.Create(AMin, AMax: Word; SomeItems: TStatusItem; ANext: TStatusDef);
begin
  inherited Create;
  Next := ANext;
  Min := AMin;
  Max := AMax;
  Items := SomeItems;
end;

constructor TStatusLine.Create(const Bounds: TRect; ADefs: TStatusDef);
begin
  inherited Create(Bounds);
  Defs := ADefs;
  Options := Options or ofPreProcess;
  EventMask := EventMask or evBroadcast;
  GrowMode := gfGrowLoY or gfGrowHiX or gfGrowHiY;
  FindItems;
end;

destructor TStatusLine.Destroy;
var
  T: TStatusDef;
  I, TI: TStatusItem;
begin
  while Defs <> nil do
  begin
    T := Defs;
    Defs := Defs.Next;
    I := T.Items;
    while I <> nil do
    begin
      TI := I;
      I := I.Next;
      TI.Free;
    end;
    T.Free;
  end;
  Items := nil;
  inherited Destroy;
end;

procedure TStatusLine.Draw;
begin
  DrawSelect(nil);
end;

procedure TStatusLine.DrawSelect(Selected: TStatusItem);
var
  B: TDrawBuffer;
  C: TMenuColors;
  T: TStatusItem;
  X, W: Integer;
  HintText: ShortString;
begin
  C := GetMenuColors(Self);
  B := TDrawBuffer.Create(Size.X);
  try
    B.MoveChar(0, Ord(' '), C.Normal[0], Size.X);
    X := 0;
    T := Items;
    while Assigned(T) do
    begin
      if T.Text <> nil then
      begin
        W := CStrLen(T.Text^) + 2;
        if X + W - 2 < Size.X then
          PutLabel(B, X, T.Text^, ItemColor(C, CommandEnabled(T.Command), T = Selected));
        Inc(X, W);
      end;
      T := T.Next;
    end;
    { the hint of the help context, after a separator }
    if X < Size.X - 2 then
    begin
      HintText := Hint(HelpCtx);
      if HintText <> '' then
      begin
        B.MoveStrS(X, HintSeparator, C.Normal[0]);
        B.MoveStrS(X + 2, HintText, C.Normal[0], Size.X - X - 2);
      end;
    end;
    WriteLine(0, 0, Size.X, 1, B);
  finally
    B.Free;
  end;
end;

procedure TStatusLine.FindItems;
var
  D: TStatusDef;
begin
  Items := nil;
  D := Defs;
  while D <> nil do
  begin
    if (HelpCtx >= D.Min) and (HelpCtx <= D.Max) then
    begin
      Items := D.Items;
      Exit;
    end;
    D := D.Next;
  end;
end;

function TStatusLine.GetPalette: TPalette;
begin
  Result := TPalette.Create(MenuViewPalette, Length(MenuViewPalette));
end;

function TStatusLine.ItemMouseIsIn(Mouse: TPoint): TStatusItem;
var
  I, K: Integer;
  T: TStatusItem;
begin
  Result := nil;
  if Mouse.Y <> 0 then
    Exit;
  I := 0;
  T := Items;
  while T <> nil do
  begin
    if T.Text <> nil then
    begin
      K := I + CStrLen(T.Text^) + 2;
      if (Mouse.X >= I) and (Mouse.X < K) then
        Exit(T);
      I := K;
    end;
    T := T.Next;
  end;
end;

procedure TStatusLine.HandleEvent(var Event: TEvent);
var
  T, Under: TStatusItem;
  Key: TKey;
begin
  inherited HandleEvent(Event);
  case Event.What of
    evKeyDown:
      if Event.KeyDown.KeyCode <> kbNoKey then
      begin
        Key := EventKey(Event);
        T := Items;
        while Assigned(T) and not ((Key = T.KeyCode) and CommandEnabled(T.Command)) do
          T := T.Next;
        { the event becomes the command at once }
        if Assigned(T) then
          SetCommand(Event, T.Command);
      end;
    evMouseDown:
      begin
        { the item under the mouse is highlighted until the button is released }
        T := nil;
        repeat
          Under := ItemMouseIsIn(MakeLocal(Event.Mouse.Where));
          if Under <> T then
          begin
            DrawSelect(Under);
            T := Under;
          end;
        until not MouseEvent(Event, evMouseMove);
        if Assigned(T) and CommandEnabled(T.Command) then
        begin
          SetCommand(Event, T.Command);
          PutEvent(Event);
        end;
        ClearEvent(Event);
        DrawView;
      end;
    evBroadcast:
      if Event.Message.Command = cmCommandSetChanged then
        DrawView;
  end;
end;

function TStatusLine.Hint(AHelpCtx: Word): ShortString;
begin
  Result := '';
end;

procedure TStatusLine.Update;
var
  P: TView;
  H: Word;
begin
  P := TopView;
  if P <> nil then
    H := P.GetHelpCtx
  else
    H := hcNoContext;
  if HelpCtx <> H then
  begin
    HelpCtx := H;
    FindItems;
    DrawView;
  end;
end;

class procedure TMenuView.WriteMenu(Os: opstream; AMenu: TMenu);
var
  Tok: Byte;
  Item: TMenuItem;
  Temp: Integer;
begin
  Tok := $FF;
  Assert(AMenu <> nil);
  Item := AMenu.Items;
  while Item <> nil do
  begin
    Os.WriteByte(Tok);
    Os.WriteString(Item.Name);
    Os.WriteWord(Item.Command);
    Temp := Ord(Item.Disabled);
    Os.WriteBytes(Temp, SizeOf(Integer));
    Os.WriteWord(Item.KeyCode.Code);
    Os.WriteWord(Item.KeyCode.Mods);
    Os.WriteWord(Item.HelpCtx);
    if Item.Name <> nil then
    begin
      if Item.Command = 0 then
        WriteMenu(Os, Item.SubMenu)
      else
        Os.WriteString(Item.Param);
    end;
    Item := Item.Next;
  end;
  Tok := 0;
  Os.WriteByte(Tok);
end;

class function TMenuView.ReadMenu(Ip: ipstream): TMenu;
var
  AMenu: TMenu;
  Last: ^TMenuItem;
  Item: TMenuItem;
  Tok: Byte;
  Temp: Integer;
begin
  AMenu := TMenu.Create;
  Last := @AMenu.Items;
  Tok := Ip.ReadByte;
  while Tok <> 0 do
  begin
    Assert(Tok = $FF);
    Item := TMenuItem.Create('', TKey.Create(0), TMenu(nil));
    Last^ := Item;
    Last := @Item.Next;
    Item.Name := Ip.ReadString;
    Item.Command := Ip.ReadWord;
    Ip.ReadBytes(Temp, SizeOf(Integer));
    Item.KeyCode.Code := Ip.ReadWord;
    Item.KeyCode.Mods := Ip.ReadWord;
    Item.HelpCtx := Ip.ReadWord;
    Item.Disabled := Temp <> 0;
    if Item.Name <> nil then
    begin
      if Item.Command = 0 then
        Item.SubMenu := ReadMenu(Ip)
      else
        Item.Param := Ip.ReadString;
    end;
    Tok := Ip.ReadByte;
  end;
  Last^ := nil;
  AMenu.Deflt := AMenu.Items;
  Result := AMenu;
end;

procedure TMenuView.Write(Os: opstream);
begin
  inherited Write(Os);
  WriteMenu(Os, Menu);
end;

function TMenuView.Read(Ip: ipstream): Pointer;
begin
  inherited Read(Ip);
  Menu := ReadMenu(Ip);
  ParentMenu := nil;
  Current := nil;
  Result := Self;
end;

class function TMenuView.Build: TStreamable;
begin
  Result := TMenuView.Create(streamableInit);
end;

constructor TMenuView.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TMenuView.StreamableName: ShortString;
begin
  Result := 'TMenuView';
end;

class function TMenuBar.Build: TStreamable;
begin
  Result := TMenuBar.Create(streamableInit);
end;

constructor TMenuBar.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TMenuBar.StreamableName: ShortString;
begin
  Result := 'TMenuBar';
end;

class function TMenuBox.Build: TStreamable;
begin
  Result := TMenuBox.Create(streamableInit);
end;

constructor TMenuBox.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TMenuBox.StreamableName: ShortString;
begin
  Result := 'TMenuBox';
end;

class function TMenuPopup.Build: TStreamable;
begin
  Result := TMenuPopup.Create(streamableInit);
end;

constructor TMenuPopup.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TMenuPopup.StreamableName: ShortString;
begin
  Result := 'TMenuPopup';
end;

class procedure TStatusLine.WriteItems(Os: opstream; Ts: TStatusItem);
var
  ACount: Integer;
  T: TStatusItem;
begin
  ACount := 0;
  T := Ts;
  while T <> nil do
  begin
    Inc(ACount);
    T := T.Next;
  end;
  Os.WriteBytes(ACount, SizeOf(Integer));
  while Ts <> nil do
  begin
    Os.WriteString(Ts.Text);
    Os.WriteWord(Ts.KeyCode.Code);
    Os.WriteWord(Ts.KeyCode.Mods);
    Os.WriteWord(Ts.Command);
    Ts := Ts.Next;
  end;
end;

class procedure TStatusLine.WriteDefs(Os: opstream; Td: TStatusDef);
var
  ACount: Integer;
  T: TStatusDef;
begin
  ACount := 0;
  T := Td;
  while T <> nil do
  begin
    Inc(ACount);
    T := T.Next;
  end;
  Os.WriteBytes(ACount, SizeOf(Integer));
  while Td <> nil do
  begin
    Os.WriteWord(Td.Min);
    Os.WriteWord(Td.Max);
    WriteItems(Os, Td.Items);
    Td := Td.Next;
  end;
end;

class function TStatusLine.ReadItems(Ip: ipstream): TStatusItem;
var
  Cur, First: TStatusItem;
  Last: ^TStatusItem;
  ACount: Integer;
  T: PStr;
  Key: TKey;
  Cmd: Word;
  Text: ShortString;
begin
  First := nil;
  Last := @First;
  Ip.ReadBytes(ACount, SizeOf(Integer));
  while ACount > 0 do
  begin
    Dec(ACount);
    T := Ip.ReadString;
    { the key as WriteItems writes it: the code, then the modifiers }
    Key.Code := Ip.ReadWord;
    Key.Mods := Ip.ReadWord;
    Cmd := Ip.ReadWord;
    if T = nil then
      Text := ''
    else
      Text := T^;
    Cur := TStatusItem.Create(Text, Key, Cmd);
    Last^ := Cur;
    Last := @Cur.Next;
    DisposeStr(T);
  end;
  Last^ := nil;
  Result := First;
end;

class function TStatusLine.ReadDefs(Ip: ipstream): TStatusDef;
var
  Cur, First: TStatusDef;
  Last: ^TStatusDef;
  ACount: Integer;
  AMin, AMax: Word;
begin
  First := nil;
  Last := @First;
  Ip.ReadBytes(ACount, SizeOf(Integer));
  while ACount > 0 do
  begin
    Dec(ACount);
    AMin := Ip.ReadWord;
    AMax := Ip.ReadWord;
    Cur := TStatusDef.Create(AMin, AMax, ReadItems(Ip));
    Last^ := Cur;
    Last := @Cur.Next;
  end;
  Last^ := nil;
  Result := First;
end;

procedure TStatusLine.Write(Os: opstream);
begin
  inherited Write(Os);
  WriteDefs(Os, Defs);
end;

function TStatusLine.Read(Ip: ipstream): Pointer;
begin
  inherited Read(Ip);
  Defs := ReadDefs(Ip);
  FindItems;
  Result := Self;
end;

class function TStatusLine.Build: TStreamable;
begin
  Result := TStatusLine.Create(streamableInit);
end;

constructor TStatusLine.Create(AInit: TStreamableInit);
begin
  inherited Create(streamableInit);
end;

function TStatusLine.StreamableName: ShortString;
begin
  Result := 'TStatusLine';
end;

initialization
  RMenuView := TStreamableClass.Create('TMenuView', @TMenuView.Build);
  RMenuBar := TStreamableClass.Create('TMenuBar', @TMenuBar.Build);
  RMenuBox := TStreamableClass.Create('TMenuBox', @TMenuBox.Build);
  RMenuPopup := TStreamableClass.Create('TMenuPopup', @TMenuPopup.Build);
  RStatusLine := TStreamableClass.Create('TStatusLine', @TStatusLine.Build);
end.
