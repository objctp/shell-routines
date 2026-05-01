---
name: shell-test-run
description: Run bash script tests with coverage enforcement
argument-hint: path
allowed-tools: [Bash, Read, Glob]
disable-model-invocation: false
---

# Run Bash Tests

Run tests for bash scripts at `$1` (default: current directory) using the available testing framework. Execute with coverage enabled and enforce an 80% minimum threshold.

## Arguments

- **$1** (optional): Script or directory to test (default: current directory)

## How It Works

1. Detect available test framework:
   - bashunit: !`command -v bashunit >/dev/null 2>&1 && echo "AVAILABLE" || echo "UNAVAILABLE"`
2. Validate the target path if provided:
   - Check exists: !`test -z "$1" || { test -e "$1" && echo "EXISTS" || echo "MISSING"; }`
   - If missing, report the error and stop
3. Run tests using the detected framework:
   - If bashunit: run with `--coverage --coverage-min 80` against `$1` or default test directory
   - Report results, coverage percentage, and any failures
4. If no framework is found, report the issue and suggest installing bashunit

## Examples

```bash
# Run all tests in current directory
/shell-test-run

# Run tests for specific script
/shell-test-run tests/process-test.sh

# Run tests in a directory
/shell-test-run ./tests
```

## See Also

- **`shell-test`** skill — Test writing patterns, framework setup, and coverage configuration
- **`/shell-audit`** command — Quality audit for scripts under test
- **`/shell-new`** command — Scaffold new scripts with test-ready structure
