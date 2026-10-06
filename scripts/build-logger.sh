#!/usr/bin/env bash
set -euo pipefail

log=$1
shift
printf '$'
printf ' %q' "$@"
printf '\n'

if "$@" >"$log" 2>&1; then
    exit 0
else
    status=$?
fi

printf 'Command failed (%s); full log: %s\n' "$status" "$log" >&2
grep -nEi 'fatal error:|error:|make(\[[0-9]+\])?: \*\*\*|FAILED:|No rule to make target' "$log" | tail -n 12 >&2 || true
tail -n 20 "$log" >&2
exit "$status"
