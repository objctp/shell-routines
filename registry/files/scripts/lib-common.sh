#!/usr/bin/env bash
# shellcheck disable=SC2178
#
# Common library of reusable bash functions
# Source this file in your scripts: source /path/to/lib-common.sh
#
# Functions:
#   log_info, log_warn, log_error, log_debug - Logging functions
#   require_command - Check if a command is available
#   validate_input - Validate input against a pattern
#   ensure_dir - Create directory if it doesn't exist
#   temp_file, temp_dir - Create temporary resources with cleanup
#   prompt_yes_no - Interactive yes/no prompt
#   get_timestamp - Get formatted timestamp
#   truncate_string - Truncate string to max length
#

# Guard against direct execution
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && {
  echo "Error: This file should be sourced, not executed" >&2
  exit 2
}

# Version tracking
# shellcheck disable=SC2034  # available for consumers to check library version
readonly LIB_COMMON_VERSION="1.0.0"

###
### :::: Logging Functions :::: #######
###

# Internal: print formatted log line (no subprocess — uses printf %()T builtin)
# Usage: _log "LEVEL" "message"
function _log() {
  printf '[%(%Y-%m-%d %H:%M:%S)T] [%s] %s\n' -1 "$1" "${*:2}" >&2
}

# Log informational message
# Usage: log_info "message"
function log_info() { _log "INFO" "$@"; }

# Log warning message
# Usage: log_warn "message"
function log_warn() { _log "WARN" "$@"; }

# Log error message
# Usage: log_error "message"
function log_error() { _log "ERROR" "$@"; }

# Log debug message (only when DEBUG=1)
# Usage: log_debug "message"
function log_debug() { [[ "${DEBUG:-0}" == "1" ]] && _log "DEBUG" "$@"; }

###
### :::: Command Validation :::: #######
###

# Check if a command is available
# Usage: require_command "cmdname"
# Returns: 0 if command exists, 1 otherwise
function require_command() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Required command not found: $cmd"
    return 1
  fi

  log_debug "Command found: $cmd"
  return 0
}

# Require multiple commands
# Usage: require_commands "cmd1" "cmd2" "cmd3"
# Returns: 0 if all commands exist, 1 otherwise
function require_commands() {
  local missing=()

  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
    return 1
  fi

  return 0
}

###
### :::: Input Validation :::: #######
###

# Validate input against a regex pattern
# Usage: validate_input "input" "pattern"
# Returns: 0 if matches, 1 otherwise
function validate_input() {
  local input="$1"
  local pattern="${2:-^[a-zA-Z0-9_-]+$}"

  [[ "$input" =~ $pattern ]]
}

# Validate a number
# Usage: is_number "value"
function is_number() {
  local value="$1"
  [[ "$value" =~ ^-?[0-9]+$ ]]
}

# Validate a port number (1-65535)
# Usage: is_port "value"
function is_port() {
  local value="$1"
  is_number "$value" && ((value >= 1 && value <= 65535))
}

###
### :::: File System Operations :::: #######
###

# Ensure a directory exists, create if missing
# Usage: ensure_dir "path" [mode]
# Returns: 0 on success, 1 on failure
function ensure_dir() {
  local path="$1"
  local mode="${2:-0755}"

  if [[ ! -d "$path" ]]; then
    log_debug "Creating directory: $path"
    mkdir -p "$path" && chmod "$mode" "$path" || return 1
  fi

  return 0
}

# Create temporary file with automatic cleanup
# Usage: temp_file var_name
# Tracks all temp files in _LIB_TEMP_FILES to avoid overwriting previous traps
function temp_file() {
  local -n var_ref="$1"
  local tmp

  tmp=$(mktemp) || {
    log_error "Failed to create temporary file"
    return 1
  }

  # shellcheck disable=SC2034  # nameref: assignment is the intended use
  var_ref="$tmp"
  log_debug "Created temp file: $tmp"

  _LIB_TEMP_FILES+=("$tmp")
}

# Create temporary directory with automatic cleanup
# Usage: temp_dir var_name
# Tracks all temp dirs in _LIB_TEMP_DIRS to avoid overwriting previous traps
function temp_dir() {
  local -n var_ref="$1"
  local tmp

  tmp=$(mktemp -d) || {
    log_error "Failed to create temporary directory"
    return 1
  }

  # shellcheck disable=SC2034  # nameref: assignment is the intended use
  var_ref="$tmp"
  log_debug "Created temp dir: $tmp"

  _LIB_TEMP_DIRS+=("$tmp")
}

# Initialise cleanup tracking arrays and register a single trap
# shellcheck disable=SC2034  # arrays populated by temp_file/temp_dir
_LIB_TEMP_FILES=()
_LIB_TEMP_DIRS=()
function _lib_cleanup() {
  local f
  for f in "${_LIB_TEMP_FILES[@]+"${_LIB_TEMP_FILES[@]}"}"; do
    rm -f "$f"
  done
  local d
  for d in "${_LIB_TEMP_DIRS[@]+"${_LIB_TEMP_DIRS[@]}"}"; do
    rm -rf "$d"
  done
}
trap _lib_cleanup EXIT

###
### :::: User Interaction :::: ########
###

# Prompt user for yes/no confirmation
# Usage: prompt_yes_no "question" [default]
# Returns: 0 for yes, 1 for no
function prompt_yes_no() {
  local question="$1"
  local default="${2:-n}"
  local prompt
  local response

  # Build prompt string
  if [[ "$default" == "y" ]]; then
    prompt="$question [Y/n] "
  else
    prompt="$question [y/N] "
  fi

  # Read response
  read -r -p "$prompt" response </dev/tty
  response=${response:-$default}

  # Check response
  case "$response" in
  [Yy] | [Yy][Ee][Ss]) return 0 ;;
  *) return 1 ;;
  esac
}

###
### :::: String Utilities :::: #######
###

# Get formatted timestamp
# Usage: get_timestamp [format]
# Default format: YYYY-MM-DD HH:MM:SS
function get_timestamp() {
  local format="${1:-+%Y-%m-%d %H:%M:%S}"
  date "$format"
}

# Truncate string to max length
# Usage: truncate_string "string" max_length [suffix]
function truncate_string() {
  local string="$1"
  local max_length="$2"
  local suffix="${3:-...}"

  if [[ ${#string} -le $max_length ]]; then
    echo "$string"
  else
    printf '%.*s%s' "$((max_length - ${#suffix}))" "$string" "$suffix"
  fi
}

# Repeat a character n times
# Usage: repeat_char "*" 40
function repeat_char() {
  local char="$1"
  local count="$2"

  printf '%*s' "$count" '' | tr ' ' "$char"
}

###
### :::: Array Utilities :::: #########
###

# Check if array contains a value
# Usage: array_contains "value" "${array[@]}"
# Returns: 0 if found, 1 otherwise
function array_contains() {
  local seek="$1"
  shift

  local item
  for item in "$@"; do
    [[ "$item" == "$seek" ]] && return 0
  done

  return 1
}

# Join array elements with delimiter
# Usage: array_join "," "${array[@]}"
function array_join() {
  local delimiter="$1"
  shift

  (($# == 0)) && return 0

  local first="$1"
  shift

  printf '%s' "$first"
  local item
  for item in "$@"; do
    printf '%s%s' "$delimiter" "$item"
  done
}

###
### :::: Exit Handling :::: ###########
###

# Exit with error message
# Usage: die "error message" [exit_code]
function die() {
  local message="$1"
  local exit_code="${2:-1}"

  log_error "$message"
  exit "$exit_code"
}

# Show usage and exit
# Usage: show_usage "usage_string"
function show_usage() {
  local usage="$1"

  echo "$usage" >&2
  exit 2
}

###
### :::: Export Functions :::: ########
###

# Export all public functions for use in subshells
export -f _log log_info log_warn log_error log_debug
export -f require_command require_commands
export -f validate_input is_number is_port
export -f ensure_dir temp_file temp_dir
export -f prompt_yes_no
export -f get_timestamp truncate_string repeat_char
export -f array_contains array_join
export -f die show_usage
