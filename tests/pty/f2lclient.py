#!/usr/bin/env python3
"""A small client of the far2l terminal extensions for test_far2l.py: it runs inside the embedded terminal (tvterm), switches the extensions on,
sends a few requests and prints what came back, one result per line (ACK, MAX, PAL, CLIP, KEY)."""
import base64, os, select, struct, sys, termios, tty

fd = sys.stdin.fileno()
old = termios.tcgetattr(fd)
tty.setraw(fd)
buf = b''


def read_until(pred, timeout=8.0):
    global buf
    import time
    end = time.time() + timeout
    while not pred(buf) and time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            buf += os.read(fd, 65536)
    return pred(buf)


def out(s):
    os.write(1, (s + '\r\n').encode())


def request(stack):
    os.write(1, b'\x1b_far2l:' + base64.b64encode(stack) + b'\x1b\\')


def reply(id_):
    """the stack of the reply with this ID (the ID popped), or None"""
    global buf
    def find(b):
        i = 0
        while True:
            i = b.find(b'\x1b_far2l', i)
            if i < 0:
                return None
            j = b.find(b'\x07', i)
            if j < 0:
                return None
            body = b[i + 7:j]
            if body != b'ok':
                st = base64.b64decode(body + b'=' * (-len(body) % 4))
                if st and st[-1] == id_:
                    return (i, j, st[:-1])
            i = j
    if not read_until(lambda b: find(b) is not None):
        return None
    i, j, st = find(buf)
    buf = buf[:i] + buf[j + 1:]
    return st


def string(s):
    return s + struct.pack('<I', len(s))


try:
    os.write(1, b'\x1b_far2l1\x1b\\\x1b[5n')
    read_until(lambda b: b'\x1b[0n' in b)
    out('ACK ' + ('yes' if b'\x1b_far2lok\x07' in buf.split(b'\x1b[0n')[0] else 'no'))
    buf = b''
    request(struct.pack('<Q', 1) + b'x\x00')
    request(b'w\x01')
    st = reply(1)
    out('MAX %d %d' % struct.unpack('<hh', st[-4:])[::-1] if st and len(st) == 4 else 'MAX none')
    request(b'p\x02')
    st = reply(2)
    out('PAL %d' % st[-1] if st else 'PAL none')
    request(string(b'0123456789abcdef0123456789abcdef-test') + b'oc\x03')
    st = reply(3)
    status = struct.unpack('<b', st[-1:])[0] if st else None
    out('OPEN %s' % status)
    if status == 1:
        request(b'hello' + struct.pack('<II', 5, 1) + b'sc\x04')
        st = reply(4)
        out('SET %s' % (st[-1] if st else None))
        request(b'cc\x00')
    out('READY')
    # the next event: a key
    read_until(lambda b: b'\x1b_f2l' in b and b'\x07' in b[b.find(b'\x1b_f2l'):])
    i = buf.find(b'\x1b_f2l')
    j = buf.find(b'\x07', i)
    body = buf[i + 5:j]
    st = base64.b64decode(body + b'=' * (-len(body) % 4))
    if st[-1:] == b'C':
        vk, cs, ch = st[0], struct.unpack('<H', st[1:3])[0], struct.unpack('<H', st[3:5])[0]
        out('KEY C vk=%02x ch=%04x' % (vk, ch))
    else:
        out('KEY %s' % st[-1:].decode())
    read_until(lambda b: False, 0.5)
    os.write(1, b'\x1b_far2l0\x07')
    out('DONE')
    read_until(lambda b: False, 30)
finally:
    termios.tcsetattr(fd, termios.TCSADRAIN, old)
