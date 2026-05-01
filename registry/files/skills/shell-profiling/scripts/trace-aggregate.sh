#!/usr/bin/env bash
set -euo pipefail

# trace-aggregate.sh -- Aggregate xtrace timestamps into cumulative per-line timings
# Usage: trace-aggregate.sh <trace-file> [top-n]
# Produces a ranked list of source locations by cumulative execution time.
#
# Expects trace files generated with:
#   PS4='+ ${EPOCHREALTIME} ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:-main} '
#   BASH_XTRACEFD=N  (redirected to the trace file)

trace_file="${1:?Usage: $0 <trace-file> [top-n]}"
top_n="${2:-20}"

if [[ ! -f "$trace_file" ]]; then
  echo "Error: trace file not found: $trace_file" >&2
  exit 1
fi

awk '
/^+/ {
    ts = $2
    if (prev > 0) {
        delta = ts - prev
        total[$3] += delta
        count[$3]++
    }
    prev = ts
}
END {
    for (loc in total)
        printf "%.4f s  %s (called %d times)\n", total[loc], loc, count[loc]
}
' "$trace_file" | sort -rn | head -n "$top_n"
