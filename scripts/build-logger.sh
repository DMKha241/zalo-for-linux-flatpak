#!/usr/bin/env bash
set -euo pipefail

log=$1
shift
printf '$'
printf ' %q' "$@"
printf '\n'

export CLICOLOR_FORCE=1
export FORCE_COLOR=1
export CMAKE_COLOR_DIAGNOSTICS=ON
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

if "$@" 2>&1 | tee "$log"; then
    exit 0
else
    status=$?
fi

printf 'Command failed (%s); full log: %s\n' "$status" "$log" >&2
grep -nEi 'fatal error:|error:|make(\[[0-9]+\])?: \*\*\*|FAILED:|No rule to make target' "$log" | tail -n 12 >&2 || true
tail -n 20 "$log" >&2
exit "$status"
