#!/usr/bin/env python3
"""The window switcher (UX guidelines 0.2, 0.3) of tvdemo in a pty: usage: test_switcher.py PATH/TO/tvdemo.
With key releases (the win32 input mode, the keyboard protocol of Kitty) Ctrl+Tab opens a list of the windows and the release of Ctrl makes the choice;
in a terminal that tells no releases the switch is at once. tools/pty_screen.py is the terminal (PTY_TOOLS is the directory)."""
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


def listed(t):
    """the rows of the list in the middle: the text of the screen between the walls of the box, 'Window' in the middle"""
    return sum(1 for l in t.text().split('\n') if '│ Window │' in l)


def active_number(t):
    """the number of the window whose frame is the active (double) one"""
    for l in t.text().split('\n'):
        if '╔' in l:
            import re
            m = re.search(r'(\d)═\[', l)
            if m:
                return int(m.group(1))
    return 0


def start(env):
    t = PtyTerm([demo], 80, 25, env=env)
    check(t.wait_for('Window'), 'the program starts')
    t.send(b'\x1bOS')                  # F4 twice: three windows, the third is active
    t.send(b'\x1bOS')
    check(active_number(t) == 3, 'three windows, the last is active', t.text())
    return t


# win32 input mode: Ctrl down, Tab down with Ctrl, Tab up, Ctrl up
t = start({'TV_WIN32_INPUT': '1'})
t.send(b'\x1b[17;29;0;1;8;1_')
t.send(b'\x1b[9;15;9;1;8;1_')
check(listed(t) == 3, 'win32: Ctrl+Tab opens the list of three windows', t.text())
check(active_number(t) == 3, '... the active window does not change yet', t.text())
t.send(b'\x1b[9;15;9;0;8;1_')
check(listed(t) == 3, '... the release of Tab does not close the list', t.text())
t.send(b'\x1b[17;29;0;0;0;1_')
check(listed(t) == 0, 'win32: the release of Ctrl closes the list', t.text())
check(active_number(t) == 1, '... and the window is chosen (the one at the bottom comes up)', t.text())
# Esc cancels
t.send(b'\x1b[17;29;0;1;8;1_')
t.send(b'\x1b[9;15;9;1;8;1_')
check(listed(t) == 3, 'win32: the list opens again', t.text())
t.send(b'\x1b[27;1;27;1;8;1_')
check(listed(t) == 0 and active_number(t) == 1, 'win32: Esc closes the list and keeps the window', t.text())
t.send(b'\x1b[27;1;27;0;8;1_')
t.send(b'\x1b[17;29;0;0;0;1_')
t.close()

# the keyboard protocol of Kitty: the terminal answers the query (ESC [ ? u) and so tells that it speaks it; the program asks for the modifiers (flag 8)
# only for the list
t = start({'TV_WIN32_INPUT': '0'})
check(b'\x1b[?u' in t.raw, 'kitty: the program asks the terminal for the flags of the protocol')
t.send(b'\x1b[?0u')
check(b'\x1b[=8;2u' not in t.raw, 'kitty: the modifiers are not asked for before the list')
t.send(b'\x1b[9;5u')
check(listed(t) == 3, 'kitty: Ctrl+Tab (ESC [ 9 ; 5 u) opens the list', t.text())
check(b'\x1b[=8;2u' in t.raw and b'\x1b[=2;2u' in t.raw, '... and the program asks for the releases and the modifiers', repr(t.raw[-200:]))
t.send(b'\x1b[9;5:3u')
check(listed(t) == 3, '... the release of Tab does not close the list', t.text())
t.send(b'\x1b[57442;1:3u')
check(listed(t) == 0 and active_number(t) == 1, 'kitty: the release of Ctrl chooses', t.text())
check(b'\x1b[=8;3u' in t.raw, '... and the program stops asking for the modifiers', repr(t.raw[-200:]))
t.close()

# a terminal with no key releases (xterm: modifyOtherKeys): at once
t = start({'TV_WIN32_INPUT': '0'})
t.send(b'\x1b[27;5;9~')
check(listed(t) == 0 and active_number(t) == 1, 'no key releases: Ctrl+Tab switches at once, no list', t.text())
t.send(b'\x1b[9;6u')                  # a multiplexer can send the form of the protocol and still tell no releases: no answer to the query, no list
check(listed(t) == 0 and active_number(t) == 3, 'no answer to the query of the protocol: Ctrl+Shift+Tab in its form switches at once', t.text())
check(b'\x1b[=8;2u' not in t.raw, '... and the program does not ask for anything', repr(t.raw[-200:]))
t.close()

print('ALL OK (%d checks)' % count if not fails else '%d of %d FAILED' % (fails, count))
sys.exit(1 if fails else 0)
