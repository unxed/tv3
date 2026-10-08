#!/bin/sh
# The tests of the terminal backend in a pty (tests/pty/test_*.py): builds the programs they need, then runs all the tests side by
# side (they wait for the program, not for the CPU), each with a HOME and XDG directories of its own. Needs fpc and python3.
# usage: tools/pty-test.sh [--build]      --build only builds the programs (CI runs the tests with tools/ci-par.sh)
# PTY_TOOLS=/dir picks the directory of pty_screen.py (default: tools/ here). Output goes to $TV_PTY_WORK (default: a new temp dir).
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
out=${TV_PTY_WORK:-$(mktemp -d "${TMPDIR:-/tmp}/tv3-pty.XXXXXX")}; mkdir -p "$out"; out=$(cd "$out" && pwd)
export PTY_TOOLS=${PTY_TOOLS:-$here/tools}
cd "$here"
fail=0
build() {   # build SOURCE.pas
    ${FPC:-fpc} -Mobjfpc -Fusrc -Fisrc -FU"$out" -FE"$out" "$1" 2>&1 | grep -E 'Error|Fatal' && { echo "BUILD FAIL $1"; fail=1; return 1; }
    return 0
}
for p in demo/tvdemo demo/tvterm tests/pty/rundemo tests/pty/clipdemo; do build $p.pas || true; done
[ "${1:-}" = --build ] && exit $fail
tests="tvdemo:test_tvdemo.py:tvdemo
switcher:test_switcher.py:tvdemo
held:test_held.py:tvdemo
win32input:test_win32input.py:tvdemo
tvterm:test_tvterm.py:tvterm
vtrun:test_vtrun.py:rundemo
clip:test_clip.py:clipdemo
ascii:test_ascii.py:tvdemo
far2l:test_far2l.py:tvdemo tvterm"
echo "$tests" | { while IFS=: read -r n t progs; do
    args=; for p in $progs; do args="$args $out/$p"; done
    (
        HOME=$out/home-$n
        XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/.local/state XDG_DATA_HOME=$HOME/.local/share XDG_CACHE_HOME=$HOME/.cache
        export HOME XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME XDG_CACHE_HOME
        mkdir -p "$HOME"
        # shellcheck disable=SC2086
        python3 "tests/pty/$t" $args > "$out/$n.txt" 2>&1; echo $? > "$out/$n.rc"
    ) &
done; wait; }
for n in $(echo "$tests" | cut -d: -f1); do
    if [ "$(cat "$out/$n.rc" 2>/dev/null)" = 0 ]; then echo "$n: $(tail -1 "$out/$n.txt")"; else echo "$n: FAILED"; grep -E '^FAIL' "$out/$n.txt" | head -10; fail=1; fi
done
[ $fail = 0 ] && [ -z "${TV_PTY_WORK:-}" ] && rm -rf "$out"
[ $fail = 0 ] || echo "the output of the tests: $out"
exit $fail
