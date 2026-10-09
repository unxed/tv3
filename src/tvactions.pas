{ TvActions: the action registry. An action is declared once: its name, its command, its caption in the menu, its key and its help context. The menus, the
  status line, the dispatch of keys that have no menu item and the check for two actions on one key all read the same table (one action = a menu item + a command + a key).

  MIT.

    RegisterAction('file.save', '~S~ave', cmSave, kbF2);
    ...
    Menu := NewMenu(NewActionItem('file.open', NewActionItem('file.save', nil)));
    Status := NewStatusDef(0, $FFFF, NewActionStatusKey('~F2~ Save', 'file.save', nil), nil);
    if ActionKeyToCommand(Event) then ...      (a key with no menu item becomes the command)

  A key may be rebound (BindActionKey, a user's key file); the menu items and the dispatch made after that use the new key. }
unit TvActions;

{$I tvdefs.inc}

interface

uses
  TvKeys, TvEvents, TvViews, TvMenus;

type
  TAction = record
    Name: ShortString;      { 'file.save': the identity (macros, key files, tests); case does not matter }
    Caption: ShortString;   { the text of the menu item, with the ~hot~ letter }
    Command: Word;
    Key: Word;              { the key code now in force, kbNoKey for none }
    DefaultKey: Word;
    HelpCtx: Word;
  end;

{ Adds an action and returns its number; a name that is there already replaces the action (so an application may redeclare a command of a library). }
function RegisterAction(const AName, ACaption: ShortString; ACommand: Word; AKey: Word = kbNoKey; AHelpCtx: Word = hcNoContext): Integer;
function ActionCount: Integer;
function ActionAt(Index: Integer): TAction;
{ -1 when there is no such action }
function FindAction(const AName: ShortString): Integer;
function FindActionByCommand(ACommand: Word): Integer;
{ the action that is on the key of the event (the keys are compared as TKey) }
function FindActionByKey(const Event: TEvent): Integer;
{ Changes the key of an action (kbNoKey: no key); False when there is no such action. }
function BindActionKey(const AName: ShortString; AKey: Word): Boolean;
{ Back to the declared keys. }
procedure ResetActionKeys;
{ The key of an action as text ("Ctrl+S"). }
function ActionKeyText(Index: Integer): AnsiString;
{ A menu item of the action (the caption, the key shown, the command), linked before Next. A name that is not declared gives Next. }
function NewActionItem(const AName: ShortString; Next: PMenuItem): PMenuItem;
{ An item of the status line: the text is given, the key and the command come from the action. }
function NewActionStatusKey(const AText, AName: ShortString; ANext: PStatusItem): PStatusItem;
{ A key event whose key belongs to an action becomes the command of that action (evCommand, the event is changed); True if it did. }
function ActionKeyToCommand(var Event: TEvent): Boolean;
{ The keys that are on two actions or more, one line per key ("Ctrl+S: file.save, edit.search"); an empty text when there are none. }
function ActionKeyConflicts: AnsiString;
{ Removes all actions. }
procedure ClearActions;
{ The key of the window switcher (TvApp.TDeskTop.SwitcherStep: the list of windows while Ctrl is held) is the key of an action, so it can be declared and rebound
  like the others: RegisterAction('window.switch', '~S~witch', cmNext, kbCtrlTab) and UseActionsForSwitcher. The key with Shift added walks backwards.
  ActionKeyToCommand leaves that action to the desktop (it needs the modifiers of the key, a command has none). }
procedure UseActionsForSwitcher(const AName: ShortString = 'window.switch');

implementation

uses
  SysUtils, TvKeyName, TvApp;

var
  Actions: array of TAction;
  Count: Integer = 0;
  SwitcherAction: ShortString = '';

function UpName(const S: ShortString): ShortString;
begin
  Result := UpperCase(S);
end;

function FindAction(const AName: ShortString): Integer;
var
  I: Integer;
  U: ShortString;
begin
  U := UpName(AName);
  for I := 0 to Count - 1 do
    if UpName(Actions[I].Name) = U then
      Exit(I);
  Result := -1;
end;

function RegisterAction(const AName, ACaption: ShortString; ACommand: Word; AKey: Word; AHelpCtx: Word): Integer;
begin
  Result := FindAction(AName);
  if Result < 0 then
  begin
    if Count >= Length(Actions) then
      SetLength(Actions, Count + 32);
    Result := Count;
    Inc(Count);
  end;
  with Actions[Result] do
  begin
    Name := AName;
    Caption := ACaption;
    Command := ACommand;
    Key := AKey;
    DefaultKey := AKey;
    HelpCtx := AHelpCtx;
  end;
end;

function ActionCount: Integer;
begin
  Result := Count;
end;

function ActionAt(Index: Integer): TAction;
begin
  Result := Actions[Index];
end;

function FindActionByCommand(ACommand: Word): Integer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Actions[I].Command = ACommand then
      Exit(I);
  Result := -1;
end;

function FindActionByKey(const Event: TEvent): Integer;
var
  I: Integer;
  K: TKey;
begin
  if Event.What <> evKeyDown then
    Exit(-1);
  K := EventKey(Event);
  for I := 0 to Count - 1 do
    if (Actions[I].Key <> kbNoKey) and (TKey.Create(Actions[I].Key) = K) then
      Exit(I);
  Result := -1;
end;

function BindActionKey(const AName: ShortString; AKey: Word): Boolean;
var
  I: Integer;
begin
  I := FindAction(AName);
  Result := I >= 0;
  if Result then
    Actions[I].Key := AKey;
end;

procedure ResetActionKeys;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    Actions[I].Key := Actions[I].DefaultKey;
end;

function ActionKeyText(Index: Integer): AnsiString;
begin
  Result := KeyCodeToStr(Actions[Index].Key);
end;

function NewActionItem(const AName: ShortString; Next: PMenuItem): PMenuItem;
var
  I: Integer;
begin
  I := FindAction(AName);
  if I < 0 then
    Exit(Next);
  with Actions[I] do
    Result := NewItem(Caption, ActionKeyText(I), Key, Command, HelpCtx, Next);
end;

function NewActionStatusKey(const AText, AName: ShortString; ANext: PStatusItem): PStatusItem;
var
  I: Integer;
begin
  I := FindAction(AName);
  if I < 0 then
    Exit(ANext);
  Result := NewStatusKey(AText, Actions[I].Key, Actions[I].Command, ANext);
end;

function ActionKeyToCommand(var Event: TEvent): Boolean;
var
  I: Integer;
begin
  I := FindActionByKey(Event);
  if (I >= 0) and (SwitcherAction <> '') and (UpName(Actions[I].Name) = SwitcherAction) then
    I := -1;                                  { the desktop takes this key itself (UseActionsForSwitcher) }
  Result := I >= 0;
  if Result then
  begin
    Event.What := evCommand;
    Event.Message.Command := Actions[I].Command;
    Event.Message.InfoPtr := nil;
  end;
end;

function ActionKeyConflicts: AnsiString;
var
  I, J: Integer;
  Line: AnsiString;
  Seen: Boolean;
begin
  Result := '';
  for I := 0 to Count - 1 do
  begin
    if Actions[I].Key = kbNoKey then
      Continue;
    { the first action of a key reports it }
    Seen := False;
    for J := 0 to I - 1 do
      if (Actions[J].Key <> kbNoKey) and (TKey.Create(Actions[J].Key) = TKey.Create(Actions[I].Key)) then
        Seen := True;
    if Seen then
      Continue;
    Line := '';
    for J := I + 1 to Count - 1 do
      if (Actions[J].Key <> kbNoKey) and (TKey.Create(Actions[J].Key) = TKey.Create(Actions[I].Key)) then
      begin
        if Line = '' then
          Line := Actions[I].Name;
        Line := Line + ', ' + Actions[J].Name;
      end;
    if Line <> '' then
      Result := Result + ActionKeyText(I) + ': ' + Line + #10;
  end;
end;

procedure ClearActions;
begin
  SetLength(Actions, 0);
  Count := 0;
end;

{ the key of the switcher: the key of the action, with or without Shift (Shift is the direction) }
function ActionSwitcherKey(const Event: TEvent; out Backward: Boolean): Boolean;
var
  I: Integer;
  K, A: TKey;
begin
  Backward := False;
  Result := False;
  I := FindAction(SwitcherAction);
  if (I < 0) or (Actions[I].Key = kbNoKey) or (Event.What <> evKeyDown) then
    Exit;
  A := TKey.Create(Actions[I].Key);
  K := TKey.Create(Event.KeyDown.KeyCode, Event.KeyDown.ControlKeyState and not kbShift);
  Result := (K = A);
  Backward := Result and ((Event.KeyDown.ControlKeyState and kbShift) <> 0);
end;

procedure UseActionsForSwitcher(const AName: ShortString);
begin
  SwitcherAction := UpName(AName);
  OnSwitcherKey := @ActionSwitcherKey;
end;

end.
