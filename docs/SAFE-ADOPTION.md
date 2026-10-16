# Better Pascal in tv3: integration inventory and contract (step 1 of unxed/tv3#3)

This document is the result of step 1 of [unxed/tv3#3](https://github.com/unxed/tv3/issues/3): a read-only inventory of tv3 against the
current specification of Better Pascal ([unxed/bp](https://github.com/unxed/bp), `safe/SPEC.md` v0.6, `safe/DN-ADOPTION.md`,
`safe/FPIDE-ADOPTION.md`). No source file was changed. Every decision names its evidence (file, count, or SPEC section); what could not be shown
without a build is marked **unverified** and is given to the step that can verify it in CI.

- tv3 baseline of this inventory: `main` at `c092ee6` (16-10-2026). The stable snapshot named in the issue is `stable-20261015`
  (`770f8914224c49af7db1d8f5aa0c0017ed77d593`); `main` has moved on since (native AArch64 job), the contract below is checked against `main`.
- bp baseline: `unxed/bp` `main` at `7a258b027f2a468d698e86ea5d7d4a74cc029116` (SPEC v0.6).
- Counts are textual (lines of `src/*.pas` and `src/*.inc` that match a pattern, comments included). They show the shape of the code, not exact
  defect numbers, and are not a CI gate.

## 1. Decisions

| # | Decision | Evidence |
|---|---|---|
| D1 | Steps 2 and 3 use the **safe layer, `unit Safe`**, not `BP`. | Section 4: `BP` changes the default string encodings when it is initialized; the public API of tv3 is `ShortString`. |
| D2 | `Safe` reaches the tv3 units as source files inside `src/` (a pinned copy of the files of `unxed/bp` `safe/`), not as a submodule and not as an external `-Fu` path. This needs the owner's decision first (D9). | Section 5. |
| D3 | The first pilot unit is `TvTimer` (`src/tvtimer.pas`, 185 lines). | Section 6. |
| D4 | `BP` (goroutines) is adopted only in steps 4 and 5, only in new opt-in units, and never in a unit that `unxed/dn` or `unxed/bp/fpide` link by default. | Section 7. |
| D5 | The first structured-concurrency candidate is the child-process runner of `TvClipCmd` (`RunProcess`), Unix only. | Section 9. |
| D6 | Units compiled with `{$H-}` (every unit that includes `tvdefs.inc` and does not say `{$H+}`) are not flipped to `{$H+}`. The public `ShortString` API is a contract. | Section 8. |
| D7 | Backends that talk to the OS (`TvDos`, `TvTermOsUnix`, `TvTermOsWin`, `TvUnix`, `TvPty`) are unsafe units with a marker and a facade, not a rewrite. | Section 3. |
| D8 | DOS keeps the synchronous path and compiles no goroutine code; Windows and other platforms get no claim until a CI job runs on them. | Section 10. |
| D9 | The owner decides, before step 2, whether a copy of the MIT-licensed `safe/` files may be added to `src/` with a notice in `THIRD-PARTY-NOTICES.md`. | `CLAUDE.md` rules 1 and 5 (legal texts change only by the owner's decision). |

## 2. What tv3 is made of (inventory)

70 units in `src/` (`*.pas`), plus include files. Matching lines in `src/*.pas` and `src/*.inc`:

| Measure | Lines | Where it concentrates |
|---|---|---|
| `ShortString`, `string[N]` | 497 | the whole public API (`DESIGN.md`, rule 5) |
| `GetMem`, `FreeMem`, `ReallocMem`, `AllocMem` | 55 | `tvviews` 11, `tvhelp` 8, `tvobjs` 7, `tvinput` 6 |
| `Move`, `FillChar`, `FillByte/Word/DWord` | 124 | `tvobjs` 14, `tvdos` 11, `tvtextview` 8, `tvviews` 7, `tvcell` 7 |
| `.Free`, `FreeAndNil` | 87 | `tvobjs` 13, `tvmenus` 10, `tvapp` 8, `tvhelp` 6, `tvini` 5 |
| `New(`, `Dispose(` | 25 | `tvtimer` (the timer list), streams |
| `object` | 14 | the class migration is done (`DESIGN.md`, rule 2); the hits are comments and words |
| `Pointer`, `PChar`, `PAnsiChar`, `PByte` | 470 | public handles (`TTimerId = Pointer`), streams, backends |
| threads (`BeginThread`, `TThread`, `cthreads`, critical sections, `RTLEvent`) | 0 | none in `src/` |
| `external` declarations | 0 | tv3 uses the RTL units (`BaseUnix`, `Unix`), not libc imports |

Unit modes: every unit that includes `src/tvdefs.inc` gets `{$mode objfpc}{$H-}{$modeswitch advancedrecords}`; only `tvclip`, `tvclipcmd`,
`tvfar2l`, `tvvtext` and `tvlocale` say `{$H+}`. So `String` is a `ShortString` in almost all of the library.

Class model: `class` with `Create`/`Destroy` (`DESIGN.md`, rule 2). `SPEC.md` section 19 (`object` types) therefore does not apply to tv3.

## 3. Ownership patterns

| Pattern | Where | Mapping to the safe layer |
|---|---|---|
| A linked list of `New`/`Dispose` records, handed out as opaque `Pointer` ids | `tvtimer.pas` (`PTimer`, `SetTimer`, `KillTimer`, the destructor) | node class owned through `TOwned`, one marked unsafe line for the opaque id (pilot, section 6) |
| Views inserted into a group; the group frees them | `tvviews`, `tvmenus`, `tvdialog`, `tvwindow`, `tvapp` | not owned by the code that creates them: fields get `// borrow: group` (S5). `TOwned` there would be a double free. **Unverified** per unit; step 3 reads each unit before it marks anything. |
| Streams and the registry of streamable classes | `tvobjs.pas` (`Move`/`FillChar` and `.Free` in the hot spots) | a "format layer" in the sense of `safe/DN-ADOPTION.md` stage 5: stays unsafe behind its facade until a unit decision is made |
| Byte buffers with `GetMem` | `tvviews`, `tvhelp`, `tvinput`, `tvdrawbuf`, `tvcell` | `TSlice`/`TArena` where the buffer has one owner; `// UNSAFE:` where a backend needs the raw address |
| OS boundary | `tvdos` (video memory, INT calls), `tvtermosunix`/`tvtermoswin`/`tvunix`/`tvpty` (poll, ioctl, fork, signals) | `// UNSAFE-UNIT:` plus a safe facade (decision D7) |

## 4. Which layer: `Safe` or `BP`

| | `unit Safe` (`bp/safe/`) | `unit BP` (`bp/bp.pas`, `bp/ext/`) |
|---|---|---|
| Adds | ownership, slices, arena, defer, FFI, poisoned primitives (SPEC sections 4 to 7) | the same plus UTF-8 by default and goroutines (SPEC sections 3 and 14) |
| Global effect | none: the encodings are left as they are (`safe/README.md`) | the `initialization` of the unit sets the default string encodings to UTF-8; on Linux the build is static without libc by default (SPEC section 18) |
| Position in `uses` | last in every module | first in the program file, last in the other units |
| Needs | `SysUtils` (its `uses` clause) | `ext/bpthreads.pas`; a thread manager that must run before `SysUtils` |

Reasons for D1 and D4:

1. The public API of tv3 is `ShortString`, internally UTF-8 bytes, with the `TvCodePage` setting (866 by default) for invalid UTF-8
   (`DESIGN.md`, rule 5; `src/tvdefs.inc`). A change of the default encoding by `BP` is a behavior change that has nothing to do with ownership, so
   it must not arrive as a side effect of a safety step (issue, "Baseline and constraints"). Whether the unit tests of the encodings
   (`t_cpall`, `t_charset`, `t_utf8`, `t_ustr`, `t_locale`) stay green with the `BP` initialization linked in is **unverified**; step 4 runs them
   in CI before any `BP` unit is allowed into a program.
2. `BP` must be first in the `uses` of the **program file** when goroutines are used, otherwise the first `Go` stops the program (code 211,
   SPEC section 14). The programs of `unxed/dn` and `unxed/bp/fpide` are not changed by this issue, so goroutines cannot be a default of the library: they
   are opt-in (D4, section 7).
3. tv3 has no threads and no libc imports today (section 2), so the libc question that blocks `BP` in fpide (`gdbpty.pas`) does not exist in tv3.

## 5. How the source and the version are supplied

Facts:

- `unxed/dn` takes tv3 as the submodule `tv` (`dn/.gitmodules`) and puts `tv/src` on the unit path (`dn/tools/build.sh`, for example line 97: `-Fu"$here/tv/src"`).
- `unxed/bp` takes tv3 as the submodule `fpide/tv` (`bp/.gitmodules`; pinned at `9f153cb0e4060ba57c43c3b1299963997ed923d1` when this was read) and builds
  with `-Fu$here/tv/src -Fi$here/tv/src` (`bp/fpide/tools/fpide-env.sh`, lines 34 and 36). It adds no path to `bp/safe`.
- Both consumers therefore see exactly one thing of tv3: the directory `src/`.

Options:

| Option | Result | Verdict |
|---|---|---|
| Submodule `unxed/bp` inside tv3 | a cycle: `bp` contains `fpide/tv` (tv3), which would contain `bp`; and every consumer's recursive checkout pulls a second copy | rejected |
| `-Fu<path to a bp checkout>` in tv3's CI and scripts only | tv3 builds, but a migrated unit with `uses Safe` does not compile in `dn` and `fpide`, which would have to add a path: changes to both repositories, forbidden here | rejected |
| A pinned copy of the `safe/` source files in `src/` | `-Fu tv/src` already finds them; no consumer changes; the version is the file content plus a recorded bp commit | **chosen**, needs D9 |
| `{$IFDEF TV_SAFE}` around `uses Safe` | two code paths per unit, the default build is not the checked one | rejected |

Contract for the copy (to be done in step 2, after D9):

- Files: `safe.pas`, `core.intf.inc`, `core.impl.inc`, `poison.intf.inc`, `poison.impl.inc` of `unxed/bp` `safe/`, MIT (SPDX header in each).
  `unit BP` and `ext/` are **not** copied (D1, D4).
- The bp commit the copy was taken from is recorded in one place (a pin file read by a CI check), and the copy is refreshed only by a PR that changes
  the pin and shows the diff.
- tv3's tests use 8.3 file names (`DESIGN.md`, rule 8) so that they run under DOS; names such as `core.intf.inc` are not 8.3 names. Whether the DOS
  tests (`dostests/`, DOSBox-X only, not in CI) can include such files is **unverified**; step 2 either renames the includes (and records the
  rename in the pin) or states that the DOS build of a Safe unit is not verified.
- `tools/audit/run.sh` is run before the push of the copy (`CLAUDE.md`, rule 4) and must print `AUDIT PASS`.
- The `Safe` unit in `src/` must not change what `dn` and `fpide` compile today when they do not use it: `tools/test.sh` builds every unit of `src/`
  into one program (`allunits`), and the library job compiles every `src/*.pas` (`ci.yml`), so both pick the copy up without a change to `ci.yml`.

## 6. The first pilot: `TvTimer`

Why this unit (D3): 185 lines; depends only on `TvSys` and `TvScreen`; its users are `tvapp`, `tvviews`, `tvdialog`, `tvvtview` (through the timer
API) and the tests `t_timer`, `t_app`, `t_dialog`; it has the ownership risk in a small space (a hand-made singly linked list of records created
with `New`, destroyed with `Dispose` in `Destroy`, `KillTimer`, and `CollectExpiredTimers`, which also frees a one-shot timer while the callback may
change the list); it has no strings; it has a focused test with a heap check (`t_timer.pas` compares `GetFPCHeapStatus.CurrHeapUsed` before and after,
line 95) and an injectable clock (`TClockProc`), so the test is deterministic; and no part of it touches a screen or the OS.

Target shape (a decision, not code): the nodes become class instances held by an owner (`TOwned`), the queue owns the list, `TTimerQueue.Destroy` releases the list
through the owner, and the unit says `uses ..., Safe;` last. The public contract stays exactly as it is: `TTimerId = Pointer`, `TTimerProc`,
`SetTimer`, `KillTimer`, `CollectExpiredTimers`, `TimeUntilNextTimeout`, `Clock`. The opaque id is the one place that needs `System.Pointer` (S4) and gets a
`// UNSAFE:` line with the reason (the id is only compared, never dereferenced outside the unit). `KillTimer` with an id that is not in the list must
keep doing nothing (today it searches the list and does nothing when the id is absent).

Not chosen for the pilot: `TvObjs` (streams, 14 raw `Move`/`FillChar` lines, the registry; large and a base of everything), `TvViews` (borrows from a group,
not owned), `TvDos` and the terminal OS units (unsafe by nature).

## 7. The event path and the `TvSys` hooks (what concurrency has to respect)

- `TvSys` is a set of hook variables set by a backend before the application is created: `OnPollEvent`, `GetClockMs`, `OnSetVideoMode`, `OnSuspend`,
  `OnResume`, `OnNotify` and others (`src/tvsys.pas`). `OnPollEvent(TimeoutMs, Event)` waits at most `TimeoutMs` (-1: for ever) and returns an event or
  `evNothing`; mouse events have priority over key events.
- `TEventQueue` (in `tvsys.pas`) keeps the events a backend gives in a small queue: `GetMouseEvent`, `GetKeyEvent`, `WaitForEvents`, `SetPasteText`.
- `TProgram.GetEvent` (`src/tvapp.pas`, line 793) takes `Pending` first; otherwise `WaitForEvents(EventWaitTimeout)`, then a mouse event, then a key event,
  then `Idle`; the status line sees key and mouse-down events; `cmScreenChanged` is turned into `SetScreenMode(smUpdate)`. This is the one order of events
  that must not change in step 5.
- Backends that set `OnPollEvent`: `TvMem` (`tvmem.pas`, the tests), `TvDos` (`tvdos.pas`), `TvUnix` (`tvunix.pas`). `TvUnix` reads through `TvTermOs`: `TvTermOsUnix`
  (`FpPoll`, termios, signals), `TvTermOsWin` (console records, Windows only, compiled by the `windows-x86_64` job only), `TvTermOsNone` (no OS).
- `TvMem` supplies a script of events (`MemKey`, `MemMouse`, `MemEvent`) and a clock (`MemClock`); when the queue is empty the clock advances by the timeout asked
  for, and more than `MemMaxIdle` (500) empty polls in a row stop the program. This is the deterministic base for the step 4 and 5 tests.
- The timers are polled from the same loop (`TTimerQueue.TimeUntilNextTimeout`), and the screen is drawn by the loop's thread: there is no other thread
  today (section 2).

Contract for steps 4 and 5: UI drawing, view state and timers stay on the thread of `TProgram`. A task never touches a view; it hands a value to the loop
(an event through the existing queue, or a channel the loop drains in `Idle`/`GetEvent`). The goroutine code lives in new units that a program imports only
by choice (D4): a consumer that does not import them links no thread manager and behaves exactly as now.

## 8. Public API and string compatibility checks

These checks are the entry condition of step 2 and the content of the final gate (step 6). Each one has an observable result.

| # | Check | How | Status |
|---|---|---|---|
| C1 | No public signature changes | the existing `tests/t_*.pas` are not edited by a migration step (a PR may add tests; a diff that edits an existing test needs a written reason); all units still build in the `linux` job | rule for every step |
| C2 | `uses Safe` in a `{$H-}` unit accepts `ShortString` values | a throw-away probe unit in CI that includes `tvdefs.inc`, passes a `ShortString` to a `Safe` API that takes `String`, and records the result in the issue (the same open question is recorded in `FPIDE-ADOPTION.md`, section 5) | **unverified**; step 2 |
| C3 | Modes do not leak between units | FPC modes are per unit; `Safe` is compiled with `{$mode objfpc}{$H+}` and tv3 units with `{$H-}`; the build of the pilot is the proof | step 2 |
| C4 | The text and code-page behavior is the same | `t_cpall`, `t_charset`, `t_utf8`, `t_ustr`, `t_locale`, `t_text`, `t_ux` pass unchanged; for `BP` the same set is run with the `BP` initialization linked in (section 4, item 1) | `Safe`: no global effect (`safe/README.md`); `BP`: **unverified**, step 4 |
| C5 | Terminal behavior is the same | the `pty` job: `test_tvdemo`, `test_switcher`, `test_held`, `test_win32input`, `test_tvterm`, `test_vtrun`, `test_clip`, `test_ascii`, `test_far2l` pass unchanged | every step |
| C6 | The DN-facing API is the same | `dn` puts `tv/src` on its unit path; `docs/API-NAMES.md` lists the names; no name is removed or renamed; checked for real in step 6 against the pinned submodule | step 6 |
| C7 | `fpide` is the same | `bp/fpide` compiles tv3 from `fpide/tv/src` (`-Fu`, `-Fi`); step 6 builds it | step 6 |
| C8 | The leak check works | the unit test of a migrated unit ends with `SafeCheckNoLeaks` (SPEC R5) in addition to the heap check that `t_timer` already has | step 2 |
| C9 | A forbidden primitive in a safe unit fails the compiler | a small set of negative compile files in the style of `bp/tests/safe/compile/mf_*.pas` (`GetMem`, `Move`, `.Free` with `uses Safe` last) run by a script in `tools/`, expected to fail to compile, wired into the `linux` job | step 2 |
| C10 | "Safe last in `uses`" does not regress | a ratchet like `tools/paths-baseline.txt`: the list of migrated units; a script fails when a listed unit does not end its `uses` with `Safe` | step 2 |

## 9. Concurrency candidates and cancellation today

| Operation | Where | How it runs now | Cancellation and shutdown today |
|---|---|---|---|
| Clipboard through the programs of the system | `TvClipCmd.RunProcess` (`tvclipcmd.pas`, Unix) | `fpFork`/`FpExecve`, a non-blocking pipe read with `FpPoll`, then `FpWaitPid(WNOHANG)` with `Sleep(5)` | a program that takes more than 1.5 s is killed (the header of the unit; `Deadline` in the loop); the test `t_clipcmd` uses fake programs in `PATH` |
| Child process in a terminal view | `tvpty.pas` | `fpFork`, `fpWaitPid` (blocking and `WNOHANG` forms, lines 213 and 215) | by the owner of the view |
| Event wait | `TvTermOsUnix` (`FpPoll`), `TvDos`, `TvMem` | one blocking wait with a timeout in the UI thread | the timeout; `TvMem` stops after `MemMaxIdle` empty polls |

Decision D5 for step 4: the pilot is `RunProcess` of `TvClipCmd`. It is backend-neutral (it has no screen), it is Unix only, it has a deterministic test that
needs no real clipboard program, and it already has a deadline, so the new structure can be compared with the old behavior. The synchronous functions
`ClipCmdSet` and `ClipCmdGet` stay as the compatibility wrapper that `TvUnix` calls (`tvunix.pas`, lines 275 and 292). Step 4 adds the task, its owner, cancellation, the timeout, the
error value and the shutdown, and tests them; a "no child process remains" check is made by pid.

## 10. Platforms and the fallback where threads are unavailable

| Target | What tv3 CI runs (`ci.yml` at `c092ee6`) | What bp states (SPEC section 2) | Contract |
|---|---|---|---|
| Linux x86_64 | `linux` (library build, `tools/test.sh`), `pty`, `generated` | `Safe`, goroutines and threads tested in bp CI | the only platform for which a step may say "verified" |
| Linux AArch64 | `linux-aarch64` (native runner: library build and the unit tests; no pty) | static aarch64 under qemu, all tests pass | `Safe` units are covered by the native unit tests; async units get the unit tests only |
| Windows x86_64 | `windows-x86_64`: compiles the units that are not Unix only; **nothing is run** | builds; running not verified | no claim; new code keeps the `{$IFDEF WINDOWS}` branches compiling |
| DOS (go32v2) | none (`dostests/` need DOSBox-X) | `test_safe` passes in DOSBox-X; no threads, `TGroup.Go` raises R8 | **synchronous fallback**: no goroutine unit is compiled for `GO32V2`; `TvDos` keeps its `OnPollEvent` as it is; a DOS run is stated as unverified until a DOS job exists |
| i386 Linux, other Unix, macOS | none | i386 under qemu passes; other Unix uses `cthreads` and libc | no claim |

Rule for steps 4 and 5: a unit that uses goroutines is compiled out on `GO32V2` (the condition the repository already uses is `DEFINED(GO32V2)`, for example in
`tvfiles.pas` and `tvpath.pas`), and its caller selects the existing synchronous routine there. The synchronous routine is not deleted when the async one
arrives. A test of the selection runs on Linux by forcing the synchronous path with a variable of the unit, since there is no DOS job.

## 11. The refined plan for steps 2 to 6

Each step is one PR from current `main`; the required `ci` run must be green on the exact SHA; the issue gets the PR, the tested SHA and the result.

**Step 2. Safe-model pilot (`TvTimer`).** Precondition: D9 (the owner's decision on the copy of `safe/`).
Content: the pinned copy of the `safe/` files in `src/` and the pin file (section 5); `tvtimer.pas` migrated as in section 6 with `uses ..., Safe;` last and
`{$WARN SYMBOL_DEPRECATED ERROR}`; `t_timer` gains `SafeCheckNoLeaks`; checks C2, C8, C9, C10 added; `tools/audit/run.sh` run.
Ready when: all jobs of `ci` are green on the PR SHA; `tvtimer` compiles with `Safe` last and with the warnings as errors; the negative compile files fail to
compile and a `System.`-qualified call compiles; `t_timer`, `t_app` and `t_dialog` pass with no edit of existing checks; the PR lists every remaining
`// UNSAFE:` line with its reason; the C2 result is written in the issue.

**Step 3. Safe-model migration.** Small PRs, one ownership boundary each, in this order: (a) values (records and arrays with no owner problem: `tvcell`, `tvdrawbuf`
candidates by the counts in section 2); (b) owned objects (`.Free` locals, for example `tvini`, `tvhelp`); (c) shared and back references with `// borrow:` marks (the
view and group units, after a unit-by-unit reading); (d) arenas (registries); (e) non-memory resources with `TDefer` (terminal raw mode in `TvTermOs`, file handles).
Units of decision D7 get `// UNSAFE-UNIT:` and a facade instead of a rewrite. Every `{$H-}` unit is either migrated after C2 is answered, with its tests, or listed as
an unsafe unit with the reason. The ratchet of C10 grows with each PR.
Ready when: every eligible unit is in the ratchet list or in the list of unsafe units with a reason; the full `ci` is green; the existing tests are unedited.

**Step 4. Structured-concurrency pilot (`TvClipCmd.RunProcess`).** Precondition: the C4 run with the `BP` initialization, and the decision how `BP` is supplied
(it needs `bp/ext/bpthreads.pas` and `bp.pas`, which are not in the pinned copy; the same rules as section 5 apply and need D9 to be extended).
Content: a bounded task with explicit ownership, cancellation, shutdown and an error value, in a new opt-in unit; the synchronous API stays as the wrapper;
the DOS rule of section 10.
Ready when: deterministic tests with fake programs cover success, cancellation, timeout, a task error and shutdown, with no leaked task or child (checked by pid and
`SafeCheckNoLeaks`); `ClipCmdSet`/`ClipCmdGet` behave as before (`t_clipcmd` unedited); `ci` is green.

**Step 5. Asynchronous event architecture.** One event source at a time, each behind its own opt-in switch, default synchronous. The order is chosen by risk:
the source that has no screen effect first (the clock/timer wake-up through `TvMem`), then the Unix input, then the signal sources (resize, suspend, resume).
Each source keeps the order of `TProgram.GetEvent` (section 7), the timer semantics of `TTimerQueue`, and drawing in the UI thread.
Ready when: each migrated source has deterministic `TvMem` tests written before the next source moves; the `pty` job scenarios pass unchanged; the synchronous path
is selected on `GO32V2` and by the test switch; `ci` is green.

**Step 6. Compatibility and adoption gate.** Build `unxed/dn` and `unxed/bp/fpide` against the candidate tv3 SHA (their submodule pointer changed in a throw-away checkout,
nothing pushed to them), run their own test entry points, and record the exact tested submodule SHAs; follow-up work goes to separate issues.
Ready when: both consumers build against the candidate SHA, the full tv3 `ci` is green on it, and the limits (section 8 results, section 10 table, the list of
unsafe units with reasons) are written in this document with the date.

## 12. Open points (not decided here)

1. D9: the copy of `safe/` in `src/`, its notice in `THIRD-PARTY-NOTICES.md` and the effect on `CLAUDE.md` rule 1 (the only foreign source of tv3) are the owner's decision.
2. C2 and C4 are unverified; they are the first things that steps 2 and 4 measure.
3. The DOS file names of the copied include files (section 5).
4. Whether `BP` may be supplied the same way as `Safe` (the thread manager sources are larger, and it must be first in a program file).
