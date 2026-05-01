#!/usr/bin/env bash
# shellcheck disable=SC2178
#
# Batch operations library for shell-routines plugin
# Source this file in scripts that perform multiple operations and return structured JSON
#
# Functions:
#   batch_add_result - Add a key-value pair to results
#   batch_add_metadata - Add metadata entry
#   batch_add_error - Add error entry
#   batch_output - Output JSON result to stdout
#   batch_progress - Log progress to stderr
#

# Guard against direct execution
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && {
  echo "Error: This file should be sourced, not executed" >&2
  exit 2
}

# Version tracking
# shellcheck disable=SC2034
readonly LIB_BATCH_VERSION="1.0.0"

###
### :::: Result Collection :::: #######
###

# Add a key-value pair to results array
# Usage: batch_add_result RESULTS "key" "value"
# Results are stored as: key=value
function batch_add_result() {
  local -n results_ref="$1"
  local key="$2"
  local value="$3"

  results_ref["${key}"]="${value}"
}

# Add a numbered result (for arrays/lists)
# Usage: batch_add_result_item RESULTS "item"
function batch_add_result_item() {
  local -n results_ref="$1"
  local item="$2"

  local index="${#results_ref[@]}"
  results_ref["${index}"]="${item}"
}

# Add metadata entry
# Usage: batch_add_metadata METADATA "key" "value"
function batch_add_metadata() {
  local -n metadata_ref="$1"
  local key="$2"
  local value="$3"

  metadata_ref+=("${key}=${value}")
}

# Add error entry
# Usage: batch_add_error ERRORS "error message"
function batch_add_error() {
  local -n errors_ref="$1"
  local error_msg="$2"

  errors_ref+=("${error_msg}")
}

###
### :::: Progress Logging :::: ########
###

# Log progress message to stderr (doesn't pollute JSON output)
# Usage: batch_progress "Processing file: $file"
function batch_progress() {
  printf '[%(%Y-%m-%d %H:%M:%S)T] [BATCH] %s\n' -1 "$*" >&2
}

# Log step with percentage
# Usage: batch_step "Processing files" 5 100
function batch_step() {
  local message="$1"
  local current="$2"
  local total="$3"

  local percentage=0
  if ((total > 0)); then
    percentage=$((current * 100 / total))
  fi

  batch_progress "${message} (${current}/${total} - ${percentage}%)"
}

###
### :::: JSON Output :::: #############
###

# Fallback for optional ERRORS argument
declare -a _EMPTY_ERRORS=()

# Build JSON from associative array (results)
# Usage: _build_results_json RESULTS
# Returns: JSON object string
function _build_results_json() {
  local -n _brj_ref="$1"
  local json="{"
  local first=true

  for key in "${!_brj_ref[@]}"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      json+=","
    fi

    # Inline JSON escaping (no subprocess)
    local value="${_brj_ref[$key]}"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"

    # Check if value is numeric (integer or float) or boolean
    if [[ "$value" =~ ^-?[0-9]+$ ]] || [[ "$value" =~ ^-?[0-9]+\.[0-9]+$ ]] || [[ "$value" =~ ^(true|false)$ ]]; then
      json+="\"${key}\":${value}"
    else
      json+="\"${key}\":\"${value}\""
    fi
  done

  json+="}"
  printf '%s' "$json"
}

# Build JSON from metadata array
# Usage: _build_metadata_json METADATA
# Returns: JSON object string
function _build_metadata_json() {
  local -n _bmj_ref="$1"
  local json="{"
  local first=true

  for entry in "${_bmj_ref[@]}"; do
    if [[ "$entry" =~ ^([^=]+)=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      # Inline JSON escaping (no subprocess)
      local value="${BASH_REMATCH[2]}"
      value="${value//\\/\\\\}"
      value="${value//\"/\\\"}"
      value="${value//$'\n'/\\n}"
      value="${value//$'\r'/\\r}"
      value="${value//$'\t'/\\t}"

      if [[ "$first" == "true" ]]; then
        first=false
      else
        json+=","
      fi

      json+="\"${key}\":\"${value}\""
    fi
  done

  json+="}"
  printf '%s' "$json"
}

# Build JSON from errors array
# Usage: _build_errors_json ERRORS
# Returns: JSON array string
function _build_errors_json() {
  local -n _bej_ref="$1"
  local json="["

  for i in "${!_bej_ref[@]}"; do
    if ((i > 0)); then
      json+=","
    fi

    # Inline JSON escaping (no subprocess)
    local escaped="${_bej_ref[$i]}"
    escaped="${escaped//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    escaped="${escaped//$'\n'/\\n}"
    escaped="${escaped//$'\r'/\\r}"
    escaped="${escaped//$'\t'/\\t}"
    json+="\"${escaped}\""
  done

  json+="]"
  printf '%s' "$json"
}

# Output final JSON result to stdout
# Usage: batch_output RESULTS METADATA [ERRORS]
# Results: JSON object with results, metadata, and optional errors
function batch_output() {
  local -n results_ref="$1"
  local -n metadata_ref="$2"
  local -n errors_ref="${3:-_EMPTY_ERRORS}"

  local json="{"

  # Add results
  json+="\"results\":$(_build_results_json results_ref),"

  # Add metadata
  json+="\"metadata\":$(_build_metadata_json metadata_ref)"

  # Add errors if any
  if [[ ${#errors_ref[@]} -gt 0 ]]; then
    json+=",\"errors\":$(_build_errors_json errors_ref)"
  fi

  json+="}"
  printf '%s\n' "$json"
}

###
### :::: Batch Processing Helpers :::: ###
###

# Process files with a callback function
# Usage: batch_process_files RESULTS METADATA ERRORS "glob_pattern" callback_function
# Example: batch_process_files RESULTS METADATA ERRORS "*.txt" process_txt_file
function batch_process_files() {
  local -n results_ref="$1"
  local -n metadata_ref="$2"
  local -n errors_ref="$3"
  local pattern="$4"
  local callback="$5"

  local files=()
  local processed=0
  local failed=0

  # Collect files
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find . -name "$pattern" -print0 2>/dev/null)

  local total="${#files[@]}"
  batch_progress "Found ${total} files matching '${pattern}'"

  # Process each file
  local i=0
  for file in "${files[@]}"; do
    i=$((i + 1))
    batch_step "Processing" "$i" "$total"

    if "$callback" "$file"; then
      processed=$((processed + 1))
    else
      failed=$((failed + 1))
      batch_add_error errors_ref "Failed to process: ${file}"
    fi
  done

  # Add summary
  batch_add_result results_ref "total" "$total"
  batch_add_result results_ref "processed" "$processed"
  batch_add_result results_ref "failed" "$failed"

  return 0
}

# Run command and capture output
# Usage: batch_run_command RESULTS "key" command [args...]
# Returns: Exit code of command
function batch_run_command() {
  local -n results_ref="$1"
  local key="$2"
  shift 2

  local output
  local exit_code

  output=$("$@" 2>&1)
  exit_code=$?

  batch_add_result results_ref "${key}_exit" "$exit_code"
  batch_add_result results_ref "${key}_output" "$output"

  return "$exit_code"
}

###
### :::: Export Functions :::: ########
###

export -f batch_add_result batch_add_result_item
export -f batch_add_metadata batch_add_error
export -f batch_progress batch_step
export -f batch_output
export -f batch_process_files batch_run_command
# Internal functions (_build_*, _EMPTY_ERRORS) are not exported
