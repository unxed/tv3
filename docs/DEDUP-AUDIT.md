# Dedup audit: what dn and fpide share, and what they still duplicate

Task: "move into tv3 everything that is used by both dn and fpide at the same time". Audit of 2026-10-08, branch
`claude/nifty-rubin-7v0d9z` (tv3 at ab82be1 + this change; dn `dn/dn/{src,compat}`; sp `fpide/{src,compat}`).
It supersedes the status column of `SHARED-CODE.md` where they disagree.

## Method and limits

- Read, not only grepped: for every candidate pair the two implementations were opened and compared (interface and bodies).
  Names were used only to find candidates (an intersection of all routine and class names of the three trees, then a
  manual pass over every unit of dn/src, dn/compat, fpide/src, fpide/compat).
- Licence of each unit was taken from its header. dn/src (125 `.pas` files): 90 carry the RIT/DN-OSP licence (not MIT, "cannot be
  put under another licence"), `evaluator.pas` the DN/2 OS licence; 34 are "own" (headers saying "our unit" or MIT, or small files without a licence text, some of them -- `hash.pas`, `dirwatch.pas`, `calendar.pas`, `topview.pas` -- with the
  names of DN/2 authors: those are treated as NOT movable). fpide/src: about 60 of the 103 files are derived from the Free Pascal IDE
  (GPL/LGPL, header "COPYING.FPC" or the author's name, plus the `.inc` files); the ones written for the port (MIT) are `fpdlv`,
  `fpgodbg`, `fplang`, `compat/asciitab`, `compat/gadgets`, `compat/tabs`; own without a licence text: `gdbpty`, `fpsrcbrw`, `compat/*`,
  `shims/manual/*`. Parts of `shims/manual/drivers.impl.inc` (FormatStr) are Free Vision code (LGPL).
- Not judged in depth: dn `menus.pas` (2141 lines) vs `TvMenus`, dn `highlite.pas` vs `TveHl`, dn `inifiles.pas` vs
  `TvIni` (differences in behaviour were not enumerated, so "equivalent" is not claimed); the Windows/DOS branches of
  every unit (only the Linux x86_64 build was compiled and run; Windows and DOS are covered by CI only); behaviour of
  fpide help readers (TPH/HTML/NG/OA/OS2/WinHelp/CHM) against `TvHelp` (different file formats, not compared line by line).
- Editor: both products sit on **tve** (separate repo, not part of this audit): dn uses 12 tve units, fpide 14.
  The glue (file options, load/save, indicator) is written twice (`dn/src/editfile.pas`, `fpide/src/wcedit.pas`) but with
  different options and different host APIs; it belongs to tve if it is ever unified.

## What each project takes from tv3 (direct `uses`, plus the units fed by the shim maps)

- both: TvApp TvCell TvClip TvCluster TvCodePg TvColors TvColorSel TvDialog TvDrawBuf TvEvents TvFileDlg TvFiles TvGeom
  TvHist TvIni TvInput TvKeys TvList TvMsgBox TvObjs TvProc TvScreen TvSys TvText TvUnix TvUStr TvUtf8 TvUtil TvValid
  TvViews TvWindow (31 units).
- dn only: TvCharset TvDos TvDosNames TvGlyphs TvHelp TvLocale TvVt TvVtRun TvXlat.
- fpide only: TvChDir (dn: only through the StdDlg shim and `tree.pas`), TvMenus (dn has its own `menus.pas`), TvWild.
- neither, directly: TvKeyName, TvTimer, TvTextView, TvMem (test backend). The terminal chain (TvTermIO, TvTermOs*, TvAnsi,
  TvMouse, TvFar2l, TvVtKeys, TvVtView, TvPty, TvClipCmd) is linked in through TvUnix/TvVtRun/TvClip; "indirectly used"
  was not traced further.

## Table

Verdicts: **shared** = already shared; **move** = duplicate that should be in tv3; **differs** = similar but different;
**keep** = one side only, or deliberately separate. "Licence" = the move into tv3 is blocked by the licence.

| # | Capability | in dn (file) | in fpide (file) | in tv3 (file) | Verdict | State |
|---|---|---|---|---|---|---|
| 1 | INI read/write (generic) | `profile.pas` (adapter, MIT); `inifiles.pas`, `iniengine.pas`, `dnini.pas` (RIT, dn.ini variable table + a second generic reader) | `fpini.pas`, `fptools.pas` use `TIniFile` directly | `tvini.pas` | shared | fpide fully, dn via `profile.pas`. Residual in dn: `inifiles.pas` (445 lines, 8 users) is a second INI parser; it is a dn-internal refactor (RIT code stays in dn), not done: ordering/comment behaviour not compared. |
| 2 | UTF-8, columns, case, copy by column | `dnutf8.pas` (adapter over TvUStr; dn's own "proxy" strings stay) | direct use in `weditor`, `fpviews`, shims | `tvustr.pas`, `tvutf8.pas`, `tvtext.pas` | shared | `dnutf8.CpUpper/CpLower/Utf8Chars/Utf8Prefix/Utf8DeleteLast` are one-line adapters. The proxy-string machinery (`Utf8ToProxy`, doc tabs) is dn only: keep. |
| 3 | Code pages, charsets, locale | `keymap.pas`, `country.pas`, `basics.pas`; uses TvCodePg, TvCharset, TvLocale | none (UTF-8 only) | `tvcodepg`, `tvcharset`, `tvlocale` | keep | one-sided; nothing duplicated. |
| 4 | Run a program / shell / capture output | `compat/osrununix.pas`, `osrunwindows.pas`, `dnrun.pas` | `fpextcomp.pas`, `fpintf.pas`, `fpviews.pas` | `tvproc.pas` | shared | |
| 5 | Run with stdin/stdout/stderr redirected to files | none | `fpredir.pas` (GPL, 865 lines, `ExecuteRedir`) | none (`TvProc` has capture, no file redirection) | keep | fpide only: dn runs programs on the terminal (`TvVtRun`) or captures through `TvProc`, it never redirects to files (checked again in the dedup pass of 2026-10-08), so there is no second user. |
| 6 | Pseudo terminal | terminal windows through `tvvtrun` (spawn on a pty) | `gdbpty.pas` (opens only the master, hands the slave name to gdb) | `tvpty.pas` (open + spawn) | differs | both open a pty with different needs (fpide: slave name for an external process). Could share the `posix_openpt` part; one user, so left. |
| 7 | System clipboard, text | `winclp.pas` (RIT; lines <-> stream over TvClip), menus use TvClip | editor via tve, `TvClip` | `tvclip.pas`, `tvclipcmd.pas` | shared | |
| 8 | History lists of input lines | via `TvHist` (`mainapp.pas`) | via `TvHist` (dialogs shim, stored in the desktop file) | `tvhist.pas` | shared | `dn/src/histories.pas` is NOT that: it keeps positions of viewed/edited files (the name misleads). |
| 9 | File masks | `fileutil.pas` `InMask`/`InMaskA`/`InFilter` (RIT; DN syntax: `>` extension, `\|` digit, `"` literal, `-` exclusion, `LastSuccessPos` for quick search) | `fputils.pas` `MatchesMask(List)` -> TvWild | `tvwild.pas` (`*`, `?`, `[..]`, `;` lists, `\|` exclusions) | differs | different syntaxes; DN's quick search needs `LastSuccessPos`. A unification means dn translating its syntax to TvWild, not a move. Not done. |
| 10 | File open dialog, change directory | `dnstddlg.pas`, `tree.pas` (RIT, a tree panel, not the dialog) | StdDlg shim | `tvfiledlg`, `tvchdir`, `tvfiles` | shared | `tree.pas` vs `TDirListBox` differs (panel vs dialog list). |
| 11 | Message boxes, input boxes | `messages.pas` (own, DN flags over TvMsgBox/TvInput) | MsgBox shim -> TvMsgBox | `tvmsgbox`, `tvinput` | shared | |
| 12 | Menu bar, boxes, status line | `menus.pas` (RIT, 2141 lines, own TMenuView/TMenuBar/TMenuBox/TMenuPopup/TStatusLine) | `TvMenus` through the Menus shim | `tvmenus.pas` | differs | dn re-implements what tv3 has. RIT code cannot go to tv3, and the way back (dn on TvMenus) is a large dn change with behaviour risk: not judged in depth, not done. |
| 13 | Colour selection dialog | `colors.pas` (RIT), `palettes.pas` (RIT, dirty) | via ColorSel shim | `tvcolorsel.pas` | shared | dn keeps its palette files (`*.pal`); fpide keeps colours in its ini. Not the same data. |
| 14 | Help | `dnhelp.pas` (RIT), `helpkern.pas`/`helpfile.pas` (15-19 line stubs) over `TvHelp` | `fphelp`, `whelp`, `whlpview`, `whtml*`, `wnghelp`, `woahelp`, `wos2help`, `wwinhelp`, `wvphelp`, `wtphwrit`, `wchmhwrap` (GPL) | `tvhelp.pas` (+ `tools/tvhc.pas`) | differs | different file formats and viewers; fpide does not use TvHelp. Licence blocks anything from the fpide side. |
| 15 | Key names <-> key codes | `evnames.pas` (generated, for the log); key names in `macro.pas` (RIT, dirty) | `fptools.pas` `GetHotKeyName` (GPL) | `tvkeyname.pas` | differs | `TvKeyName` is used by nobody yet. Candidate adopters: dn `macro.pas` (dirty: blocked until dn is free), fpide `fptools` (own GPL table). Not equivalent output formats, not done. |
| 16 | Shortcuts in other keyboard layouts | `keymap.pas`, `iniengine.pas` use TvXlat | not used | `tvxlat.pas` | keep | a gap in fpide, not a duplicate. |
| 17 | "Learn keys" dialog | none | `fpkeys.pas` (GPL) | none | keep | |
| 18 | ASCII table | `asciitab.pas`: subclasses of the TvAscii views (DN key codes, the byte of data, the report text, title, help context, gray window, stream records, the modal run) | `fpviews.pas` `TFPASCIIChart` over `TAsciiChart` in the Unicode mode (the pick goes into the edit window); `compat/asciitab.pas` removed | `tvascii.pas` (table, report, window; code page or Unicode blocks; `OnPick` and a command; hooks for the text of a cell and the palette; stream records) | shared | done (2026-10-08): fpide gained the pick and the hex / U+ report; tests: `t_ascii`, pty `test_ascii.py` (tvdemo Tools > ASCII table). |
| 19 | Heap / clock gadgets | `gadgets.pas` (RIT; `TTrashCan`, `TKeyMacros` unchanged): `TClockView` is a subclass of the TvGadgets clock with the options of dn.ini, the time format of the country, the macro mark, Shift / Ctrl shows the memory / the date, the calendar and the drag; `THeapView` is the TvGadgets one | `TFPClockView`, `TFPHeapView` over the TvGadgets views; `compat/gadgets.pas` removed | `tvgadgets.pas` (`TClockView`: seconds, blinking separator, 12/24 h, format hook, margins, width follows the text, right alignment, click hook, redraw only on a change; `THeapView`) | shared | done (2026-10-08); tests: `t_gadgets`, pty `test_ascii.py` (tvdemo `/clock`). |
| 20 | Calculator / expression evaluator | `evaluator.pas` (DN/2 licence), `calcwin.pas`, `calcline.pas` (RIT, spreadsheet) | `fpcalc.pas` (GPL desk calculator), `fpevalw.pas` (debugger evaluate window) | none; **tve** has `tvecalc.pas` (MIT) | differs | not a duplicate: dn evaluates typed expressions (a calculator line, a spreadsheet), fpide has a desk calculator with buttons and the evaluation of the debugger (gdb does the work). No function is the same on both sides. |
| 21 | Calendar | `calendar.pas` (DN OSP) | none | none | keep | |
| 22 | Directory/file change watching | `dirwatch.pas`, `dbwatch.pas` | none (tve: `TveDiskChanged`, one stat call) | none | keep | `SHARED-CODE.md` #9 `TvWatch` has no second user. |
| 23 | Flight recorder, crash report | `flightrec.pas`, `dnerrlog.pas`, `fatalerr.pas` (own MIT) | `fpcatch.pas` (GPL: signals, Ctrl-C), `fp.pas` exit hook | none | keep | one-sided (`TvFlight` #7 has no second user). |
| 24 | Per-user config directory | `cfgdir.pas` + `OSConfigDir` in `compat/ossystem*.pas` (XDG: `~/.config/dn`, `%APPDATA%\DN`, migrates old files) | `fpini.pas` (`~/.fp`, `%APPDATA%/fp`, the IDE's own rules) | none | differs | same idea, different policy; a `TvConfigDir(AppName)` would change fpide's location (tests and users rely on `~/.fp`): owner decision. |
| 25 | Desktop save/restore | `dnutil.pas` (RIT) | `fpdesk.pas` (GPL) | stream registry in `tvobjs` | differs | the only shared part, the stream registry of the views, is already in `tvobjs`; the files themselves have different formats and contents. Nothing to move. |
| 26 | External tools menu with macro expansion | `usermenu.pas`, `macro.pas` (RIT) | `fptools.pas` (GPL) | none | differs | same feature, different syntax and data files. |
| 27 | Text editor | `editcore/editfile/editinfo/editwin.pas` | `weditor.pas`, `wcedit.pas` | tve (separate repo) | shared | see "Method". |
| 28 | Syntax highlighting | `highlite.pas` (RIT) next to `TveHl` | `TveHl` through tve | tve | differs | dn still has a second highlighter (used by the viewer); not compared. |
| 29 | Borland `Drivers` API on tv3: `GetAlt*`, `GetCtrl*` | `compat/drivers.pas` (delegates) | shim map -> `TvUtil` | `tvutil.pas` | shared | |
| 30 | `CStrLen` (length of a `~`-text) | `compat/drivers.pas` had a copy | shim map -> `TvUtil` | `tvutil.pas` | shared | **done in this change:** dn's copy was line-for-line the same as `TvUtil.CStrLen`; it now calls it. |
| 31 | Next key event without waiting (`GetKeyEvent`) | `compat/drivers.pas` (loop that drops mouse events) | `shims/manual/drivers.impl.inc` (one poll, drops anything else) | **`TvSys.PollKeyEvent` (new)** | move | **done in this change:** dn's loop (MIT, ours) became `TvSys.PollKeyEvent`; both `GetKeyEvent` call it. fpide's old version lost the key if a mouse event came first. |
| 32 | `Move*`, `MoveCStr`, cell helpers over `TScreenCell` | `compat/drivers.pas` (via `TDrawBuffer`; BIOS attr 0 = set black) | `drivers.impl.inc` (own `PutUtf8`; attr 0 = keep) | `tvdrawbuf.pas`, `tvcell.pas` | differs | same API, different handling of attribute 0 and of wide/combining characters; unifying changes drawing in one product. Not clearly equivalent. |
| 33 | `FormatStr` (Borland `%d %s %c %x` with a slot array) | `compat/drivers.pas` `FormatStr` calls `TvFormat.FormatStr` | `drivers.impl.inc` `FormatStr` calls `TvFormat.FormatStr` | **`tvformat.pas` `FormatStr` (new)**, with the `array of const` overload that `tvmsgbox.pas` uses | move | **done in the dedup pass of 2026-10-08.** One behaviour for both: pointer-sized slots (both callers already used them; a number is the low 32 bits of its slot), `%s %d %u %x %X %c %%`, `-` and `0` flags, a width that never cuts the text, unknown items kept as they are. Visible changes: dn: `%04d` now fills with zeros (the dBase date of `dbview` was written with spaces), `%3c` no longer hangs; fpide: `%x` is lower case (`%X` upper), a width no longer cuts a longer text or number, `%u` works. |
| 34 | Lifecycle no-ops (`InitEvents`, `DoneEvents`, `ShowMouse`, `HideMouse`, `InitSysError`, `DoneSysError`, `ButtonCount`, `DoubleDelay`...) | `compat/drivers.pas` | `drivers.inc/impl.inc` | none | keep | empty procedures and variables kept so old call sites compile; moving them to tv3 would add Borland API noise to the library. |
| 35 | Collections (sorted/string/unsorted/int/line) | `shims/manual/collect.inc` (long strings, `Sort`, `TLineCollection`...) | `wutils.pas` (GPL: `TUnsortedStringCollection`, `TIntCollection`, `TNoDisposeCollection`...) | `tvobjs.pas` (base classes) | differs | different element types and APIs. |
| 36 | Stream helpers (null/sub/fast buffered, read line) | `streams.inc` shim | `wutils.pas` (GPL) | `tvobjs.pas` | keep | fpide only: dn has no null, sub or line-reading stream (checked again in the dedup pass of 2026-10-08). |
| 37 | CRC-32 | none (`envutil.pas` `GetCrc` had no caller: removed with its table in `linepos`/`basics`) | `fpini.pas` uses `TvCrc.Crc32Str` (the copy `compat/fpc/fpccrc.pas` removed) | **`tvcrc.pas` (new)** | move | **done in the dedup pass of 2026-10-08.** `filecopy.pas` keeps its CRC-16 (another checksum). |
| 38 | Date/time to text | `strutil.pas` `FormatDateTime(DT, Time)` with `CountryInfo`; `drives.pas` | `wutils.pas` `FormatDateTime(D, 'dd/mm/yy..')` (GPL) | none | differs | different signatures and rules. |
| 39 | File copy/erase/rename | `filecopy.pas` (RIT, full copier with progress), `fileutil.pas` `EraseFile` | `wutils.pas` `CopyFile`, `fputils.pas` `EraseFile`/`RenameFile` | `tvfiles.pas` has none | differs | fpide's are 10-line wrappers around `SysUtils` with IDE error handling (GPL). |
| 40 | Path helpers (expand, split, current dir) | `lfn.pas`, `compat/dnpath.pas` (own MIT, DOS-style paths) | `wutils.pas` (`DirOf`, `NameOf`, `CompletePath`, `GetCurDir` with trailing slash), `fputils.pas` (GPL) | `tvfiles.pas` (`FExpand`, `FSplit`, `GetCurDir`) | differs | `wutils.GetCurDir` differs from `TvFiles.GetCurDir` (trailing separator, no DOS-name conversion). The helpers that are the same on both sides (a trailing separator, the directory or the name of a path) are in the RTL (`SysUtils`), so a tv3 unit would add nothing. |
| 41 | Strip `~` from a menu text | `archset.pas`, `pktview.pas` call `TvCStr.StripTilde` | `fputils.pas` `KillTilde` removed; its 13 callers call `TvCStr.StripTilde` | **`tvcstr.pas` `StripTilde` (new)** | move | **done in the dedup pass of 2026-10-08.** dn `menus.pas` deletes only the first `~` (another operation): left. |
| 42 | Tick counter / timers | `timeutil.pas` (RIT, `TEventTimer`) | `GetDosTicks` in the drivers shim | `tvtimer.pas` (used by nobody), `TvSys.ClockMs` | differs | `TvTimer` is not adopted by either product. |
| 43 | ANSI | none | `wansi.pas` (GPL, reads ANSI art for the desktop) | `tvansi.pas` (writes escape sequences) | keep | opposite directions. |
| 44 | User screen / output of the run program | `usersavr.pas` (RIT), `compat/dnscreen.pas`, `osstartscreen.pas` | `fpusrscr.pas` (GPL) + `UnixSuspend/UnixResume` | `tvunix.pas` suspend/resume | shared (backend) / differs (the screen copy) | both take the terminal from tv3; the copies of "what was on the screen" differ. |
| 45 | Tree / outline view | `tree.pas` (RIT, directory tree) | `compat/outline.pas` (own, `TOutline` for the symbol browser) | none | differs | |
| 46 | Tab control, timed dialog | none | `compat/tabs.pas`, `compat/timeddlg.pas` | none | keep | one user. |
| 47 | Shim generator (`gen-shim.py` + `shims.map` + `manual/*.inc`) | `dn/compat/shims` | `fpide/compat/shims` | `tvgeom`..., names | shared (tool) / differs (manual parts) | the generator is the same; the manual parts follow rows 32-36. |
| 48 | Config of window/viewer positions | `histories.pas` | in `fpdesk.pas` | none | differs | see row 8. |

### Counts

48 rows: **shared 13** (rows 1, 2, 4, 7, 8, 10, 11, 13, 27, 29, 30, 44, 47; rows 44 and 47 are partly "differs", counted
as shared because the common part is the point of the row), **duplicate: move 4** (rows 31, 33, 37, 41, done), **similar but different 20**,
**keep 11**. Row 30 (`CStrLen`) was a second, smaller duplicate inside dn only (dn against tv3), also fixed. Everything else
that looks like a duplicate is either not equivalent (the behaviour differs in ways a user or a test can see) or blocked by the licence.

### Licence blocks the move (the code exists on both sides or is wanted by both, but the source is not MIT)

- everything fpide takes from the Free Pascal IDE (GPL/LGPL): `wutils`, `fputils`, `fpredir`, the help readers, `fpcalc`, `fptools`,
  `fpdesk`, `fpkeys`, `fpusrscr`, `wansi`;
- everything dn takes from DN-OSP/RIT: `menus`, `gadgets`, `histories`, `inifiles`, `filecopy`, `fileutil` (`InMask`), `strutil`
  (`FormatDateTime`), `timeutil`, `usermenu/macro`, `winclp`, `highlite`; `evaluator.pas` (DN/2 licence);
- for these the rule of `SHARED-CODE.md` applies: a unit can be written under MIT in tv3 and must pass the audit (`tools/audit/borrow-audit.py`),
  never copied.

### Blocked until dn is free

At the time of the audit `git status` of dn showed `dn/src/archiver.pas`, `archset.pas`, `histories.pas`, `macro.pas`, `palettes.pas` and
`data/colors/default.pal` modified by the other agent (later also `colors.pas`, `paneldlgs.pas`, `phones.pas`; the list moves while that work goes on). No duplicate found here needs those files except the optional adoption of
`TvKeyName` by `macro.pas` (row 15), which is therefore "blocked until dn is free" (and not equivalent anyway).

## What was extracted in this change

| Change | tv3 | fpide | dn |
|---|---|---|---|
| `TvSys.PollKeyEvent`: next key event without waiting, non-key events before it dropped | `src/tvsys.pas`, `tests/t_pollkey.pas` (8 checks) | `compat/shims/manual/drivers.impl.inc` `GetKeyEvent` calls it | `dn/compat/drivers.pas` `GetKeyEvent` calls it |
| `CStrLen` of dn = `TvUtil.CStrLen` | - | - | `dn/compat/drivers.pas` delegates |
| `TvCStr.StripTilde` (row 41) | `src/tvcstr.pas`, `tests/t_cstr.pas` | `KillTilde` removed, callers switched | `archset`, `pktview` |
| `TvCrc.Crc32` (row 37) | `src/tvcrc.pas`, `tests/t_crc.pas` | `fpini` uses it, `compat/fpc/fpccrc.pas` removed | the unused `GetCrc` and its table removed |
| `TvFormat.FormatStr` (row 33) | `src/tvformat.pas`, `tests/t_format.pas` | `FormatStr` of the drivers shim calls it | `FormatStr` of `compat/drivers.pas` calls it |

Verification: all 56 tv3 unit tests (55 existing + the new `t_pollkey`) (`tests/t_*.pas`, fpc -Mobjfpc -Fusrc -Fisrc) pass; dn builds (`tools/build.sh linux64`),
`dn-linux-ops.py` with `DN_OPS_UTF8=1` 42/42, `tools/dn-test.sh` all `ALL OK`; fpide builds (`tools/build-fpide.sh linux64`, with
`fpide/tv` pointing at the working tree of tv3) and `test_functions.py` 245 checks, 0 failed.

## Suggested next steps (not done, with the reason)

1. Decide the config directory policy for fpide (row 24); then a `TvConfigDir` is a ten-line function.
2. dn onto `TvMenus` / `TvIni` (rows 1, 12): removes RIT code from dn rather than adding to tv3; large, owner decision.
3. `TvKeyName` has no user; either adopt it in dn `macro.pas` or drop it from the plan.
