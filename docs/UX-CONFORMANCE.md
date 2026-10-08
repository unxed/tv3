# Conformance to the navigation guidelines of vtui

The rules are those of [`UX_GUIDELINES.md`](https://github.com/unxed/vtui/blob/main/UX_GUIDELINES.md) of vtui (the word rules of Ctrl+Left and Ctrl+Right are in its
`WORDNAV.md`). This file records, rule by rule, what tv3 does, what the projects built on it do, and how that was found out. It replaces the shorter
`UX-CONFORMANCE.md` of the repository root.

State: tv3 `claude/nifty-rubin-7v0d9z` after task 6 (rows 0.2, 0.3, M.7, X.4 closed, L.2 and E.7 made optional), tve at the same branch, fpide (`sp/fpide`) at the same branch (its column is as it was at task 5 and is updated separately). dn (DOS Navigator) is **not covered**: it is
edited elsewhere and will be audited later; it uses tv3 through its own pin, so it gets none of the changes below until the pin is moved.

Verdicts: **conformant** (the rule holds everywhere it applies), **gap** (it does not hold somewhere, or only partly; the cell says where), **n/a** (the rule
is about a component that does not exist in these projects). A rule is not called conformant for a project unless it was checked there.

How checked (the last column):

* `T:name` a unit test in `tv3/tests/` (`t_ux` is the test of these guidelines, `t_esc` runs every stock modal window with Esc as its only input).
* `P:tvdemo` `tv3/tests/pty/test_tvdemo.py`: the demo program in a terminal emulator (`tools/pty_screen.py` of dn), keys and mouse reports are sent, the screen is read.
* `P:tve` `tve/tests/pty/test_app.py`: the same for the tve program.
* `P:switcher`, `P:held` `tv3/tests/pty/test_switcher.py` and `test_held.py`: tvdemo in the emulator of a terminal that tells key releases (win32 input mode, the keyboard protocol of Kitty) and repeats.

All of `T:` and `P:` run in CI (`.github/workflows/ci.yml`; locally `tools/test.sh`, `tools/pty-test.sh`); tve has `tools/test.sh` and its own workflow.
* `A:ux` the section `ux` of `sp/fpide/tests/accept/test_functions.py` (fpide in a tmux terminal); `A:esc` is `test_esc_sweep.py` next to it (every dialog item of the menu bar, one Esc).
* `C` read in the code only (the file is named); nothing was run.

## The table

Abbreviations: `TCluster` etc. are in `tv3/src/tv<name>.pas`. "fixed" means the gap was closed in this task.

| # | Rule of the guidelines | tv3 | tve | fpide | Verdict | Checked by |
|---|---|---|---|---|---|---|
| 0.1 | `Ctrl+Tab` / `Ctrl+Shift+Tab` cycle forward / backward through the screens | fixed: `TDeskTop.HandleEvent` (tvapp.pas) turns the key into the next / previous window when no view took it (`UxCtrlTab`). tv3 has windows, no separate "screens" | the tve program has one window; the editor view leaves the key alone | fixed: works for the editor windows (a tabbed dialog keeps its own Ctrl+Tab) | conformant (windows) | T:t_ux, P:tvdemo, A:ux |
| 0.2 | A switcher overlay in the centre lists the titles | fixed where the terminal tells key releases (win32 input mode; a terminal that answers the query of the keyboard protocol of Kitty): `Ctrl+Tab` opens a list of the windows (`TDeskTop.SwitcherStep`, `TSwitcherBox`), more presses walk it, `Ctrl+Shift+Tab` goes the other way, `Esc` cancels. Without releases there is no list (see 0.3). Switch `UxSwitcher` | one window | not changed (column of fpide: see the top) | conformant (needs key releases) | T:t_switch, P:switcher |
| 0.3 | The switch is committed when `Ctrl` is released | fixed with the list: `TvSys.KeyUpAvailable` tells that the terminal reports releases (win32 input mode on, or the answer to `ESC [ ? u`); the list asks for the release of the modifiers only while it is open (`TvSys.KeyUpForApp`: flag 2 and 8 of Kitty, the releases of Ctrl in the win32 mode, parsed by `TvTermIO` as `evKeyUp` with `KeyCode = 0`). Where no releases come (xterm, tmux, the Linux console, Windows console backend) the switch is at once, as before; a list that gets no release for `SwitcherTimeoutMs` (8 s) commits itself. The key can be an action: `RegisterAction('window.switch', ..., kbCtrlTab)` + `UseActionsForSwitcher` (`OnSwitcherKey`), tvdemo does it | same | not changed | conformant (needs key releases) | T:t_switch, T:t_termio, P:switcher |
| 1.1 | `Tab` / `Shift+Tab` move to the next / previous focusable element in logical order | `TWindow.HandleEvent`: `FocusNext` | in the editor `Tab` is text (n/a); dialogs are tv3's | dialogs: tv3's; editor `Tab` is text | conformant | T:t_ux |
| 1.2 | The cycle wraps | yes | same | same | conformant | T:t_ux |
| 2.1 | Arrow keys navigate inside a component | yes | the editor view moves the caret | same | conformant | T:t_ux, C |
| 2.2 | Arrows leave a group / list only at its boundary (`Up`/`Left` on the first item to the previous element, `Down`/`Right` on the last to the next); elsewhere the key is swallowed | groups: `TCluster.UxClusterKey`; lists: `TListViewer.HandleEvent` (`Up`, `Down`; fixed: `Left`, `Right` also, one or several columns). In the middle of a one-column list `Left`/`Right` are not taken but bubble (the dialog ignores them). Applied to a button and, vertically, to a one-line edit field (fixed, `UxArrowPass`) by analogy: the text has no such rule, far2l does it. Switch `UxNavBoundary` | n/a (the dialogs are tv3's) | tv3's dialogs; `A:ux` looks at the Find dialog | conformant | T:t_ux, A:ux |
| 3.1 | `Alt+<char>` activates; the label marks the letter | `~S~ave` (the tilde of Turbo Vision, not the ampersand); in any keyboard layout by `TvXlat` | same | same | conformant | T:t_xlat, T:t_dialog, C |
| 3.2 | In a dialog with no text field focused a plain letter activates the hot key | `TButton` / `TCluster` in the post-process phase | same | same | conformant | T:t_ux |
| D.1 | `Enter` presses the default button (marked, else the first that can act), also when an edit field is focused | marked default: Turbo Vision; fixed: with no marked default the first enabled button is pressed (`UxEnterButton`, `TDialog.HandleEvent`) | n/a | dialogs of fpide are tv3's | conformant | T:t_ux, T:t_dialog |
| D.2 | `Esc` closes the window or dialog | `TDialog.HandleEvent` sends `cmCancel`; stock windows: message box, input box, file dialog, directory dialog, color dialog, history list | the Find dialog closes (checked by hand); the editor window does not close on `Esc` (it is text, n/a) | all 25 dialog items of the menu bar close with one `Esc` | conformant | T:t_esc, T:t_hist, A:esc, P:tve |
| D.3 | `F1` opens the help of the focused element | the chain exists (`GetHelpCtx`, `TCluster` adds the item number) and `THelpWindow`; binding `F1` is the application's job and the demo has no help | no help | `F1` on the desktop opens the help window; fixed: in a modal dialog `F1` (the command or the key) is taken in `TIDEApp.GetEvent` and opens the help window modally above the dialog (`HelpModal` in fphelp.pas, Esc closes it and the dialog is still there) | conformant (fpide); gap in tv3 (no help in the demo) | A:ux |
| D.4 | Dragging the top border moves a window; dragging the bottom right corner resizes it | windows: yes. Dialogs move (`wfMove`) but have no `wfGrow` (fixed layouts) | the program window is zoomed | same as tv3 | gap (dialogs are not resizable) | P:tvdemo (window), C (dialog flags) |
| G.1 | Arrows move the cursor of a group, the selection does not change | fixed: `TRadioButtons.MovedTo` no longer selects in a dialog (`UxNavBoundary`); check boxes always did | the Find / Replace dialogs have check boxes only | fixed: the Find dialog (Scope, Direction, Origin) | conformant | T:t_ux, A:ux |
| G.2a | `Space` toggles / selects the item under the cursor | yes | yes | yes | conformant | T:t_ux, A:ux |
| G.2b | `Enter` toggles / selects the item under the cursor | `Enter` is the default button of the dialog (rule D.1 and this rule contradict each other in a dialog with a default button); see "Conflicts" | same | same | gap | C |
| G.3 | Snake navigation in multi-column groups | `TCluster.UxClusterKey` | n/a | n/a | conformant | T:t_ux |
| L.1 | `Up`/`Down`, `PgUp`/`PgDn` in lists | yes | n/a | yes | conformant | T:t_list |
| L.2 | `Home` / `End` in lists | `Home` goes to the first row **shown**, `End` to the last row shown (Turbo Vision); `Ctrl+PgUp` / `Ctrl+PgDn` go to the first / last item. The guideline behaviour is there as a switch, **off** by default: `UxListHomeEnd := True` (`TvList`) | n/a | same | gap (recorded in "Conflicts", kept; switch available) | T:t_list |
| L.3 | `Up` on the first item and `Down` on the last pass the focus on | see 2.2 | n/a | same | conformant | T:t_ux |
| L.4 | `Enter` or double click performs the action of the item | double click selects (`cmListItemSelected`); `Enter` reaches the default button of the dialog | n/a | same | conformant | T:t_list, T:t_fdlg |
| L.5 | `ListBox` is a one-column `Table` and behaves the same | tv3 has `TListBox` (`TListViewer`) and no table; every list behaves alike | n/a | n/a | conformant | C |
| E.1 | `Left`/`Right` by one character, `Home`/`End` to the line ends | `TInputLine` (by characters, UTF-8 aware) | the editor view | same | conformant | T:t_input |
| E.2 | `Ctrl+Left` / `Ctrl+Right` by the far2l rules (three classes: space, divider, word) | fixed: `TvWordNav`, used by `TInputLine` (`UxWordNav`) | the editor has its own word definition, see E.7 | input fields: tv3's | conformant (input fields) | T:t_wordnav, T:t_input |
| E.3 | Adding `Shift` selects by the finer rule set of the input fields | fixed: the same unit (`Fine`) | n/a | input fields: tv3's | conformant (input fields) | T:t_wordnav, T:t_input |
| E.4 | `Shift` + a navigation key creates / extends a selection | yes | yes | yes | conformant | T:t_input, A:edit |
| E.5 | `Ctrl+C` and `Ctrl+Ins` copy to the clipboard | fixed: `TInputLine` copies on both keys itself (before it needed a hot key bound by the application) | `Ctrl+Ins` yes; `Ctrl+C` is WordStar there ("Conflicts") | input fields: tv3's; editor: `Ctrl+Ins` | conformant (input fields) | T:t_input |
| E.6 | A field opened with an unchanged value clears when typing starts, unless a navigation key came first | the whole text is selected on focus and the first typed character replaces it; a navigation key drops the selection | n/a | same | conformant | T:t_input |
| E.7 | Word movement of the multi-line editor follows the same rules (WORDNAV.md, editor part) | n/a | the default is the word definition of the editor (`MoveWordLeft/Right`, families A and B). The rules of WORDNAV.md are there as an optional key map: commands `FarWordLeft`, `FarWordRight`, `SelFarWordLeft`, `SelFarWordRight` (`TTveEditor.MoveFarWordLeft/Right`: three classes, a stop at the line ends, the coarse rule with Shift), `TveFarWordsKeymapText`, `tve --words=far2l`. Not bound by default. Word wrap is not taken into account (a jump stops at the end of the logical line, not of the screen row) | same editor | gap (recorded in "Conflicts", kept; the map is available) | tve: T:t_editor, T:t_cmds, T:t_wheel, P:tve |
| C.1 | `Ctrl+Down` or a click on the arrow opens the list of a combo box | `THistory` (an edit field and a list): `Ctrl+Down`, `Down` and a click on the arrow | history in the dialogs | history in the dialogs | conformant | T:t_hist, T:t_ux |
| C.2 | A chosen item fills the field and the focus goes back to it | `THistory.HandleEvent` | same | same | conformant | T:t_hist |
| C.3 | `DropdownOnly` mode | there is no such component | n/a | n/a | n/a | C |
| P.1 | File panels (`Left`/`Right` by pages, `Ctrl+Enter`) | f4 only | n/a | n/a | n/a | C |
| M.1 | The menu bar is activated by `F9` or `Alt+<char>` | `Alt+char`: yes. The bar does not bind a key itself; the demo binds `F10` only | fixed: the program binds `F9` and `F10` | `Alt+char` yes; `F10` yes; `F9` is Make ("Conflicts") | gap | P:tvdemo, P:tve, A:ux |
| M.2 | `Left`/`Right` cycle the items of an active bar and open their menus | fixed: opens the drop-down of the item moved to (`UxMenuAutoOpen`); before, only with a drop-down already open | same (tv3's bar) | fixed in the three copies of `Execute` in wviews.pas | conformant | T:t_menus, P:tvdemo, A:ux |
| M.3 | `Down` or `Enter` opens the menu of the item | yes | yes | yes | conformant | T:t_menus |
| M.4 | `Esc` closes the open drop-down and keeps the bar; the second `Esc` leaves the bar | fixed: `TMenuView.Execute` (`UxMenuEsc`, `SubClosedByEsc`) | same | fixed in wviews.pas | conformant | T:t_menus, P:tvdemo, P:tve, A:ux |
| M.5 | In a drop-down `Left`/`Right` close it and open the neighbour | yes | yes | yes | conformant | T:t_menus, P:tvdemo |
| M.6 | `Up` on the first / `Down` on the last item wrap around | yes | yes | yes | conformant | T:t_menus |
| M.7 | Held arrows stop at the end with `SetMenuLoopScroll(false)` | fixed where the terminal tells auto repeats: a held `Up` / `Down` stops at the first / last item of a menu and a held `Left` / `Right` at the ends of the bar, a single press still wraps (`UxMenuHeldStop`). The repeat is `TEvent.KeyFlags and kfRepeat`: the win32 input mode and the far2l terminal (a press again with no release), the keyboard protocol of Kitty (event type 2; the menu asks for it with `TvSys.KeyRepeatInfo` while it runs). Elsewhere a held arrow wraps as before. Only menus (lists pass the focus on at the ends, rule L.3) | n/a | n/a | conformant (needs auto repeat information) | T:t_menus, T:t_termio, P:held |
| M.8 | A stand-alone menu (context menu) passes the focus on at its boundary | the popup menu is modal and has no neighbours: it wraps | n/a | n/a | n/a | C |
| X.1 | Left click focuses / activates | Turbo Vision (`ofFirstClick`) | yes | yes | conformant | T:t_dialog, A:mouse |
| X.2 | Double click is `Enter` | lists: yes; the file dialog turns it into `cmOK` | n/a | yes | conformant | T:t_list, T:t_fdlg, A:mouse |
| X.3 | Right click for secondary actions in file panels | f4 only | n/a | n/a | n/a | C |
| X.4 | The wheel scrolls the component under the cursor, whatever has the focus | fixed: `TGroup.HandleEvent` routes `evMouseWheel` by position like a click (`UxWheelUnderCursor`, on by default; off gives the old routing to every view). The view under the pointer takes it; if it does not, the scroll bars of the window under the pointer do (`TWindow.HandleEvent`: three steps, also the hidden bars of a window that is not active). A list or a scroller in a window with its bar scrolls with it; a view that handles the wheel itself (the terminal view, `TTveView`, views of applications) gets it only under the pointer | `TTveView` scrolls itself, now only the one under the pointer | not changed (measured before: the wheel over an unfocused window scrolls the focused one) | conformant (tv3, tve) | T:t_wheel (tv3 and tve), P:tvdemo |
| R.1 | One action = a menu item + a command + a key, declared once (the action registry; asked for by the owner, not in the text of the guidelines) | fixed: `TvActions` (name, caption, command, key, help context; menu item and status key built from it; key to command; rebinding; report of two actions on one key). Used by tvdemo | used by the tve program; the editor commands keep `TveCmds` (names, key maps), which is the same idea for the editor | fixed: the 109 actions of the menu bar and the keys of the status line are registered once (`RegisterIDEActions` in fpide.pas) and the menu items (`IdeItem`) and status keys (`NewActionStatusKey`) are built from them; `fp --list-actions` prints the table and the keys that are on two actions (none). Not moved: context-specific status keys (help window, messages window), the editor's own keys (tve), local menus | conformant for tv3, tve and fpide; gap in dn (not covered) | T:t_actions, A:ux |

### Count

46 rows: **36 conformant, 6 gap, 4 n/a.** The gaps: D.4, G.2b, L.2, E.7, M.1, and D.3 in tv3 (the demo has no help); R.1 is open in dn only. Rows 0.2, 0.3 and M.7 are conformant only where the terminal tells key releases or
auto repeats (a limit of the terminal, not of the library); L.2 and E.7 exist as optional behaviour that is not the default.
Rows closed by this task (they were gaps or not audited before): 0.1, 2.2 (the boundary rule for rows and buttons and one-line fields), D.1, G.1, E.2, E.3,
E.5, M.2, M.4; R.1 is closed in tv3 and tve only. Closed by task 6: 0.2, 0.3, M.7, X.4. Closed in fpide afterwards: D.3, R.1.

## Conflicts that need a decision of the owner

Nothing below was changed. In each case the guideline and a documented behaviour of a project disagree.

1. **G.2b: `Enter` on a check box or radio button.** The guidelines say `Enter` toggles it; they also say `Enter` runs the default button even when an
   edit field has the focus. In a dialog with a default button both cannot hold. Kept: `Enter` is the default button (Turbo Vision, Borland IDE, Far).
   A middle way is possible (`Enter` toggles only in a dialog that has no default button) and cheap, but it makes `Enter` unpredictable.
2. **M.1: `F9` activates the menu bar.** In fpide `F9` is Compile > Make (Borland / Free Pascal IDE muscle memory, in the status line and in the
   menu). `F10` and `Alt+letter` open the bar. tve has no `F9` use and got both keys; tvdemo only has `F10`.
3. **L.2: `Home` / `End` in lists.** Turbo Vision lists go to the top / bottom of the visible page and use `Ctrl+PgUp` / `Ctrl+PgDn` for the first / last item;
   the guidelines call them "standard list navigation" without saying which. Changing it moves the cursor in every list of fpide and dn.
4. **E.7 / E.5: the multi-line editor.** tve has two key families (A: DN, B: Borland / Free Pascal IDE) and a configurable word definition; its `Ctrl+C` is
   WordStar (page down) in both, `Ctrl+Ins` copies. The far2l word rules are a different definition. The input fields (`TInputLine`) follow the guidelines.
5. **C.1: `Down` in an edit field that has a history.** Turbo Vision opens the list on `Down`; the guidelines (and the fix of rule 2.2) would pass the
   focus on. Kept: such a field keeps `Down` (`TInputLine.KeepVertical`, set by `THistory`); `Ctrl+Down` opens the list as well.
6. **D.4: resizing dialogs.** Dialogs have fixed layouts; making them resizable needs a layout (grow modes) in every dialog of fpide and dn.

## What the changes of this task are (switches)

All behaviour changes are switches of tv3 with the guideline value on by default; `False` gives the old Turbo Vision behaviour, used by the older tests.

| Switch | Unit | Rule |
|---|---|---|
| `UxNavBoundary` | TvDialog | 2.2, G.1 (old) |
| `UxEnterButton` | TvDialog | D.1 |
| `UxCtrlTab` | TvApp | 0.1 |
| `UxMenuEsc` | TvMenus | M.4 |
| `UxMenuAutoOpen` | TvMenus | M.2 |
| `UxWordNav` | TvWordNav | E.2, E.3 |
| `TInputLine.KeepVertical` | TvInput | 2.2 vs C.1 |
| `UxWheelUnderCursor` (True) | TvViews | X.4 |
| `UxSwitcher` (True), `SwitcherTimeoutMs`, `OnSwitcherKey` (nil: Ctrl+Tab), `TvSys.KeyUpAvailable` / `KeyUpForApp` | TvApp, TvSys | 0.2, 0.3 |
| `UxMenuHeldStop` (True), `TvSys.KeyRepeatInfo`, `TEvent.KeyFlags` | TvMenus, TvSys, TvEvents | M.7 |
| `UxListHomeEnd` (**False**) | TvList | L.2 |
| `FarWordLeft` ... `TveFarWordsKeymapText`, `tve --words=far2l` (not default) | tve: TveCmds, TveEditor | E.7 |

## Not done, and why

* 0.2, 0.3, M.7 without terminal support: the Windows console backend (`TvTermOsWin`) was not changed (it could report releases and repeats from the console records, but
  that code cannot be built or run here); xterm, tmux, the Linux console and the like tell neither releases nor repeats. The immediate switch and the wrapping arrow stay there.
  A terminal that speaks the keyboard protocol of Kitty but does not answer `ESC [ ? u` is treated as having no releases. Real terminals (kitty, foot, WezTerm, Windows Terminal)
  were not tried: the behaviour is checked against the emulator of the pty tests and the parser tests, which send what the specification says.
* D.3 in fpide is done (see the table). R.1: dn's declarations of commands are still a large hand-written table; moving them to `TvActions` is a task of its own (fpide's move shows how: register the actions, build the items from them).
* X.4 in dn and fpide: not looked at (other agents work there). Their views that handle the wheel themselves keep getting it, now only under the pointer; their windows with
  scroll bars scroll under the pointer through `TWindow`. `UxWheelUnderCursor := False` restores the old routing.
* E.7 by default and L.2 by default: the decisions of the owner are kept (see "Conflicts"); the optional behaviour is there for whoever wants it.
