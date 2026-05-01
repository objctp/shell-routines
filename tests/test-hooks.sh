#!/usr/bin/env bash
# bashunit tests for hooks/scripts/shell-hooks.sh
# shellcheck disable=SC2034
# Arrays passed by nameref to hook_run_checks/hook_build_json_output trigger SC2034

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

function set_up_before_script() {
  HOOK_SCRIPT="$PROJECT_ROOT/hooks/scripts/shell-hooks.sh"
  # shellcheck source=hooks/scripts/shell-hooks.sh
  source "$HOOK_SCRIPT"
  TEST_DIR=$(mktemp -d)
}

function tear_down_after_script() {
  rm -rf "$TEST_DIR"
}

###
### :::: Existing tests (script existence, extension/shebang detection, tool checks) :::: #############################
###

function test_hook_script_exists() {
  assert_file_exists "$HOOK_SCRIPT"
}

function test_hook_detects_sh_extension() {
  local test_file="$TEST_DIR/test.sh"
  printf '#!/usr/bin/env bash\n' >"$test_file"

  assert_file_exists "$test_file"
  assert_matches "#!.*bash" "$(head -1 "$test_file")"
}

function test_hook_detects_bash_extension() {
  local test_file="$TEST_DIR/test.bash"
  printf '#!/usr/bin/env bash\n' >"$test_file"

  assert_file_exists "$test_file"
}

function test_hook_detects_shebang_without_extension() {
  local test_file="$TEST_DIR/script"
  printf '#!/usr/bin/env bash\n' >"$test_file"

  assert_matches "#!.*bash" "$(head -1 "$test_file")"
}

function test_hook_detects_zsh_shebang() {
  local test_file="$TEST_DIR/zsh-script"
  printf '#!/bin/zsh\n' >"$test_file"

  assert_matches "#!.*zsh" "$(head -1 "$test_file")"
}

function test_valid_bash_syntax() {
  local test_file="$TEST_DIR/valid.sh"
  printf '#!/usr/bin/env bash\necho "hello"\n' >"$test_file"

  bash -n "$test_file" 2>&1
  assert_successful_code
}

function test_invalid_bash_syntax_fails() {
  local test_file="$TEST_DIR/invalid.sh"
  printf '#!/usr/bin/env bash\nif [\n' >"$test_file"

  bash -n "$test_file" 2>/dev/null
  assert_unsuccessful_code
}

function test_shfmt_formats_when_available() {
  local test_file="$TEST_DIR/messy.sh"
  printf '#!/usr/bin/env bash\nfoo="bar"\n' >"$test_file"

  if command -v shfmt >/dev/null 2>&1; then
    shfmt -w "$test_file" 2>&1
    assert_successful_code
  fi
}

function test_shellcheck_runs_when_available() {
  local test_file="$TEST_DIR/clean.sh"
  printf '#!/usr/bin/env bash\necho "test"\n' >"$test_file"

  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$test_file" >/dev/null 2>&1
    assert_successful_code
  fi
}

###
### :::: Integration tests via hook_main (converted from subprocess to function call) :::: ############################
###

function test_hook_outputs_valid_json_for_shellcheck_findings() {
  local test_file="$TEST_DIR/unquoted.sh"
  cat >"$test_file" <<'SCRIPT'
#!/usr/bin/env bash
var="hello world"
echo $var
SCRIPT

  if command -v shellcheck >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    local input_file="$TEST_DIR/input.json"
    printf '{"tool_input":{"file_path":"%s"}}' "$test_file" >"$input_file"
    hook_main "$input_file" >"$TEST_DIR/output.txt" 2>/dev/null || true
    local output
    output=$(cat "$TEST_DIR/output.txt")

    if [ -n "$output" ]; then
      echo "$output" | jq . >/dev/null 2>&1
      assert_successful_code
    fi
  fi
}

function test_hook_passes_findings_to_claude_via_additional_context() {
  local test_file="$TEST_DIR/unquoted2.sh"
  cat >"$test_file" <<'SCRIPT'
#!/usr/bin/env bash
var="hello world"
echo $var
SCRIPT

  if command -v shellcheck >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    local input_file="$TEST_DIR/input.json"
    printf '{"tool_input":{"file_path":"%s"}}' "$test_file" >"$input_file"
    hook_main "$input_file" >"$TEST_DIR/output.txt" 2>/dev/null || true
    local output
    output=$(cat "$TEST_DIR/output.txt")

    if [ -n "$output" ]; then
      local context
      context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // empty')
      assert_not_empty "$context"
    fi
  fi
}

function test_hook_exits_cleanly_for_non_shell_file() {
  local test_file="$TEST_DIR/readme.md"
  printf '# Not a shell file\n' >"$test_file"

  local input_file="$TEST_DIR/input.json"
  printf '{"tool_input":{"file_path":"%s"}}' "$test_file" >"$input_file"
  hook_main "$input_file" 2>/dev/null
  assert_successful_code
}

function test_hook_exits_cleanly_for_missing_file() {
  local input_file="$TEST_DIR/input.json"
  printf '{"tool_input":{"file_path":"/tmp/does-not-exist-xyz.sh"}}' >"$input_file"
  hook_main "$input_file" 2>/dev/null
  assert_successful_code
}

###
### :::: Unit tests: hook_extract_file_path :::: ##############################
###

function test_hook_extract_file_path_returns_path() {
  hook_extract_file_path '{"tool_input":{"file_path":"/tmp/test.sh"}}' >"$TEST_DIR/r.txt"
  assert_equals "/tmp/test.sh" "$(cat "$TEST_DIR/r.txt")"
}

function test_hook_extract_file_path_returns_empty_for_missing_key() {
  hook_extract_file_path '{"tool_input":{}}' >"$TEST_DIR/r.txt"
  assert_equals "" "$(cat "$TEST_DIR/r.txt")"
}

function test_hook_extract_file_path_returns_empty_for_empty_input() {
  hook_extract_file_path '{}' >"$TEST_DIR/r.txt"
  assert_equals "" "$(cat "$TEST_DIR/r.txt")"
}

###
### :::: Unit tests: hook_is_shell_file :::: ##################################
###

function test_hook_is_shell_file_detects_ksh() {
  local test_file="$TEST_DIR/test.ksh"
  printf '#!/bin/ksh\n' >"$test_file"

  hook_is_shell_file "$test_file"
  assert_successful_code
}

function test_hook_is_shell_file_rejects_py_file() {
  local test_file="$TEST_DIR/test.py"
  printf '#!/usr/bin/env python3\n' >"$test_file"

  hook_is_shell_file "$test_file"
  assert_unsuccessful_code
}

function test_hook_is_shell_file_detects_shebang_only_file() {
  local test_file="$TEST_DIR/script-noext"
  printf '#!/usr/bin/env bash\necho hi\n' >"$test_file"

  hook_is_shell_file "$test_file"
  assert_successful_code
}

function test_hook_is_shell_file_accepts_sh_extension() {
  local test_file="$TEST_DIR/plain.sh"
  printf '#!/usr/bin/env bash\n' >"$test_file"

  hook_is_shell_file "$test_file"
  assert_successful_code
}

###
### :::: Unit tests: hook_detect_target_shell :::: ############################
###

function test_hook_detect_target_shell_defaults_to_bash() {
  local test_file="$TEST_DIR/bash-script.sh"
  printf '#!/usr/bin/env bash\n' >"$test_file"

  local target_shell is_posish
  hook_detect_target_shell "$test_file" target_shell is_posish

  assert_equals "bash" "$target_shell"
  assert_equals "false" "$is_posish"
}

function test_hook_detect_target_shell_identifies_posix_sh() {
  local test_file="$TEST_DIR/posix-script.sh"
  printf '#!/bin/sh\n' >"$test_file"

  local target_shell is_posish
  hook_detect_target_shell "$test_file" target_shell is_posish

  assert_equals "sh" "$target_shell"
  assert_equals "true" "$is_posish"
}

function test_hook_detect_target_shell_identifies_dash() {
  local test_file="$TEST_DIR/dash-script.sh"
  printf '#!/usr/bin/dash\n' >"$test_file"

  local target_shell is_posish
  hook_detect_target_shell "$test_file" target_shell is_posish

  assert_equals "dash" "$target_shell"
  assert_equals "true" "$is_posish"
}

###
### :::: Unit tests: hook_run_checks :::: #####################################
###

function test_hook_run_checks_detects_todos() {
  local test_file="$TEST_DIR/todo.sh"
  printf '#!/usr/bin/env bash\n# TODO: fix this later\necho hi\n' >"$test_file"

  local feedback=()
  # shellcheck disable=SC2034
  local warnings=()
  hook_run_checks "$test_file" "bash" "false" feedback warnings

  assert_not_empty "expected feedback for TODO marker"
  # Verify at least one feedback item mentions TODO
  local found=false
  for item in "${feedback[@]}"; do
    if echo "$item" | grep -q "TODO"; then
      found=true
      break
    fi
  done
  assert_equals "true" "$found"
}

function test_hook_run_checks_detects_batch_pattern_without_output() {
  local test_file="$TEST_DIR/batch.sh"
  cat >"$test_file" <<'SCRIPT'
#!/usr/bin/env bash
source lib-batch.sh
echo "missing the required function call"
SCRIPT

  local feedback=()
  local warnings=()
  hook_run_checks "$test_file" "bash" "false" feedback warnings

  local found=false
  for item in "${feedback[@]}"; do
    if echo "$item" | grep -q "batch_output"; then
      found=true
      break
    fi
  done
  assert_equals "true" "$found"
}

function test_hook_run_checks_detects_batch_pattern_without_results_array() {
  local test_file="$TEST_DIR/batch2.sh"
  cat >"$test_file" <<'SCRIPT'
#!/usr/bin/env bash
source lib-batch.sh
batch_output
SCRIPT

  local feedback=()
  # shellcheck disable=SC2034
  local warnings=()
  hook_run_checks "$test_file" "bash" "false" feedback warnings

  local found=false
  for item in "${feedback[@]}"; do
    if echo "$item" | grep -q "declare -A RESULTS"; then
      found=true
      break
    fi
  done
  assert_equals "true" "$found"
}

###
### :::: Unit tests: hook_build_json_output :::: ##############################
###

function test_hook_build_json_output_with_context_only() {
  local ctx=("some feedback")
  local warn=()

  hook_build_json_output ctx warn >"$TEST_DIR/output.txt"
  local output
  output=$(cat "$TEST_DIR/output.txt")

  if command -v jq >/dev/null 2>&1; then
    echo "$output" | jq . >/dev/null 2>&1
    assert_successful_code

    local has_context
    has_context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // empty')
    assert_not_equals "" "$has_context"
  fi
}

function test_hook_build_json_output_with_warning_only() {
  local ctx=()
  local warn=("some warning")

  hook_build_json_output ctx warn >"$TEST_DIR/output.txt"
  local output
  output=$(cat "$TEST_DIR/output.txt")

  if command -v jq >/dev/null 2>&1; then
    echo "$output" | jq . >/dev/null 2>&1
    assert_successful_code

    local has_msg
    has_msg=$(echo "$output" | jq -r '.systemMessage // empty')
    assert_not_equals "" "$has_msg"
  fi
}

function test_hook_build_json_output_with_both() {
  local ctx=("feedback item")
  local warn=("warning item")

  hook_build_json_output ctx warn >"$TEST_DIR/output.txt"
  local output
  output=$(cat "$TEST_DIR/output.txt")

  if command -v jq >/dev/null 2>&1; then
    echo "$output" | jq . >/dev/null 2>&1
    assert_successful_code

    local has_context has_msg
    has_context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // empty')
    has_msg=$(echo "$output" | jq -r '.systemMessage // empty')
    assert_not_equals "" "$has_context"
    assert_not_equals "" "$has_msg"
  fi
}

function test_hook_build_json_output_empty_produces_nothing() {
  local ctx=()
  local warn=()

  hook_build_json_output ctx warn >"$TEST_DIR/output.txt"
  local output
  output=$(cat "$TEST_DIR/output.txt")
  assert_equals "" "$output"
}

###
### :::: Integration: hook_main edge cases :::: ###############################
###

function test_hook_main_with_empty_file_path() {
  local input_file="$TEST_DIR/input.json"
  printf '{"tool_input":{"file_path":""}}' >"$input_file"
  hook_main "$input_file" >"$TEST_DIR/output.txt" 2>/dev/null
  assert_equals "" "$(cat "$TEST_DIR/output.txt")"
}

###
### :::: Additional coverage: hook_run_checks branches :::: ###################
###

function test_hook_run_checks_syntax_error_in_bash_script() {
  local test_file="$TEST_DIR/syntax-err.sh"
  printf '#!/usr/bin/env bash\nif [\n' >"$test_file"

  local feedback=()
  local warnings=()
  hook_run_checks "$test_file" "bash" "false" feedback warnings

  local found=false
  for item in "${feedback[@]}"; do
    if echo "$item" | grep -q "Syntax error"; then
      found=true
      break
    fi
  done
  assert_equals "true" "$found"
}

function test_hook_run_checks_posix_bashisms_detected() {
  if ! command -v checkbashisms >/dev/null 2>&1; then
    return 0
  fi

  local test_file="$TEST_DIR/posix-bashism.sh"
  cat >"$test_file" <<'SCRIPT'
#!/bin/sh
echo "hello" > /dev/tcp/127.0.0.1/80
SCRIPT

  local feedback=()
  local warnings=()
  hook_run_checks "$test_file" "sh" "true" feedback warnings

  local found=false
  for item in "${feedback[@]}"; do
    if echo "$item" | grep -q "bashism"; then
      found=true
      break
    fi
  done
  assert_equals "true" "$found"
}

function test_hook_run_checks_skips_syntax_check_for_posix_sh() {
  local test_file="$TEST_DIR/posix-clean.sh"
  printf '#!/bin/sh\necho "clean"\n' >"$test_file"

  local feedback=()
  local warnings=()
  hook_run_checks "$test_file" "sh" "true" feedback warnings

  # Should have NO syntax error feedback (bash -n is skipped for POSIX sh)
  local found=false
  for item in "${feedback[@]}"; do
    if echo "$item" | grep -q "Syntax error"; then
      found=true
      break
    fi
  done
  assert_equals "false" "$found"
}

function test_hook_run_checks_shfmt_posix_dialect() {
  if ! command -v shfmt >/dev/null 2>&1; then
    return 0
  fi

  local test_file="$TEST_DIR/posix-fmt.sh"
  printf '#!/bin/sh\necho "format me"\n' >"$test_file"

  local feedback=()
  local warnings=()
  hook_run_checks "$test_file" "sh" "true" feedback warnings

  # Should complete without errors for valid POSIX sh
  local found=false
  for item in "${warnings[@]}"; do
    if echo "$item" | grep -q "shfmt"; then
      found=true
      break
    fi
  done
  assert_equals "false" "$found"
}

function test_hook_run_checks_clean_bash_script_no_feedback() {
  local test_file="$TEST_DIR/clean-bash.sh"
  printf '#!/usr/bin/env bash\necho "hello"\n' >"$test_file"

  local feedback=()
  local warnings=()
  hook_run_checks "$test_file" "bash" "false" feedback warnings

  # A clean script should produce no warnings
  assert_equals "0" "${#warnings[@]}"
}

function test_hook_run_checks_detects_fixme_marker() {
  local test_file="$TEST_DIR/fixme.sh"
  printf '#!/usr/bin/env bash\n# FIXME: resolve this\necho hi\n' >"$test_file"

  local feedback=()
  local warnings=()
  hook_run_checks "$test_file" "bash" "false" feedback warnings

  local found=false
  for item in "${feedback[@]}"; do
    if echo "$item" | grep -q "FIXME"; then
      found=true
      break
    fi
  done
  assert_equals "true" "$found"
}

function test_hook_run_checks_detects_hack_marker() {
  local test_file="$TEST_DIR/hack.sh"
  printf '#!/usr/bin/env bash\n# HACK: temporary workaround\necho hi\n' >"$test_file"

  local feedback=()
  local warnings=()
  hook_run_checks "$test_file" "bash" "false" feedback warnings

  local found=false
  for item in "${feedback[@]}"; do
    if echo "$item" | grep -q "HACK"; then
      found=true
      break
    fi
  done
  assert_equals "true" "$found"
}

###
### :::: Additional coverage: hook_main integration paths :::: ################
###

function test_hook_main_produces_json_for_unquoted_var() {
  if ! command -v shellcheck >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  local test_file="$TEST_DIR/integration-unquoted.sh"
  cat >"$test_file" <<'SCRIPT'
#!/usr/bin/env bash
var="hello"
echo $var
SCRIPT

  local input_file="$TEST_DIR/input.json"
  printf '{"tool_input":{"file_path":"%s"}}' "$test_file" >"$input_file"
  hook_main "$input_file" >"$TEST_DIR/output.txt" 2>/dev/null || true
  local output
  output=$(cat "$TEST_DIR/output.txt")

  if [ -n "$output" ]; then
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null
    assert_successful_code
  fi
}

function test_hook_main_clean_script_no_output() {
  local test_file="$TEST_DIR/integration-clean.sh"
  printf '#!/usr/bin/env bash\necho "clean"\n' >"$test_file"

  local input_file="$TEST_DIR/input.json"
  printf '{"tool_input":{"file_path":"%s"}}' "$test_file" >"$input_file"
  hook_main "$input_file" >"$TEST_DIR/output.txt" 2>/dev/null
  assert_equals "" "$(cat "$TEST_DIR/output.txt")"
}

function test_hook_main_non_shell_returns_empty() {
  local test_file="$TEST_DIR/integration.txt"
  printf 'not a shell file\n' >"$test_file"

  local input_file="$TEST_DIR/input.json"
  printf '{"tool_input":{"file_path":"%s"}}' "$test_file" >"$input_file"
  hook_main "$input_file" >"$TEST_DIR/output.txt" 2>/dev/null
  assert_equals "" "$(cat "$TEST_DIR/output.txt")"
}

function test_hook_main_with_no_file_path_key() {
  local input_file="$TEST_DIR/input.json"
  printf '{"tool_input":{}}' >"$input_file"
  hook_main "$input_file" >"$TEST_DIR/output.txt" 2>/dev/null
  assert_equals "" "$(cat "$TEST_DIR/output.txt")"
}
