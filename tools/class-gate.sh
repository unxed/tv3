#!/bin/sh
# The class migration gate: no type of the old object model in the Pascal sources of the tree.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

# a type of the old object model: "= object" or "= packed object" (the method pointers "of object" and the class TObject are fine)
if LC_ALL=C grep -r -l -i -E --include='*.pas' --include='*.pp' --include='*.inc' --include='*.dpr' --exclude-dir=.git \
    '=[[:space:]]*(packed[[:space:]]+)?obj[e]ct([[:space:]]|\(|;|$)' "$here"; then
    echo "CLASS GATE FAIL: legacy type spelling is still present" >&2
    exit 1
else
    status=$?
    if [ "$status" -ne 1 ]; then
        echo "CLASS GATE FAIL: tree scan could not be completed" >&2
        exit "$status"
    fi
fi
echo "tv3 class gate: PASS"
