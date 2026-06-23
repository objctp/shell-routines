#!/usr/bin/env bash
# security-audit.sh -- Scan shell scripts for security vulnerabilities
#
# Usage:
#   ./security-audit.sh <file|directory>
#
# Scans .sh files for destructive commands, hardcoded credentials,
# insecure permissions, fork bombs, and other security risks.
# For detailed explanations and fix commands, see references/dangerous-commands.md
#
# shellcheck disable=SC2329

set -euo pipefail

###
### :::: Helpers :::: #################
###

readonly RED='\033[0;31m'
readonly PUR='\033[0;35m'
readonly YEL='\033[0;33m'
readonly LGRN='\033[92m'
readonly RST='\033[0m'
readonly BOLD='\033[1m'

function fatal() { echo -e "${PUR}${BOLD}◆ [FATAL]${RST}  $*"; }
function severe() { echo -e "${RED}● [SEVERE]${RST} $*"; }
function moderate() { echo -e "${YEL}▲ [MODERATE]${RST} $*"; }
function clean() { echo -e "${LGRN}✔ [OK]${RST}    $*"; }

###
### :::: Check functions :::: #########
###

# Internal: grep a file for a pattern, report matches via severity function
# Usage: _check_grep FILE PATTERN SEVERITY_FUNC OK_MSG [MSG_PREFIX]
#   SEVERITY_FUNC: fatal, severe, or moderate
#   OK_MSG: message shown when no matches found
#   MSG_PREFIX: optional prefix before the match (e.g. "Possible fork bomb: ")
# Returns: 0 if clean, 1 if issues found
function _check_grep() {
  local file="$1"
  local pattern="$2"
  local severity="$3"
  local ok_msg="$4"
  local msg_prefix="${5:-}"

  local found=0
  while IFS= read -r raw_line; do
    local line="${raw_line%%:*}"
    local match="${raw_line#*:}"
    [[ -z "$match" ]] && continue
    "$severity" "Line ${line}: ${msg_prefix}${match}"
    found=1
  done < <(grep -nE "$pattern" "$file" 2>/dev/null || true)

  if ((found == 0)); then
    clean "$ok_msg"
  fi
  return "$found"
}

function check_destructive_commands() {
  _check_grep "$1" \
    'rm\s+-rf\s+(/|\$|--no-preserve-root)|dd\s+(if=|of=).*/dev/sd|dd\s+(if=|of=).*/dev/nvme|mkfs\b' \
    fatal "No destructive commands found"
}

function check_fork_bombs() {
  _check_grep "$1" \
    ':\s*\(\)\s*\{.*\|.*:&\s*\}\s*;|\w+\(\)\s*\{\s*\w+\|\w+&\s*\}' \
    fatal "No fork bomb patterns found" "Possible fork bomb: "
}

function check_system_file_writes() {
  _check_grep "$1" \
    '>\s*/etc/(passwd|shadow|sudoers|group|hosts|crontab)|cat\s+>.*etc/' \
    severe "No system file writes found" "Writes to system file: "
}

function check_hardcoded_credentials() {
  _check_grep "$1" \
    '(password|passwd|pwd|api_key|apikey|secret|token|auth)\s*=\s*["\047][^"\047]{8,}' \
    severe "No hardcoded credentials found" "Hardcoded credential: "
}

function check_credential_formats() {
  _check_grep "$1" \
    '(AKIA[0-9A-Z]{16}|gh[pou]_[a-zA-Z0-9]{36}|sk-[a-zA-Z0-9]{20,}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9]{10,}-[0-9]{10,}-[a-zA-Z0-9]{24})' \
    severe "No recognised credential formats found" "Recognised credential format: "
}

function check_insecure_permissions() {
  _check_grep "$1" \
    'chmod\s+777|chmod\s+-R.*777|chmod\s+a\+rwx' \
    severe "No insecure permissions (chmod 777) found" "Insecure permissions: "
}

function check_trap_injection() {
  _check_grep "$1" \
    'trap\s+.*\$' \
    moderate "No trap injection patterns found" "Trap with variable: "
}

function check_dangerous_sudo() {
  _check_grep "$1" \
    'sudo\s+(rm|dd|mkfs|chmod|kill|killall)' \
    severe "No dangerous sudo commands found" "Dangerous sudo command: "
}

function check_system_config_writes() {
  _check_grep "$1" \
    '(echo|printf|sed|awk).*>>.*\/etc\/(ssh|systemd|network)' \
    moderate "No system config writes found" "System config write: "
}

function check_dynamic_execution() {
  _check_grep "$1" \
    'eval\s+.*\$|source\s+.*\$[^({]' \
    moderate "No dynamic execution patterns found" "Dynamic execution: "
}

###
### :::: Audit a single file :::: #####
###

function audit_file() {
  local file="$1"
  local issues=0

  echo ""
  echo -e "${BOLD}=== Security Audit: ${file} ===${RST}"

  local checks=(
    check_destructive_commands
    check_fork_bombs
    check_system_file_writes
    check_hardcoded_credentials
    check_credential_formats
    check_insecure_permissions
    check_trap_injection
    check_dangerous_sudo
    check_system_config_writes
    check_dynamic_execution
  )

  for check in "${checks[@]}"; do
    echo ""
    echo -e "${BOLD}[$check]${RST}"
    if ! "$check" "$file"; then
      ((issues++)) || true
    fi
  done

  echo ""
  if ((issues > 0)); then
    echo -e "${RED}${BOLD}Found ${issues} categories with issues in ${file}${RST}"
    return 1
  else
    echo -e "${LGRN}${BOLD}No security issues found in ${file}${RST}"
    return 0
  fi
}

###
### :::: Main :::: ####################
###

function main() {
  local target="${1:-}"

  if [[ -z "$target" ]]; then
    echo "Usage: $0 <file|directory>" >&2
    exit 1
  fi

  if [[ ! -e "$target" ]]; then
    echo "Error: ${target} does not exist" >&2
    exit 1
  fi

  local total_issues=0

  if [[ -d "$target" ]]; then
    # Scan all .sh files in directory
    local file_count=0
    while IFS= read -r -d '' file; do
      ((file_count++)) || true
      if ! audit_file "$file"; then
        ((total_issues++)) || true
      fi
    done < <(find "$target" -maxdepth 1 -name '*.sh' -print0)

    if ((file_count == 0)); then
      echo "No .sh files found in ${target}" >&2
      exit 1
    fi
  else
    audit_file "$target" || total_issues=1
  fi

  if ((total_issues > 0)); then
    exit 1
  fi
  exit 0
}

main "$@"
