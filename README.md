# Shell Routines

Shell scripting toolkit for **Claude Code** and **OpenCode** — automated scaffolding, best practices, and quality enforcement.

## Prerequisites

| Tool                 | Purpose                     |
| -------------------- | --------------------------- |
| bash-language-server | LSP server for Bash         |
| shellcheck           | Static analysis and linting |
| shfmt                | Code formatting             |
| bashunit             | Test execution              |
| checkbashisms        | POSIX compatibility checks  |
| hyperfine            | Statistical benchmarking    |

```bash
# macOS
npm i -g bash-language-server
brew install shellcheck shfmt bashunit checkbashisms hyperfine

# Ubuntu/Debian
npm i -g bash-language-server
sudo apt install shellcheck shfmt bashunit checkbashisms hyperfine

# Arch Linux
npm i -g bash-language-server
sudo pacman -S shellcheck shfmt bashunit checkbashisms hyperfine
```

## Installation

**Claude Code:**

```bash
/plugin marketplace add objctp/shell-routines
/plugin install shell-routines@objct-plugins

# Local development
git clone https://github.com/objctp/shell-routines && cd shell-routines && claude
```

**OpenCode:**

Add to your config — OpenCode auto-installs npm plugins via Bun at startup.

```jsonc
// Project scope: opencode.json
{ "plugin": ["@objctp/opencode-shell-routines"] }

// Global scope: ~/.config/opencode/opencode.json
{ "plugin": ["@objctp/opencode-shell-routines"] }
```

```bash
# OCX registry (alternative)
ocx add objct/shell-routines

# Local development
git clone https://github.com/objctp/shell-routines && cd shell-routines && opencode
```

## Components

| Component    | Purpose                                    | Trigger                           |
| ------------ | ------------------------------------------ | --------------------------------- |
| **Hooks**    | Validation and formatting after file edits | Automatic on `.sh`, `.bash`, etc. |
| **Skills**   | Best practices, patterns, and scaffolding  | Context or manual (`/skill-name`) |
| **Commands** | Interactive tools                          | Manual only (`/command-name`)     |
| **Agents**   | Specialised subagents for complex tasks    | Auto-spawned                      |

### Skills

| Skill                    | When to Use                               | Purpose                                  |
| ------------------------ | ----------------------------------------- | ---------------------------------------- |
| `shell-best-practices`   | Writing or creating bash scripts          | Standards enforcement + scaffolding      |
| `shell-debugging`        | Script has runtime failures               | Systematic troubleshooting               |
| `shell-security`         | Auditing for security vulnerabilities     | Destructive commands, credentials, fixes |
| `shell-test`             | Generating tests                          | Creates bashunit test files              |
| `shell-review`           | Quality review of a working script        | Structured assessment                    |
| `shell-batch-operations` | Processing 100+ items or multi-stage work | Token-efficient multi-file processing    |
| `shell-profiling`        | Script works but runs slowly              | Benchmarking and bottleneck analysis     |

### Commands

| Command                      | Purpose                                                 |
| ---------------------------- | ------------------------------------------------------- |
| `/shell-new <path> [type]`   | Create new script (delegates to `shell-best-practices`) |
| `/shell-test-run [path]`     | Run tests using bashunit                                |
| `/shell-audit <path>`        | Quality audit (delegates to `shell-review` skill)       |
| `/shell-batch-exec <script>` | Execute batch script and parse JSON output              |
| `/shell-routines-setup`      | Configure bash-language-server, ShellCheck, shfmt       |

### Agents

| Agent             | Purpose                                                 |
| ----------------- | ------------------------------------------------------- |
| `shell-architect` | Design complex bash architecture (read-only, no writes) |
| `shell-expert`    | Deep implementation work following skill standards      |

### Templates

Located in `skills/shell-best-practices/assets/`:

| Template      | Use For                                         |
| ------------- | ----------------------------------------------- |
| `standard.sh` | Most scripts (argument parsing, error handling) |
| `minimal.sh`  | Simple one-task utilities                       |
| `library.sh`  | Sourced libraries (no direct execution)         |
| `posix.sh`    | POSIX-compatible scripts (containers, embedded) |

## License

MIT

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — Internal architecture
