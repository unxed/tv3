#!/usr/bin/env python3
"""A held arrow stops at the end of a menu (UX guidelines M.7) in a terminal that tells the auto repeats (the win32 input mode): usage: test_held.py PATH/TO/tvdemo.
The File menu of tvdemo has three entries; Down is pressed four times without a release (a held key), then once released and pressed again.
tools/pty_screen.py is the terminal (PTY_TOOLS is the directory)."""
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


DOWN_PRESS = b'\x1b[40;80;0;1;0;1_'
DOWN_RELEASE = b'\x1b[40;80;0;0;0;1_'
ENTER = b'\x1b[13;28;13;1;0;1_\x1b[13;28;13;0;0;1_'
F10 = b'\x1b[21~'


def run(held):
    t = PtyTerm([demo], 80, 25, env={'TV_WIN32_INPUT': '1'})
    t.wait_for('Window')
    t.send(F10)
    t.send(b'\x1b[B')                         # the drop-down of File opens, the first entry is chosen
    check('New window' in t.text(), 'the File menu is open', t.text())
    if held:
        for i in range(4):
            t.send(DOWN_PRESS, settle=0.1)    # no release between the presses: the key is held
        t.send(DOWN_RELEASE)
    else:
        for i in range(4):
            t.send(DOWN_PRESS, settle=0.1)
            t.send(DOWN_RELEASE, settle=0.1)
    t.send(ENTER, settle=0.6)
    status = None if t.alive() else t.status
    alive = t.alive()
    t.close()
    return alive


# held: the cursor stops on the last entry (Exit), Enter ends the program
check(not run(True), 'a held Down stops at the last entry: Enter chooses Exit and the program ends')
# four separate presses go round: New, Close, Exit, New, Close -> Enter closes the window and the program goes on
check(run(False), 'four separate presses of Down wrap: Enter does not choose Exit')

print('ALL OK (%d checks)' % count if not fails else '%d of %d FAILED' % (fails, count))
sys.exit(1 if fails else 0)
