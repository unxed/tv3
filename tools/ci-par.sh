#!/bin/bash
# Runs the commands of $CMDS (one per line) side by side, each with a HOME of its own and the XDG directories in it (the pty
# tests mostly wait for the program, so they do not compete for the CPU), then prints the output of each one in a group of
# the log and fails when any of them failed.
# usage: CMDS="cmd1
# cmd2" tools/ci-par.sh
set -u
dir=$(mktemp -d)
i=0
pids=()
cmds=()
while IFS= read -r c; do
  [ -z "$c" ] && continue
  i=$((i + 1))
  cmds[$i]=$c
  ( export HOME="$dir/home$i"
    export XDG_CONFIG_HOME="$HOME/.config" XDG_STATE_HOME="$HOME/.local/state" XDG_DATA_HOME="$HOME/.local/share" XDG_CACHE_HOME="$HOME/.cache"
    mkdir -p "$HOME"
    start=$(date +%s)
    bash -c "$c" > "$dir/out$i" 2>&1; echo $? > "$dir/rc$i"
    echo $(( $(date +%s) - start )) > "$dir/time$i" ) &
  pids[$i]=$!
done <<< "${CMDS:-}"
for p in "${pids[@]}"; do wait "$p"; done
rc=0
for n in $(seq 1 $i); do
  r=$(cat "$dir/rc$n" 2>/dev/null || echo 1)
  echo "::group::[$r, $(cat "$dir/time$n" 2>/dev/null)s] ${cmds[$n]}"
  cat "$dir/out$n"
  echo "::endgroup::"
  if [ "$r" != 0 ]; then
    echo "::error::failed ($r): ${cmds[$n]}"
    rc=1
  fi
done
rm -rf "$dir"
exit $rc
