#!/bin/sh
# Unit tests of tv3 (tests/t_*.pas): tools/test.sh [t_name ...]. Needs fpc. Each test prints "ALL OK" as its last line when all checks pass.
# The units of src are built once; then the tests are built and run side by side (TV_TEST_JOBS, default nproc), each with
# a directory of its own for its objects, its TMPDIR and its HOME.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
w=${TV_TEST_WORK:-${TMPDIR:-/tmp}/tv3-tests}; mkdir -p "$w"
w=$(cd "$w" && pwd)
fpc=${FPC:-fpc}
flags="-Mobjfpc -Fusrc -Fisrc -Fitests -Futests"
cd "$here"

if [ "${1:-}" = "--one" ]; then                         # one test: build it, run it, write $w/$n.res
    n=$2; d="$w/$n"; rm -rf "$d"; mkdir -p "$d/tmp" "$d/home"
    out=$($fpc -Fu"$w/lib" $flags -FU"$d" -FE"$d" "tests/$n.pas" 2>&1) || true
    if echo "$out" | grep -qE "Error|Fatal"; then
        { echo "BUILD FAIL $n"; echo "$out" | grep -E "Error|Fatal" | head -3; } > "$w/$n.res"; exit 0
    fi
    (cd "$here/tests" && TMPDIR="$d/tmp" HOME="$d/home" "$d/$n" > "$w/$n.txt" 2>&1) || true
    r=$(tail -1 "$w/$n.txt"); echo "$n: $r" > "$w/$n.res"
    case "$r" in "ALL OK"*) ;; *) grep -E '^FAIL' "$w/$n.txt" | head -10 >> "$w/$n.res";; esac
    exit 0
fi

if [ $# -gt 0 ]; then tests=$(for n in "$@"; do basename "${n%.pas}"; done); else tests=$(ls tests/t_*.pas | xargs -n1 basename | sed 's/\.pas$//'); fi

# the units of src, once, in one compiler run (every test then reads them from $w/lib, which comes first in its unit path)
mkdir -p "$w/lib"
{ echo "program allunits;"; echo "uses"
  ls src/*.pas | grep -v 'src/tvtermoswin.pas' | xargs -n1 basename | sed 's/\.pas$//' | paste -sd, -
  echo "; begin end."; } > "$w/lib/allunits.pas"
out=$($fpc $flags -FU"$w/lib" -FE"$w/lib" "$w/lib/allunits.pas" 2>&1) || true
if echo "$out" | grep -qE "Error|Fatal"; then echo "BUILD FAIL the units of src"; echo "$out" | grep -E "Error|Fatal" | head -5; exit 1; fi

for n in $tests; do rm -f "$w/$n.res"; done
echo "$tests" | xargs -P "${TV_TEST_JOBS:-$(nproc)}" -n1 "$here/tools/test.sh" --one

fail=0
for n in $tests; do
    if [ -f "$w/$n.res" ]; then cat "$w/$n.res"; else echo "NO RESULT $n"; fail=1; continue; fi
    head -1 "$w/$n.res" | grep -q ": ALL OK" || fail=1
done
exit $fail
