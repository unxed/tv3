# The asynchronous contract of tv3

This document fixes how a tv3 program may do work in the background while its views stay responsive, in the model of
unxed/vtui: one UI loop, and background tasks that send events into it. The modules of the event-loop core (`TvEvents`,
`TvSys`, then `TProgram.GetEvent` and `Idle` of `TvApp`) implement it; every other module relies on it. It is checked
against `docs/SAFE-ADOPTION.md` (section 7, the event path, and steps 4-6 of unxed/tv3#3) and gate G3 of unxed/dn#170.
The test of the contract is `tests/t_async.pas`.

Names follow `docs/API-NAMES.md`: `TEventQueue.WakeUp` is `TEventQueue::wakeUp` of tvision `system.h`.

## 1. The rules

**(a) The UI is single-threaded.** Every `TView` (and everything a view owns: its group, its draw buffer, the screen,
the status line, the menus) is created, changed, drawn and freed only on the thread of the event loop, the thread that
runs `TProgram.Run`. No other thread calls a method of a view, not even a read.

**(b) The thread-safe surface is exactly three things.** Any thread may call:

1. `TEventQueue.WakeUp` - makes a `WaitForEvents` that is waiting, or the next one, return at once. It can be called
   any number of times; several calls before the loop wakes count as one. It never blocks and never allocates.
2. the task queue - a task hands a message to the loop (`PostMessage` of a task, or a channel of the Safe layer that
   the loop drains). The loop delivers each message as an event on its own thread, in the order of posting; posting
   calls `WakeUp`.
3. the timers - setting and killing a timer of `TTimerQueue` from a task; the timer fires on the loop thread.

Nothing else of tv3 is thread-safe, and nothing else may be called from a task.

**(c) `WaitForEvents` waits for three things.** `TEventQueue.WaitForEvents(TimeoutMs)` returns when input is waiting
(a key, the mouse, a command of the backend), when `WakeUp` was called, or when the next timer is due, whichever comes
first, and at the latest after `TimeoutMs` (-1: no limit). How a backend waits:

| system | input | wake-up |
| --- | --- | --- |
| Unix | the terminal descriptor in `poll` | a self-pipe or an `eventfd`, in the same `poll` |
| Windows | the console input handle | an event object, in the same `WaitForMultipleObjects` |
| DOS | polling of the BIOS and the mouse driver | no threads: `WakeUp` sets a flag that the poll reads (rule f) |
| tests (`TvMem`) | the script of events | a flag; the clock of the script advances as now |

**(d) Nested modal loops work with tasks.** `ExecView` (a dialog, a message box, a menu) runs a loop of its own, and a
task may post while it runs. Every loop, the main one and the nested ones, gets its events through one
`TProgram.GetEvent`, and that `GetEvent` drains the task queue. So a message posted during a modal dialog is delivered
during that dialog, to the views that exist then; it does not wait for the dialog to close.

**(e) Cancel and progress.** A task takes a cancel token: the loop sets it (Esc, a Cancel button, closing the owner
view), the task polls it between units of work and stops. The token is the one of unxed/dn#170 step 1 (`Cancelled`,
`Reason`, `Reset`). A task reports progress only by posting messages (rule b2): the loop turns them into the state of
a progress view.

**(f) DOS has no threads.** On DOS a task is the same object as elsewhere, written as a resumable step (`Start`,
`Step(Budget)`, `Done`, `Cancel`), and `Idle` runs one step of each live task. Posting, the token and progress work the
same way, so a program has one code path for all systems; only the scheduler differs.

**(g) A task never owns a view.** A task that needs to address a view holds only a weak reference to it (`TWeak` of the
Safe layer of unxed/bp, unxed/bp#56), and only to name it in a message. The loop resolves the reference on its thread
when it delivers the message; a view that was freed meanwhile makes the message void, not a crash.

## 2. What the contract does not change

- The order of events that `TProgram.GetEvent` gives today stays: pending event, then mouse, then key, then `Idle`
  (`docs/SAFE-ADOPTION.md`, section 7). Messages of tasks come after the input of the same turn.
- A program that starts no task behaves exactly as before and links no thread manager: the task queue and the timers
  are cheap when empty, and `WakeUp` needs no thread.
- The public string API (`ShortString`) and the `{$H-}` units are not touched (`docs/SAFE-ADOPTION.md`, D6).

## 3. Tests

- `tests/t_async.pas`: `WakeUp` called from a second thread makes a `WaitForEvents` with a long timeout return at once.
  It runs when `TvSys` provides `TEventQueue.WakeUp` (the unit then declares the constant `TvAsyncCore`); until then it
  prints a `SKIP` line with the reason and passes, so that CI stays green and shows what is not yet checked.
- Further checks come with the modules that implement each rule: the task queue in order and from a modal loop (d), the
  token (e), a resumable task driven by `Idle` with no threads (f), a message to a freed view (g).
- A DOS build of the test needs a DOS job in CI, which does not exist yet.
