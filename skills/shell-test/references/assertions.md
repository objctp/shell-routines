# Bashunit Assertions Reference

Complete list of bashunit assertions for test cases.

> **Verify against your installed version.** This is a static summary — the authoritative list, including exact signatures, is `bashunit doc assert` (filter with `bashunit doc <term>`, e.g. `bashunit doc exit`). Run it before relying on an assertion: versions differ (e.g. `assert_success` was removed; `assert_exec` was added; the exit-code family takes **no** command argument — see Exit Code Assertions below).

## Core Assertions

| Assertion | Use Case | Example |
|-----------|----------|---------|
| `assert_equals "expected" "$actual"` | String comparison (ignores ANSI colours) | `assert_equals "hello" "$output"` |
| `assert_same "expected" "$actual"` | Exact comparison (including special chars) | `assert_same "hello" "hello"` |
| `assert_not_same "a" "b"` | Exact inequality | `assert_not_same "hello" "world"` |
| `assert_matches "regex" "$string"` | Regex pattern matching | `assert_matches "^[0-9]+$" "$var"` |
| `assert_not_matches "regex" "$string"` | Negative regex match | `assert_not_matches "^[a-z]+$" "123"` |
| `assert_contains "needle" "$haystack"` | Substring check | `assert_contains "error" "$log"` |
| `assert_not_contains "needle" "$haystack"` | Negative substring check | `assert_not_contains "ok" "$log"` |
| `assert_contains_ignore_case "NEEDLE" "$haystack"` | Case-insensitive substring | `assert_contains_ignore_case "hello" "Hello World"` |
| `assert_empty "$var"` | Assert value is empty | `assert_empty ""` |
| `assert_not_empty "$var"` | Assert value is non-empty | `assert_not_empty "content"` |
| `assert_string_starts_with "prefix" "$string"` | Prefix check | `assert_string_starts_with "Hello" "Hello World"` |
| `assert_string_ends_with "suffix" "$string"` | Suffix check | `assert_string_ends_with "World" "Hello World"` |
| `assert_string_matches_format "%d items" "$string"` | Format matching with placeholders | `assert_string_matches_format "%d items at %f each" "42 items at 9.99 each"` |
| `assert_line_count N "$multiline"` | Assert number of lines | `assert_line_count 3 "$output"` |

## Exit Code Assertions

These read `$?` from the command run immediately before the assertion — they take **no** command argument. To run a command string and check its exit in one call, use `assert_exec`.

| Assertion | Use Case | Example |
|-----------|----------|---------|
| `assert_exit_code "N"` | Last command exited with code N | `cmd; assert_exit_code 2` |
| `assert_successful_code` | Last command exited 0 | `ok_cmd; assert_successful_code` |
| `assert_unsuccessful_code` | Last command exited non-zero | `bad_cmd; assert_unsuccessful_code` |
| `assert_general_error` | Last command exited 1 | `bad_input; assert_general_error` |
| `assert_command_not_found` | Last command exited 127 | `missing; assert_command_not_found` |
| `assert_exec "cmd" --exit N` | Run a command string, assert its exit | `assert_exec "curl -s http://x" --exit 0` |

## File Assertions

| Assertion | Use Case | Example |
|-----------|----------|---------|
| `assert_file_exists "$path"` | File exists | `assert_file_exists "/tmp/output.txt"` |
| `assert_file_contains "needle" "$path"` | File contains substring | `assert_file_contains "error" "/var/log/app.log"` |
| `assert_file_not_exists "$path"` | File does not exist | `assert_file_not_exists "/tmp/old"` |
| `assert_directory_exists "$path"` | Directory exists | `assert_directory_exists "/var/log"` |
| `assert_directory_not_exists "$path"` | Directory does not exist | `assert_directory_not_exists "/tmp/missing"` |

## Array Assertions

| Assertion | Use Case | Example |
|-----------|----------|---------|
| `assert_array_contains "needle" "${arr[@]}"` | Array contains value | `assert_array_contains "apple" "${fruits[@]}"` |
| `assert_array_not_contains "needle" "${arr[@]}"` | Array does not contain value | `assert_array_not_contains "pear" "${fruits[@]}"` |

## Usage Patterns

### Testing Function Output
```bash
function test_function_returns_expected() {
  my_function "input" > "$TEMP_FILE"   # main-shell call so coverage records the body
  assert_equals "expected_value" "$(<"$TEMP_FILE")"
}
```

### Testing Exit Codes
```bash
function test_function_succeeds() {
  my_function "valid_input"
  assert_successful_code
}

function test_function_fails_on_invalid_input() {
  my_function "invalid_input"
  assert_general_error
}
```

### Testing File Operations
```bash
function test_creates_output_file() {
  my_function "$TEMP_FILE"
  assert_file_exists "$TEMP_FILE"
}

function test_output_contains_expected_content() {
  my_function "$TEMP_FILE"
  assert_file_contains "expected text" "$TEMP_FILE"
}
```

### Testing String Content
```bash
function test_output_contains_error_message() {
  local result
  result=$(my_function)
  assert_contains "Error:" "$result"
}
```

### Testing Pattern Matching
```bash
function test_returns_numeric_id() {
  local result
  result=$(get_id)
  assert_matches "^[0-9]+$" "$result"
}
```

### Mocking External Commands
```bash
# Simple mock with fixed output
function test_fetch_returns_data() {
  bashunit::mock curl <<< '{"status":"ok"}'
  local result
  result=$(fetch_data "http://example.com")
  assert_contains "ok" "$result"
}

# Conditional mock based on arguments
function test_deploy_selects_region() {
  mockAws() {
    if [[ "$1" == "region" ]]; then echo "eu-west-1"; fi
  }
  bashunit::mock aws mockAws
  local result
  result=$(deploy_function)
  assert_equals "eu-west-1" "$result"
}

# Multi-line mock with heredoc
function test_ps_lists_processes() {
  bashunit::mock ps <<EOF
PID TTY          TIME CMD
1234 pts/0    00:00:01 bash
EOF
  local result
  result=$(list_processes)
  assert_line_count 2 "$result"
}
```

## Edge Case Testing

| Edge Case | Test Pattern |
|-----------|--------------|
| Empty input | `function_name ""; assert_general_error` |
| Whitespace input | `function_name "   "; assert_equals "trimmed" "$result"` |
| Special characters | `function_name '$!*@#'; assert_successful_code` |
| Large input | `function_name "$(seq 1 10000)"; assert_successful_code` |
| Null/zero values | `function_name 0; assert_equals "0" "$result"` |

## Coverage

bashunit tracks **whole-file** line-level code coverage natively via the `--coverage` flag. This includes main blocks, private helpers, and untestable external calls, so it can under-state how well public functions are tested or be unreachable on some scripts. To measure **public-function** coverage directly (scoped to `<namespace>::` functions, excluding private `_` helpers and non-function code), run `scripts/public-coverage.sh`.

### CLI Flags

| Flag | Purpose | Example |
|------|---------|---------|
| `--coverage` | Enable coverage tracking | `bashunit tests/ --coverage` |
| `--coverage-min N` | Fail if coverage below N% | `bashunit tests/ --coverage-min 80` |
| `--coverage-paths` | Source paths to track | `--coverage-paths "src/,lib/"` |
| `--coverage-exclude` | Exclude glob patterns | `--coverage-exclude "vendor/*,*_mock.sh"` |
| `--coverage-report-html` | Generate HTML report | `--coverage-report-html coverage/html` |
| `--no-coverage-report` | Console output only (skip LCOV) | `--coverage --no-coverage-report` |

### Enforcement

- **Default threshold**: 80% (set via `--coverage-min 80`)
- **Behaviour**: bashunit exits with code 1 if coverage is below the threshold -- suitable for CI pipelines
- **Override**: pass a different threshold to `/shell-test-run`

```bash
# Standard run with default 80% threshold
bashunit tests/ --coverage --coverage-paths src/ --coverage-min 80

# Lower threshold for scripts with untestable external calls
bashunit tests/ --coverage --coverage-min 50

# Example failure output
# Coverage: 75.5% (below minimum 80%)
# Exit code: 1
```
