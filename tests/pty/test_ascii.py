#!/usr/bin/env python3
"""The ASCII table (TvAscii) and the clock (TvGadgets) in tvdemo through a pty: Tools > ASCII table opens the window, the
keys and the mouse move the cursor, the report follows it, Enter, a typed character and a double click pick a character;
with /clock the menu bar shows the time and it changes. usage: test_ascii.py PATH/TO/tvdemo"""
import os
import re
import sys
import time

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


F10, RIGHT, DOWN, ENTER, ESC = b'\x1b[21~', b'\x1b[C', b'\x1b[B', b'\r', b'\x1b'
CTRL_PGDN = b'\x1b[6;5~'


def find(t, s):
    for y, line in enumerate(t.text().split('\n')):
        if s in line:
            return line.index(s), y
    return None


t = PtyTerm([demo], 80, 25)
check(t.wait_for('Window'), 'the program starts')
t.send(F10)
t.send(RIGHT)
t.send(RIGHT)
t.send(DOWN)
check('ASCII table' in t.text(), 'the Tools menu has the ASCII table', t.text())
t.send(ENTER)
check(t.wait_for('ASCII Table'), 'the ASCII table opens', t.text())
check(find(t, ' !"#$%&') is not None, 'the table shows the characters 32..', t.text())
check(find(t, 'Dec: 0  U+0000') is not None, 'the report shows the code 0', t.text())
t.send(DOWN)
t.send(DOWN)
t.send(RIGHT)
check(find(t, 'Char: A  Dec: 65  U+0041') is not None, 'the arrows move the cursor, the report follows', t.text())
t.send(ENTER)
check(t.wait_for('Picked: A (65)'), 'Enter picks the character', t.text())
t.send(ENTER)
check('Picked' not in t.text(), 'the message is closed', t.text())
t.send('é'.encode())
check(t.wait_for('Picked: é (233)'), 'a typed character is picked', t.text())
t.send(ENTER)
check(find(t, 'U+00E9') is not None, '... and the cursor is on it', t.text())
t.send(CTRL_PGDN)
check(find(t, 'U+01E9') is not None, 'Ctrl+PgDn shows the next block of 256 code points', t.text())
pos = find(t, 'ĀāĂă')
check(pos is not None, 'the block U+0100.. is drawn', t.text())
if pos:
    x, y = pos
    # a double click on the third cell of the first row: U+0102
    for _ in range(2):
        t.send(('\x1b[<0;%d;%dM' % (x + 3, y + 1)).encode(), settle=0.02)
        t.send(('\x1b[<0;%d;%dm' % (x + 3, y + 1)).encode(), settle=0.02)
    check(t.wait_for('Picked: Ă (258)'), 'a double click picks the character under the mouse', t.text())
    t.send(ENTER)
t.send(b'\x1bx')
t.close()

t = PtyTerm([demo, '/clock'], 80, 25)
check(t.wait_for('Window'), 'the program starts with /clock')
time.sleep(0.3)
t.pump(0.3)
first = t.text().split('\n')[0]
m = re.search(r' (\d\d:\d\d:\d\d)$', first)
check(m is not None and len(first) == 79, 'the clock is at the right of the menu bar, with a margin: %r' % first)
time.sleep(1.2)
t.pump(0.5)
second = t.text().split('\n')[0]
m2 = re.search(r'(\d\d:\d\d:\d\d)', second)
check(bool(m and m2 and m.group(1) != m2.group(1)), 'the clock changes: %r -> %r' % (first[-10:], second[-10:]))
t.send(b'\x1bx')
t.close()

print('ALL OK (%d checks)' % count if fails == 0 else '%d of %d checks FAILED' % (fails, count))
sys.exit(1 if fails else 0)
