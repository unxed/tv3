#!/usr/bin/env python3
"""The far2l terminal extensions in a pty, both sides. usage: test_far2l.py PATH/TO/tvdemo PATH/TO/tvterm
1. The client (TvUnix): tvdemo is run in a terminal that answers as a far2l terminal (this script): the acknowledgement, the features, the palette,
   a key as an event, far2l0 at the end; TV_FAR2L=0 and TERM=linux do not ask.
2. The server (TvVtView): tvterm runs tests/pty/f2lclient.py, which talks to the embedded terminal; the clipboard dialog is answered. Prints ALL OK."""
import base64, os, shutil, struct, sys, tempfile, time

sys.path.insert(0, os.environ.get('PTY_TOOLS', os.path.join(os.path.dirname(__file__), '..', '..', 'tools')))
from pty_screen import PtyTerm

demo, term = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
fails = 0


def check(cond, name, info=''):
    global fails
    print(('PASS ' if cond else 'FAIL ') + name)
    if not cond:
        fails += 1
        if info:
            print(info)


def requests(raw):
    """the decoded stacks of the requests in the output"""
    res = []
    i = 0
    while True:
        i = raw.find(b'\x1b_far2l:', i)
        if i < 0:
            return res
        j = raw.find(b'\x1b\\', i)
        body = raw[i + 8:j]
        res.append(base64.b64decode(body + b'=' * (-len(body) % 4)))
        i = j


def event(stack):
    return b'\x1b_f2l' + base64.b64encode(stack) + b'\x07'


# --- 1. the client ---
t = PtyTerm([demo], 80, 25, env={'TERM': 'xterm-256color', 'TV_FAR2L': ''})
t.pump(1.5)
check(b'\x1b_far2l1\x1b\\\x1b[5n' in t.raw, 'the client asks for the extensions (far2l1 with ST, then ESC [ 5 n)')
start = len(t.raw)
t.send(b'\x1b_far2lok\x07\x1b[0n', 0.6)
reqs = requests(t.raw[start:])
feats = [r for r in reqs if len(r) >= 2 and r[-2:-1] == b'x']
check(feats and feats[0][-1] == 0 and struct.unpack('<Q', feats[0][:8])[0] == 1, 'features: compact input, ID 0', repr(reqs))
pal = [r for r in reqs if len(r) == 2 and r[0:1] == b'p' and r[1] != 0]
check(len(pal) == 1, 'the palette is asked with an ID', repr(reqs))
if pal:
    start = len(t.raw)
    t.send(b'\x1b_far2l' + base64.b64encode(bytes([0, 24, pal[0][1]])) + b'\x07', 1.0)
    check(b'\x1b[2J' in t.raw[start:] and len(t.raw) - start > 2000, 'the answer 24 bits: the screen is made and drawn again (more colors)')
# Alt+X as a compact key press and release: the program ends and switches the extensions off
t.send(event(bytes([0x58]) + struct.pack('<HH', 0x02, ord('x')) + b'C') + event(bytes([0x58]) + struct.pack('<HH', 0x02, ord('x')) + b'c'), 1.0)
st = t.close(3)
check(st == 0, 'Alt+X as a far2l key event ends the program', repr(st))
check(t.raw.rstrip().find(b'\x1b_far2l0') > 0, 'far2l0 at the end')

for env, name in (({'TERM': 'xterm-256color', 'TV_FAR2L': '0'}, 'TV_FAR2L=0'), ({'TERM': 'linux', 'TV_FAR2L': ''}, 'TERM=linux')):
    t = PtyTerm([demo], 80, 25, env=env)
    t.pump(1.2)
    check(b'far2l1' not in t.raw, name + ': not asked')
    t.close(0.5)
t = PtyTerm([demo], 80, 25, env={'TERM': 'linux', 'TV_FAR2L': '1'})
t.pump(1.2)
check(b'far2l1' in t.raw, 'TV_FAR2L=1: asked also on TERM=linux')
t.close(0.5)

# --- 2. the server ---
client = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'f2lclient.py')
home = tempfile.mkdtemp(prefix='tv3-f2l-test-')
cfg = os.path.join(home, 'config')
t = PtyTerm([term, sys.executable, client], 100, 30, env={'TERM': 'xterm-256color', 'TV_FAR2L': '0', 'TV_CONFIG_DIR': cfg, 'HOME': home})
ok = t.wait_for('Clipboard access', 8)
txt = t.text()
check('ACK yes' in txt, 'the embedded terminal acknowledges', txt)
check('MAX ' in txt and 'MAX none' not in txt, 'GET_WINDOW_MAXSIZE is answered', txt)
check('PAL ' in txt and 'PAL none' not in txt, 'GET_COLOR_PALETTE is answered', txt)
check(ok, 'CLIP_OPEN shows the dialog "Clipboard access"', txt)
t.send(b'\x1bs', 1.0)                                  # Alt+S: Share clipboard
txt = t.text()
check('OPEN 1' in txt and 'SET 1' in txt, 'shared: the clipboard is set', txt)
t.wait_for('READY', 3)
t.send(b'q', 1.0)
txt = t.text()
check('KEY C vk=51 ch=0071' in txt, 'a key goes to the program as a compact event', txt)
check(t.wait_for('DONE', 3), 'far2l0 is taken', t.text())
t.close(1)
shutil.rmtree(home, ignore_errors=True)
print('ALL OK' if not fails else '%d FAILED' % fails)
sys.exit(1 if fails else 0)
