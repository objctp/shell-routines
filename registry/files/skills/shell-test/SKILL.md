---
name: shell-test
description: Generate bashunit test files for bash scripts with proper assertions, setup, and teardown. This skill should be used when writing, creating, or scaffolding test files for shell scripts. Trigger on "write tests", "test this script", "add test coverage", "create unit tests", "generate test file", "bashunit test", "I need tests for", or "how do I test this".
allowed-tools: Read, Write, Edit, Bash
argument-hint: [script-path]
---

# Shell Test Generation

Generates bashunit test files for bash scripts.

Scope: test file generation only. For running tests, use the `/shell-test-run` command. For debugging failing tests, use `shell-debugging` instead.

## Process

**Target script:** `$ARGUMENTS`

If `$ARGUMENTS` is not provided, ask the user which script to generate tests for. If `$ARGUMENTS` is a directory, generate tests for each `.sh` file in that directory.

1. **Read and analyse the target script** at `$ARGUMENTS`
2. **Create test file** — `tests/$(basename "$ARGUMENTS" .sh)-test.sh` (create `tests/` directory if it does not exist)
3. **Write test cases** — generate tests to meet the **coverage target** (default 80%)
4. **Show usage** — inform the user to run tests with `/shell-test-run`

### Step 1: Analyse the Target Script

Before writing any tests, identify:

- **Public functions** — functions intended to be called externally; test all of these
- **Private functions** — helper functions prefixed with `_` or `__`; test only if they contain non-trivial logic
- **Side effects** — file I/O, network calls, process creation, environment variable mutation
- **External dependencies** — calls to other scripts, CLI tools, or APIs
- **Main block** — code executed at source time (outside any function); determines sourcing strategy

### Step 2: Create the Test File

Place the test file at `tests/[script-name]-test.sh`. Create the `tests/` directory if it does not exist.

Use the `set_up_before_script()` function to source the target script. This keeps the sourcing path explicit and easy to adjust.

### Step 3: Write Test Cases

Generate enough test cases to meet the default 80% coverage target. Prioritise in this order:

1. **Happy path** — each function called with valid input, asserting expected output or exit code
2. **Edge cases** — empty input, whitespace, special characters, zero/null values (see `references/assertions.md` edge-case table)
3. **Error paths** — invalid input, missing arguments, failed preconditions

For the complete assertion reference, consult `references/assertions.md`.

### Step 4: Show Usage

After generating the test file, display a summary of generated tests and instruct the user to run them with `/shell-test-run`.

### Coverage Target

Default: 80% line coverage. Override per-script via `/shell-test-run --coverage-min N`.

For full details including all CLI flags (`--coverage`, `--coverage-paths`, `--coverage-exclude`, `--coverage-report-html`, `--no-coverage-report`) and enforcement behaviour, consult `references/assertions.md` -- Coverage section.

## Test Structure

For the complete test file template with setup/teardown functions, consult `references/test-template.md`.

bashunit provides four lifecycle hooks:

| Hook | Scope | Typical Use |
|------|-------|-------------|
| `set_up_before_script()` | Once before all tests | Source the script under test, start services |
| `set_up()` | Before each test | Create temp files, set environment variables |
| `tear_down()` | After each test | Remove temp files, unset variables |
| `tear_down_after_script()` | Once after all tests | Stop services, final cleanup |

## Handling Common Patterns

### Scripts with a Main Block

Many bash scripts contain top-level code that runs on source (e.g. argument parsing, `main "$@"`). This code executes when the test file sources the script, causing unintended side effects.

Detect this pattern by looking for code outside function definitions. When present, wrap the main block in a guard:

```bash
# In the source script, wrap the main block:
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

If modifying the source script is not possible, use environment variables to control behaviour:

```bash
function set_up_before_script() {
  export SKIP_MAIN=1
  source path/to/script.sh
  unset SKIP_MAIN
}
```

### Scripts with Side Effects

Functions that write files, create directories, or modify global state require cleanup. Use `set_up()` and `tear_down()` for per-test isolation. Use `bashunit::temp_file` for temporary file paths:

```bash
function set_up() {
  TEMP_FILE=$(bashunit::temp_file)
}

function tear_down() {
  rm -f "$TEMP_FILE"
}
```

For one-time resources (e.g. test databases, service instances), use `set_up_before_script()` and `tear_down_after_script()` instead.

### Scripts Using External Commands

When a function calls external tools (`curl`, `git`, `docker`, etc.), use `bashunit::mock` to replace them with controlled responses:

```bash
function test_fetch_queries_api() {
  bashunit::mock curl <<< '{"status":"ok"}'
  local result
  result=$(fetch_data "http://example.com")
  assert_contains "ok" "$result"
}
```

For conditional behaviour based on arguments, define a mock function and pass it to `bashunit::mock`:

```bash
function test_deploy_checks_region() {
  mockAws() {
    if [[ "$1" == "region" ]]; then echo "eu-west-1"; fi
  }
  bashunit::mock aws mockAws
  local result
  result=$(deploy_function)
  assert_contains "eu-west-1" "$result"
}
```

### Scripts with Environment Variables

Functions that read environment variables should be tested with both set and unset states. Set variables in `set_up()` and unset in `tear_down()` to prevent state leaking between tests:

```bash
function set_up() {
  export AWS_REGION="eu-west-1"
}

function tear_down() {
  unset AWS_REGION
}

function test_deploy_uses_custom_region() {
  local result
  result=$(deploy_function)
  assert_contains "eu-west-1" "$result"
}

function test_deploy_defaults_to_us_east_1() {
  unset AWS_REGION
  local result
  result=$(deploy_function)
  assert_contains "us-east-1" "$result"
}
```

## Test Naming Conventions

Follow a consistent naming pattern to make test intent clear:

| Pattern | Use For | Example |
|---------|---------|---------|
| `test_[fn]_returns_[expected]` | Happy path output | `test_square_returns_product` |
| `test_[fn]_defaults_to_[value]` | Default/fallback behaviour | `test_greet_defaults_to_world` |
| `test_[fn]_handles_[edge_case]` | Boundary or unusual input | `test_parse_handles_empty_input` |
| `test_[fn]_fails_on_[condition]` | Error/invalid input | `test_square_fails_on_missing_arg` |
| `test_[fn]_with_[setup]` | When a specific state is needed | `test_deploy_with_custom_region` |

For descriptive test output, use `set_test_title` inside the test function:

```bash
function test_parse_handles_empty_input() {
  set_test_title "Parser gracefully handles empty input string"
  parse ""
  assert_general_error
}
```

## Assertions

For the complete assertion reference with usage patterns, edge-case testing, and coverage CLI flags, consult `references/assertions.md`.

## Additional Resources

### Reference Files

- `references/test-template.md` -- Complete test file structure with setup/teardown
- `references/assertions.md` -- Full assertion reference with usage patterns and edge-case table

Always read all references and examples before generating tests.

### Example Files

- `examples/test-example.md` -- End-to-end example showing input script, generated tests, and execution

## Integration

- **`/shell-test-run`** command — Run generated tests
- **`shell-expert`** agent — Complex test scenarios
- **`shell-review`** skill — Test quality review
- **`shell-debugging`** skill — Debug failing tests
