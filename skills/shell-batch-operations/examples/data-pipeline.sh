#!/usr/bin/env bash
# Example: Multi-stage data pipeline
# Description: Extract log entries, transform them, aggregate by status code
# Usage: ./data-pipeline.sh [log_file]
#
# shellcheck disable=SC1091  # dynamic source paths resolved at runtime
# shellcheck disable=SC2034

set -euo pipefail

SCRIPT_NAME="${0##*/}"

# Source batch utilities
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  source "${CLAUDE_PLUGIN_ROOT}/scripts/lib-batch.sh"
elif [[ -f "$(dirname "$0")/../../scripts/lib-batch.sh" ]]; then
  source "$(dirname "$0")/../../scripts/lib-batch.sh"
else
  echo "Error: Cannot find lib-batch.sh" >&2
  exit 2
fi

# Configuration
LOG_FILE="${1:-access.log}"
STATUS_PATTERN="${STATUS_PATTERN:-'^[0-9]{3}$'}"

# Stage 1: Extract status codes from log file
# Assumes Combined Log Format or similar
function stage1_extract() {
  local log_file="$1"

  batch_progress "Stage 1: Extracting status codes from ${log_file}"

  if [[ ! -r "$log_file" ]]; then
    batch_add_error ERRORS "Cannot read log file: ${log_file}"
    return 1
  fi

  # Extract status codes (assumes standard log format with status at position 9)
  awk '{print $9}' "$log_file" | grep -E "$STATUS_PATTERN" || true
}

# Stage 2: Transform and count status codes
function stage2_transform() {
  batch_progress "Stage 2: Aggregating status codes"

  local -A status_counts
  local count=0

  while IFS= read -r status; do
    if [[ -n "$status" ]]; then
      status_counts["$status"]=$((${status_counts["$status"]:-0} + 1))
      count=$((count + 1))
    fi
  done

  # Output results
  for status in "${!status_counts[@]}"; do
    printf '%s|%s\n' "$status" "${status_counts[$status]}"
  done | sort -t '|' -k2 -nr
}

# Stage 3: Calculate statistics
function stage3_analyze() {
  batch_progress "Stage 3: Calculating statistics"

  local total_requests=0
  local success_requests=0
  local redirect_requests=0
  local error_requests=0

  while IFS='|' read -r status count; do
    total_requests=$((total_requests + count))

    case "$status" in
    2*)
      success_requests=$((success_requests + count))
      ;;
    3*)
      redirect_requests=$((redirect_requests + count))
      ;;
    4* | 5*)
      error_requests=$((error_requests + count))
      ;;
    esac
  done

  printf '%s|%s|%s|%s\n' "$total_requests" "$success_requests" "$redirect_requests" "$error_requests"
}

# Main processing pipeline
function main() {
  declare -A RESULTS
  declare -a METADATA
  declare -a ERRORS

  # Metadata
  batch_add_metadata METADATA "script" "$SCRIPT_NAME"
  batch_add_metadata METADATA "log_file" "$LOG_FILE"
  batch_add_metadata METADATA "started" "$(date -Iseconds)"

  local temp_extract
  local temp_transform
  temp_extract=$(mktemp)
  temp_transform=$(mktemp)
  trap 'rm -f "$temp_extract" "$temp_transform"' EXIT

  # STAGE 1: Extract
  if ! stage1_extract "$LOG_FILE" >"$temp_extract"; then
    batch_add_metadata METADATA "completed" "$(date -Iseconds)"
    batch_add_result RESULTS "success" "false"
    batch_output RESULTS METADATA ERRORS
    return 1
  fi

  local extracted_count
  extracted_count=$(wc -l <"$temp_extract")
  batch_add_result RESULTS "extracted_entries" "$extracted_count"

  # STAGE 2: Transform
  stage2_transform <"$temp_extract" >"$temp_transform"

  # Store top status codes
  local index=0
  while IFS='|' read -r status count && ((index < 10)); do
    batch_add_result RESULTS "status_${status}" "$count"
    index=$((index + 1))
  done <"$temp_transform"

  # STAGE 3: Analyze
  while IFS='|' read -r total success redirect error; do
    batch_add_result RESULTS "total_requests" "$total"
    batch_add_result RESULTS "success_requests" "$success"
    batch_add_result RESULTS "redirect_requests" "$redirect"
    batch_add_result RESULTS "error_requests" "$error"

    # Calculate percentages
    if ((total > 0)); then
      local success_pct=$((success * 100 / total))
      local redirect_pct=$((redirect * 100 / total))
      local error_pct=$((error * 100 / total))

      batch_add_result RESULTS "success_percent" "$success_pct"
      batch_add_result RESULTS "redirect_percent" "$redirect_pct"
      batch_add_result RESULTS "error_percent" "$error_pct"
    fi
  done < <(stage3_analyze <"$temp_transform")

  # Complete metadata
  batch_add_metadata METADATA "completed" "$(date -Iseconds)"
  batch_add_result RESULTS "success" "true"

  # Output JSON
  batch_output RESULTS METADATA ERRORS
}

main "$@"
