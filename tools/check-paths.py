#!/usr/bin/env python3
"""Counts the places that spell a path by hand (a separator, a drive letter, a ':' test, the mask '*.*') in the Pascal
sources; TvPath (src/tvpath.pas) is the one place that may. A ratchet: the count of a file may only fall.
tools/check-paths.py [--update] [-v]   the baseline is tools/paths-baseline.txt; -v shows the lines"""
import os, re, sys

root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
dirs = ['src', 'demo', 'tools']
skip_files = {'src/tvpath.pas'}
base = os.path.join(root, 'tools', 'paths-baseline.txt')

pat = re.compile(
    r"(?<![#\d(])'\\'"                # a backslash as a character (not #27'\' or Ord('\') of an escape sequence)
    r"|'[A-Za-z]?:\\"                  # a drive prefix: 'C:\...', ':\'
    r"|\[2\]\s*(=|<>)\s*':'"           # S[2] = ':'
    r"|\[1\]\s*(=|<>)\s*'/'"           # S[1] = '/': a root test
    r"|\+\s*'/'|'/'\s*\+"              # a slash joined to a path
    r"|'\*\.\*'"                       # the DOS mask of every file
    r"|\(\s*'\\'\s*,\s*'/'\s*\)"       # ('\', '/')
)
string = re.compile(r"'(?:[^']|'')*'")


def code_lines(path):
    """The lines without comments; string literals stay."""
    text = open(path, encoding='utf-8', errors='replace').read()
    out, i, n, depth, cur = [], 0, len(text), 0, []
    while i < n:
        c = text[i]
        if depth == 0 and c == "'":
            m = string.match(text, i)
            j = m.end() if m else n
            cur.append(text[i:j])
            i = j
            continue
        if depth == 0 and text.startswith('//', i):
            while i < n and text[i] != '\n':
                i += 1
            continue
        if c == '{' and not text.startswith('{$', i):
            depth += 1
        elif c == '}' and depth > 0:
            depth -= 1
            i += 1
            continue
        if c == '\n':
            out.append(''.join(cur))
            cur = []
        elif depth == 0:
            cur.append(c)
        i += 1
    out.append(''.join(cur))
    return out


counts, hits = {}, {}
for d in dirs:
    full = os.path.join(root, d)
    if not os.path.isdir(full):
        continue
    for f in sorted(os.listdir(full)):
        rel = d + '/' + f
        if not f.endswith(('.pas', '.pp', '.inc')) or rel in skip_files:
            continue
        n = 0
        for no, line in enumerate(code_lines(os.path.join(full, f)), 1):
            k = len(pat.findall(line))
            if k:
                n += k
                hits.setdefault(rel, []).append('%s:%d: %s' % (rel, no, line.strip()))
        if n:
            counts[rel] = n
total = sum(counts.values())
if '--update' in sys.argv:
    with open(base, 'w') as fh:
        for f, n in sorted(counts.items()):
            fh.write('%s %d\n' % (f, n))
    print('baseline', total)
    sys.exit(0)
old = {}
if os.path.exists(base):
    for l in open(base):
        if l.strip():
            a, b = l.split()
            old[a] = int(b)
bad = [(f, n, old.get(f, 0)) for f, n in sorted(counts.items()) if n > old.get(f, 0)]
for f, n, o in bad:
    print('FAIL %s: %d paths spelled by hand (the baseline allows %d); use TvPath (if it is no path, such as the escape of a'
          ' regular expression, raise the baseline with --update)' % (f, n, o))
    for h in hits[f]:
        print('    ' + h)
if '-v' in sys.argv:
    for f in sorted(hits):
        for h in hits[f]:
            print(h)
lower = [f for f in old if counts.get(f, 0) < old[f]]
if lower:
    print('fewer than the baseline in %s: run tools/check-paths.py --update' % ', '.join(sorted(lower)))
print('total %d (baseline %d)' % (total, sum(old.values())))
sys.exit(1 if bad else 0)
