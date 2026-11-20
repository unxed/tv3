#!/usr/bin/env python3
"""The clipboard of the terminal backend: TClipboard.SetText sends OSC 52 (base64 of the UTF-8 text); not on the Linux console (TERM=linux)
and not with TV_CLIPBOARD=0. usage: test_clip.py PATH/TO/clipdemo"""
import base64
import os
import re
import sys
import tempfile

sys.path.insert(0, os.environ.get('PTY_TOOLS', os.path.join(os.path.dirname(__file__), '..', '..', 'tools')))
from pty_screen import PtyTerm

demo = sys.argv[1]
fails = count = 0


def check(cond, name, info=''):
    global fails, count
    count += 1
    print(('PASS ' if cond else 'FAIL ') + name)
    if not cond:
        fails += 1
        if info:
            print(info)


def run(env):
    t = PtyTerm([demo], 80, 25, env=env)
    t.pump(1.5, 6)
    raw = t.raw
    t.close()
    return re.findall(rb'\x1b\]52;c;([A-Za-z0-9+/=]*)\x07', raw)


with tempfile.TemporaryDirectory(prefix='tv3-clip-') as d:
    marker = os.path.join(d, 'xclip-called')
    fake_clip = '#!/bin/sh\nprintf called > "$TV3_XCLIP_MARKER"\ncat >/dev/null\n'
    for program in ('xclip', 'xsel'):
        with open(os.path.join(d, program), 'w', encoding='utf-8') as f:
            f.write(fake_clip)
        os.chmod(os.path.join(d, program), 0o755)
    env = {
        'PATH': d + os.pathsep + os.environ.get('PATH', ''),
        'DISPLAY': ':99',
        'WAYLAND_DISPLAY': '',
        'SSH_CONNECTION': '',
        'SSH_TTY': '',
        'TV3_XCLIP_MARKER': marker,
    }
    ordinary = run(env)
    check(os.path.exists(marker), 'a local X session may use the system clipboard')
    check(ordinary == [], 'a successful system clipboard write does not also send OSC 52')
    os.unlink(marker)
    env['SSH_TTY'] = '/dev/pts/1'
    ssh = run(env)
    check(not os.path.exists(marker), 'an SSH session does not write to the remote X clipboard')
    check(
        len(ssh) == 1 and base64.b64decode(ssh[0]).decode('utf-8') == 'Привет, мир',
        'an SSH session sends the text through OSC 52', repr(ssh),
    )


m = run({'TERM': 'xterm-256color'})
check(len(m) == 1 and base64.b64decode(m[0]).decode('utf-8') == 'Привет, мир', 'OSC 52 carries the text in UTF-8', repr(m))
check(run({'TERM': 'linux'}) == [], 'no OSC 52 on the Linux console')
check(run({'TERM': 'xterm-256color', 'TV_CLIPBOARD': '0'}) == [], 'no OSC 52 with TV_CLIPBOARD=0')
print('ALL OK (%d checks)' % count if not fails else '%d of %d checks FAILED' % (fails, count))
sys.exit(1 if fails else 0)
