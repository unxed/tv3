#!/bin/sh
# The audit in one command: fetches the reference corpora once (into $CORPORA, default ~/.cache/tv-audit: outside the
# repository, never committed), then compares with them the tree and every file of every commit of the history.
# usage: tools/audit/run.sh            needs: python3, git, curl, sha256sum, unrar, unzip
set -eu
here=$(cd "$(dirname "$0")/../.." && pwd)
export CORPORA=${CORPORA:-${XDG_CACHE_HOME:-$HOME/.cache}/tv-audit}
cd "$here"
tools/audit/fetch-corpora.sh
allowed=""
if [ -d tools/audit/facts ]; then allowed="--allowed $CORPORA/allowed.txt"; fi
paths=$(for d in src app tests tools demo; do if [ -d "$d" ]; then printf "%s " "$d"; fi; done)
rc=0
audit() {
    r=0
    python3 tools/audit/borrow-audit.py --cache "$CORPORA/index" --ref "$CORPORA/list.txt" $allowed "$@" > "$CORPORA/last.txt" || r=$?
    grep -v '^generated' "$CORPORA/last.txt" || true
    [ $r = 0 ] || rc=1
}
echo "== the tree"
audit $paths
echo "== every commit of the history"
audit --git-range HEAD
[ $rc = 0 ] && echo "AUDIT PASS" || echo "AUDIT FAIL"
exit $rc
