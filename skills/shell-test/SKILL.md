---
name: shell-test
description: Generate bashunit test files for bash scripts — analyse the target, scaffold a test file with setup/teardown, and write happy-path, edge, and error cases targeting ~80% public-function coverage. Use when creating tests for a shell script ("write tests", "test this script", "add test coverage"). For running tests use /shell-test-run; for debugging failing tests use shell-debugging.
allowed-tools: Read, Write, Edit, Bash
argument-hint: [script-path]
---

# Shell Test Generation

Generates bashunit test files for bash scripts.

Scope: generate test files and verify they meet the ~80% public-function coverage target. For running the full suite in CI, use `/shell-test-run`. For debugging failing tests, use `shell-debugging` instead.

## Process

**Target script:** `$ARGUMENTS`

If `$ARGUMENTS` is not provided, ask the user which script to generate tests for. If `$ARGUMENTS` is a directory, generate tests for each `.sh` file in that directory.

1. **Read and analyse the target script** at `$ARGUMENTS`
2. **Create test file** — `tests/$(basename "$ARGUMENTS" .sh)-test.sh` (create `tests/` directory if it does not exist)
3. **Write test cases** — happy-path, edge, and error coverage for every public function
4. **Verify coverage** — run `scripts/public-coverage.sh`; if below target, return to step 3
5. **Show usage** — inform the user to run the full suite with `/shell-test-run`

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

Write tests so **every public function** has happy-path, edge, and error coverage — this is the real target. Prioritise:

1. **Happy path** — each public function called with valid input, asserting expected output or exit code
2. **Edge cases** — empty input, whitespace, special characters, zero/null values (see `references/assertions.md` edge-case table)
3. **Error paths** — invalid input, missing arguments, failed preconditions

Aim for ~80% coverage of public-function behaviour.

For the complete assertion reference, consult `references/assertions.md`.

### Step 4: Verify Coverage

Run the public-function coverage check on the generated tests:

```bash
scripts/public-coverage.sh "tests/$(basename "$ARGUMENTS" .sh)-test.sh" --coverage-paths "$(dirname "$ARGUMENTS")/"
```

If the result is below the threshold (default 80%), the report names the uncovered public functions — return to **Step 3** and add happy/edge/error cases for them, then re-run. Stop when the target is met.

If it reports "no public functions", the target has no `<namespace>::` functions: either namespace them per the convention, or skip this check and rely on whole-file coverage (`/shell-test-run --coverage-min`).

### Step 5: Show Usage

After generating the test file, display a summary of generated tests and instruct the user to run them with `/shell-test-run`.

**Done when** every public function has happy-path, edge, and error tests; every assertion used is confirmed available in the installed bashunit (`bashunit doc assert`); the test file sources cleanly under `set_up_before_script()`; and main-block and side-effect patterns are handled. Verify coverage with `scripts/public-coverage.sh`.

### Coverage Target

Target: ~80% line coverage of **public functions** (`<namespace>::name`). bashunit's `--coverage`/`--coverage-min` report **whole-file** coverage — which includes main blocks, private helpers, and untestable code — so the skill measures the public-function figure directly in Step 4 (`scripts/public-coverage.sh`; `--min N` to change the threshold).

For all bashunit CLI flags, consult `references/assertions.md` -- Coverage section.

## Test Structure

bashunit provides four lifecycle hooks — `set_up_before_script`, `set_up`, `tear_down`, `tear_down_after_script`. See `references/test-template.md` for the full hook table and the complete test-file skeleton.

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

### Sourcing and Strict Mode

bashunit runs tests with strict mode **off** (`set +euo pipefail`) so a failing command doesn't abort before an assertion can inspect `$?`. But `shell-best-practices` mandates `set -euo pipefail` at the top of every script — so sourcing the script under test re-enables strict mode, and `failing_cmd; assert_general_error` aborts before the assertion runs. Save and restore shell options around the source (the default in the test template):

```bash
function set_up_before_script() {
  local _opts
  _opts=$(shopt -po errexit nounset pipefail 2>/dev/null || true)
  source path/to/script.sh
  eval "$_opts"   # restore bashunit's non-strict execution model
}
```

Also: when bashunit sources the test, `$0` is bashunit's binary, not the script under test — so a script that resolves its own directory via `$(dirname "$0")` computes the wrong path. Set the relevant path variable before sourcing.

### Scripts with Side Effects

Functions that write files, create directories, or modify global state require cleanup. Use `set_up()` and `tear_down()` for per-test isolation. Use `bashunit::temp_file` for a temporary file or `bashunit::temp_dir` for a directory:

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

When a function calls external tools (`curl`, `git`, `docker`, etc.), replace them with `bashunit::mock`. The simplest form feeds a fixed response:

```bash
bashunit::mock curl <<< '{"status":"ok"}'
```

For conditional mocks, multi-line heredoc mocks, and the full pattern set, see `references/assertions.md` -- Mocking External Commands.

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

### Coverage and Subshells

bashunit's coverage tracks the main shell only. A function called inside `$(...)`, a pipeline, or `( )` runs in a subshell — its body lines are **not** recorded, so public-function coverage reads 0% even when the test passes. Since Step 4 enforces public-function coverage, call every function under test in the main shell and capture its output through a file:

```bash
function test_myapp_add() {
  myapp::add 2 3 > "$TEMP_FILE"   # main-shell call -> body lines covered
  assert_equals "5" "$(<"$TEMP_FILE")"
}
```

`$(<file)` reads the file without re-running the function. Functions you are *not* measuring coverage on may still use `result=$(fn)`.

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
- `references/advanced-patterns.md` -- Data providers, spies, and snapshot testing

Always read all references and examples before generating tests.

### Example Files

- `examples/test-example.md` -- End-to-end example showing input script, generated tests, and execution

### Scripts

- `scripts/public-coverage.sh` -- Measures line coverage scoped to public (`<namespace>::`) functions, excluding private `_` helpers and non-function code. Usage: `scripts/public-coverage.sh [--min N] [bashunit args...]`

## Integration

- **`/shell-test-run`** command — Run generated tests
- **`shell-expert`** agent — Complex test scenarios
- **`shell-review`** skill — Test quality review
- **`shell-debugging`** skill — Debug failing tests
