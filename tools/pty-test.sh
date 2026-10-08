#!/bin/sh
# The tests of the terminal backend in a pty (tests/pty/test_*.py): builds the programs they need, runs them. Needs fpc and python3.
# PTY_TOOLS=/dir picks the directory of pty_screen.py (default: tools/ here). Output goes to $TV_PTY_WORK (default /tmp/tv3-pty).
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
out=${TV_PTY_WORK:-${TMPDIR:-/tmp}/tv3-pty}; mkdir -p "$out"
export PTY_TOOLS=${PTY_TOOLS:-$here/tools}
cd "$here"
fail=0
build() {   # build SOURCE.pas
    ${FPC:-fpc} -Mobjfpc -Fusrc -Fisrc -FU"$out" -FE"$out" "$1" 2>&1 | grep -E 'Error|Fatal' && { echo "BUILD FAIL $1"; fail=1; return 1; }
    return 0
}
run() {     # run NAME TEST.py ARGS...
    n=$1; shift
    if python3 "$@" > "$out/$n.txt" 2>&1; then echo "$n: $(tail -1 "$out/$n.txt")"; else echo "$n: FAILED"; grep -E '^FAIL' "$out/$n.txt" | head -10; fail=1; fi
}
for p in demo/tvdemo demo/tvterm tests/pty/rundemo tests/pty/clipdemo; do build $p.pas || true; done
run tvdemo tests/pty/test_tvdemo.py "$out/tvdemo"
run switcher tests/pty/test_switcher.py "$out/tvdemo"
run held tests/pty/test_held.py "$out/tvdemo"
run win32input tests/pty/test_win32input.py "$out/tvdemo"
run tvterm tests/pty/test_tvterm.py "$out/tvterm"
run vtrun tests/pty/test_vtrun.py "$out/rundemo"
run clip tests/pty/test_clip.py "$out/clipdemo"
run ascii tests/pty/test_ascii.py "$out/tvdemo"
run far2l tests/pty/test_far2l.py "$out/tvdemo" "$out/tvterm"
exit $fail
