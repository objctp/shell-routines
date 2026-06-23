# Example: Generating Tests

## Input Script

```bash
#!/usr/bin/env bash
# greeter.sh

myapp::greet() {
    local name="${1:-World}"
    echo "Hello, ${name}!"
}

myapp::square() {
    local num="$1"
    if [[ -z "$num" ]]; then
        echo "Error: argument required" >&2
        return 1
    fi
    echo "$((num * num))"
}
```

## Generated Test File

Public functions are called in the main shell with output redirected to a temp file, so bashunit records their body coverage. A function run inside `$(...)` or a pipe does not register coverage — see **Coverage and Subshells** in the skill.

```bash
#!/usr/bin/env bash
# tests/greeter-test.sh

function set_up() {
  OUT=$(bashunit::temp_file)
}

function set_up_before_script() {
    source src/greeter.sh
}

function test_greet_with_name() {
    myapp::greet "Alice" > "$OUT"
    assert_equals "Hello, Alice!" "$(<"$OUT")"
}

function test_greet_defaults_to_world() {
    myapp::greet > "$OUT"
    assert_equals "Hello, World!" "$(<"$OUT")"
}

function test_square_positive_number() {
    myapp::square 5 > "$OUT"
    assert_equals "25" "$(<"$OUT")"
}

function test_square_zero() {
    myapp::square 0 > "$OUT"
    assert_equals "0" "$(<"$OUT")"
}

function test_square_fails_without_argument() {
    myapp::square
    assert_general_error
}
```

## Running Tests

```bash
# Verify public-function coverage meets the 80% target (Step 4)
scripts/public-coverage.sh tests/ --coverage-paths src/

# Run the full suite
/shell-test-run tests/greeter-test.sh
```
