#!/bin/sh
# UTF-8 file names under DOSBox-X (the provider DOS-UTF8/NAMES, option "utf8 file names" of [dos]; DOSBox-X from October 2026).
# usage: DOSBOX=path/to/dosbox-x FPC_GO32V2=path/to/fpc-go32v2 dostests/utf8-names.sh
# Builds t_dosuni.pas, puts three files with names of different scripts (and CWSDPMI.EXE) in a directory, runs the program twice (UTF-8 mode, and the code page
# mode with TV_DOS_UTF8_NAMES=0) on the code page 866 and checks what the program saw and what the host directory got.
# exit status: 0 = all checks passed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
DOSBOX=${DOSBOX:-dosbox-x}
FPC_GO32V2=${FPC_GO32V2:-fpc-go32v2}
work=$(mktemp -d)
mkdir "$work/obj" "$work/dir"
"$FPC_GO32V2" -Fu"$here/../src" -FU"$work/obj" -FE"$work/dir" "$here/t_dosuni.pas" > "$work/build.log" 2>&1 || { cat "$work/build.log"; exit 1; }
if [ -n "${CWSDPMI:-}" ]; then cp "$CWSDPMI" "$work/dir/CWSDPMI.EXE"; else
  curl -fsSL --retry 4 -o "$work/csdpmi.zip" https://www.delorie.com/pub/djgpp/current/v2misc/csdpmi7b.zip
  unzip -q -j -o "$work/csdpmi.zip" bin/CWSDPMI.EXE -d "$work/dir"
fi
# names: Cyrillic (in cp866), Chinese (not in cp866), ASCII
python3 - "$work/dir" <<'PY'
import os, sys
d = sys.argv[1]
for name in ('мир.txt', '世界.txt', 'ascii.txt'):
    open(os.path.join(d, name), 'w').write('host\n')
PY
cat > "$work/dosbox.conf" <<CONF
[sdl]
output=surface
[dosbox]
memsize=32
[dos]
ver=7.10
lfn=true
utf8 file names=true
[autoexec]
@echo off
mount c "$work/dir"
c:
chcp 866
t_dosuni.exe > mode8.txt
set TV_DOS_UTF8_NAMES=0
t_dosuni.exe > mode0.txt
exit
CONF
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 ${DOS_TIMEOUT:-180} "$DOSBOX" -silent -nogui -noconsole -conf "$work/dosbox.conf" >/dev/null 2>&1 || true
python3 - "$work/dir" <<'PY'
import os, sys
d = sys.argv[1]
bad = 0
def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what)
    if not ok:
        bad += 1
        if info: print('    | ' + info)
def lines(name):
    p = os.path.join(d, name)
    if not os.path.exists(p): return None
    return open(p, 'rb').read().decode('utf-8', 'replace').replace('\r', '').split('\n')
for mode, title in (('mode8.txt', 'UTF-8 mode'), ('mode0.txt', 'code page mode')):
    L = lines(mode)
    check(L is not None, title + ': the program ran and wrote its output')
    if L is None: continue
    have = {l.split(':', 1)[0]: l.split(':', 1)[1] for l in L if ':' in l}
    check('END' in L, title + ': the program reached the end', '\n'.join(L[:10]))
    check(have.get('PROVIDER') == '1', title + ': the provider DOS-UTF8/NAMES is found')
    check(have.get('LFN') == '1', title + ': long file names work')
    check(have.get('UTF8MODE') == ('1' if mode == 'mode8.txt' else '0'), title + ': the mode is the wanted one')
    entries = [l[len('ENTRY:'):] for l in L if l.startswith('ENTRY:')]
    check('ascii.txt' in entries, title + ': an ASCII name', repr(entries))
    check('мир.txt' in entries, title + ': a Cyrillic name comes back as it is', repr(entries))
    check('世界.txt' in entries, title + ': a Chinese name comes back as it is (in the code page mode too: from the form with braces)', repr(entries))
    check(any(l == 'MADE:новый.txt' for l in L), title + ': a Cyrillic file is made')
    check(any(l == 'MADE:新.txt' for l in L), title + ': a Chinese file is made')
host = set(os.listdir(d))
check('новый.txt' in host, 'the host directory has the Cyrillic file the program made', repr(sorted(host)))
check('新.txt' in host, 'the host directory has the Chinese file the program made', repr(sorted(host)))
print('%d failed' % bad)
sys.exit(1 if bad else 0)
PY
rc=$?
rm -rf "$work"
exit $rc
