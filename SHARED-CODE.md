# Shared code of dn and fpide -> tv3 (stage 3 of the plan)

Rule: what both projects use goes here, under MIT, and passes the audit of `tools/audit/borrow-audit.py` (see `CLAUDE.md`).

| # | Area | New tv3 unit | Origin | Status |
|---|---|---|---|---|
| 1 | Borland Drivers API adapter (MoveStr, MoveCStr, CStrLen, FormatStr, GetAlt*...) | - | skipped: only ~10 functions coincide, the rest are bridges of the old API of each project | skipped; FormatStr: see 15 |
| 2 | INI files and settings | TvIni | new unit | done; fpide uses it; dn: profile.pas is an adapter on it (inifiles.pas, iniengine.pas still own) |
| 3 | UTF-8 string helpers (columns, case, copy by column) | TvUStr | merge of dnutf8 + wutf8 (both own) | done in both |
| 4 | Key names <-> codes | TvKeyName | new unit | unit and tests done; not used by dn/fpide yet |
| 5 | Wildcard masks with lists and exclusions | TvWild | new unit | done; fpide uses it; dn InMask has its own syntax, to be compared |
| 6 | Process execution and capture | TvProc | own/MIT osrun* + fpextcomp | done in both (Windows build checked only by CI) |
| 7 | Flight recorder, crash report, config dir | TvFlight | own/MIT (dn) | todo |
| 8 | Combo box, notebook (tabs) | TvCtrls | new unit | todo |
| 9 | Directory/file change watching | TvWatch | new | todo |
| 10 | Progress / "please wait" | TvProgress | new unit | todo |
| 11 | ASCII table, heap/clock gadgets | TvAscii, TvGadgets | own/MIT both sides | todo |
| 12 | Code pages (localecp) merged into TvLocale | TvLocale | BSD-3 (unxed) | todo |
| 13 | Calculator/expression evaluator | TvCalc | new unit | later |
| 14 | DOS names/clipboard/UTF-8 API | TvDos, TvDosNames | NameToDos/NameFromDos, tested on DOSBox-X master (dostests/utf8-names.sh) | done; dn uses it |
| 15 | FormatStr of the Drivers API (% items, pointer-sized slots) | TvFormat | new unit | done; dn and fpide call it from their `FormatStr` |
| 16 | CRC-32 | TvCrc | new unit | done; fpide (`fpini`) uses it; dn had only an unused copy (removed) |
| 17 | The text of a menu item without its '~' marks | TvCStr | new unit | done in both |
| 18 | The form of paths (separator, root, drives, absolute, join, split, expand) | TvPath | new unit | done; the file dialogs and tve use it; `tools/check-paths.py` counts the paths spelled by hand; dn (DnPath) and fpide: todo |
| 19 | The directories of the configuration, data, state and cache of a program (XDG, macOS, Windows, DOS) | TvAppDir | new unit | done; dn (`cfgdir`) and TvFar2l use it; fpide: todo |

Already in tv3 (not duplicated): TvHist, TvClip, TvHelp, TvAnsi/TvVt*, TvPty, TvColorSel, TvLocale, TvCodePg, TvUtf8, TvText,
TvTextView, TvFileDlg/TvChDir/TvFiles, TvMenus, TvDos.

Project-specific (stay in their projects): the file manager, archives, viewers, DBs of dn; the IDE, compiler/debugger glue, help readers of fpide.
The text editor is handled separately: a new MIT editor in unxed/tve.
