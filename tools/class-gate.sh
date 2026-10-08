#!/bin/sh
# The class migration gate covers every working file, including build caches.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

if LC_ALL=C grep -r -a -l -i --exclude-dir=.git --exclude=.git \
    'obj[e]ct' "$here"; then
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
