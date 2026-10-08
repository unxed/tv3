#!/bin/sh
# Unit tests of tv3 (tests/t_*.pas): tools/test.sh [t_name ...]. Needs fpc. Each test prints "ALL OK" as its last line when all checks pass.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
w=${TV_TEST_WORK:-${TMPDIR:-/tmp}/tv3-tests}; mkdir -p "$w"
cd "$here"
if [ $# -gt 0 ]; then tests=$(for n in "$@"; do echo "tests/${n%.pas}.pas"; done); else tests=$(ls tests/t_*.pas); fi
fail=0
for t in $tests; do
    n=$(basename "$t" .pas)
    out=$(${FPC:-fpc} -Mobjfpc -Fusrc -Fisrc -Fitests -Futests -FU"$w" -FE"$w" "$t" 2>&1) || true
    if echo "$out" | grep -qE "Error|Fatal"; then echo "BUILD FAIL $n"; echo "$out" | grep -E "Error|Fatal" | head -3; fail=1; continue; fi
    (cd "$here/tests" && "$w/$n" > "$w/$n.txt" 2>&1) || true
    r=$(tail -1 "$w/$n.txt"); echo "$n: $r"
    case "$r" in "ALL OK"*) ;; *) fail=1; grep -E '^FAIL' "$w/$n.txt" | head -10;; esac
done
exit $fail
