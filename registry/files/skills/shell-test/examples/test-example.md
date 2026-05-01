# Example: Generating Tests

## Input Script

```bash
#!/usr/bin/env bash
# greeter.sh

greet() {
    local name="${1:-World}"
    echo "Hello, ${name}!"
}

square() {
    local num="$1"
    if [[ -z "$num" ]]; then
        echo "Error: argument required" >&2
        return 1
    fi
    echo "$((num * num))"
}
```

## Generated Test File

```bash
#!/usr/bin/env bash
# tests/greeter-test.sh

function set_up_before_script() {
    source src/greeter.sh
}

function test_greet_with_name() {
    local result
    result=$(greet "Alice")
    assert_equals "Hello, Alice!" "$result"
}

function test_greet_defaults_to_world() {
    local result
    result=$(greet)
    assert_equals "Hello, World!" "$result"
}

function test_square_positive_number() {
    local result
    result=$(square 5)
    assert_equals "25" "$result"
}

function test_square_zero() {
    local result
    result=$(square 0)
    assert_equals "0" "$result"
}

function test_square_fails_without_argument() {
    square
    assert_general_error
}
```

## Running Tests

```bash
# Run with coverage enforcement (default 80% threshold)
./bashunit tests/ --coverage --coverage-paths src/ --coverage-min 80

# Or use the plugin's command
/shell-test-run tests/greeter-test.sh
```
