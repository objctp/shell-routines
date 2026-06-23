# Advanced Testing Patterns

Data providers, spies, and snapshots for richer tests. Verified against bashunit 0.40.0 — confirm against your installed version with `bashunit doc assert`.

## Data Providers (table-driven tests)

Run a test function once per row of data; each row's words become `$1`, `$2`, …:

```bash
function dp_add() {
  echo "2 3 5"      # $1=2  $2=3  expected=$3
  echo "10 10 20"
  echo "0 0 0"
}

# data_provider dp_add
function test_add() {
  assert_equals "$3" "$(( $1 + $2 ))"
}
```

The `# data_provider <fn>` annotation sits directly above the test function. Each line the provider echoes is one test run.

## Spies (verify a function was called)

`bashunit::spy` wraps a function to track its calls without changing its behaviour; the `assert_have_been_called*` assertions then inspect the calls:

```bash
function test_deploy_calls_notify() {
  bashunit::spy notify
  myapp::deploy
  assert_have_been_called notify
  assert_have_been_called_times 1 notify
  assert_have_been_called_with "success" notify
}
```

- `bashunit::mock` **replaces** a command with fixed output; `bashunit::spy` **observes** a function while keeping its behaviour.
- The spy command is `bashunit::spy` (a bare `spy` is not available in user tests).

## Snapshot Testing

For stable multi-line output (help text, generated reports), snapshot it once and assert future runs match:

```bash
function test_help_output() {
  myapp::print_help > "$TEMP_FILE"
  assert_match_snapshot "$(<"$TEMP_FILE")"
}
```

After intentional output changes, refresh the stored snapshot: `bashunit --update-snapshots tests/`.
