# Changelog

## Unreleased

### Added

- Add public-function coverage check

### Changed

- Publish.yml dependency bumps
- Drop OCX registry distribution
- Namespace lib-common functions and recolour security-audit output
- Revise shell-routines skills

### Fixed

- Guard bench.sh against missing EPOCHREALTIME on Bash 4.4

## [1.1.0](https://github.com/objctp/shell-routines/compare/v1.0.0...v1.1.0) - 2026-05-16

### Added

- **OpenCode support** — Full dual-platform compatibility for both Claude Code and OpenCode
- **npm distribution** — `@objctp/opencode-shell-routines` published to GitHub Packages with CI publish workflow
- **OCX registry** — `registry/registry.jsonc` with 17 components for component-level OpenCode installs
- **`build/build.mjs`** — Build script producing flat npm package and syncing registry files

### Changed

- **Dual-platform structure** — Skills, commands, and agents at repo root; `.opencode/` symlinks to shared content for OpenCode discovery
- **`README.md`** — OpenCode installation instructions aligned with official docs (config-based, auto-installed via Bun)
- **Version bumped** to 1.1.0 across `plugin.json` and `package.json`

## [1.0.0](https://github.com/objctp/shell-routines/compare/v0.9.0...v1.0.0) - 2026-05-01

### Added

- **`shell-profiling` skill** — Performance profiling, bottleneck identification, and optimisation for bash scripts
- **Dynamic execution detection** in `shell-security` — `eval` with variables, dynamic `source`, indirect commands; classification guide (by design / needs review / safe)
- **`references/security-patterns.md`** — Conceptual detection category map with auto-fix status for `shell-security`
- **Assessment guides** in `references/dangerous-commands.md` — Context-aware classification tables for eval and dynamic source findings
- **`shroutines::` namespace convention** — public functions use `shroutines::function_name`, private functions use `_function_name`
- **Comment conventions** in `shell-best-practices` — file headers, section dividers, public function docs, inline and annotation comment rules
- **`tests/test-hooks.sh`** — Comprehensive test suite for the hook pipeline (unit and integration tests)

### Changed

- **`shell-expert` agent** — `shell-profiling` added to preloaded skills (now 6)
- **`shell-architect` agent** — `shell-profiling` added to preloaded skills
- **`shell-security` skill** — `check_dynamic_execution` added to audit script; SKILL.md expanded with dynamic execution scope and integration diagram
- **`shell-best-practices` skill** — naming conventions expanded with `local -r` vs `readonly` vs `declare -r` guidance; `&& ||` is not if/else anti-pattern
- **Templates** — all four updated with `shroutines::` namespace (`shroutines_` prefix for POSIX); `standard.sh` uses section dividers, heredoc help, `${0##*/}` for SCRIPT_NAME; `library.sh` uses separate `readonly` declaration
- **`shell-hooks.sh`** — tool availability cached once per invocation; `hook_detect_target_shell` refactored to nameref-based interface; ksh support in shfmt dialect mapping
- **Batch examples and template** — `file-batch.sh`, `data-pipeline.sh`, and `batch-template.sh` updated with `${CLAUDE_PLUGIN_ROOT}/scripts/lib-batch.sh` sourcing
- **`shell-debugging` and `shell-review` skills** — cross-references to `shell-profiling` for performance-related scenarios
- **Documentation** — README.md, ARCHITECTURE.md updated for profiling skill; lifecycle diagram expanded

## [0.9.0](https://github.com/objctp/shell-routines/compare/v0.8.0...v0.9.0) - 2026-04-10

### Added

- `shell-test` skill preloaded by `shell-expert` agent — test generation is now a standard workflow step
- `lib-common.sh` added as reference file in `shell-best-practices` skill

### Changed

- **Performance optimisations across runtime libraries** — `$(date)` replaced with `printf %()T` builtin in lib-common.sh, lib-batch.sh, and library.sh template; `_json_escape` inlined via parameter expansion in lib-batch.sh; `repeat_char` rewritten to O(n); `command -v` results cached in shell-hooks.sh; `jq -Rs` made lazy
- **lib-batch.sh sourcing path** unified to `${CLAUDE_PLUGIN_ROOT}/scripts/lib-batch.sh` across all consumers
- **security-audit.sh** — 9 duplicated check functions refactored into `_check_grep` helper
- **shell-expert agent** — redundant Performance section removed; preloaded skills expanded to all 5
- **Templates and examples** — `$(basename "$0")` → `${0##*/}`, `wc | tr` → parameter expansion, `show_help` rewritten as heredoc
- **Documentation** — README.md, ARCHITECTURE.md, decision-tree.md updated to reflect current state

### Fixed

- `temp_file`/`temp_dir` trap overwrite bug — cleanup array pattern prevents EXIT trap clobbering
- Shebang detection false positive — `\bsh\b` no longer matches `fish`
- `BUG:` grep false positive — word boundary prevents match inside `DEBUG:-0`
- Test suite API mismatches — exit codes, namerefs, and hook_main file-path input corrected

## [0.8.0](https://github.com/objctp/shell-routines/compare/v0.7.0...v0.8.0) - 2026-04-04

### Added

- **Structured agent frontmatter** — both `shell-architect` and `shell-expert` agents converted to multi-line YAML descriptions with `<example>` blocks for better trigger matching, plus `model: opus`, `color`, `maxTurns`, and `skills:` arrays for skill preloading
- **`disable-model-invocation: true`** added to all 5 commands (`/setup`, `/shell-new`, `/shell-audit`, `/shell-test-run`, `/batch-exec`) — prevents unnecessary model calls during command execution
- **TODO marker detection** in `shell-format.sh` hook — surfaces `TODO`, `FIXME`, `HACK`, `XXX`, and `BUG` comments as additional context for Claude
- **`shell-test` skill expansion** — detailed sections added for mocking external commands (`bashunit::mock`), handling scripts with main blocks, side effects, environment variable testing, and test naming conventions
- **`ARCHITECTURE.md` rewrite** — expanded with skill boundaries table, command delegation pattern, agent vs skill relationship section, and detailed hooks documentation

### Removed

- **`.claude/shell-routines.local.md.example`** — config example file had no downstream consumers; no skill, command, or hook reads it
- **`/setup` step 5** (project configuration offer) — removed alongside the config file

## [0.7.0](https://github.com/objctp/shell-routines/compare/v0.6.0...v0.7.0) - 2026-03-30

### Added

- **Dialect-aware hook pipeline** — `shell-hooks.sh` now detects the target shell from shebang and configures tooling accordingly
  - ShellCheck runs with `-s bash`, `-s sh`, or `-s dash` based on shebang
  - shfmt runs with `-ln bash` or `-ln posix` based on shebang
  - `checkbashisms` runs on `#!/bin/sh` scripts to catch bashisms that would fail under dash
  - `bash -n` syntax check skips POSIX sh scripts (not validated against bash's parser)
- **POSIX sh template** (`templates/posix.sh`) — pure POSIX sh script template for containers, embedded, Alpine, and CI base images; no bashisms, passes `checkbashisms`
- **POSIX review gating** in `shell-review/references/guidelines.md` — POSIX compliance raised as Critical for `#!/bin/sh` scripts, suppressed for bash scripts
- **Bash Pitfalls coverage** — 12 common pitfalls documented with BAD/GOOD examples across skill references:
  - `patterns.md`: numeric vs string comparison, exact equality vs pattern matching, IFS trailing empty fields, `--` before variable file arguments, in-place file rewrite, stderr to `/dev/null` (not close), broken symlink detection, subshell variable preservation, bracing convention, indirect expansion
  - `SKILL.md`: `set -e` caveat (does not exit inside `if`/`while`/`&&`/subshells), `&& ||` is not if/else
  - `debugging-guide.md`: diagnostic sections for `&& ||` wrong branch and numeric comparison errors
- **Google Shell Style Guide alignment** — naming conventions, `readonly`/`declare -r`/`local -r` usage rules, explicit `return 0`, TODO comment format, executable naming convention (no `.sh` extension for directly executed scripts)
- **`local` with command substitution** — separate declaration and assignment rule documented with BAD/GOOD example; `local` masks exit codes from command substitutions

### Changed

- **`shell-best-practices`** POSIX vs Bash section expanded from two-line note to full section with shebang discipline table, when-to-choose guidance, and Bash 4.4+ baseline
- **`shell-expert`** agent updated with Bash 4.4+ baseline, checkbashisms validation step, POSIX fallback guidance
- **`shell-architect`** agent updated with Bash 4.4+ baseline, POSIX portability decision guidance, Alpine scenario
- **`standard.sh`** — `SCRIPT_NAME` and `VERSION` now use `readonly`; command substitutions use separate assignment then `readonly`
- **Scaffolding process** — step 3 now guides extensionless naming for executables and `.sh` for libraries; step 6 updated for POSIX workflow with `checkbashisms` verification

### Removed

- `references/compatibility.md` — redundant reference file; the model already knows POSIX restrictions and bash version gates natively

## [0.6.0](https://github.com/objctp/shell-routines/compare/v0.5.0...v0.6.0) - 2026-03-29

### Changed

- **All 6 skill descriptions** converted to third-person perspective ("This skill should be used when..." instead of "Use when...")
- **`shell-security`** description now includes explicit trigger phrases (was the only skill missing them)
- **`shell-best-practices/references/security.md`** trimmed to focus on preventive writing patterns only; credential exposure detection and file permission auditing removed (owned by `shell-security`); secrets handling, file permissions, and umask guidance restored as preventive patterns
- **`shell-best-practices`** description no longer claims "conducting security reviews" (that is `shell-security`'s domain)
- **`shell-review`** Integration section now references `shell-security` skill for deep security auditing
- **`shell-debugging`** SKILL.md trimmed — duplicated error patterns and diagnostic tools replaced with brief pointers to `references/debugging-guide.md`
- **`/shell-audit`** command is now a thin wrapper that delegates to the `shell-review` skill (eliminates near-identical review logic)
- **`/shell-new`** command is now a thin wrapper that delegates to `shell-best-practices` Mode B scaffolding (eliminates duplicated template logic)
- **`shell-expert`** agent trimmed — Ground Rules, Code Patterns, Performance Guidance, and Security Checklist sections removed (duplicated skill content); replaced with references to `shell-best-practices` and `shell-security` skills
- **`/shell-test-run`** command renamed from `/shell-test` to avoid name collision with the `shell-test` skill (generate vs run)

### Fixed

- **`shell-review`** description typo: "Scope;" corrected to "Scope:"

### Removed

- Code Review Checklist from `shell-best-practices/references/security.md` (owned by `shell-review`)
- Duplicated scaffolding process from `/shell-new` command (now delegates to skill)
- Duplicated audit checklist from `/shell-audit` command (now delegates to skill)

## [0.5.0](https://github.com/objctp/shell-routines/compare/v0.4.0...v0.5.0) - 2026-03-09

### Added

- `shell-best-practices` now handles new script scaffolding directly, replacing `shell-script-scaffold`
  - Templates (`standard.sh`, `minimal.sh`, `library.sh`) moved into `skills/shell-best-practices/templates/`
  - Skill operates in two modes: _modify/improve_ for existing scripts, _new script_ for creation requests
  - Template selection guidance (standard / minimal / library) built into the skill body

### Changed

- **`shell-batch-operations` skill** — reframed purpose around collection processing rather than token efficiency; description now leads with what the user gets rather than an implementation rationale; body trimmed and conforms to skill-creator progressive-disclosure guidelines
- **`shell-review` skill** — scope clarified to quality assessment of working scripts only; removed "debugging help" as a trigger; added explicit redirect to `shell-debugging` for runtime failures
- **`shell-debugging` skill** — scope clarified to runtime failures only; added explicit redirect to `shell-review` for quality assessment; redundant "When This Skill Applies" prose section removed

### Removed

- **`shell-script-scaffold` skill** — merged into `shell-best-practices`; the scaffold folder deleted

### Migration

- Delete `skills/shell-script-scaffold/` — its templates now live in `skills/shell-best-practices/templates/`
- No changes required to commands, agents, hooks, or shared scripts

## [0.4.0](https://github.com/objctp/shell-routines/compare/v0.3.0...v0.4.0) - 2026-03-07

### Added

- **`shell-security` skill** — Security vulnerability detection for bash scripts
  - Detects destructive commands (rm -rf /, dd, fork bombs, chmod 777)
  - Identifies system file risks (/etc/passwd, /etc/sudoers, /etc/shadow)
  - Finds hardcoded credentials (API keys, passwords, tokens)
  - Recognises sensitive file patterns (.env, .pem, .key, credentials files)
  - Offers auto-fix capabilities with user approval
  - Comprehensive reference documentation with grep patterns for detection
  - Severity categorisation (Fatal / Severe / Moderate)
  - Unique coverage that complements ShellCheck and shell-best-practices

### Changed

- Enhanced documentation with security-focused workflow integration

## [0.3.0](https://github.com/objctp/shell-routines/compare/v0.2.0...v0.3.0) - 2026-03-04

### Added

- **`shell-expert` agent** — Deep bash implementation expert
- **`shell-test` skill** — Bashunit test generation
- **`shell-review` skill** — Structured bash code review

### Changed

- Consistent `shell-*` naming across all agents and skills
- Removed bats-core references (bashunit only)
- Updated cross-references between components
- Enhanced integration between shell-expert and shell-architect agents

### Migration

- Consolidated all bash development tools in shell-routines plugin
- Root plugin now focuses on LSP server integrations

## [0.2.0](https://github.com/objctp/shell-routines/compare/v0.1.0...v0.2.0) - 2026-03-03

### Added

- **Batch operations pattern** for efficient multi-file processing (token savings approach)
  - New `lib-batch.sh` utility library with result collection and JSON output functions
  - New `shell-batch-operations` skill with decision tree for when to batch vs individual calls
  - New `batch-template.sh` script template for batch operations
  - New `batch-exec` command for executing batch scripts and parsing JSON results
  - Example batch scripts: `file-batch.sh` and `data-pipeline.sh`
  - Reference documentation: `decision-tree.md` with visual decision guide
- Enhanced `shell-architect` agent with "Batch vs Individual Operations" guidance
- Updated `shell-format` hook to detect batch script patterns and verify proper usage
- Token efficiency keywords added to plugin manifest

### Changed

- Added `batch-exec` command to command list
- Updated README.md with batch operations documentation

## [0.1.0](https://github.com/objctp/shell-routines/releases/tag/v0.1.0) - 2026-02-28

### Added

- Initial release of shell-routines plugin for shell script automation
- **Skills** (auto-triggering capabilities):
  - `shell-best-practices` - Enforces secure, portable bash standards
  - `shell-script-scaffold` - Generates properly structured script templates
  - `shell-debugging` - Guides systematic troubleshooting
- **Commands** (user-invocable):
  - `/shell-new <path> [type]` - Create new bash script from template
  - `/shell-test-run [path]` - Run tests using bashunit or bats
  - `/shell-audit <path>` - Comprehensive quality audit
- **Agents**:
  - `shell-architect` - Expert assistance for complex bash architecture decisions
- **Hooks**:
  - PostToolUse hook for automatic ShellCheck, shfmt, and syntax validation
- **Shared utilities**:
  - `lib-common.sh` - Common functions library (logging, validation, temp files, etc.)
- **Templates**:
  - Standard template with argument parsing and error handling
  - Minimal template for simple scripts
  - Library template for sourced modules
- Documentation for all skills with references and examples
