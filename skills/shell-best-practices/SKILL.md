---
name: shell-best-practices
description: Write secure, portable bash scripts with proper structure, error handling, and quoting. This skill should be used when creating, modifying, scaffolding, or auditing bash/shell scripts — including new scripts from scratch, bash functions, helpers, deployment scripts, file operations, service checks, and backups. Trigger on "write a bash script", "create a script", "new shell script", "scaffold", "bash function", "shell automation", "bash helper", "fix this script", "refactor bash", "add error handling to", "shell script best practices", or any request to begin a new bash file. Also applies when refactoring, debugging, or hardening an existing shell script.
allowed-tools: Read, Write, Edit, Bash
argument-hint: [script-name-or-path]
---

# Shell Best Practices Skill

Guides Claude to write secure, portable, well-structured bash scripts — and to scaffold new scripts from the right template when starting from scratch.

## When This Skill Applies

- Writing or modifying any shell script
- Creating a new bash script ("create a script", "new bash file", "scaffold", "script template")
- Improving or auditing existing shell code
- Writing bash functions, helpers, or libraries

## Two Modes

**Mode A — Modify/improve**: Apply the core standards below to the existing script at `$ARGUMENTS`.

**Mode B — New script**: Select the appropriate template (see Templates section), create the file at `$ARGUMENTS` (see naming rules in Scaffolding Process), fill in the placeholders, then apply core standards.

---

## Core Standards

Every script must include:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- **Shebang**: `#!/usr/bin/env bash` — not `/bin/bash`
- **Strict mode**: `set -euo pipefail` — catches unbound variables, failed commands, and pipe errors
- **Strict mode caveat**: `set -e` does not exit on failures inside `if`/`while` conditions, `&&`/`||` chains, subshells, or negated commands. Use explicit exit-code checks or `trap ERR` for reliable error handling:
  ```bash
  trap 'echo "Error at line $LINENO" >&2; exit 1' ERR
  ```

### Quoting

- Always quote variable expansions: `"$var"`, `"${array[@]}"`
- Quote command substitutions: `"$(cmd)"`
- Never leave variables unquoted in command positions

### Naming Conventions

- Local variables: `lower_case_with_underscores`
- Constants and globals/exports: `UPPERCASE_WITH_UNDERSCORES`
- Public functions: `<namespace>::function_name` — use `shroutines::` for plugin-internal scripts, or the project name (e.g. `myapp::`) for project-specific scripts
- Private functions: `_function_name` — leading underscore signals internal use; not part of any public API
- Use `local -r` for constants inside functions — scopes the variable and protects it. Use `readonly` for script-level constants (maximum portability). Use `declare -r` at the top level only when you need type flags (`-i`, `-a`, `-lx`). The meaningful distinction is `local -r` (scoped) vs `readonly`/`declare -r` (global):

  ```bash
  # Script-level — readonly for portability
  SCRIPT_NAME=$(basename "$0")
  readonly SCRIPT_NAME
  readonly VERSION="0.1.0"

  # Script-level with type flag — declare -r
  declare -ar EXIT_CODES=(["ok"]=0 ["error"]=1 ["usage"]=2)

  # Function-scoped — local -r
  _parse_args() {
      local -r max_retries=3
  }

  # Public function — shroutines:: namespace
  shroutines::process_file() {
      local input="$1"
      # ...
  }
  ```

### Functions

> Replace the `shroutines::` prefix with the target project's namespace when scaffolding scripts for external projects.

```bash
shroutines::process_file() {
    local input_path="$1"

    if [[ ! -r "$input_path" ]]; then
        echo "Error: cannot read file: $input_path" >&2
        return 1
    fi

    # logic here

    return 0
}
```

- Use `local` for all function-scoped variables
- **Separate declaration and assignment** when the value comes from a command substitution — `local` does not propagate the exit code:

  ```bash
  # BAD - $? is always 0 (exit code of 'local', not my_func)
  local my_var="$(my_func)"
  (( $? == 0 )) || return

  # GOOD - separate lines preserve the exit code
  local my_var
  my_var="$(my_func)"
  (( $? == 0 )) || return
  ```

- End functions with explicit `return 0` — makes success exit point visible and distinguishes "fell off the end" from "deliberately succeeded"
- Use `[[ ]]` for bash tests, `[ ]` for POSIX sh
- Errors go to stderr: `>&2`
- Return meaningful exit codes: 0 = success, 1 = error, 2 = misuse

### File Structure

Every script must follow this top-to-bottom order for any sections that are present:

1. **Shebang and strict mode** — `#!/usr/bin/env bash` + `set -euo pipefail`
2. **Constants** — `readonly` / `declare -r` values that never change
3. **Globals** — `UPPERCASE` variables with script-wide scope
4. **Private functions** — `_function_name` helpers, internal utilities
5. **Public functions** — `shroutines::function_name` entry points and API
6. **Guard and execution** — `BASH_SOURCE[0]` guard + `main "$@"`

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly VERSION="0.1.0"

VERBOSE=0
OUTPUT_FILE=""

_log_info() { printf '[INFO] %s\n' "$*" >&2; return 0; }

shroutines::process() {
  local input="$1"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

### Line Length

- Soft limit: **120 characters** per line
- Break long strings, pipelines, or argument lists across lines
- Prefer `printf` over `echo` for multi-line output

```bash
cleanup() {
    rm -f "$tmp_file"
}
trap cleanup EXIT

tmp_file=$(mktemp)
```

- **Do not use `&& ... || ...` as if/else** — if the middle command fails, the `||` branch runs even though the `&&` condition succeeded:

  ```bash
  # BAD - rollback runs if deploy succeeds but healthcheck fails
  deploy && healthcheck || rollback

  # GOOD - explicit if/else
  if deploy && healthcheck; then
      echo "Deploy succeeded"
  else
      rollback
  fi
  ```

### Comment Conventions

Only comment when the code itself cannot convey the information: a hidden constraint, a subtle invariant, a bug workaround, or behaviour that would surprise a careful reader. Write one explaining _why_ not _what_. If removing the comment wouldn't confuse a future reader, don't write it.

**File header** — every script starts with one:

```bash
#!/usr/bin/env bash
#
# [BRIEF DESCRIPTION OF WHAT THIS SCRIPT DOES]
# Usage: [SCRIPT_NAME] [ARGUMENTS]
#
```

**Section dividers** — only when an individual section exceeds ~50 lines or complexity makes structure worth signposting. The standard file structure ordering is self-evident; dividers between short sections add noise. `#` tail fills to the nearest of 40, 80, or 120 columns:

```bash
###
### :::: [description] :::: ###########
###
```

**Public function docs** — only when the function's name and arguments don't fully convey its contract: non-obvious return codes, argument constraints, side effects, or failure conditions. Public (`shroutines::`) functions only; never on private (`_`) helpers.

```bash
# [description]
# Arguments:
#   $1 - [name]: [description]
#   $2 - [name]: [description]
# Returns:
#   0 - [success description]
#   1 - [failure description]
```

**Inline comments** — trailing `#` on the same line:

```bash
# GOOD — explains why
local -r threshold=$((mem_total / 10))  # 10% of total memory

# BAD — restates what
local -r threshold=$((mem_total / 10))  # calculate threshold
```

**Annotation comments** — bare `#` line above a block:

```bash
# Track descriptors so the trap can close them even if the list changes later
exec 3>/var/log/daemon.log
exec 4>&1
_OPEN_FDS+=(3 4)
```

### Security Prohibitions

- **Never use `eval`** — command injection risk
- **Never pipe to `sh` or `bash`** — injection risk
- **Always validate** user input before use
- **Use `mktemp`** for temporary files with `trap` cleanup

---

## Templates (Mode B — New Scripts)

Choose based on complexity and purpose:

| Template             | Use When                                                                     |
| -------------------- | ---------------------------------------------------------------------------- |
| `assets/standard.sh` | Most scripts — argument parsing, error handling, direct execution            |
| `assets/minimal.sh`  | Simple one-task utilities, no complex flag parsing                           |
| `assets/library.sh`  | Sourced by other scripts; provides reusable functions, no direct execution   |
| `assets/posix.sh`    | POSIX sh — containers, embedded, Alpine, CI base images, maximum portability |

### Template Selection Guide

- Does it need `--flag` style options or multiple arguments? → **standard**
- Is it a short utility doing one thing? → **minimal**
- Will other scripts `source` it? → **library**
- Must run in containers, embedded, Alpine, or under dash? → **posix**

### Scaffolding Process

1. Determine script name from `$ARGUMENTS` or ask the user
2. Select template type based on purpose
3. Create file at `$ARGUMENTS` — for directly executed scripts, omit the `.sh` extension (e.g. `deploy` not `deploy.sh`); for libraries meant to be sourced, keep the `.sh` extension (e.g. `lib-common.sh`)
4. Copy template content and fill in placeholders:
   - Script description
   - Usage examples
   - Function implementations
5. Apply all core standards above
6. If POSIX portability is required: use the POSIX template instead, apply `#!/bin/sh` shebang, and follow the POSIX sh Feature Restrictions below. Run `checkbashisms` to verify the final result

---

## POSIX vs Bash

This plugin targets **Bash 4.4+** as its primary compatibility tier. POSIX sh is a secondary tier for maximum portability.

**Rule: If the shebang says `#!/bin/sh`, the script must contain zero bashisms.** Use `#!/usr/bin/env bash` if you need bash features. The hook pipeline detects the shebang and configures ShellCheck, shfmt, and checkbashisms accordingly.

### Shebang Discipline

| Shebang               | Meaning                          | Tooling                                                  |
| --------------------- | -------------------------------- | -------------------------------------------------------- |
| `#!/usr/bin/env bash` | Bash-specific. Bashisms allowed. | shellcheck `-s bash`, shfmt `-ln bash`, `bash -n`        |
| `#!/bin/sh`           | POSIX sh only. No bash features. | shellcheck `-s sh`, shfmt `-ln posix`, `checkbashisms`   |
| `#!/usr/bin/dash`     | Explicit dash. Same as POSIX sh. | shellcheck `-s dash`, shfmt `-ln posix`, `checkbashisms` |

### When to Choose POSIX sh

Choose `#!/bin/sh` when:

- The script runs in containers with minimal base images (Alpine, distroless)
- It must execute on embedded systems or CI runners with no bash
- It is a lightweight utility (init script, hook, wrapper) that doesn't need arrays or complex string manipulation

Choose `#!/usr/bin/env bash` when:

- You need arrays, associative arrays, or pattern matching with `[[ ]]`
- The script does complex string manipulation, argument parsing, or data processing
- It sources a library (the library template uses namerefs and associative arrays)

For POSIX sh scripts, ensure no bashisms are present. Common traps: `[[ ]]`, arrays, `${var,,}`, `<<<`, `source`, `function` keyword, `echo -e`. Use `checkbashisms` to verify.

When the user specifies POSIX portability, use `assets/posix.sh` instead of the bash templates.

---

## Reference Files

- `references/patterns.md` — Argument parsing, temp files, arrays, string manipulation, parallel processing, progress output, exit code handling
- `references/security.md` — Preventive security patterns for writing: injection prevention, input validation, temp files, signal handling
- `${CLAUDE_PLUGIN_ROOT}/scripts/lib-common.sh` — General-purpose runtime library (logging, validation, temp files, string/array utilities). Source directly when the script can depend on the plugin being installed

Always consult these reference files before producing output — both for reviewing existing scripts and scaffolding new ones.

---

## Integration

- **`shell-security`** — Destructive commands, credential exposure, system file risks
- **`shell-review`** — Structured quality review of a completed script
- **`shell-architect`** agent — Multi-file project design, performance decisions, library vs executable structure
- **Hook automation** — ShellCheck and shfmt run automatically after file creation/modification
