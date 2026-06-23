# Shell Script Debugging Guide

## Quick Reference

### Enable Debug Output
```bash
# Print each command before execution
set -x

# Print script lines as read
set -v

# Show function calls in trace
set -o functrace
```

### Disable Debug Output
```bash
set +x
set +v
set +o functrace
```

### Syntax Check
```bash
# Parse without executing
bash -n script.sh

# Check all .sh files
for f in *.sh; do bash -n "$f"; done
```

## Debugging Checklist

Use this checklist when troubleshooting:

### Environment Issues
- [ ] Correct shell? (`echo $SHELL`, `ps -p $$`)
- [ ] Bash version compatible? (`bash --version`)
- [ ] Required tools installed? (`command -v toolname`)
- [ ] PATH correct? (`echo $PATH`)
- [ ] Environment variables set? (`env | grep VAR`)

### Syntax Issues
- [ ] Run `bash -n script.sh` for syntax errors
- [ ] Check paired quotes: `'` and `"`
- [ ] Check paired brackets: `(`, `[`, `{`, `((`, `[[`
- [ ] Check line continuation: `\` at end of lines
- [ ] No Windows line endings? (`file script.sh`)

### Variable Issues
- [ ] Variable defined before use?
- [ ] Variable scope correct? (`local` vs global)
- [ ] Proper quoting? `"$var"` not `$var`
- [ ] Default value needed? `${var:-default}`
- [ ] Indirect reference correct? `${!varname}`

### Logic Issues
- [ ] Correct comparison operator?
  - Strings: `[[ "$a" == "$b" ]]` or `[ "$a" = "$b" ]`
  - Numbers: `(( a == b ))` or `[ "$a" -eq "$b" ]`
- [ ] Test returns expected value? `echo $?`
- [ ] Exit codes correct? 0=success, non-zero=failure
- [ ] Pipeline error handled? `set -o pipefail`

### File Issues
- [ ] File exists? `[[ -f "$file" ]]`
- [ ] Readable? `[[ -r "$file" ]]`
- [ ] Correct path? Absolute vs relative
- [ ] Permission problems? `ls -l "$file"`

## Common Patterns

### Debug Function

```bash
debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Usage
DEBUG=1
debug "Variable value: $var"
```

### Debug Section

```bash
# Enable debug for a section only
debug_section() {
    local PS4='+ ${BASH_SOURCE}:${LINENO}: '
    set -x
    # Problematic code here
    "$@"
    set +x
}

debug_section your_function arg1 arg2
```

### Trace Variable Changes

```bash
# Monitor variable assignment
# Note: eval is used here for diagnostic purposes only.
# Do not copy this pattern into production scripts.
trace_var() {
    local var_name="$1"
    local old_value="${!var_name}"
    local new_value="$2"

    echo "[TRACE] $var_name: '$old_value' -> '$new_value'" >&2
    eval "$var_name='$new_value'"
}

# Usage
trace_var myvar "new value"
```

## Debugging Specific Issues

### "Command not found"

**Symptoms**: Script fails with `command: not found`

**Checklist**:
1. Verify command spelling
2. Check if command exists: `which command` or `command -v command`
3. Verify PATH: `echo $PATH`
4. Check if alias/function shadowing: `type command`

**Solution**:
```bash
# Use absolute path
/usr/bin/python3 script.py

# Or verify command exists first
if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 not found" >&2
    exit 1
fi
```

### "Unbound variable"

**Symptoms**: Script fails with `unbound variable` when using `set -u`

**Checklist**:
1. Variable used before definition?
2. Empty array causing issue?
3. Conditional variable not set?

**Solution**:
```bash
# Provide default value
echo "${var:-default}"

# Or allow empty
echo "${var:-}"

# Or check first
if [[ -n "${var:-}" ]]; then
    echo "$var"
fi
```

### Pipeline fails silently

**Symptoms**: Error in middle of pipeline doesn't cause exit

**Solution**:
```bash
# Enable pipefail
set -euo pipefail

# Or capture pipeline status
command1 | command2
pipeline_status=(${PIPESTATUS[@]})
if [[ ${pipeline_status[0]} -ne 0 ]]; then
    echo "command1 failed" >&2
fi
```

### Subshell loses variables

**Symptoms**: Variables set in pipeline/subshell not available after

**Solution**:
```bash
# BAD - var lost
echo "data" | while read line; do
    var="$line"
done
echo "$var"  # Empty

# GOOD - var preserved
while IFS= read -r line; do
    var="$line"
done < <(echo "data")
echo "$var"  # Works
```

### Whitespace breaking arguments

**Symptoms**: Filename with spaces causing errors

**Solution**:
```bash
# BAD
for file in *.txt; do
    mv $file /dest/
done

# GOOD
for file in *.txt; do
    mv "$file" /dest/
done

# GOOD for find
find . -name "*.txt" -print0 | while IFS= read -r -d '' file; do
    mv "$file" /dest/
done
```

### "Wrong branch" in && || chain

**Symptoms**: The `||` fallback command runs unexpectedly, even when the initial command succeeded

**Checklist**:
1. Is there a `cmd1 && cmd2 || cmd3` pattern?
2. Did `cmd2` fail even though `cmd1` succeeded?
3. The `||` triggers on ANY failure in the chain, not just `cmd1`

**Solution**:
```bash
# BAD - if cmd2 fails, cmd3 runs regardless of cmd1
deploy && healthcheck || rollback

# GOOD - use explicit if/else
if deploy && healthcheck; then
    echo "OK"
else
    rollback
fi
```

### Numeric comparison gives wrong result

**Symptoms**: A numeric comparison behaves unexpectedly (e.g., "9 is less than 7")

**Checklist**:
1. Does the comparison use `>` or `<` inside `[[ ]]`?
2. `>` inside `[[ ]]` is lexicographic, not numeric: `"9" < "7"` as strings
3. Does the comparison use `-gt`/`-lt` in `(( ))`? Those are wrong — `(( ))` uses `>`/`<`

**Solution**:
```bash
# BAD - lexicographic comparison
[[ $count > 7 ]]    # "9" is NOT greater than "7" as strings

# GOOD - arithmetic context
(( count > 7 ))

# GOOD - or test operators inside [[ ]]
[[ $count -gt 7 ]]
```

## Advanced Debugging

### Custom PS4 for Better Traces

```bash
# Custom trace prompt
export PS4='+ [${BASH_SOURCE}:${LINENO}] ${FUNCNAME[0]:-main}: '

set -x
# Your code here
set +x
```

### Logging All Calls

```bash
# Log every function call
declare -A call_log
call_count() {
    local func="${FUNCNAME[1]}"
    ((call_log[$func]++)) || true
    echo "Call $func: ${call_log[$func]}" >&2
}

trap 'call_count' DEBUG

# ... script code ...

trap - DEBUG  # Disable
```

### Timing Execution

```bash
# Time a section
start=$(date +%s.%N)
# ... code ...
end=$(date +%s.%N)
duration=$(echo "$end - $start" | bc)
echo "Took: $duration seconds"
```

> For comprehensive performance profiling with PS4 timing, BASH_XTRACEFD, strace analysis, and benchmarking workflows, see the `shell-profiling` skill.

## ShellCheck Quick Reference

Common ShellCheck warnings and fixes:

| SC Code | Meaning | Fix |
|---------|---------|-----|
| SC2086 | Double quote to prevent globbing | Use `"$var"` |
| SC2039 | In POSIX sh | Replace bashism |
| SC2164 | Use `cd ... || exit` | Add error handling |
| SC2155 | Declare and assign separately (masks return value) | Declare, then assign: `local x; x="$(cmd)"` |
| SC2002 | Useless use of cat | Pass the file directly: `grep pattern file` |
| SC2046 | Quote to prevent word splitting | `"$(cmd)"` |
| SC1091 | File not found | Fix path or disable |
| SC2206 | Word splitting when filling an array | `read -ra arr <<< "$s"` or `mapfile -t arr` |

Run ShellCheck:
```bash
shellcheck script.sh
# Or with specific format
shellcheck -f gcc script.sh
# Or ignore specific rules
shellcheck -e SC2039 script.sh
```
