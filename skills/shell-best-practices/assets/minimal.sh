#!/usr/bin/env bash
#
# Description: [BRIEF DESCRIPTION]
# Usage: [SCRIPT_NAME] [ARGUMENTS]
# shellcheck disable=SC2034

set -euo pipefail

###
### :::: Constants :::: ###############
###

readonly VERSION="0.1.0"

###
### :::: Globals :::: ###############
###

INPUT=""

###
### :::: Private functions :::: ########
###

# Main logic
function _main() {
  local input="$1"

  if [[ -z "$input" ]]; then
    echo "Error: input required" >&2
    exit 2
  fi

  # Process input
  echo "Processing: $input"
  return 0
}

###
### :::: Public functions :::: ########
###

function shroutines::main() {
  _main "$@"
  return 0
}

###
### :::: Guard and execution :::: #####
###

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  shroutines::main "$@"
fi
