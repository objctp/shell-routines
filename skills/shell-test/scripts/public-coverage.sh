#!/usr/bin/env bash
# public-coverage.sh -- Measure PUBLIC-function line coverage (plugin convention).
#
# Public functions are <namespace>::function_name (e.g. shroutines::add, myapp::run).
# Private functions are _function_name (leading underscore). This script reports line
# coverage scoped to PUBLIC functions only -- excluding private helpers and all
# non-function code (main blocks, top-level statements, constants).
#
# Why: bashunit's --coverage / --coverage-min measure WHOLE-FILE line coverage, which
# includes untestable code (main blocks, external calls) and can be unreachable or
# meaningless. The ~80% target in the shell-test skill refers to public-function
# coverage; this script measures that figure directly.
#
# Requires: bashunit >= 0.36 (BASHUNIT_COVERAGE_SHOW_FUNCTIONS / per-function LCOV).
#
# Usage:
#   public-coverage.sh [--min N] [bashunit args...]
#       --min N   Minimum public-function coverage percent (default 80)
#   Examples:
#       public-coverage.sh tests/ --coverage-paths src/
#       public-coverage.sh --min 90 tests/ --coverage-paths src/,lib/
#
# Exit status: 0 if public coverage >= threshold; 1 if below or no public functions.

set -euo pipefail

MIN=80
ARGS=()
while (($# > 0)); do
  case "$1" in
  --min)
    MIN="${2:?--min requires a value}"
    shift 2
    ;;
  --)
    shift
    ARGS=("$@")
    break
    ;;
  *)
    ARGS+=("$1")
    shift
    ;;
  esac
done

# Run bashunit with per-function output forced on. Swallow its exit code: a test
# failure or a whole-file --coverage-min miss must not abort the public-coverage check.
RAW=$(BASHUNIT_COVERAGE_SHOW_FUNCTIONS=true bashunit "${ARGS[@]}" --coverage 2>&1) || true

# From the "Functions" section, extract each entry as "<name> <hit> <total>".
FUNCS=$(printf '%s\n' "$RAW" |
  sed $'s/\x1b\\[[0-9;]*m//g' |
  awk '/^Functions$/{f=1;next} /^Coverage report written/{f=0} f && /lines \(/' |
  sed -nE 's/^ +([^ ]+) +([0-9]+)\/ *([0-9]+) lines.*/\1 \2 \3/p') || true

echo "Public-function coverage (<namespace>::name; private _ helpers excluded)"
echo "------------------------------------------------------------------------"

PUB_HIT=0
PUB_TOTAL=0
while IFS=' ' read -r name hit total; do
  [[ -z "${name:-}" ]] && continue
  # public = namespaced with :: and not private (_-prefixed)
  if [[ "$name" == *::* && "$name" != _* ]]; then
    [[ "${total:-0}" =~ ^[0-9]+$ ]] || continue
    ((total == 0)) && continue
    pct=$((hit * 100 / total))
    printf '  %-36s %s/%s (%d%%)\n' "$name" "$hit" "$total" "$pct"
    PUB_HIT=$((PUB_HIT + hit))
    PUB_TOTAL=$((PUB_TOTAL + total))
  fi
done <<<"${FUNCS}"

echo "------------------------------------------------------------------------"
if ((PUB_TOTAL == 0)); then
  echo "No public (<namespace>::name) functions found in the coverage report." >&2
  echo "Namespace your public functions (e.g. myapp::run) per the plugin convention," >&2
  echo "or fall back to whole-file coverage: bashunit tests/ --coverage --coverage-min N." >&2
  exit 1
fi

PUB_PCT=$((PUB_HIT * 100 / PUB_TOTAL))
printf 'Public functions: %d/%d lines (%d%%)  --  threshold %d%%\n' \
  "$PUB_HIT" "$PUB_TOTAL" "$PUB_PCT" "$MIN"

if ((PUB_PCT >= MIN)); then
  echo "PASS"
  exit 0
else
  echo "FAIL: public-function coverage below threshold" >&2
  exit 1
fi
