#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic source paths resolved at runtime
#
# Batch script template for shell-routines plugin
# Description: [Brief description of what this batch script does]
# Usage: ./script-name.sh [arguments]
# Output: JSON with results, metadata, and optional errors
#

set -euo pipefail

###
### :::: CONFIGURATION :::: ###########
###

SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source batch utilities
# Note: CLAUDE_PLUGIN_ROOT is set by Claude Code plugin
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  source "${CLAUDE_PLUGIN_ROOT}/scripts/lib-batch.sh"
elif [[ -f "${SCRIPT_DIR}/lib-batch.sh" ]]; then
  source "${SCRIPT_DIR}/lib-batch.sh"
else
  echo "Error: Cannot find lib-batch.sh. Install shell-routines plugin or copy lib-batch.sh to ${SCRIPT_DIR}/" >&2
  exit 2
fi

###
### :::: ARGUMENT PARSING :::: ########
###

# Default values
VERBOSE=0

# shellcheck disable=SC2034  # VERBOSE is a template placeholder, used after scaffolding
while getopts ":vh" opt; do
  case "$opt" in
  v) VERBOSE=1 ;;
  h)
    echo "Usage: $SCRIPT_NAME [options]"
    echo "Options:"
    echo "  -v    Verbose output"
    echo "  -h    Show this help"
    exit 0
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 2
    ;;
  esac
done

shift $((OPTIND - 1))

###
### :::: FUNCTIONS :::: ###############
###

# Process a single item
# Usage: process_item "item"
# Returns: 0 on success, 1 on failure
process_item() {
  local item="$1"

  # Your processing logic here
  batch_progress "Processing: ${item}"

  return 0
}

# Main processing function
# Usage: main
main() {
  # Results storage
  # shellcheck disable=SC2034  # passed by nameref to lib-batch.sh functions
  declare -A RESULTS
  # shellcheck disable=SC2034
  declare -a METADATA
  # shellcheck disable=SC2034
  declare -a ERRORS

  # Add metadata
  batch_add_metadata METADATA "script" "$SCRIPT_NAME"
  batch_add_metadata METADATA "started" "$(date -Iseconds)"

  ###
  ### :::: YOUR LOGIC HERE :::: ########
  ###

  batch_progress "Starting batch processing"

  # Capture total before processing loop
  local total=$#

  # Example: Process items
  local count=0
  for item in "$@"; do
    if process_item "$item"; then
      count=$((count + 1))
    else
      batch_add_error ERRORS "Failed to process: ${item}"
    fi
  done

  # Add summary results
  batch_add_result RESULTS "total" "$total"
  batch_add_result RESULTS "processed" "$count"
  batch_add_result RESULTS "failed" "$(($# - count))"

  ###
  ### :::: OUTPUT RESULTS :::: #########
  ###

  batch_add_metadata METADATA "completed" "$(date -Iseconds)"
  batch_output RESULTS METADATA ERRORS
}

###
### :::: ENTRY POINT :::: #############
###

main "$@"
