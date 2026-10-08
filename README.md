# tv: Turbo Vision in Free Pascal

A translation into Pascal of the C++ library [magiblot/tvision](https://github.com/magiblot/tvision)
(commit `b4831e2`) using classes (`class`, `Create`/`Destroy`, `TFoo.Create(...)`, `P.Free`) while
keeping the names of Pascal Turbo Vision: `TView.HandleEvent`. The text inside is UTF-8; single-byte strings are shown through a code
page (a setting). Free Pascal 3.2.x; targets: DOS (go32v2), Linux (x86_64, i386, aarch64), Windows (win32, win64).

## Where it comes from

TV was written while reviving DOS Navigator ([unxed/dn](https://github.com/unxed/dn), the DN OSP 2.14 sources, ported to Free Pascal)
on a modern library instead of the old Borland Turbo Vision (whose sources cannot be redistributed). Everything the revival needed from the
library was done here: the translation, the UTF-8 text inside, the backends (DOS, Unix terminals, Windows console, memory), the terminal
emulator view, the help system, the file dialogs. Then the library was split out of `dn` into this repository, because it is useful
without DN: a program on Turbo Vision needs TV, not a file manager.

`dn` uses this repository as the git submodule `tv/`. Nothing here depends on `dn`.

## License

- The translated units are a derivative work of magiblot/tvision, and so of the Turbo Vision 2.0
  release published by Borland: the Borland disclaimer and the MIT license of magiblot apply
  ([`COPYRIGHT.magiblot`](COPYRIGHT.magiblot)). The header of each such unit names the magiblot
  files it was translated from.
- The other units (the backends `TvSys`, `TvMem`, `TvDos`, the terminal units, `TvUtil` in the part that is not a
  translation, the help compiler, the tests, the demos) are under the MIT license ([`LICENSE`](LICENSE)), so that the
  package as a whole has one clear license.
- `dn` links to this repository as a submodule; DN has its own license (see the `dn` repository).
- `tools/audit/borrow-audit.py` compares the sources with the code of other projects (see `CLAUDE.md`); CI runs it.

## Contents

- `src/`: the units (the list and the correspondence to the magiblot files are in [`DESIGN.md`](DESIGN.md), in Russian);
- `tests/`: a test program per unit, `t_<unit>.pas`, on the "in memory" backend (`TvMem`); they run natively and under DOS; `tests/pty/`: tests of the Unix backend in a pseudo terminal (Python);
- `dostests/`: tests of the DOS backend (in DOSBox-X only);
- `demo/`: `tvdemo.pas` (windows, menus, status line; the smallest example) and `tvterm.pas` (a shell in a TV window);
- `tools/tvhc.pas`: the help compiler (`.htx` to `.hlp`, the format of the Borland help compiler).

The backends: `TvDos` (DOS: video memory, BIOS keyboard, INT 33h mouse), `TvUnix` with `TvTermIo`/`TvTermOs` (Unix terminals and the Windows console:
raw mode, ANSI output, key and mouse reports; the terminal protocols are in `DESIGN.md`), `TvMem` (tests). Keys in a terminal: **the far2l terminal extensions** (`TvFar2l`: the terminal sends every key, its release and the mouse as events, takes and gives the clipboard; asked for by default except on `TERM=linux`, `dumb` or empty, `TV_FAR2L=0` never, `TV_FAR2L=1` always), the xterm and Kitty protocols are understood, and the **win32 input mode** (`ESC [ ? 9001 h`: every key and combination of Windows Terminal, conhost, WezTerm...; asked for by default in Windows Terminal, `TV_WIN32_INPUT=1|0` forces it).
The clipboard: `TvClip` keeps the text of the program; the ways to the system clipboard are those of tvision, in its order: the **programs of the system** (`TvClipCmd`:
`wl-copy`/`wl-paste` when `WAYLAND_DISPLAY` is set, `xsel` or `xclip` when `DISPLAY` is set, `pbcopy`/`pbpaste` on macOS, `clip.exe` and a CScript script of Windows under WSL; a program that takes
more than 1.5 s is killed), then the **far2l terminal**, then the clipboard of **Windows** (CF_UNICODETEXT), then the terminal by **OSC 52** (`TV_CLIPBOARD=0` switches that off).
The embedded terminal (`TvVt`, `TvVtView`, `TvVtRun`) is a **far2l extensions server** too (`TvVtExt`): a program that runs in it and switches the extensions on gets the clipboard of the application (after the user's answer in the dialog "Clipboard access"; `TvVtRun` has no dialog: `TV_VT_CLIPBOARD=allow`), notifications, F-key titles, the window requests and the events of keys and the mouse.
Beyond text, `TvClip` keeps several formats (`ClipboardSetItems`, `ClipboardGetItem`, `ClipboardHasItem`, `ClipboardRegisterFormat`; `cfText`, `cfUnicodeText`, `cfHtml`, `VerticalBlockFormat`) — the far2l terminal stores them, elsewhere they stay in the program. Through the far2l terminal: `TvSys.Notify`, `SetFKeyTitles`, `WindowMaxSize`, `WindowMaximize`, `QuickEdit`; `Notify` also works without it (`notify-send`, `osascript`).
A terminal that answers the probes sent at the start (alacritty and foot: `OSC 52 ; ; ?`; kitty: XTGETTCAP `read-clipboard`; xterm: XTQALLOWED `allowWindowOps`) is known to give its clipboard
and is asked for it by OSC 52 without any setting. Text that the terminal pastes itself (bracketed paste) comes as key events with the `kbPaste` flag, line breaks and tabs as text;
`TView.TextEvent` gathers a whole paste into one string (tvision's `textEvent`).
Reading the clipboard of the terminal by OSC 52 (`ESC ] 52 ; c ; ? ESC \`) is on only for a terminal that said (the probes) it can (most terminals refuse, some ask the user): `TV_OSC52_READ=1` asks any terminal, `TV_OSC52_READ=0` none, `TV_OSC52_WAIT` is the wait in ms (400);
a terminal that does not answer is not asked again for a minute. In the embedded terminal (`TvVt`) a program sets the clipboard by OSC 52 and reads it with `?`: the answer comes from the clipboard of the application.
**The keyboard event keeps what the win32 input mode tells** (2026-10-04): besides `KeyCode`, `Text` and `ControlKeyState` a key event has `VirtualKey` (VK_*), `RepeatCount` and `Win32State`
(dwControlKeyState: the left and the right Alt and Ctrl are told apart); where the terminal tells nothing (xterm, Kitty) `EventVirtualKey`, `EventScanCode`, `EventWin32State` and `EventUtf16` work the
fields out from the key code (a US layout). The release of a key is `evKeyUp`: it is made only if a program asks (`TvSys.KeyUpEvents := True`) and the terminal sends it; it goes the way of a key but
only a view with `evKeyUp` in its `EventMask` gets it, so nothing that knows nothing of it changes. The embedded terminal (`TvVt`) takes a program's request `ESC [ ? 9001 h` (`Emu.Win32Input`):
`VtKeyBytes(Event, AppCursor, True)` gives `ESC [ Vk ; Sc ; Uc ; Kd ; Cs ; Rc _` for every key and release (a pair of such sequences above U+FFFF), and `TvVtView`/`TvVtRun` ask the backend for the releases.
DOS: the clipboard is WinOldAp (INT 2Fh 17xx); if the provider `DOS-UTF8/CLIPBRD` is there (AMIS, INT 2Dh: go2dos, DOSBox-X with the patches) the text goes as UTF-8 and nothing is lost to the
code page (`TV_DOS_UTF8_CLIP=0` keeps CF_OEMTEXT); `AmisFind`/`AmisSetEncoding` of `TvDos` find a provider and switch an encoding on for the process (`DosInit` uses them for `DOS-UTF8/NAMES` too: the file names go as UTF-8, `TV_DOS_UTF8_NAMES=0` keeps the code page; a program with a code page inside turns its names with `TvDosNames`).
**The keyboard protocol of Kitty** (2026-10-04): the outer terminal is asked for the flags 1 and 4 as before; when a program wants the releases (`TvSys.KeyUpEvents`) the flag 2 is set (`CSI = 2 ; 2 u`), repeats are presses, releases are `evKeyUp`.
The embedded terminal takes the flags of a program (`CSI > f u`, `CSI < n u`, `CSI = f ; m u`, `CSI ? u`: `Emu.KittyFlags`) and `VtKeyBytes(..., Kitty)` encodes the keys: 1 (Esc, and the keys with Ctrl or Alt, as `CSI code ; modifiers u`), 2 (the types of events:
`CSI ... ; m : 3 ...` for a release) and 8 (every key as an escape code). Not done: the flags 4 (alternate keys) and 16 (the text of a key), the modifiers Super, Hyper, Meta, Caps Lock, Num Lock.
The embedded terminal: `TvVt` (emulator),
`TvPty` (a pty and the program), `TvVtKeys`, `TvVtView` (the view), `TvVtRun` (run a program on the whole screen and keep what it drew).

## Build and check

From the root of this repository, with `fpc` 3.2.x:

    cd tests
    for t in t_*.pas; do fpc -Fu../src -Fu. $t && ./${t%.pas}; done   # each prints "ALL OK"

This leaves `.o` and `.ppu` files next to the sources; `dn` has a script that builds them aside (`tools/tv-test.sh` in `dn`: `-FU`/`-FE` into a work
directory, another CPU with `TV_FPC` and `TV_RUN`).

Under DOS you need a go32v2 cross compiler and DOSBox-X: `tools/build-fpc-go32v2.sh` and `tools/dos-run.sh` (they live in the `dn` repository, see
`tools/` there; the CI of `dn` runs the whole set of tests, native, DOS, ARM under qemu, Windows).

## How to use it in your project

**A program on the TV API.** Add `src` to the unit path (`-Fu`); in the program use `TvApp` (the application), `TvViews`, `TvWindow`, `TvMenus`,
`TvDialog` and the like, and a backend: `TvDos` under DOS, `TvUnix` on Unix and Windows, `TvMem` in tests. The minimal example is
[`demo/tvdemo.pas`](demo/tvdemo.pas); `{$I src/tvdefs.inc}` sets the compiler mode (objfpc) the units expect. The unit names are `TvXxx`, not
the Borland names (`Views`, `Dialogs`, `App`...): see the next section if you have code that uses those.

**Code written for the Borland Turbo Vision (the shim units).** DN has about 160 files written for Borland TV, with the legacy view, dialog, application and stream units in its `uses` clauses. To compile
them against this library without renaming everything, `dn` generates *shim units*: units with the Borland names that only give the names of the `Tv*` units. The tools
are in the `dn` repository (not here yet; this is documentation of where they are):

- `tools/gen-shim.py MAP_FILE OUT_DIR [TV_SRC_DIR]`: reads the interfaces of the listed `Tv*` units and writes `UNIT.pas` per shim: a type or a constant becomes an alias
  (the members of an enumeration become constants), a variable becomes `absolute` of the original, a procedure or a function becomes a wrapper. Nothing else is in a shim.
- `dn/shims/shims.map`: the map, one line per shim: `Views: TvGeom TvColors TvKeys TvEvents ... [+OwnUnit] [-Name] [-Prefix*]` (`+Unit` goes to the `uses` only,
  `-Name` is a name that is not given, `-Prefix*` all the names that begin so). It shows which Borland unit became which `Tv*` units (`Views`, `Dialogs`, `App`, `MsgBox`, `StdDlg`,
  the stream and collection shims...).
- `dn/shims/manual/UNIT.inc` and `UNIT.impl.inc`: what is written by hand and included into the shim (the interface part and the implementation part): the names that the
  Borland unit had and `Tv*` has not, or has differently (`defines*.inc`, `collect*.inc`, `views*.inc`, `dialogs.inc`, `streams.inc`; about 500 lines).
- `tools/dn-env.sh` (`dn_gen_shims`): how the shims are generated into a build directory (not committed) and put on the unit path next to `tv/src`.

Differences from Borland TV that the shims cannot hide and that cost time in DN (worth knowing before you start): the fields `Command` and `KeyCode` of `TEvent` are not at the same place (`Message(R, evKeyDown, Key, nil)`
does nothing; DN has `MessageKey` for it); the text of a key is UTF-8 (`Text`, `TextLength`), not only a character; strings can be UTF-8 inside; the screen is 16-bit cells with attributes of
`TvCell`; resources (streams) use `TStreamRec` and deferred pointer fixups (`GetSubViewPtr` of `TView` is deferred, of `TGroup` immediate: a saved desktop depends on it).
The notes on what else was met during the revival are in `docs/MODERNIZATION-GUIDE.md` of `dn`.

**Other things in `dn` that could be reused (not done: only noted):**

- `tools/gen-codepage.py` (makes `src/tvcp.inc`, the tables byte to Unicode for DOS code pages) and `tools/gen-width.py` (makes `src/tvwidth.inc`, the widths of Unicode characters, from the Unicode
  database of Python): the generators of two files of this repository; they live in `dn` for now.
- `dn/src/drivers.pas` (DN's own compatibility layer over `Tv*`: the key code of DN with shift bits, `MessageKey`, double click, the screen of the user) and `dn/src/vpsyslow.pas` (the system layer
  of Virtual Pascal over `TvSys`: file names, the screen, running programs): their license is that of DN, see `dn/PROVENANCE.md` before taking anything.
- The cross compilers: `tools/build-fpc-go32v2.sh`, `build-fpc-i386-linux.sh`, `build-fpc-aarch64-linux.sh`, `build-fpc-windows.sh`: scripts that build an FPC 3.2.2 cross compiler from the sources.
- `tools/pty_screen.py`, `tools/render-dump.py`: a terminal screen for tests in a pty, and a picture of a DOS screen dump.

## History

This repository was split out of [unxed/dn](https://github.com/unxed/dn) (directory `tv/`). Its history is the history of that
directory in `dn` up to `dn` commit `b8f2bd1` (the commits that touched `tv/`, with their original messages and dates, so some
messages mention `PLAN.md` and other parts of `dn`; the hashes differ from the ones in `dn`).

**Development continues here, in this repository.** `dn` no longer has a copy of this code: it uses this repository as the git
submodule `tv/` (the commit recorded in `dn` is the version DN builds with). A change to TV is made and tested here; then `dn` moves
its pointer (`git -C tv pull && git add tv`).

Some comments in the sources and `DESIGN.md` still say `tv/src`, `tv/tests` (the old paths inside `dn`): read them without the `tv/`.
