# Bashunit Assertions Reference

Complete list of bashunit assertions for test cases.

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

| Assertion | Use Case | Example |
|-----------|----------|---------|
| `assert_success` | Command exited with 0 | `run_command; assert_success` |
| `assert_general_error` | Command failed (non-zero exit) | `invalid_input; assert_general_error` |
| `assert_successful_code "command"` | Assert command returns success code | `assert_successful_code "curl -s http://localhost/ping"` |

## File Assertions

| Assertion | Use Case | Example |
|-----------|----------|---------|
| `assert_file_exists "$path"` | File exists | `assert_file_exists "/tmp/output.txt"` |
| `assert_file_contains "needle" "$path"` | File contains substring | `assert_file_contains "error" "/var/log/app.log"` |

## Usage Patterns

### Testing Function Output
```bash
function test_function_returns_expected() {
  local result
  result=$(my_function "input")
  assert_equals "expected_value" "$result"
}
```

### Testing Exit Codes
```bash
function test_function_succeeds() {
  my_function "valid_input"
  assert_success
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
| Special characters | `function_name '$!*@#'; assert_success` |
| Large input | `function_name "$(seq 1 10000)"; assert_success` |
| Null/zero values | `function_name 0; assert_equals "0" "$result"` |

## Coverage

bashunit tracks line-level code coverage natively via the `--coverage` flag.

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
