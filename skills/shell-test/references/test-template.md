# Bashunit Test Template

Standard test file structure for bashunit tests.

```bash
#!/usr/bin/env bash
# tests/[script-name]-test.sh

# Runs once before all tests in this file
function set_up_before_script() {
  source path/to/[script_name].sh
}

# Runs before each test
function set_up() {
  TEMP_FILE=$(bashunit::temp_file)
}

# Runs after each test
function tear_down() {
  rm -f "$TEMP_FILE"
}

function test_[function_name]_does_something() {
  local result
  result=$([function_name] "input")
  assert_equals "expected" "$result"
}

function test_[function_name]_handles_empty_input() {
  [function_name] ""
  assert_general_error
}

# Runs once after all tests in this file
function tear_down_after_script() {
  # Cleanup after all tests
}
```

## Template Components

| Component | Scope | Purpose |
|-----------|-------|---------|
| `set_up_before_script()` | Once before all tests | Source the script under test, start services |
| `set_up()` | Before each test | Create temp files, set environment variables |
| `tear_down()` | After each test | Remove temp files, unset variables |
| `test_[name]()` | Per test case | Individual test case -- name describes what is being tested |
| `tear_down_after_script()` | Once after all tests | Stop services, final cleanup |

## Naming Conventions

- **Test file:** `[script-name]-test.sh` in `tests/` directory
- **Test function:** `test_[function_name]_[scenario]()`
- **Custom title:** Use `set_test_title "Description"` inside test functions for descriptive reporting
- **Assertions:** Use descriptive assertions that clearly show expected vs actual
