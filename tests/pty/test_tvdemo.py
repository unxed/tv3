#!/usr/bin/env python3
"""Tests of the terminal backend through a pty: tvdemo is run in a terminal of 80x25, keys are sent, the screen is
compared. usage: test_tvdemo.py PATH/TO/tvdemo   (tools/pty_screen.py is the terminal)"""
import os
import sys

sys.path.insert(0, os.environ.get('PTY_TOOLS', os.path.join(os.path.dirname(__file__), '..', '..', 'tools')))
from pty_screen import PtyTerm

demo = sys.argv[1]
fails = 0
count = 0


def check(cond, name, info=''):
    global fails, count
    count += 1
    print(('PASS ' if cond else 'FAIL ') + name)
    if not cond:
        fails += 1
        if info:
            print(info)


t = PtyTerm([demo], 80, 25)
check(t.wait_for('Window'), 'the program starts and draws the menu bar')
scr = t.text()
lines = scr.split('\n')
check('File' in lines[0] and 'Window' in lines[0], 'the menu bar is on the first row', scr)
check('Alt-X Exit' in lines[24], 'the status line is on the last row', scr)
check(('Window' in ''.join(lines[1:5])) and '┌' in scr or '╔' in scr, 'a window is on the desktop', scr)
check(not t.screen.cursor_visible, 'the cursor is hidden')
check(('h', 1049) in t.screen.log, 'the alternate screen is on')
check(('h', 1006) in t.screen.log, 'the mouse reporting (SGR) is on')

# F4: another window
t.send(b'\x1bOS')
check(t.text().count('Window') >= 2 or 'Window 2' in t.text(), 'F4 (ESC O S) opens another window', t.text())

# the menu: F10, then Esc
t.send(b'\x1b[21~')
check('New window' not in t.text(), 'F10 activates the menu bar (no drop-down yet)', t.text())
t.send(b'\x1b[B')
check('New window' in t.text(), 'Down opens the drop-down', t.text())
t.send(b'\x1b[B')
t.send(b'\x1b[B')
check('Close' in t.text(), '... and Down moves in it', t.text())
t.send(b'\x1b')
check('New window' not in t.text(), 'Esc closes the drop-down', t.text())
t.send(b'\x1b[B')
check('New window' in t.text(), '... the menu bar stays active (UX guidelines): Down opens it again', t.text())
t.send(b'\x1b')
t.send(b'\x1b')
t.send(b'\x1b[B')
check('New window' not in t.text(), 'the second Esc leaves the menu bar', t.text())

# Right in the active menu bar opens the next drop-down at once (UX guidelines)
t.send(b'\x1b[21~')
t.send(b'\x1b[C')
check('Tile' in t.text() and 'New window' not in t.text(), 'Right in the menu bar opens the Window menu', t.text())
t.send(b'\x1b')
t.send(b'\x1b')

# Ctrl+Tab (CSI 9;5u, the form of the keyboard protocol of Kitty; this terminal did not answer the query of the protocol, so no releases are expected and the
# switch is at once; tests/pty/test_switcher.py looks at the list that a terminal with releases gets) walks through the windows: the active window changes
before = t.text()
t.send(b'\x1b[9;5u')
check(t.text() != before, 'Ctrl+Tab switches to another window', t.text())
t.send(b'\x1b[9;6u')
check(t.text() == before, 'Ctrl+Shift+Tab switches back', t.text())

# the mouse: a drag of the top border moves the window, a drag of the bottom right corner resizes it (UX guidelines)
def find(ch):
    for y, l in enumerate(t.text().split('\n')):
        if ch in l:
            return (l.index(ch), y)
    return None
before = find('╔')
t.send(('\x1b[<0;%d;%dM' % (before[0] + 16, before[1] + 1)).encode())
t.send(('\x1b[<32;%d;%dM' % (before[0] + 20, before[1] + 3)).encode())
t.send(('\x1b[<0;%d;%dm' % (before[0] + 20, before[1] + 3)).encode())
after = find('╔')
check(after == (before[0] + 4, before[1] + 2), 'a drag of the top border moves the window', t.text())
rows = [(y, l.rindex('┘')) for y, l in enumerate(t.text().split('\n')) if '─┘' in l and '╔' not in l]
corner = rows[-1]
t.send(('\x1b[<0;%d;%dM' % (corner[1] + 1, corner[0] + 1)).encode())
t.send(('\x1b[<32;%d;%dM' % (corner[1] + 4, corner[0] + 2)).encode())
t.send(('\x1b[<0;%d;%dm' % (corner[1] + 4, corner[0] + 2)).encode())
rows = [(y, l.rindex('┘')) for y, l in enumerate(t.text().split('\n')) if '─┘' in l]
check(rows and rows[-1][1] > corner[1] and rows[-1][0] > corner[0], 'a drag of the bottom right corner resizes the window', t.text())

# the mouse: a click on File in the menu bar opens the menu (SGR: button 0 at column 3, row 1)
t.send(b'\x1b[<0;3;1M')
t.send(b'\x1b[<0;3;1m')
check('New window' in t.text(), 'a click on the menu bar opens the menu', t.text())
t.send(b'\x1b')

# a change of the size of the terminal
t.resize(100, 30)
t.pump(0.6)
lines = t.text().split('\n')
check(len(lines) == 30 and 'Alt-X Exit' in lines[29], 'the size changed: the status line is on the last row of 30', t.text())
check('File' in lines[0], '... and the menu bar is still on the first')
t.resize(60, 20)
t.pump(0.6)
lines = t.text().split('\n')
check('Alt-X Exit' in lines[19], 'the terminal got smaller: the status line is on row 20', t.text())

# Alt-X ends the program, the terminal is put back
t.send(b'\x1bx', settle=0.5)
status = t.close()
check(status == 0, 'Alt-X ends the program with status 0 (got %r)' % (status,))
check(('l', 1049) in t.screen.log, 'the alternate screen is off at the end')
check(('l', 1006) in t.screen.log, 'the mouse reporting is off at the end')

# the wheel scrolls the window under the pointer, not the active one (UX guidelines X.4)
t = PtyTerm([demo], 80, 25)
t.wait_for('Window')
t.send(b'\x1bOS')                       # window 2 is active and covers most of window 1
rows = lambda: t.text().split('\n')
strip = lambda: [l[5:8] for l in rows()[3:14]]        # the part of window 1 that shows
body = lambda: [l[8:30] for l in rows()[3:14]]          # the text of window 2
first, second = strip(), body()
t.send(b'\x1b[<65;7;10M')               # the wheel down over the part of window 1 that shows (column 7, row 10)
check(strip() != first, 'the wheel over an inactive window scrolls that window', t.text())
check(body() == second, '... and the active window stays', t.text())
t.send(b'\x1b[<65;30;10M')              # over the active window (inside its text)
check(body() != second, 'the wheel over the active window scrolls it', t.text())
t.send(b'\x1bx', settle=0.5)
t.close()

print('ALL OK (%d checks)' % count if not fails else '%d of %d checks FAILED' % (fails, count))
sys.exit(1 if fails else 0)
