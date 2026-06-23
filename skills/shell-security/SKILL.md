---
name: shell-security
description: Audit a bash script for security risks the linters miss: destructive commands, system-file writes, hardcoded credentials, insecure permissions, and dynamic execution (eval/source). Run the bundled detector, classify each finding by severity, and offer safer fixes on approval. Use when checking a script's safety ("audit for vulnerabilities", "is this safe?", "secure this script"). For quoting and general standards use shell-best-practices; for overall quality review use shell-review.
allowed-tools: Read, Grep, Bash, Write, Edit
argument-hint: [script-path]
---

# Shell Security Skill

Analyse bash scripts for security vulnerabilities, warn about risks, and automatically fix issues with safer alternatives upon approval.

## Target

**Target script:** `$ARGUMENTS`

If `$ARGUMENTS` is not provided, prompt the user to specify which script to audit. If `$ARGUMENTS` is a directory, scan each `.sh` file in that directory.

## How It Works

1. **Read the script** -- Understand purpose and context
2. **Run `scripts/security-audit.sh "$TARGET"`** -- Do not replicate its grep patterns manually; always use the script
3. **Interpret results** -- Consult all `references/` files (`dangerous-commands.md`, `security-patterns.md`, `sensitive-files.md`) and `examples/` (`secure-script-example.sh` for safer patterns, `dangerous-command-review.md` for output format) for context; categorise as Fatal/Severe/Moderate. For dynamic execution findings (`eval`/`source` with variables), classify each as **by design** (developer tool inherently executes code), **needs review** (handles untrusted input), or **safe** (variable is internally generated). Report "by design" findings as informational, not actionable issues. See the Assessment guide in `references/dangerous-commands.md` under the Dynamic Execution section.
4. **Warn with context** -- Explain risk, provide line number, suggest safer alternative
5. **Offer to fix** -- For fixable issues, offer to apply safer alternatives
6. **Confirm before modifying** -- Always ask for approval before applying any fix

**Done when** every detector category has run via `scripts/security-audit.sh`; each finding has a line, severity (Fatal/Severe/Moderate), and safer alternative; every dynamic-execution finding is classified (by design / needs review / safe); and no fix is applied without explicit approval.

## Scope

This skill covers **destructive commands, credentials, sensitive files, insecure permissions, and dynamic execution patterns**. For quoting and general best practices, use shell-best-practices instead. For overall quality review, use shell-review instead.

## What It Checks (Unique Coverage)

| Category                    | Examples                                             | Already Covered By |
| --------------------------- | ---------------------------------------------------- | ------------------ |
| **Destructive commands**    | `rm -rf /`, `dd`, fork bombs, `chmod 777`            | UNIQUE             |
| **System file risks**       | Editing `/etc/passwd`, `/etc/sudoers`, `/etc/shadow` | UNIQUE             |
| **Credential exposure**     | Hardcoded API keys, secrets in code                  | UNIQUE             |
| **Sensitive file patterns** | `.env`, `.pem`, `.key`, credentials files            | UNIQUE             |
| **Dynamic execution**       | `eval` with variables, dynamic `source`, indirect commands | UNIQUE |

**NOT covered here** (use existing tools):
| Issue | Use Instead |
|-------|-------------|
| Unquoted variables | ShellCheck, shell-best-practices |
| Pipe to `sh`/`bash` | shell-best-practices |
| Temp file issues | shell-best-practices |
| Syntax errors | bash -n hook |
| Formatting | shfmt hook |

## Auto-Fix Behaviour

**Auto-fixable issues** (applied upon approval):

- Add `--preserve-root` to rm commands
- Replace hardcoded credentials with environment variables
- Add confirmation prompts to dangerous commands
- Replace `chmod 777` with specific permissions
- Add guards before system file operations

**Requires manual review**:

- Fork bomb patterns (need architecture review)
- Destructive commands with variable paths
- System file modifications (needs intent clarification)

**Always confirm before modifying** -- even for auto-fixable issues, the workflow is:

1. Show the dangerous code
2. Explain the risk
3. Show the safer alternative
4. Prompt the user for approval before applying the fix

## Integration

**How shell-security fits with existing tooling:**

```
┌─────────────────────────────────────────────────────────────────────┐
│                    EXISTING TOOLING (runs first)                     │
├─────────────────────────────────────────────────────────────────────┤
│  Hooks (PostToolUse):  ShellCheck │ shfmt │ bash -n                │
│  LSP:                  bash-language-server (real-time)              │
│  Skills:               shell-best-practices (eval, quoting, temp)    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│              shell-security (UNIQUE coverage only)                  │
├─────────────────────────────────────────────────────────────────────┤
│  Focus: Destructive commands │ System files │ Credentials │ 777    │
│  Action: Warn + Auto-fix (with permission)                          │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    shell-review (final output)                      │
├─────────────────────────────────────────────────────────────────────┤
│  Consolidates: ShellCheck + shell-security + other findings         │
│  Output: Structured review with severity categories                 │
└─────────────────────────────────────────────────────────────────────┘
```

**Key point**: shell-security does NOT duplicate what ShellCheck/shell-best-practices already catch. It focuses on:

- **Destructive command severity** ([FATAL]/[SEVERE]/[MODERATE]) with security context
- **System file awareness** (knows `/etc/passwd` is sensitive)
- **Credential detection** (recognises API keys, secrets)
- **Dynamic execution detection** (flags eval/source with variable arguments)
- **Auto-fix capability** (can apply safer alternatives)

## References

- `references/dangerous-commands.md` -- Catalogue of destructive commands with risk levels and safer alternatives
- `references/security-patterns.md` -- Conceptual map of detection categories and auto-fix status
- `references/sensitive-files.md` -- Files that require careful handling

Always read all references and examples before producing audit results.

## Examples

- `examples/dangerous-command-review.md` -- Sample review output with remediation
- `examples/secure-script-example.sh` -- Secure coding reference

## Scripts

- `scripts/security-audit.sh` -- Reusable audit script that runs all detection grep patterns against a target file or directory.
