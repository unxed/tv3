program t_actions;
{$I ../src/tvdefs.inc}
uses TvGeom, TvEvents, TvKeys, TvViews, TvMenus, TvActions;
{$I testlib.inc}

const
  cmSave = 200;
  cmOpen = 201;
  cmFind = 202;

var
  I: Integer;
  M: PMenuItem;
  S: PStatusItem;
  E: TEvent;

begin
  Check(ActionCount = 0, 'no actions at first');
  RegisterAction('file.save', '~S~ave', cmSave, kbF2, 5);
  RegisterAction('file.open', '~O~pen', cmOpen, kbF3);
  RegisterAction('edit.find', '~F~ind', cmFind, kbNoKey);
  Check(ActionCount = 3, 'three actions');
  Check(FindAction('FILE.SAVE') = 0, 'the name is found, case does not matter');
  Check(FindAction('file.nothing') = -1, 'an unknown name');
  Check(FindActionByCommand(cmOpen) = 1, 'found by command');
  Check(FindActionByCommand(999) = -1, 'an unknown command');
  Check((ActionAt(0).Caption = '~S~ave') and (ActionAt(0).Key = kbF2) and (ActionAt(0).HelpCtx = 5), 'the fields of an action');
  Check(ActionKeyText(0) = 'F2', 'the key as text');

  { a menu item and a status line item come from the action }
  M := NewActionItem('file.save', NewActionItem('missing', nil));
  Check((M <> nil) and (M^.Command = cmSave) and KeyEq(M^.KeyCode, KeyMake(kbF2)) and (M^.Next = nil), 'NewActionItem: the command and the key of the action; an unknown name adds nothing');
  Check(M^.Param^ = 'F2', '... and the key text is shown');
  DisposeMenu(NewMenu(M));
  S := NewActionStatusKey('~F3~ Open', 'file.open', nil);
  Check((S <> nil) and (S^.Command = cmOpen) and KeyEq(S^.KeyCode, KeyMake(kbF3)), 'NewActionStatusKey');
  Dispose(S);

  { a key becomes the command }
  MakeKeyEvent(E, kbF3, 0);
  Check(FindActionByKey(E) = 1, 'the action of a key');
  Check(ActionKeyToCommand(E) and (E.What = evCommand) and (E.Message.Command = cmOpen), 'a key of an action becomes its command');
  MakeKeyEvent(E, kbF9, 0);
  Check(not ActionKeyToCommand(E) and (E.What = evKeyDown), 'another key stays a key');

  { rebinding }
  Check(BindActionKey('file.open', kbF4), 'a key is rebound');
  MakeKeyEvent(E, kbF3, 0);
  Check(FindActionByKey(E) = -1, 'the old key is free');
  MakeKeyEvent(E, kbF4, 0);
  Check(FindActionByKey(E) = 1, 'the new key works');
  Check(not BindActionKey('nothing', kbF4), 'an unknown action cannot be bound');
  ResetActionKeys;
  Check(ActionAt(1).Key = kbF3, 'the declared keys come back');

  { two actions on one key }
  Check(ActionKeyConflicts = '', 'no conflicts');
  BindActionKey('edit.find', kbCtrlF3);
  Check(ActionKeyConflicts = '', 'a key of its own');
  BindActionKey('edit.find', kbF2);
  Check(ActionKeyConflicts = 'F2: file.save, edit.find'#10, 'two actions on F2 are reported');
  { redeclaring a name replaces the action }
  I := RegisterAction('edit.find', '~F~ind', cmFind, kbF5);
  Check((I = 2) and (ActionCount = 3) and (ActionKeyConflicts = ''), 'a redeclared action replaces the old one');
  ClearActions;
  Check(ActionCount = 0, 'ClearActions');
  Finish;
end.
