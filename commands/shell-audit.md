---
name: shell-audit
description: Audit shell scripts for quality, security, and best practices
argument-hint: path
allowed-tools: [Read, Glob, Bash, Grep]
disable-model-invocation: true
---

# Shell Script Audit

Perform a comprehensive quality audit of the shell script or directory at `$1` by delegating to the **`shell-review`** skill, which owns the review process, output format, and severity categorisation.

## Arguments

- **$1** (required): Script file or directory to audit

## How It Works

1. Validate the target path:
   - Check exists: !`test -e "$1" && echo "EXISTS" || echo "MISSING"`
   - If missing, report the error and stop
2. Gather context if available:
   - ShellCheck: !`command -v shellcheck >/dev/null 2>&1 && echo "AVAILABLE" || echo "UNAVAILABLE"`
3. Pass `$ARGUMENTS` to the `shell-review` skill and execute its full review process:
   - Read and understand the code
   - Interpret ShellCheck and hook diagnostics
   - Run `shell-security` checks for vulnerability detection
   - Categorise findings (Critical / Moderate / Minor)
   - Produce structured output from the review template
4. Return the complete review

## Examples

```bash
# Audit a single script
/shell-audit scripts/deploy.sh

# Audit a directory
/shell-audit scripts/
```

## See Also

- **`shell-review`** skill — The actual review process, output template, and guidelines
- **`shell-security`** skill — Deep security auditing (destructive commands, credentials, system files)
- **`/shell-test-run`** command — Run test suites
- **Hook automation** — ShellCheck and shfmt run automatically on file changes
