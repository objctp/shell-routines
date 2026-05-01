#!/usr/bin/env bash
#
# Example: Batch file processing
# Description: Find all .txt files, count lines in each, return summary statistics
# Usage: ./file-batch.sh [directory]
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
SEARCH_DIR="${1:-.}"
MAX_SIZE="${MAX_SIZE:-10485760}" # 10MB default max file size

# Process a single text file
function process_file() {
  local file="$1"
  local lines
  local size
  local filename

  filename="${file##*/}"
  lines=$(wc -l <"$file" 2>/dev/null)
  lines="${lines// /}"
  size=$(wc -c <"$file" 2>/dev/null)
  size="${size// /}"

  printf '%s|%s|%s\n' "$filename" "$lines" "$size"
}

# Main processing
function main() {
  declare -A RESULTS
  declare -a METADATA
  declare -a ERRORS

  # Metadata
  batch_add_metadata METADATA "script" "$SCRIPT_NAME"
  batch_add_metadata METADATA "search_dir" "$SEARCH_DIR"
  batch_add_metadata METADATA "started" "$(date -Iseconds)"

  batch_progress "Searching for .txt files in: ${SEARCH_DIR}"

  # Variables for statistics
  local file_count=0
  local total_lines=0
  local total_size=0
  local largest_file=""
  local largest_lines=0
  local smallest_file=""
  local smallest_lines=""
  local first_file=true

  # Process files
  local temp_file
  temp_file=$(mktemp)
  trap 'rm -f "$temp_file"' EXIT

  while IFS= read -r -d '' file; do
    batch_progress "Found: ${file}"

    # Check file size
    local file_size
    file_size=$(wc -c <"$file" 2>/dev/null)
    file_size="${file_size// /}"

    if ((file_size > MAX_SIZE)); then
      batch_add_error ERRORS "File too large, skipping: ${file} (${file_size} bytes)"
      continue
    fi

    # Process file
    if output=$(process_file "$file"); then
      echo "$output" >>"$temp_file"
      ((file_count++))
    else
      batch_add_error ERRORS "Failed to process: ${file}"
    fi
  done < <(find "$SEARCH_DIR" -name "*.txt" -print0 2>/dev/null)

  batch_progress "Processing statistics from ${file_count} files"

  # Calculate statistics
  while IFS='|' read -r filename lines size; do
    total_lines=$((total_lines + lines))
    total_size=$((total_size + size))

    # Track largest/smallest
    if ((lines > largest_lines)); then
      largest_lines=$lines
      largest_file="$filename"
    fi

    if $first_file || ((lines < smallest_lines)); then
      first_file=false
      smallest_lines=$lines
      smallest_file="$filename"
    fi
  done <"$temp_file"

  # Calculate averages
  local avg_lines=0
  local avg_size=0
  if ((file_count > 0)); then
    avg_lines=$((total_lines / file_count))
    avg_size=$((total_size / file_count))
  fi

  # Store results
  batch_add_result RESULTS "file_count" "$file_count"
  batch_add_result RESULTS "total_lines" "$total_lines"
  batch_add_result RESULTS "total_size" "$total_size"
  batch_add_result RESULTS "avg_lines" "$avg_lines"
  batch_add_result RESULTS "avg_size" "$avg_size"
  batch_add_result RESULTS "largest_file" "$largest_file"
  batch_add_result RESULTS "largest_lines" "$largest_lines"
  batch_add_result RESULTS "smallest_file" "$smallest_file"
  batch_add_result RESULTS "smallest_lines" "$smallest_lines"

  # Complete metadata
  batch_add_metadata METADATA "completed" "$(date -Iseconds)"

  # Output JSON
  batch_output RESULTS METADATA ERRORS
}

main "$@"
