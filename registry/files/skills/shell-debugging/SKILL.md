---
name: shell-debugging
description: This skill should be used when the user asks to "debug this script", "fix my script", "script not working", "bash error", "shell error", "broken script", "why is this failing", "non-zero exit code", "script exits with error", or any shell error/failure scenario. Covers runtime failures producing errors, wrong output, or unexpected behaviour.
allowed-tools: Read, Edit, Bash, Grep, Glob
argument-hint: [script-path]
---

# Shell Debugging Skill

Guides systematic debugging of bash scripts to identify and resolve issues efficiently.

**Scope**: This skill handles runtime failures — scripts that error, crash, or produce wrong output. For quality assessment of a working script, use `shell-review` instead.

**Design principle**: Never leave debug instrumentation in the target script. Use non-invasive methods (`bash -x`) first; when targeted tracing is needed, instrument a temporary copy and discard it afterwards.

## Debugging Workflow

### 1. Gather Information

**Target script:** `$ARGUMENTS`

If `$ARGUMENTS` is not provided, ask the user which script needs debugging.

Understand the failure:

- **Error message**: What is the exact error?
- **Exit code**: What is `$?` after the failing command?
- **Failure point**: Where exactly does the script fail?
- **Reproduction**: Can the failure be reproduced consistently?

### 2. Read the Target Script

Read `$ARGUMENTS` to understand:

- Overall structure and purpose
- Functions called near the failure point
- Variable dependencies
- Error handling patterns

### 3. Enable Debug Mode

**Non-invasive** — run with tracing from the command line, no file modification:

```bash
bash -x script.sh args
```

- `+` prefix indicates the command being executed
- Variables are expanded before printing

**Targeted tracing** — when you need tracing around a specific section only, create a temporary copy:

```bash
cp script.sh /tmp/script.debug.sh
# Add set -x / set +x around the suspect section in the copy
bash /tmp/script.debug.sh args
rm /tmp/script.debug.sh
```

Never add `set -x` or debug prints directly to the original script.

### 4. Syntax Validation

```bash
bash -n script.sh
```

### 5. Incremental Execution

**Warning**: `source` executes all top-level code in the script. Before sourcing a broken script, inspect it for side effects (file operations, network calls, deployments). Consider using a container or VM for untrusted scripts.

```bash
# Source the script to load functions
source script.sh

# Call functions individually with test data
your_function "test_input"
```

### 6. Identify the Issue

Consult `references/debugging-guide.md` for:

- Error pattern tables and fixes (unbound variables, pipelines, subshells, whitespace)
- Advanced techniques: custom PS4, timing, call logging
- ShellCheck quick-reference table for common warning codes

Quick reference:

- **Print debugging**: `echo "DEBUG: var='$var'" >&2`
- **Syntax check**: `bash -n script.sh`
- **Lint**: `shellcheck script.sh`
- **Trace**: `export PS4='+ [${BASH_SOURCE}:${LINENO}] ${FUNCNAME[0]:-main}: '` then `set -x`

## Additional Resources

### References

- `references/debugging-guide.md` -- Error pattern tables, debugging checklist, common issue solutions, advanced techniques (custom PS4, timing, call logging), ShellCheck quick reference

Always read all references and examples before producing output.

### Examples

- `examples/debug-session.md` -- Walks through diagnosing an unbound variable error from start to finish

## Integration

- **`shell-best-practices`** -- Prevent issues before they occur
- **`shell-review`** -- Quality assessment once the script is working
- **`shell-profiling`** -- For scripts that work correctly but run too slowly. See profiling workflow for timing, tracing, and benchmarking.
- **`/shell-audit`** command -- Comprehensive quality checks
