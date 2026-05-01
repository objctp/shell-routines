#!/usr/bin/env bash
set -euo pipefail

# bench.sh -- Manual benchmark harness for shell scripts
# Usage: bench.sh [-r runs] [-w warmup] [--] <command...>
#   -r runs     Number of measured runs (default: 10)
#   -w warmup   Number of warm-up runs to discard (default: 1)
#   --          End option parsing; all following args form the command
#
# Example:
#   bench.sh -r 15 -w 2 -- bash script.sh arg1 arg2
#   bench.sh -- ./my-script

runs=10
warmup=1
cmd=()

while [[ $# -gt 0 ]]; do
  case "$1" in
  -r)
    runs="${2:?Missing value for -r}"
    shift 2
    ;;
  -w)
    warmup="${2:?Missing value for -w}"
    shift 2
    ;;
  --)
    shift
    cmd=("$@")
    break
    ;;
  *)
    cmd=("$@")
    break
    ;;
  esac
done

if [[ ${#cmd[@]} -eq 0 ]]; then
  echo "Usage: $0 [-r runs] [-w warmup] [--] <command...>" >&2
  exit 1
fi

# Warm-up runs (discarded)
for ((i = 1; i <= warmup; i++)); do
  "${cmd[@]}" >/dev/null 2>&1 || true
done

# Measured runs
results=()
for ((i = 1; i <= runs; i++)); do
  start=$EPOCHREALTIME
  "${cmd[@]}" >/dev/null 2>&1 || true
  end=$EPOCHREALTIME
  elapsed=$((10#${end%.*} * 1000000 + 10#${end#*.} - 10#${start%.*} * 1000000 - 10#${start#*.}))
  results+=("$elapsed")
done

# Compute statistics
mapfile -t sorted < <(printf '%s\n' "${results[@]}" | sort -n)

min=${sorted[0]}
max=${sorted[-1]}
mid=$((runs / 2))
median=${sorted[$mid]}

if [[ $((runs % 2)) -eq 0 ]]; then
  median=$(((median + sorted[$((mid - 1))]) / 2))
fi

echo "Runs:      $runs (+ $warmup warm-up)"
echo "Median:    $((median / 1000)) ms"
echo "Min:       $((min / 1000)) ms"
echo "Max:       $((max / 1000)) ms"
echo "Spread:    $(((max - min) / 1000)) ms"
