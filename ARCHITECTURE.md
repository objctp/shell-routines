# Shell Routines Plugin - Architecture Documentation

This document explains how the plugin components work internally. For usage, see [README.md](README.md).

## Value Proposition

**Without shell-routines**: Multiple iterations, inconsistent tooling, manual formatting.

**With shell-routines**: One iteration, professional output, auto-formatted via hooks, consistent tooling.

## Dual-Platform Architecture

Shell Routines supports both **Claude Code** and **OpenCode** from a single repository. Shared content (skills, commands, hook logic) lives at the repo root and is symlinked into `opencode/`.

| Component       | Shared? | Claude Code                                  | OpenCode                                                |
| --------------- | ------- | -------------------------------------------- | ------------------------------------------------------- |
| **Skills**      | Yes     | Plugin root `skills/`                        | `opencode/skills/` → root `skills/`                    |
| **Commands**    | Yes     | Plugin root `commands/`                      | `opencode/commands/` → root `commands/`                |
| **Hook logic**  | Yes     | `hooks/scripts/shell-hooks.sh` (plugin root) | `opencode/plugins/shell-hooks.ts` (wraps same checks)  |
| **Agents**      | No      | `agents/*.md` (Claude frontmatter)           | `opencode/agents/*.md` (OpenCode frontmatter)          |
| **Hook config** | No      | `hooks/hooks.json` (PostToolUse)             | `opencode/plugins/shell-hooks.ts` (tool.execute.after) |
| **LSP**         | N/A     | `.lsp.json`                                  | Built-in bash LSP                                       |
| **Formatter**   | N/A     | N/A                                          | `opencode.json` formatter config                        |

### Key Differences

| Aspect            | Claude Code                                    | OpenCode                                                                 |
| ----------------- | ---------------------------------------------- | ------------------------------------------------------------------------ |
| Agent frontmatter | `tools:`, `maxTurns:`, `skills:`, `color:`     | `permission:`, `steps:`, `color:`, `mode:`                               |
| Hook system       | `hooks.json` with shell scripts, outputs JSON  | TS plugins with `tool.execute.after` events                              |
| Context injection | Hook `additionalContext` feeds directly to LLM | Hook appends findings to `output.output` (visible to LLM in tool result) |
| Skill discovery   | `.claude/skills/*/SKILL.md`                    | `.opencode/skills/*/SKILL.md` (also discovers `.claude/skills/`)         |
| Command discovery | `.claude/commands/*.md`                        | `.opencode/commands/*.md`                                                |
| Formatter config  | N/A                                            | `opencode.json` `formatter` section                                      |

### Symlink Structure

```
opencode/skills/shell-best-practices → ../../skills/shell-best-practices
opencode/commands/shell-new.md       → ../../commands/shell-new.md
```

Skills, commands, agents, and hooks live at the repo root level — the Claude Code plugin root.
`opencode/` symlinks point to the same source files, so changes propagate to both platforms.

For npm distribution, the build script (`scripts/build.mjs`) produces a scope-agnostic flat package in `dist/` with `agents/`, `commands/`, `plugins/`, `skills/`, `scripts/` at the root level. OpenCode installs components into `.opencode/` (project scope) or `~/.config/opencode/` (global scope) depending on which `opencode.json` declares the plugin.

## Component Overview

| Component    | Format                                   | Trigger                           | Internal Role                                        |
| ------------ | ---------------------------------------- | --------------------------------- | ---------------------------------------------------- |
| **Skills**   | Directory with SKILL.md + optional files | Context OR manual (`/skill-name`) | Structured workflows, templates, canonical standards |
| **Commands** | Markdown file in commands/               | Manual only (`/command-name`)     | Thin wrappers delegate to skills                     |
| **Agents**   | Single .md file in agents/               | Auto (agent decides)              | Deep expertise, autonomous work                      |
| **Hooks**    | Claude: shell script + JSON config       | Auto (after Write/Edit)           | Code quality enforcement                             |
|              | OpenCode: TS plugin                      | Auto (after write/edit)           | Formatting + linting side effects                    |

## Component Differences

| Aspect         | Agents              | Skills                    | Commands      |
| -------------- | ------------------- | ------------------------- | ------------- |
| **Format**     | Single .md file     | Directory + files         | Markdown file |
| **Execution**  | Spawned as subagent | Loaded into main context  | Interactive   |
| **Invocation** | Auto (agent)        | Auto OR manual            | Manual only   |
| **Best for**   | Deep expertise      | Auto-triggering workflows | User control  |

## Component Interaction Flow

```
User Request → Agent → Loads Components → Produces Output
                          │
                          ├── Skills (auto or manual)
                          ├── Commands (user invoked, may delegate to skills)
                          ├── Agents (auto-spawned, reference skills for standards)
                          └── Hooks (after file ops)
```

### Workflow Example

```
1. User: "/shell-new scripts/deploy"
2. /shell-new command delegates to shell-best-practices skill (Mode B scaffolding)
3. Write tool completes → PostToolUse hook fires (ShellCheck + shfmt)
4. Output: Formatted, validated script
```

## Skills

Skills are designed to map a natural development lifecycle:

```
Design ────────────► Write ────► Test ────► Review ────► Debug ────► Profile (cycle back)
(shell-architect     (best-      (test)     (review)     (debugging) (profiling)
   agent)          practices)
                        │                                              │
                        ▼                                              ▼
                   Security audit                               Batch operations
                     (security)                                (when scale needed)
```

### Skill Boundaries

Each skill owns a distinct domain. Skills reference each other rather than duplicating content:

| Skill                    | Owns                                                                    | Does NOT cover (delegates)                        |
| ------------------------ | ----------------------------------------------------------------------- | ------------------------------------------------- |
| `shell-best-practices`   | Writing standards, scaffolding, preventive security                     | Deep security auditing → `shell-security`         |
| `shell-security`         | Destructive commands, credentials, system files                         | Quoting/eval prevention → `shell-best-practices`  |
| `shell-review`           | Structured quality assessment of working scripts                        | Runtime failures → `shell-debugging`              |
| `shell-debugging`        | Runtime failure diagnosis                                               | Quality of working scripts → `shell-review`       |
| `shell-test`             | bashunit test file generation                                           | Running tests → `/shell-test-run` command         |
| `shell-batch-operations` | JSON-output batch scripts, lib-batch.sh API                             | Standards inside scripts → `shell-best-practices` |
| `shell-profiling`        | Performance profiling, bottleneck identification, optimisation patterns | Runtime failures → `shell-debugging`              |

### Skill Structure

```
shared/skills/shell-best-practices/
├── SKILL.md              # Required: instructions, triggers, tools
├── references/           # Optional: patterns, security checklist
└── assets/               # Script templates for scaffolding
    ├── standard.sh
    ├── minimal.sh
    ├── library.sh
    └── posix.sh
```

### Skill Loading Mechanism

| Platform    | Trigger           | Mechanism                                                    |
| ----------- | ----------------- | ------------------------------------------------------------ |
| Claude Code | Context detection | Claude analyses user request and matches skill description   |
| Claude Code | Manual invocation | User types `/skill-name` or asks Claude to load skill        |
| OpenCode    | Context detection | Agent calls the `skill` tool after matching name/description |
| OpenCode    | Manual invocation | User types `/skill-name` in the TUI                          |

## Commands

For the complete commands list, see [README.md - Features](README.md#features).

### Command Delegation Pattern

Several commands are thin wrappers that delegate to skills rather than implementing their own logic:

| Command        | Delegates To           | Why                                                      |
| -------------- | ---------------------- | -------------------------------------------------------- |
| `/shell-new`   | `shell-best-practices` | Skill owns templates, scaffolding process, and standards |
| `/shell-audit` | `shell-review`         | Skill owns review process, output format, and guidelines |

This avoids duplicating logic between commands and skills. The command provides a convenient slash-trigger; the skill provides the actual workflow.

## Agents

For agent descriptions, see [README.md - Features](README.md#features).

### When Each Agent Spawns

| Agent             | Spawns When                   | Decision Criteria                                  |
| ----------------- | ----------------------------- | -------------------------------------------------- |
| `shell-architect` | Architecture decisions needed | Multi-file projects, bash vs POSIX, library design |
| `shell-expert`    | Deep implementation needed    | Complex refactoring, performance, portability      |

### Claude Code vs OpenCode Agent Format

Claude Code agents use:

```yaml
tools: Read, Write, Edit, Bash, Grep, Glob
skills:
  - shell-best-practices
maxTurns: 15
color: blue
```

OpenCode agents use:

```yaml
permission:
  edit: deny
  bash: deny
steps: 15
color: primary
```

Skills are referenced in the prompt body rather than a `skills:` field.

### Agent vs Skill Relationship

Agents reference skills for standards rather than duplicating rules:

- `shell-expert` follows standards defined in `shell-best-practices`, `shell-security`, `shell-review`, `shell-batch-operations`, and `shell-test`
- `shell-architect` references `shell-best-practices`, `shell-batch-operations`, and `shell-security` for implementation standards
- Agents contain only procedural workflow (clarify, read, write, validate) and decision criteria

### Agent vs Skill Execution

| Aspect        | Agents                                 | Skills                      |
| ------------- | -------------------------------------- | --------------------------- |
| **Execution** | Spawned as subagent process            | Loaded into main context    |
| **Tools**     | Configured via permission/agent config | Uses skill's allowed-tools  |
| **State**     | Fresh context, no conversation history | Access to full conversation |
| **Standards** | Reference skills for rules/patterns    | Own the canonical rules     |

## Hooks

### Claude Code: PostToolUse Flow

| Step | Action                                        | Output                                  |
| ---- | --------------------------------------------- | --------------------------------------- |
| 1    | Detect shell file (extension or shebang)      | —                                       |
| 2    | Detect target dialect from shebang            | bash / sh / dash                        |
| 3    | Run ShellCheck with dialect flag              | Issues as additionalContext             |
| 4    | Run shfmt with dialect flag                   | Formatted file (in-place)               |
| 5    | Run `bash -n` (bash scripts only)             | Syntax errors as additionalContext      |
| 6    | Run `checkbashisms` (POSIX sh scripts only)   | Bashism findings as additionalContext   |
| 7    | Grep for TODO/FIXME/HACK/XXX/BUG markers      | Unresolved markers as additionalContext |
| 8    | Validate batch script pattern (if applicable) | Missing batch_output/RESULTS warnings   |

### OpenCode: tool.execute.after Flow

| Step | Action                                        | Output                                     |
| ---- | --------------------------------------------- | ------------------------------------------ |
| 1    | Detect shell file (extension or shebang)      | —                                          |
| 2    | Detect target dialect from shebang            | bash / sh / dash                           |
| 3    | Run ShellCheck with dialect flag              | Findings appended to tool output           |
| 4    | Run `bash -n` (bash scripts only)             | Syntax errors appended to tool output      |
| 5    | Run `checkbashisms` (POSIX sh scripts only)   | Bashism findings appended to tool output   |
| 6    | Grep for TODO/FIXME/HACK/XXX/BUG markers      | Unresolved markers appended to tool output |
| 7    | Validate batch script pattern (if applicable) | Missing batch_output/RESULTS warnings      |

Tool availability (ShellCheck, checkbashisms) is cached once at plugin initialisation rather than probed per invocation. shfmt formatting is handled separately by the `opencode.json` formatter config, which auto-runs on shell files.

### Hook Output Format (Claude Code)

```json
{
  "systemMessage": "Warning shown to user",
  "hookSpecificOutput": {
    "additionalContext": "Findings shown to Claude"
  }
}
```

**Key point**: Claude Code hooks output **only valid JSON** on stdout. Any other text breaks integration.

- `additionalContext` — ShellCheck findings, syntax errors, TODO markers (for Claude)
- `systemMessage` — Formatting failures or critical errors (for user)

## Related Documentation

- [README.md](README.md) — User guide and quick start
- [CHANGELOG.md](CHANGELOG.md) — Version history and changes
