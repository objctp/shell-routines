#!/usr/bin/env bash
#
# Description: [LIBRARY NAME] - Reusable bash functions
# Usage: source /path/to/[FILE].sh
#
# This file provides reusable functions for [PURPOSE]
#
# For general-purpose utilities (logging, validation, temp files), consider
# sourcing the plugin runtime library instead:
#   source "${CLAUDE_PLUGIN_ROOT}/scripts/lib-common.sh"
#
# Functions:
#   shroutines::function_name - Description of what the function does
#

# Guard against direct execution
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && {
  echo "Error: This file should be sourced, not executed" >&2
  exit 2
}

set -euo pipefail

###
### :::: Constants :::: ###############
###

# shellcheck disable=SC2034  # template placeholder, used after scaffolding
readonly _LIB_VERSION="0.1.0"

###
### :::: Globals :::: #################
###

# shellcheck disable=SC2034
_LIB_TEMP_FILES=()

###
### :::: Private functions :::: #######
###

# Cleanup tracking
function _lib_cleanup() {
  local f
  for f in "${_LIB_TEMP_FILES[@]+"${_LIB_TEMP_FILES[@]}"}"; do
    rm -f "$f"
  done
  return 0
}

trap _lib_cleanup EXIT

###
### :::: Public functions :::: ########
###

# Validates user input against a pattern
# Arguments:
#   $1 - input: The string to validate
#   $2 - pattern: Regex pattern to match (optional, defaults to alphanumeric)
# Returns:
#   0 - valid input
#   1 - invalid input

function shroutines::validate_input() {
  local input="$1"
  local pattern="${2:-^[a-zA-Z0-9_-]+$}"

  [[ "$input" =~ $pattern ]]
  return 0
}

# Log a message with timestamp and level (no subprocess)
# Arguments:
#   $1 - level: Log level (INFO, WARN, ERROR, DEBUG)
#   $2 - message: The message to log
# Returns: None
function shroutines::log_message() {
  printf '[%(%Y-%m-%d %H:%M:%S)T] [%s] %s\n' -1 "$1" "${*:2}" >&2
  return 0
}

# Check if a command is available
# Arguments:
#   $1 - command: Name of the command to check
# Returns:
#   0 - command exists
#   1 - command not found
function shroutines::require_command() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    shroutines::log_message "ERROR" "Required command not found: $cmd"
    return 1
  fi

  return 0
}

# Ensure a directory exists, create if missing
# Arguments:
#   $1 - path: Directory path to ensure
#   $2 - mode: Optional permissions (default: 0755)
# Returns:
#   0 - directory exists or was created
#   1 - failed to create directory
function shroutines::ensure_dir() {
  local path="$1"
  local mode="${2:-0755}"

  if [[ ! -d "$path" ]]; then
    mkdir -p "$path" || return 1
    chmod "$mode" "$path"
  fi

  return 0
}

# Create a temporary file with automatic cleanup
# Arguments:
#   $1 - var_name: Name of variable to store temp file path
# Returns:
#   0 - temp file created successfully
#   1 - failed to create temp file
function shroutines::temp_file() {
  local -n var_ref="$1"
  local tmp

  tmp=$(mktemp) || return 1
  # shellcheck disable=SC2034  # nameref: assignment is the intended use
  var_ref="$tmp"

  _LIB_TEMP_FILES+=("$tmp")
  return 0
}

# Export functions for use in subshells
export -f shroutines::validate_input
export -f shroutines::log_message
export -f shroutines::require_command
export -f shroutines::ensure_dir
export -f shroutines::temp_file
