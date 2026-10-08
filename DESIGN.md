# tv: port of magiblot/tvision to Free Pascal

Source: https://github.com/magiblot/tvision, commit `b4831e2` (2026-09-18). We port
the library (`source/tvision`, `source/platform`, `include/tvision` without `compat/`);
`examples/` is not ported (see `research/2026-10-01-magiblot-provenance.md`). License:
`COPYRIGHT.magiblot` (Borland's disclaimer of warranties plus MIT) — the port preserves it.

## Porting rules

1. **A unit header** names which files and which commit of magiblot the unit was
   ported from. There is no new code without a source in `tv/`, except the platform backends,
   which are marked `{ original }`.
2. **Class model — `class` (tv3):** `constructor Create`, `destructor Destroy; override`,
   `virtual`/`override`, `TFoo.Create(...)`, `P.Free`. The RTL root type is not duplicated.
   The aliases `PFoo = TFoo` are kept as references to classes, so that code declaring
   `P: PView` changes minimally. The compiler zeroes instance fields itself. The stream
   registry works through the root class `TStreamable`, from which all
   registered classes inherit.
3. **Names — as in Pascal TV** (`TView.HandleEvent`, `TRect.Assign`, `cmQuit`, `kbEnter`):
   method and constant names are the interface that DN uses. Methods that Pascal TV does not
   have (the Unicode ones from magiblot) are named as in magiblot, with a capital first letter.
4. **Integers:** `Integer` is 32 bits (`objfpc` mode), `Int32` explicitly where the width matters.
   There are no 16-bit assumptions.
5. **Strings:** the public API is `ShortString` (as in DN), internally the text is UTF-8 bytes.
   Invalid UTF-8 is treated as characters of a single-byte code page
   (the `TvCodePage` setting, 866 by default); this lets DN work without rework.
6. **Compilation mode:** `{$mode objfpc}{$H-}{$modeswitch advancedrecords}`, shared file
   `tv/src/tvdefs.inc`. Units do not depend on the platform, except `tv/src/platform/*`.
7. **No assembler**, except possibly in the DOS backend.
8. **Tests:** each unit has a program in `tv/tests/t_<unit>.pas` (the file name is no longer than 8 characters: longer is not possible under DOS without LFN), which prints
   `PASS`/`FAIL` and `ALL OK` at the end. CI runs them on Linux (natively) and under DOS
   (go32v2, DOSBox-X).

## Unit order (from the leaves to the root)

| No. | Unit | From | Status |
|---|---|---|---|
| 1 | `TvGeom` — `TPoint`, `TRect` | geometry header | done, CI green (Linux and DOS) |
| 2a | `TvColors` — BIOS/RGB/xterm colors, attribute (64 bits), quantization to 16 and 256 colors | `colors.h`, `source/platform/colors.cpp` | done |
| 2b | `TvUtf8` — UTF-8 decoding/encoding, character width | `internal/utf8.h`; width — tables from the Unicode database (`tools/gen-width.py`) | done |
| 2c | `TvCell` — `TScreenCharacter`, `TScreenCell` (a cell with UTF-8) | `scrncell.h` | done |
| 2c2 | `TvGlyphs` — the frame, shade, block and arrow characters by name (Unicode code points `glLightH`, `glDblDR`, ...; `GlyphByte`, `GlyphChar`, `GlyphStr`, `SetCellGlyph`; the Char constants `gc*` for typed constants); `TDrawBuffer.MoveGlyph`/`PutGlyph` | own (the C++ original has the CP437 bytes in the sources) | done; the frames, shadows, scroll bars and icons of the views use it, test `t_glyphs` |
| 2d | `TvCodePg`, `TvText` — code pages; `TText`: Next, Width, Prev, DrawOne, DrawStr, Scroll | `ttext.h`, `source/platform/{ttext,codepage}.cpp` | done (without `equalsIgnoreCase`, UTF-32 and `drawStrEx` with a callback) |
| 3a | `TvKeys` — key codes `kb*`, modifiers, `TKey` (normalization of key combinations) | `tkeys.h`, `tkey.cpp` | done |
| 3b | `TvEvents` — the `TEvent` record, event codes and masks | `system.h` (events; the queue, mouse and screen are in the backends) | done; the `cm*` command codes are in `TvViews` |
| 4 | `TvDrawBuf` — `TDrawBuffer`: MoveChar, MoveStr, MoveCStr, MoveBuf | `drawbuf.h`, `drivers.cpp` | done |
| 5a | `TvScreen` — screen size, screen buffer, backend hooks (write, caret) | `TScreen`, `THardwareInfo` (the screen part) | done |
| 5b | `TvViews` — constants, `TCommandSet`, palettes, `TView`, `TGroup`, the output engine and the visibility check | `views.h`, `tview.cpp`, `tgroup.cpp`, `tvwrite.cpp`, `tvexposd.cpp`, `tvcursor.cpp`, etc. | done (without streams and timers) |
| 5c | `TvWindow` — `TFrame`, `TScrollBar`, `TScroller`, `TWindow` | `views.h`, `tframe.cpp`, `framelin.cpp`, `tscrlbar.cpp`, `tscrolle.cpp`, `twindow.cpp`, `tvtext1.cpp` (frame tables) | done (without streams); `CtrlToArrow` is in `TvKeys` |
| 5d | `TvUtil` — hot keys and strings with `~`: `HotKeyStr`, `CStrLen`, `GetAltCode/Char/CharStr`, `GetCtrlCode/Char`, `EqualsIgnoreCase`, `NewStr` | `util.h`, `tvtext2.cpp`, `tinputli.cpp`, `drivers2.cpp`, `ttext.cpp` | done |
| 6a | `TvMenus` — menus: `TMenuView`, `TMenuBar`, `TMenuBox`, `TMenuPopup`, `NewMenu/NewSubMenu/NewItem/NewLine` | `menus.h`, `tmnuview.cpp`, `tmenubar.cpp`, `tmenubox.cpp`, `tmenupop.cpp` | done (without streams) |
| 6b | `TvMenus` — status line: `TStatusLine`, `TStatusDef`, `TStatusItem`, `NewStatusDef/NewStatusKey` | `menus.h`, `tstatusl.cpp` | done (without streams) |
| 7a | `TvSys` — backend hooks: event polling, clock, video mode switching, screen mode | own (in the original `THardwareInfo`, `TEventQueue`) | done |
| 7b | `TvTimer` — the timer queue `TTimerQueue` | `system.h`, `ttimerqu.cpp` | done |
| 7c | `TvApp` — `TBackground`, `TDeskTop` (Tile, Cascade), `TProgram`, `TApplication` | `app.h`, `tprogram.cpp`, `tapplica.cpp`, `tdesktop.cpp`, `tbkgrnd.cpp` | done (without streams, `LowMemory`; dialog — any view) |
| 7d | `TvMouse` — mouse state → events (press, release, move, auto-repeat, wheel, double and triple click) | `tevent.cpp` (`getMouseEvent`) | done; delays in ms (in the original, ticks of 55 ms), configurable via variables |
| 7e | `TvObjs` — `TStreamable`, the streams `TStream`/`TDosStream`/`TBufStream`/`TMemoryStream` with a type registry (`RegisterType`, `Get`, `Put`), the collections `TCollection`/`TSortedCollection`/`TStringCollection` | own, following the Pascal TV API and the semantics of magiblot's `TNSCollection` | written; `TView` is now a descendant of `TStreamable` |
| 9a | `TvDialog` — `TDialog`, `TStaticText`, `TLabel`, `TButton` | `dialogs.h`, `tdialog.cpp`, `tstatict.cpp`, `tlabel.cpp`, `tbutton.cpp` | done (without streams) |
| 9b | `TvMsgBox` — `MessageBox`, `MessageBoxRect`, formatted variants | `msgbox.h`, `msgbox.cpp` | done; `InputBox` is in `TvInput` |
| 9c | `TvValid` — `TValidator`, `TPXPictureValidator`, `TFilterValidator`, `TRangeValidator`, `TLookupValidator`, `TStringLookupValidator` | `validate.h`, `tvalidat.cpp` | done (without streams) |
| 9d | `TvInput` — `TInputLine`, `InputBox`, `InputBoxRect` | `tinputli.cpp`, `msgbox.cpp` | done (without streams) |
| 9e | `TvCluster` — `TCluster`, `TRadioButtons`, `TCheckBoxes`, `TMultiCheckBoxes`, `TSItem`/`NewSItem` | `tcluster.cpp`, `tradiobu.cpp`, `tcheckbo.cpp`, `tmulchkb.cpp` | done (without streams) |
| 9f | `TvList` — `TListViewer`, `TListBox`, `TListBoxRec` | `tlstview.cpp`, `tlistbox.cpp` | done (without streams) |
| 9g | `TvHist` — `HistoryAdd/Count/Str`, `THistory`, `THistoryWindow`, `THistoryViewer` | `histlist.cpp`, `thistory.cpp`, `thistwin.cpp`, `thstview.cpp` | done (without streams) |
| 10a | `TvFiles` — `TSearchRec`, `TFileFinder`, `TFileCollection`, `TDirCollection`, `FExpand`, `FSplit`, `PathValid`... | `stddlg.h`, `tfilecol.cpp`, `tdircoll.cpp` | done (without streams) |
| 10b | `TvFileDlg` — `TFileDialog`, `TFileList`, `TSortedListBox`, `TFileInputLine`, `TFileInfoPane` | `tfildlg.cpp`, `tfillist.cpp`, `stddlg.cpp` | done (without streams) |
| 10c | `TvChDir` — `TChDirDialog`, `TDirListBox` | `tchdrdlg.cpp`, `tdirlist.cpp` | done (without streams) |
| 11a | `TvColorSel` — `TColorDialog`, `TColorSelector`, `TMonoSelector`, `TColorDisplay`, `TColorGroupList`, `TColorItemList`, `ColorItem`, `ColorGroup` | `colorsel.cpp` | done (without streams) |
| 11b | `TvTextView` — `TTextDevice`, `TTerminal`, `AssignDevice` | `textview.cpp`, `ttprvlns.cpp` | done |
| 11c | `TView.WriteBufW/WriteLineW/GetColorW` — the Turbo Vision for Borland Pascal interface on 16-bit cells | — (ours) | done |
| 8a | `TvMem` — the in-memory backend: the screen in a buffer, events from a script, a fake clock | own | done |
| 8b | `TvDos` — the DOS backend: video memory, int 10h (caret, mode), keyboard int 16h, mouse int 33h, BIOS clock | own | written; tested in DOSBox-X (`tv/dostests/t_dosbk.pas`, demo `tv/demo/tvdemo.pas`) |
| 8c | `TvClip` — the clipboard (UTF-8, internal buffer, hooks for the system one, OEM re-encoding and CR LF); in `TvDos` — WinOldAp (int 2Fh AX=17xxh) | own | written; WinOldAp is tested in DOSBox-X (`t_dosbk`) and still needs testing in Windows (milestone 5) |
| 8c2 | `TvDosNames` — a file name at the border of a DOS with the UTF-8 API (`DOS-UTF8/NAMES` of AMIS, switched on by `TvDos.DosInit`): the conversion for a program with a code page inside | own | written; tested natively (`t_dosnam`); the provider is in DOSBox-X master since October 2026 |
| 8d | `TvTermIO` — terminal bytes → events: keys (xterm, Kitty, modifyOtherKeys, Linux console), mouse (SGR, X10), UTF-8, paste | `termio.cpp` (`TermIO::parse*`, `CSIData`, `GetChBuf`), `ncursinp.cpp` (plain keys, Alt = ESC + key) | done; without ncurses (see below); the far2l extensions in `ParseApc`; **win32-input mode** (`ESC[?9001h`, `ParseWin32Key`: Windows Terminal, conhost, WezTerm; any key combinations) added 2026-10-03 (not in the original), turns on by itself in Windows Terminal, forced with `TV_WIN32_INPUT=1\|0`; test `t_termio`, `tests/pty/test_win32input.py`. The mode state query (DECRQM 9001) for auto-detection is not done |
| 8e | `TvAnsi` — cells and attributes → ANSI terminal bytes, colors matched to capabilities (8/16/256/24 bits, Linux console quirks) | `ansiwrit.cpp` | done |
| 8f | `TvUnix` — the Unix backend: raw mode, alternate screen, output of changed cells, input, mouse, SIGWINCH | `unixcon.cpp`, `linuxcon.cpp`, `sigwinch.cpp`, `dispbuff.cpp`, `events.cpp` | done; no clipboard (OSC 52), Ctrl+Z/shells, GPM |

After the pilot (milestones 3–4 of the plan): dialogs, clusters, lists, file dialogs, help,
collections and streams, the editor — to the extent that DN uses them.

## What we do not port

- `source/platform` for Unix and Win32 — milestone 6.
- The Borland C++ compatibility layer (`include/tvision/compat`).

## Decisions made during the port

- **Color and attribute** — simple types with functions, not classes with operators:
  `TColor` is `LongWord` (24 bits of value and 3 bits of type), `TColorAttr` is a record with 64
  bits (27 bits `fg`, 27 bits `bg`, 10 bits of style), as in magiblot. The zero attribute is
  default colors without style. The functions are named `ColorXxx`, `AttrXxx`.
- **DN's two-byte attribute.** DN is used to a BIOS attribute byte and a cell of two
  bytes. For it there are `AttrFromBIOS`, `AttrAsBIOSByte` (`$5F` if the attribute cannot be
  reduced to BIOS) and `AttrToBIOS` (with quantization). How exactly DN's
  `TDrawBuffer` is coupled with a UTF-8 cell we decide in the `TvDrawBuf` unit (No. 4).
- **Test file names** `t_*.pas`: DOS without LFN allows 8 characters.
- **Character width.** magiblot takes it from the system (`wcwidth` on Unix, a console check on
  Windows). We have tables from the Unicode database, generated by the script
  `tools/gen-width.py` (`tv/src/tvwidth.inc`, the Unicode version is recorded in the header): this way the
  result is the same on all platforms, including DOS. Width: −1 for control characters,
  0 for combining and formatting characters (categories Mn, Me, Cf, except U+00AD, plus
  U+1160..11FF), 2 for East Asian Wide/Fullwidth, otherwise 1. Updating Unicode means a new
  run of the script.
- **The UTF-8 decoder is our own:** it checks the shortest form, surrogates and the upper bound
  U+10FFFF; on an error it returns a `Used` from which decoding can continue
  (as with a single-byte code page character).
- **The screen cell** is as in magiblot: `TScreenCharacter` (15 bytes of UTF-8 text plus a byte
  "length−1 / flags": wide, wide trail, overflow), 16 bytes; `TScreenCell` is a
  character plus a `TColorAttr`, 24 bytes. This is plain data: zero bytes are a valid empty
  cell, comparison is bytewise. A converter from a DOS word (`CellFromBIOS`) is needed for DN and for
  the DOS backend.
- **Code pages** (`TvCodePg`, tables from `tools/gen-codepage.py`): currently 437 and 866,
  selected with `CpSelect`, 866 by default (magiblot uses 437). The lower half (0..31 and 7Fh)
  is shown as IBM PC graphic characters (☺, ♥, ⌂…), the upper half comes from the Python codec.
  I checked the CP437 table against magiblot's table: it matches in all 256 positions. A new
  page is a row in `PAGES` of the script and a branch in `CpSelect`.
- **Text** — pairs of `PByte` + length (plus wrappers for `ShortString`): this way data is not copied
  and it is easy to work with pieces of a buffer. Cells are `PScreenCell` + a counter. The attribute is
  optional (`PColorAttr`, `nil` means do not change). Invalid UTF-8 is treated as a character
  of width 1 and is drawn through the code page.
- **Events.** `TEvent` is one flat record, as in Pascal TV (`Event.Where`,
  `Event.KeyCode`, `Event.Command`, `Event.InfoPtr`), and not magiblot's nested structures.
  `ControlKeyState` is shared by the keyboard and the mouse and sits in the common part of the record. The key
  text is UTF-8 (`Text`, `TextLength`). The event queue, the mouse and the screen (`TEventQueue`,
  `THWMouse`, `TScreen`) are platform code, replaced by the backends.
- **Keys.** The `kb*` codes are BIOS codes (scan code in the high byte, character in the low byte).
  The modifiers are the DOS BIOS set (`kbShift=3`, `kbCtrlShift=4`, `kbAltShift=8`,
  `kbScrollState=$10`, etc.), unlike magiblot's set for Windows; our own
  `kbEnhanced` is added. `TKey` reduces equivalent forms of key combinations to one.
- **`TDrawBuffer`** is a class with a cell buffer `Data`/`Capacity`; the capacity is
  `8 + Max(ScreenDim, 80)` (the buffer is also used by vertical views), the screen size is
  passed by the caller (`Init(ScreenDim)`); in magiblot it is taken from `TScreen`. "Attribute 0"
  means "keep the attribute" and stands for the BIOS attribute `$00` (black on black) — it
  cannot be drawn through these calls; a zero cell (`Data = 0`) is default
  colors. The magiblot variants for 32-bit systems are implemented; the assembler 16-bit ones
  were not ported.
- **Bytes ≥ $80 in interface strings** (window frames, buttons: `'\xC4'`, `'\xB3'`…) are, as in
  the original, CP437 codes. They are not valid UTF-8, so they are drawn through the code
  page. In the DOS pages (437, 850, 866) the block of line-drawing characters $B0–$DF is the same,
  so the frames look the same. For other pages and for the terminal such constants
  will have to be given in Unicode — we will decide when porting `TFrame`, `TButton`, `TScrollBar`.
- **The class model is verified** (`tv/tests/t_objmod.pas`, support unit `ObjModA.pas`):
  a class with virtual methods, a descendant in another unit with a new field and a new
  virtual method, `inherited` in an override, `Create`, `Free` (the chain of
  destructors), a `var` record through a virtual method, an array of references to the base type
  with different descendants. It works natively and under DOS. The view hierarchy uses the same
  class semantics without workarounds.
- **View order.** `First` is the top view, `Last` is the bottom one; `Next` goes from top to bottom, and
  `Last.Next = First`. `Insert` puts a new view on top. `NextView` is the view below,
  `DrawUnderRect` redraws the views below. `ResetCurrent` looks for a suitable view starting from `Last`,
  so the oldest selectable view becomes current.
- **The output and visibility engines** (`tvwrite`, `tvexposd`) are preserved step by step, with the same
  labels `L0`…`L50` (these are translations of Borland assembler that magiblot has already written in
  C++); rewriting them "more nicely" would risk subtle
  divergences. Shadows are marked in the attribute by the flag `slWindowShadow`.
- **Palettes** are an array of `TColorAttr`, element 0 is the number of entries; `nil` is an empty palette.
  A non-top view maps an index to the owner's index (via a BIOS byte), the top one (the future
  `TApplication`) gives the real colors. `MakePalette(#1#2#3)` builds a palette from a string
  of indices, like the palette strings of Pascal TV.
- **The destructor** `Done` detaches the view from its group (as in Pascal TV), so `shutDown` from
  C++ is not ported as a separate method; the group in `Done` hides and deletes its subviews.
- **`TCommandSet`** is `set of Byte`; commands above 255 are always enabled.
- **Not yet ported in `TView`/`TGroup`:** streams (`read`/`write`/`build`), timers,
  `getEvent` with a timeout and `textEvent` (`TvApp` is waiting for them).
- **`ResetCurrent` and the traversal order.** `FirstMatch` starts from `Last` (the bottom view), then
  goes from top to bottom (`Last.Next = First`). A new window becomes current because the bottom
  view of the desktop (the background) is not selectable; if there is no background and the bottom window is selectable, it
  stays current (the same in the original). The window tests therefore put a background under the windows.
- **`TWindow`:** the frame is created by the virtual method `InitFrame` (as in Pascal TV), and not by the
  helper class `TWindowInit`. The title is a `ShortString`; an empty title
  is drawn as no title (in the original an empty string gave two spaces).
  `Done` zeroes `Frame` before deleting the subviews; `Close` does `Frame := nil` and `Dispose`.
  The window number is an `Integer`.
- **The frame:** the tables `FrameInit`/`FrameChars` and the icons `[■]`, `[↑]`, `[↕]`, the resize
  corners are CP437 codes (including the control codes $12 and $18, which the code page
  table displays, see the test). The original substitutes `frameChars[30]` for non-437 pages
  in `updateIntlChars`; here it is not needed, because the page displays $CD by itself.
  The frames of neighboring views with `ofFramed` are joined in `FrameLine` (verified by a test). Drawing
  a view inside a window does not redraw the frame: after inserting such a view the frame has to be redrawn
  (`Frame^.DrawView`), the same in the original.
- **`TScrollBar`:** the mouse state (`SbMouse`, `SbP`, `SbS`, `SbExtent`) consists of unit variables,
  like the static variables in the original; two bars are not handled at the same time.
  The arithmetic of the thumb position is `Int64` (in the original `long`).
- **The window tests** (`t_window.pas`) use a top view `TTop` with an event queue: it gives
  the `MouseEvent` loops of the frame and the bar pre-prepared events and remembers `PutEvent`.
  This is a draft of what will later become `TProgram.GetEvent`.
- **Not yet ported in `TvWindow`:** streams; `TWindow.Palette` and `Flags` have the same
  values as in the original.
- **Menus are built with the Pascal TV functions** (`NewMenu`, `NewSubMenu`, `NewItem`, `NewLine`), and not with the
  overloaded `operator +` from C++. The item key is a key code (`Word`), a normalized
  `TKey` is stored inside; comparison is `KeyEq`. An item and a menu are records, the name is a pointer to
  `ShortString` (`nil` is a separator). `DisposeMenu` frees a menu with its submenus; `TMenuBar`
  and `TMenuPopup` free their menu in `Done`, `TMenuBox` does not (it belongs to the parent).
- **`EqualsIgnoreCase`** lowercases using a small built-in table (Latin-1, Latin
  Extended-A, Greek, Cyrillic), and not the platform tables; bytes that are not UTF-8
  are treated as code page characters (as in the original). Other alphabets are not distinguished
  by case: if needed, the table will have to be generated from the Unicode database (like
  `gen-width.py`).
- **`TMenuView.Execute`** is ported without changes to the logic; `getEvent` takes events from the
  top view, so the menu tests (`t_menus.pas`) use `TTop` with an event queue and
  a deferred event (`PutEvent`/`GetEvent`, as in `TProgram`), and when the queue is empty they give
  Esc, so that the menu always closes.
- **Leak check:** `t_menus.pas` compares `GetFPCHeapStatus.CurrHeapUsed` before and after
  creating and deleting a menu.
- **The status line** is built with `NewStatusDef`/`NewStatusKey` (as in Pascal TV) and frees its
  definitions in `Done`. `Hint` returns a `ShortString`; the hint separator is the CP437 byte
  $B3 and a space. `Update` takes the help context from `TopView` — it will be called by
  `TProgram.Idle` (unit `TvApp`).
- **The backend is a set of `TvSys` hooks** (`OnPollEvent`, `GetClockMs`, `OnSetVideoMode`,
  `OnSuspend/OnResume`, `ScreenMode`) and `TvScreen` hooks (write, caret). `PollEvent(TimeoutMs)`
  waits up to `TimeoutMs` ms for one event (the mouse takes priority over the keyboard) and returns `evNothing` if
  nothing happened; then `TProgram.GetEvent` calls `Idle`. This way the DOS, terminal and
  Windows backends plug in without changes in `TvApp`.
- **`TProgram`:** the desktop, the status line and the menu bar are created by the virtual methods
  `InitDeskTop`, `InitStatusLine`, `InitMenuBar` (in `Init` they are called in that order);
  the class variables of the original (`Application`, `StatusLine`, `MenuBar`, `DeskTop`, `AppPalette`,
  `EventTimeoutMs`) are unit variables. The application palettes (`cpAppColor`, etc.) are generated
  from `app.h` into `tvapppal.inc` (135 values each, the count is verified). For hidden status line
  items (a key without text) `NewStatusKey` with empty text stores `nil`.
- **Timers** send the program `cmTimerExpired` with the timer identifier in `InfoPtr`;
  expiry is checked in `Idle`, and the wait for events is shortened to the nearest timer.
- **The tests use `TvMem`:** `MemKey`, `MemMouse`, `MemText`, `MemAttr`, `MemIsShadow`.
  If the script has ended and the program is waiting for an event, the backend advances the clock by the
  timeout (this is how timers are tested), and after 500 empty polls it stops the test.
- **`DosShell`** is not covered by tests (it launches the shell from `COMSPEC`/`SHELL`).
- **`TvDos`** (go32v2 only): the screen is video memory `$B800` (`$B000` for mode 7) via
  `dosmemput`; cell → word: a single byte goes as is (it is a character of the font's code page
  or ASCII), UTF-8 is converted through the current code page (`CpFromUnicode`), what is not in the
  page becomes `?`, the trail of a wide character becomes a space. The code page is taken from DOS (int 21h
  AX=6601h) and must be 437 or 866, otherwise 437; `DosInit(866)` can be passed. 16 background colors
  instead of blinking (int 10h AX=1003h). The caret is int 10h AH=1/2. The keyboard is int 16h
  AH=11h/10h/12h: extended keys ($E0) lose their character, a character > $7F turns into the UTF-8
  text of the event; the modifiers are the BIOS flags byte (the bits match `kbShift`, etc.). The mouse is
  int 33h, coordinates /8, the wheel via CuteMouse (AX=0011h, BH) if present; the mouse cursor
  is hidden while writing to video memory. Mouse events are built by `TvMouse`. The clock is the BIOS
  tick counter (54.9 ms, midnight rollover is handled). Waiting is int 2Fh AX=1680h.
- **`TvUnix`** (Unix; test — `tv/tests/pty/test_tvdemo.py`): a single thread, everything is in `PollEvent`: first the accumulated output is flushed
  (`UnixFlush`), then we wait for input with `fpPoll` (with a mouse button pressed — in 20 ms steps, so that the `TvMouse` timers work).
  The terminal screen is kept as a "shadow" (`Shown`): only cells that differ from it are drawn; a wide character is drawn
  together with its trail, one half-overwritten is drawn as a space. Single-byte cell text ($80 and above or a control character) is a character of the
  code page and is converted to UTF-8 via `CpToUtf8` (as in `TvMem.MemChar`). Start: `ESC[?1049h` (alternate
  screen), `ESC[?7l` (no line wrapping), key modes (`SeqKeyModsOn`), SGR mouse (`TV_MOUSE=0` turns it off); at exit and on
  the signals SIGTERM/SIGHUP everything is restored. The size is `TIOCGWINSZ`; SIGWINCH sets a flag, `PollEvent` gives
  `cmScreenChanged`, the program calls `SetScreenMode(smUpdate)`, the hook `OnSetVideoMode` recreates the screen and the shadow.
  Colors are taken from `COLORTERM`/`TERM` (`TermCapFromEnv`; `TV_COLORS` forces them). `ESCDELAY` (ms, 25) is how long
  to wait for a continuation after ESC (a lone ESC is the Esc key, ESC + key is Alt).
  **Difference from magiblot:** there the keys without modifiers (arrows, F1–F12) come from ncurses/terminfo, we have no ncurses:
  `TvTermIO` parses the simple xterm/VT sequences (`CSI A`, `SS3 P`, `CSI 15~`) and the Linux console ones
  (`CSI [ A` = F1…F5) itself. Risks: `ESC P`, `ESC ]`, `ESC _` are parsed as the start of a string (a terminal reply), so Alt+Shift+P,
  Alt+] and Alt+_ are lost (the same in the original); non-standard terminals with other sequences — via a setting later.
- **Testing in DOSBox-X without a screen:** `t_dosbk` reads video memory back (`DosReadRow`,
  `DosReadAttr`), puts keys directly into the BIOS buffer (`DosStuffKey`) and reads them through int 16h,
  moves the mouse via int 33h AX=4. The demo with `/auto` "presses" the keys itself, makes a dump of the screen
  (`DosDumpScreen`) into `SCR.DAT`; `tools/render-dump.py` prints it as text into the CI log and draws a
  PNG (artifact `dos-demo`).
- **Not done in DOS:** modes with more than 25 rows have not been tested, fonts for code
  pages that the video adapter does not have, the WinOldAp clipboard.
- **The clipboard.** `TvClip` keeps an internal buffer and the hooks of the backend's system clipboard:
  `ClipboardSetText` puts the text into both, `ClipboardGetText` asks the system one first,
  then takes the internal one, so cut and paste work everywhere. The text is an `AnsiString` in
  UTF-8 (the unit has `{$H+}`). Under DOS the system clipboard is Windows via WinOldAp (INT 2Fh):
  1700h check (AX ≠ 1700h — present), 1701h open, 1702h empty, 1703h write
  (DX = format, ES:BX — data, SI:CX — size), 1704h size (DX:AX), 1705h read,
  1708h close; the format is CF_OEMTEXT (7) in the current code page — Windows
  synthesizes it from CF_TEXT itself. The data buffer is allocated in conventional memory
  (`global_dos_alloc`), the limit is 256 KB. On writing, any line break is turned into CR LF,
  on reading the text is left as is (CR LF). The facts about the API are from Ralf Brown's Interrupt List
  (from memory), checked against the emulation in DOSBox-X; testing on real Windows (9x, XP)
  is left for milestone 5. Text only.
- **`TvObjs` — the Pascal API of classes, streams and collections** (needed by DN: `TCollection` in 17 files,
  `TBufStream`/`TDosStream` in 13 and 6, `TStreamRec`/`RegisterType` in 9). Written anew from the
  behavior of the API, and not from the Borland or FPC sources (the same-named FPC module matches Borland by
  20%, so we do not take it). Differences:
  - the `Create` constructor zeroes the class fields; the instance size is taken from the VMT;
    `TView` is now a descendant of `TStreamable`;
  - type registration: `Load` is a factory function `function(var S: TStream): TStreamable`, `Store` is a
    procedure `procedure(P: TStreamable; var S: TStream)`, `VmtLink` is `PtrUInt(TypeOf(TFoo))`
    (calling a constructor through a pointer is not portable between FPC targets); entries of the form
    `Load: @TFoo.Load` in DN have to be replaced with factories on import (import script, milestone 4);
  - sizes and counters are 32-bit; `ForEach`/`FirstThat`/`LastThat` take a pointer to an
    ordinary procedure/function, not to a nested one (the nested ones in DN will have to be moved out);
  - repeated registration of a type number is ignored;
  - `TBufStream` has its own buffer window algorithm (a write into the middle of a file first reads the window).
- **FPC trap:** `SizeOf(X)` for a class variable with a VMT reads the size from the VMT
  of the instance (an uninitialized instance — a crash); for a static size write
  `SizeOf(TFoo)`.
- The test programs now flush the output after each `PASS` line (`Flush`), otherwise if a test
  hangs the output is lost.
- **Dialogs.** The first inserted selectable view of a dialog gets focus only after
  `SelectNext(False)`: `FirstMatch` starts from the bottom view and then goes from top to bottom, so
  the last inserted one becomes current (as in the original; the dialog code calls
  `SelectNext(False)` at the end). View timers: `TView.SetTimer`/`KillTimer` are virtual,
  the chain of owners ends at `TProgram`, which has the timer queue; a button is animated
  for 100 ms (`cmTimerExpired`), so the dialog tests run on `TvMem` with a clock that
  advances while waiting for an event.
- **Message boxes.** The texts of buttons and titles (`MsgYesText`, `MsgErrorText`, …) are variables
  (translations); the formatted variants accept a Pascal format (`SysUtils.Format`, `%s`, `%d`) and
  `array of const`. The validator messages (`ValidRangeError`, etc.) are variables too.
  The "empty" field (`prEmpty`) of a picture validator is not considered valid: `IsValid('')` is false,
  as in the original.

### TvInput (9d): decisions

- `Data: PStr` (GetMem MaxLen+1), the limit is in bytes only, `MaxLen` is 1..255.
- `InputLineOem` (False by default): the typed UTF-8 is turned into a single code page byte (for DN strings that store OEM); when copying to the clipboard — back into UTF-8.
- Pasting from the clipboard is synchronous, the first line of the clipboard is taken.
- Test: references to literals in the main block keep temporary AnsiStrings until the end of the program — for the "memory does not leak" check the comparisons with the clipboard are moved into the function `ClipIs`.

### TvCluster (9e): decisions

- The list of texts is a chain of `TSItem` via `NewSItem(Str, Next)` instead of `operator+`; the cluster takes the texts into a `TStringCollection` (AtInsert, no sorting) and frees the chain.
- `Value` and `EnableMask` are `LongWord`; `DataSize` = 2 (Word) as in the original, for `TMultiCheckBoxes` — 4.
- `SpecialChars` was moved to the interface part of `TvDialog` (the clusters need it).
- Drawing rows are `0..Size.Y-1` (the original draws one more row outside the view — without effect).
- Shifts of more than 31 bits (`TMultiCheckBoxes` with large `Flags`/numbers) are undefined in the original; for us they give 0 / no action.

### TvList (9f): decisions

- `GetText(Item, MaxLen): ShortString` (a function) instead of filling a `char*` buffer; an empty list draws `EmptyText = '<empty>'`.
- The `TListBox` items are `PStr` (as in `TStringCollection`); `Items` belongs to the list (`NewList`/`SetData` free the previous collection).
- `Done` replaces `shutDown`: it zeroes the pointers to the scroll bars (the same decision as in `TScroller`).
- `TListBoxRec` = `(Items: PCollection; Selection: Word)`; `DataSize` is its size.

### TvHist (9g): decisions

- The list of strings is a dynamic array of records (Id, string) instead of a block of bytes; the `HistorySize` accounting is the same (3 bytes + length per entry), the oldest entries are evicted.
- The empty first element of the original is not needed: after it is evicted the original skips the first string of the list (a bug), we do not have that.
- Initialization/release are in the unit's `initialization`/`finalization`; `ClearHistory`, `DoneHistory` — on demand (tests).
- `HistoryStr` returns `''` if there is no string (the original — nil).
- `THistoryWindow` gets the viewer from the virtual `InitViewer` (instead of a pointer to the function `THistInit`).
- DN compatibility (separate styles, `HistoryAdd` with long strings, storage in a file) is a task for the adapter layer in `dn/new`.

### TvFiles (10a): decisions

- File search is `TFileFinder` on top of `SysUtils.FindFirst/FindNext`: in DOS the RTL itself uses the LFN API (Windows 9x, DOSLFN) if it is present; the name is a `ShortString` (a long name up to 255), the size is `Int64`.
- `TSearchRec` is named as in the original; with a simultaneous `uses SysUtils` it has to be qualified (`TvFiles.TSearchRec`).
- `TFileCollection`: files, then directories, `..` last; names are compared case-insensitively (the original — bytewise), names equal case-insensitively are distinguished bytewise.
- `Insert` into a sorted collection does not insert a duplicate (as in the original): the caller frees the rejected entry.
- Drives (`DriveValid`, the drive prefix in `GetCurDir`, `:` in `FSplit`) — only where there are drive letters (DOS/Windows/OS2); otherwise the only "drive" is always valid.
- The test creates the directory `tvf_test` in the current directory (in DOS without LFN the long name is replaced with 8.3).

### TvFileDlg (10b): decisions

- The dialog data record is a `ShortString` (the input line up to 255 characters; the original — `MAXPATH`).
- Reading a directory: files (`faReadOnly or faArchive`, hidden/system ones are not shown, as in the original), then directories (except those starting with `.`), then `..` (if not the root). The message "Too many files" was removed.
- The separator in the list and in the input line is `DirDelim` (`\` where there are drive letters, otherwise `/`).
- `FExpandFrom(Path, RelativeTo)` in `TvFiles` replaces the two-argument `fexpand` of the original (a path relative to the dialog's directory).
- The dialog sizes are fitted to the screen as in magiblot (screen >90 columns / >34 rows).
- The `t_fdlg` test does a `ChDir` into a temporary directory `tvf_dlg` in the current directory.
- Known limitation: the typed search by first letters in `TSortedListBox` compares case-insensitively, like the original on DOS (`strnicmp`).

### TvChDir (10c): decisions

- The tree is built using both separators: the root is `C:\` (where there are drives) or `/`; the tree characters are CP437/866 bytes (`#$C0#$C4#$C2`, etc., as in the original).
- `ChDir` instead of `chdir`+`setdisk`; on systems without drive letters there is one "drive" — `C` (`DriveValid`, `GetDisk`).
- The "all files" mask is `AllMask` (`*.*` for DOS/Windows, `*` otherwise) — it is also used by the file dialog.
- The `t_chdir` test changes the current directory into a temporary `tvf_cd` and returns back.

### TvColorSel (11a): decisions

- The lists of groups and items are built with `ColorItem(Name, Index, Next)` and `ColorGroup(Name, Items, Next)` (instead of `operator+`); the dialog takes and frees them; `ColorGroupItems` adds items to the last group.
- The palette is `TPalette` (a dynamic array of `TColorAttr`, element 0 is the size); the dialog data is a `TPalette`: `GetData` gives a copy, `SetData` takes a copy. Colors are edited as BIOS colors (16 colors) via `AttrToBIOS`/`AttrFromBIOS`.
- The remembered group indices are the global `ColorIndexes` (like the static `colorIndexes` of the original), `FreeColorIndexes` frees it.
- In `SetData` the original takes the group item index as the palette index (`pal->data[groups->getGroupIndex(...)]`) — repeated as is, with a bounds check.
- BIOS color 0 in `TDrawBuffer` means "keep the attribute" — `TColorDisplay` shows it as `ErrorAttr`, like the original.

### TvTextView (11b): decisions

- `TTextDevice` is not a `streambuf`: the interface is the virtual `DoSputn(S: PByte; Count)`, the conveniences `PutStr`, `PutLine`, `PutChar` (not `Write`/`WriteLn`: otherwise the descendants lose the system `Write`). Instead of `otstream` — `AssignDevice(T, Device)` (like `TextView` of Borland Pascal): `Write(T, ...)` goes to the terminal; CR is discarded, the text file's `LineEnd` is LF.
- `TTerminal`: a ring buffer of up to 32000 bytes, old lines are evicted whole; `Draw` draws from the end, in a chunk of up to 256 bytes it does not cut a UTF-8 character.
- FPC pitfall: `FillChar(T, ...)` zeroes `TextRec.LineEnd`, without it `WriteLn` gives no line break.

### DOS code pages (milestone 5a)

- `TvCodePg` knows 16 DOS OEM pages (437 737 775 850 852 855 857 858 860 861 862 863 864 865 866 869); the tables are generated by `tools/gen-codepage.py` from Python codecs (the lower half — IBM PC glyphs, bytes not defined in the page — U+FFFD). Selection is `CpSelect(Id)`; `TvDos.DosInit` takes the number from DOS (`INT 21h AX=6601h`), an unknown one — 437.


### The 16-bit cell interface (11c): decisions

- For programs written for Turbo Vision for Borland Pascal (DN): a cell is a `Word` (the low byte is the character, the high byte is the
  BIOS attribute), a color is a BIOS attribute. `WriteBufW`/`WriteLineW` convert the cells with `CellFromBIOS` and write through `WriteView`;
  `GetColorW(C)` = `Lo + 256 * Hi` of `GetColor(C)` (`AttrAsBIOSByte`). These are separate names (not overloads): an untyped
  argument would be ambiguous with `PScreenCell`.
- The character is a byte of the screen's code page (as in `TDrawBuffer.MoveChar`); colors with RGB/xterm lose precision
  when converted to a BIOS byte — for DOS and 16 colors this is lossless.

- `TListBox.List` (and not `Items`): a field name from Pascal TV (`TListBoxRec.List`); in `TSortedListBox` the typed access
  became the function `SortedList` (in C++ it is `list()`). The Pascal TV forms `GetBounds/GetExtent/GetClipRect(var R)` and
  `MakeLocal/MakeGlobal(Source; var Dest)` are overloads (`overload`) of the magiblot functions.
- The streams (`TvObjs`) were extended for DN: positions and sizes are `Int64` (`GetPos`, `GetSize`, `Seek`, `CopyFrom`), `Write(const Buf; ...)`;
  `Eof`, `ReadStrV`, `ReadLongStr`/`ReadLongStrV`/`WriteLongStr` (length `LongInt`), `StrRead`/`StrWrite` (length `Word`),
  for `TDosStream` — `Open`, `DoOpen`, `Close`, `ReadBlock`, the field `FName`. The string format is ours; DN resources
  are compiled anew, compatibility with foreign resource files is not needed.
- `FirstThat`/`LastThat`/`ForEach` of collections and groups accept procedural variables of the `is nested` kind
  (`{$modeswitch nestedprocvars}` in `tvdefs.inc`): this makes local functions work, like `@Name` in Turbo Pascal.

### View streams (Load/Store, 2026-10-02)

- `TView.Load/Store`, `TGroup.Load/Store` and the other classes (`TFrame`, `TScrollBar`, `TScroller`, `TWindow`, `TDialog`,
  `TStaticText`, `TLabel`, `TButton`, `TInputLine`, `THistory`, `TCluster` and its descendants, `TListViewer`, `TListBox`,
  collections) write their fields; the format is ours. The type records `RView`, `RGroup`, `RFrame`, `RScrollBar`, `RScroller`, `RWindow`, `RDialog`,
  `RStaticText`, `RLabel`, `RButton`, `RInputLine`, `RCluster`, `RRadioButtons`, `RCheckBoxes`, `RMultiCheckBoxes`, `RListViewer`,
  `RListBox`, `RHistory`, `RCollection`, `RStringCollection` have the Turbo Vision numbers (1, 6, 2, 7, 3, 4, ...); the
  program registers them: `RegisterType(RView)`.
- A reference to a neighboring view (`GetPeerViewPtr`/`PutPeerViewPtr`, `GetSubViewPtr`/`PutSubViewPtr`) is written as a number in the owner's
  list and becomes a pointer when the group has read all the views (`TGroup.Load`; the list of fixups is in the module).
  `TGroup.ReadChildPtr` reads the number of a child view of the group immediately (for the window's `Frame` and `Current`).
- A view that was read is not active, not selected, not focused: `State` is cleared of `sfActive`, `sfSelected`, `sfFocused`, `sfExposed`;
  `TInputLine.Awaken` selects all the text (the cursor position after loading is 0, as in Borland TV).
- DN fields in `TView`: `UpdTicks`, `UpTmr` (`TEventTimer`), `ClearPositionalEvents`, the method `Update` (does nothing).

## far2l terminal extensions

The protocol is described in `VTExts.md` (far2l, branch `extsdocs`). tv3 has both sides.

- `TvFar2l`: the stack serializer (`TF2lStack`), Base64, the APC strings of requests, replies and events, the events decoded and built (`F2lDecodeInput`,
  `F2lKeySeq`, `F2lMouseSeq`, `F2lSizeSeq`), the client ID (64 characters, kept in `far2l-clipboard-id` of `$TV_CONFIG_DIR`, else of the configuration
  directory `tv` of `TvAppDir`) and `TF2lClient`, the requests of a client: features, notification, F-key titles (the first request with an ID, then ID 0 and only on a
  change), the largest window, maximize/restore, quick edit, cursor height, palette, the clipboard (open with the client ID, empty, set in pieces of 16 KiB
  when the terminal takes chunks, get, the data ID cache, available, register a format; `CF_UNICODETEXT` goes as `CF_TEXT` and is read as UTF-32 only when
  there is no text; a terminal that answers -1 is not asked again).
- `TvTermIO.ParseApc`: the acknowledgement, the replies and the size go to `TInputState`; key events go through `ParseWin32Key` (releases as `evKeyUp` when
  `TvSys.KeyUpEvents`/`KeyUpForApp` want them, a repeat count above 1 sets `kfRepeat`), mouse events become raw mouse reports.
- `TvUnix`: `far2l1` and `ESC [ 5 n` are sent at the start and after a resume (`TV_FAR2L=0|1`; not on `TERM=linux`, `dumb` or empty), `far2l0` at the
  exit, at a suspend and when the program is killed. Nothing is waited for at the start: the acknowledgement is taken with the input; then the features
  (compact input, the size event only with `TV_FAR2L_SIZE=1`), the palette (more colors switch the writer up and redraw, `TV_COLORS` wins), the window
  counts as inactive until the first focus report. While the extensions are on: the cursor height in percent instead of DECSCUSR, the clipboard after the
  system programs and before OSC 52 (several formats only here), `TvSys` hooks for notifications, F-key titles, the window and the color depth. A reply is
  awaited `ReplyMs` (3 s), the first authorization `TV_FAR2L_WAIT` ms (30000); events that come meanwhile are queued. The size of the event is used when
  the kernel does not know the size (`OsToldCols`, `OsToldRows`).
- `TvVtExt` (`TVtExtServer`, a member `Ext` of `TVtEmu`, which collects the APC strings): `far2lok` (in order with the other answers, so before the answer
  to `ESC [ 5 n`), `far2l0`, `far2l#` (the first one is kept and goes before the client ID), every request with an ID answered (the ID alone when it is
  unknown or too short), images with no capabilities. The clipboard is that of `TvClip`: the client ID is checked; the clients shared for the activation and
  those in `far2l-clipboard-autheds` are let in, the others go to `TVtExtHost.AskClipboard` (block 0, remote -1, share 1, share always 1 and the file);
  data and data IDs are given only within 5 s of a paste gesture (`PasteGesture`), a read extends it at most 3 times; chunks, data IDs (a 64-bit hash,
  never 0), the formats with their numbers. `TvVtView` asks with the dialog "Clipboard access", shows the F-key titles only while it is focused, draws the
  cursor height, sends keys, releases and the mouse as events (Ctrl+V, Shift+Ins and the middle button are the gestures); `TvVtRun` refuses the clipboard
  unless `TV_VT_CLIPBOARD=allow`.
- Tests: `t_far2l` (Base64, stack, the examples of section 7 of the specification, the client, the parser), `t_vtext` (the server against the examples,
  the authorization, the gesture window, chunks, formats, a `TF2lClient` talking to the emulator), `t_clip` (several formats), `tests/pty/test_far2l.py`
  (tvdemo in a scripted far2l terminal; tvterm with `tests/pty/f2lclient.py` inside).
- Not done: image display (the server says "no capabilities", the client does not use images), drag and drop (a proposal), the host identity sent by the
  client, the emergency exit key of the server.

- **Free Vision extensions for the IDE port (`unxed/sp`, `fpide/`).** `TListBox.GetFocusedItem` /
  `SetFocusedItem(Item)` work with the item itself instead of its index (additive, no change to
  existing API; `SetFocusedItem(nil)` or an unknown item does nothing).
- **A list of masks in the file dialog.** `TFileList.ReadDirectoryMask` searches `*.pas;*.pp;*.inc` mask by mask (the file
  dialogs of the Free Pascal IDE use such masks). A mask without `;` is searched as before.
