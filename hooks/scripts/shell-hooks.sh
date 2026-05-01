#!/usr/bin/env bash
# Shell format hook for shell-routines plugin
# PostToolUse hook - fires after Write or Edit on shell scripts
# Runs: ShellCheck (linting), shfmt (formatting), bash -n (syntax),
#       checkbashisms (POSIX sh only), TODO grep
# Output: JSON on stdout only — either hookSpecificOutput or empty object

set -euo pipefail

###
### :::: Cache tool availability (run once per invocation) :::: ###############
###

_HAS_SHELLCHECK=false
_HAS_SHFMT=false
_HAS_CHECKBASHISMS=false

function _cache_tool_availability() {
  command -v shellcheck >/dev/null 2>&1 && _HAS_SHELLCHECK=true
  command -v shfmt >/dev/null 2>&1 && _HAS_SHFMT=true
  command -v checkbashisms >/dev/null 2>&1 && _HAS_CHECKBASHISMS=true
}
_cache_tool_availability
readonly _HAS_SHELLCHECK _HAS_SHFMT _HAS_CHECKBASHISMS

###
### :::: Extract file path from JSON input :::: ###############################
###

# Reads JSON from a temp file rather than a shell argument to avoid
# hitting system ARG_MAX limits with large payloads.
function hook_extract_file_path() {
  local input_file="$1"
  jq -r '.tool_input.file_path // empty' "$input_file"
}

###
### :::: Detect whether a file is a shell script :::: #########################
###

# Uses exit code as the return convention (0 = yes, 1 = no), consistent
# with hook_detect_target_shell below and idiomatic for use in `if` tests.
function hook_is_shell_file() {
  local file_path="$1"
  local ext="${file_path##*.}"

  case "$ext" in
  sh | bash | zsh | ksh)
    return 0
    ;;
  esac

  local first_line=""
  IFS= read -r first_line <"$file_path" 2>/dev/null || true

  if [[ "$first_line" =~ ^#!.*\b(bash|sh|zsh|ksh)\b ]]; then
    return 0
  fi

  return 1
}

###
### :::: Detect target shell dialect from shebang :::: ########################
###

# Sets caller-supplied variables via nameref rather than printing two lines
# to stdout, avoiding a hidden line-order protocol and keeping the values
# in the caller's scope without a subshell.
# Usage: hook_detect_target_shell "$file_path" target_shell_var is_posish_var
function hook_detect_target_shell() {
  local file_path="$1"
  local -n __hdt_target_shell__="$2"
  local -n __hdt_is_posish__="$3"

  local shebang=""
  IFS= read -r shebang <"$file_path" 2>/dev/null || true

  __hdt_target_shell__="bash"
  __hdt_is_posish__="false"

  if [[ "$shebang" =~ ^#!.*\bdash\b ]]; then
    __hdt_target_shell__="dash"
    __hdt_is_posish__="true"
  elif [[ "$shebang" =~ ^#!.*\bsh\b ]] && [[ ! "$shebang" =~ \b(bash|zsh|ksh)\b ]]; then
    __hdt_target_shell__="sh"
    __hdt_is_posish__="true"
  fi
}

###
### :::: Run all checks, populating feedback/warnings arrays via nameref :::: #
###

function hook_run_checks() {
  local file_path="$1"
  local target_shell="$2"
  local is_posish="$3"
  local -n __hr_feedback__="$4"
  local -n __hr_warnings__="$5"

  # ShellCheck — dialect-aware; findings go to Claude as additionalContext
  if [[ "$_HAS_SHELLCHECK" == "true" ]]; then
    local sc_output
    sc_output=$(shellcheck -s "$target_shell" "$file_path" 2>&1 || true)
    if [ -n "$sc_output" ]; then
      __hr_feedback__+=("ShellCheck findings in ${file_path} (shell=${target_shell}):"$'\n'"${sc_output}")
    fi
  fi

  # shfmt — checks formatting with correct dialect; reports drift as context for Claude
  # Dialect map: posix covers sh/dash; mksh covers ksh variants.
  # zsh is treated as bash (closest supported dialect shfmt offers).
  if [[ "$_HAS_SHFMT" == "true" ]]; then
    local shfmt_dialect="bash"
    case "$target_shell" in
    sh | dash) shfmt_dialect="posix" ;;
    ksh) shfmt_dialect="mksh" ;;
    esac
    local shfmt_diff
    shfmt_diff=$(shfmt -ln "$shfmt_dialect" -i 2 -d "$file_path" 2>&1 || true)
    if [ -n "$shfmt_diff" ]; then
      __hr_feedback__+=("Formatting drift in ${file_path} (shfmt dialect= ${shfmt_dialect}):"$'\n'"${shfmt_diff}")
    fi
  fi

  # bash -n syntax check — only for bash-targeting scripts.
  # Skipped for POSIX sh: bash accepts some constructs that dash rejects,
  # so a clean bash -n result would give false confidence for sh scripts.
  if [ "$is_posish" = "false" ]; then
    local syntax_err
    syntax_err=$(bash -n "$file_path" 2>&1 || true)
    if [ -n "$syntax_err" ]; then
      __hr_feedback__+=("Syntax error in ${file_path}: ${syntax_err}")
    fi
  fi

  # checkbashisms — POSIX sh scripts only
  # Detects bash-specific features that would fail under dash
  if [ "$is_posish" = "true" ] && [[ "$_HAS_CHECKBASHISMS" == "true" ]]; then
    local bashisms
    bashisms=$(checkbashisms "$file_path" 2>&1 || true)
    if [ -n "$bashisms" ]; then
      __hr_feedback__+=("POSIX compatibility issue in ${file_path} — bashisms detected:"$'\n'"${bashisms}"$'\n'"Note: /bin/sh is dash on Ubuntu/Debian. These will fail at runtime.")
    fi
  fi

  # Surface TODO/FIXME/HACK/XXX/BUG — goes to Claude as context
  local todos
  todos=$(grep -n -E '(^|[^[:alnum:]_])(TODO|FIXME|HACK|XXX|BUG):' "$file_path" 2>/dev/null || true)
  if [ -n "$todos" ]; then
    __hr_feedback__+=("Unresolved markers in ${file_path}:"$'\n'"${todos}")
  fi

  # Detect batch script pattern — checks for lib-batch.sh usage
  if grep -q "lib-batch.sh" "$file_path" 2>/dev/null; then
    if ! grep -q "batch_output" "$file_path" 2>/dev/null; then
      __hr_feedback__+=("Batch script detected in ${file_path}: ensure batch_output() is called to return JSON results")
    fi
    if ! grep -q "declare -A RESULTS" "$file_path" 2>/dev/null; then
      __hr_feedback__+=("Batch script detected in ${file_path}: declare RESULTS array with: declare -A RESULTS")
    fi
  fi
}

###
### :::: Build JSON output from feedback/warnings arrays :::: #################
###

# Nameref aliases use double-underscore wrapping to minimise the risk of
# colliding with the caller's variable names (a known Bash nameref hazard).
function hook_build_json_output() {
  local -n __bjo_ctx__="$1"
  local -n __bjo_warn__="$2"

  if [ "${#__bjo_ctx__[@]}" -eq 0 ] && [ "${#__bjo_warn__[@]}" -eq 0 ]; then
    return 0
  fi

  local IFS=$'\n'
  local context="${__bjo_ctx__[*]}"
  local warning="${__bjo_warn__[*]}"

  # Lazy jq -Rs: only fork when the string is non-empty
  # additionalContext  → shown to Claude
  # systemMessage      → shown to the user as a warning
  if [ -n "$context" ] && [ -n "$warning" ]; then
    local escaped_context escaped_warning
    escaped_context=$(printf '%s' "$context" | jq -Rs .)
    escaped_warning=$(printf '%s' "$warning" | jq -Rs .)
    printf '{"systemMessage":%s,"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":%s}}' \
      "$escaped_warning" "$escaped_context"
  elif [ -n "$context" ]; then
    local escaped_context
    escaped_context=$(printf '%s' "$context" | jq -Rs .)
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":%s}}' \
      "$escaped_context"
  else
    local escaped_warning
    escaped_warning=$(printf '%s' "$warning" | jq -Rs .)
    printf '{"systemMessage":%s}' "$escaped_warning"
  fi
}

###
### :::: Orchestrator :::: ####################################################
###

function hook_main() {
  local input_file="$1"
  local file_path
  file_path=$(hook_extract_file_path "$input_file")

  [ -z "$file_path" ] && return 0
  # Canonicalise path — resolves .., symlinks, and prevents traversal
  file_path=$(realpath -- "$file_path" 2>/dev/null) || return 0
  [ ! -f "$file_path" ] && return 0

  # hook_is_shell_file now uses exit codes — no stdout capture needed
  if ! hook_is_shell_file "$file_path"; then
    return 0
  fi

  # hook_detect_target_shell now sets variables via nameref — no process
  # substitution or line-reading protocol needed
  local target_shell is_posish
  hook_detect_target_shell "$file_path" target_shell is_posish

  # shellcheck disable=SC2034
  local claude_feedback=()
  # shellcheck disable=SC2034
  local user_warnings=()
  hook_run_checks "$file_path" "$target_shell" "$is_posish" claude_feedback user_warnings
  hook_build_json_output claude_feedback user_warnings
}

###
### :::: Entrypoint: only run when executed directly (not sourced) :::: #######
###

# stdin is written to a temp file so it can be passed by path rather than
# as a shell argument, sidestepping ARG_MAX limits on large JSON payloads.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _input_tmp=$(mktemp)
  trap 'rm -f "$_input_tmp"' EXIT
  cat >"$_input_tmp"
  hook_main "$_input_tmp"
  exit 0
fi
