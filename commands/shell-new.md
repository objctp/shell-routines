---
name: shell-new
description: Scaffold a new bash script from template with best practices
argument-hint: path [type]
allowed-tools: [Read, Write, Bash]
disable-model-invocation: true
---

# Create New Bash Script

Create a new bash script at `$1` by delegating to the **`shell-best-practices`** skill (Mode B — New Script), which owns the scaffolding process, template selection, and standards enforcement.

## Arguments

- **$1** (required): File path where the script will be created
- **$2** (optional): Template type
  - `minimal` — Simple single-function script
  - `standard` — Full-featured script with argument parsing (default)
  - `library` — Sourced by other scripts; provides reusable functions
  - `posix` — Posix compatible script

## How It Works

1. Validate the target path:
   - Check parent directory: !`dirname "$1" | xargs test -d && echo "DIR_EXISTS" || echo "DIR_MISSING"`
   - Check file doesn't already exist: !`test -e "$1" && echo "ALREADY_EXISTS" || echo "NEW"`
   - If directory is missing or file exists, report the issue and stop
2. Pass `$ARGUMENTS` to the `shell-best-practices` skill (Mode B) and execute its scaffolding process:
   - Determine script name from the path
   - Select template type based on `$2` (default: `standard`)
   - Create the file — for directly executed scripts, omit the `.sh` extension (e.g. `deploy` not `deploy.sh`); for libraries meant to be sourced, keep the `.sh` extension (e.g. `lib-helpers.sh`)
   - Fill in placeholders (description, usage, functions)
   - Apply all core standards (shebang, strict mode, quoting, error handling)
   - Make the file executable (`chmod +x`)
3. Hooks run automatically (ShellCheck, shfmt)

## Examples

```bash
# Create a standard script
/shell-new scripts/process-data

# Create a minimal script
/shell-new utils/quick-fix minimal

# Create a library
/shell-new lib/helpers.sh library

# Create in current directory
/shell-new myscript
```

## See Also

- **`shell-best-practices`** skill — Owns the scaffolding process, templates, and core standards
- **`/shell-audit`** command — Quality audit after development
- **`/shell-test-run`** command — Run test suites
