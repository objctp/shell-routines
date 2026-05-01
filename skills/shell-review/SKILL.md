---
name: shell-review
description: This skill should be used when the user asks to "review my script", "check for issues", "evaluate this script", "is this good bash?", "pre-merge review", "code review this", or any request to assess shell script quality. Reviews and audits bash/shell scripts for quality, correctness, and standards compliance. For working scripts only — use shell-debugging for runtime failures.
allowed-tools: Read, Grep, Glob, Bash
argument-hint: [file-or-diff]
---

# Shell Review Skill

Produces a structured, actionable review of bash/shell scripts at: **$ARGUMENTS**.

**Scope**: Quality assessment of working scripts — correctness, standards, security, and style. For scripts that are failing or producing errors at runtime, use `shell-debugging` instead.

## Target

**Target:** `$ARGUMENTS`

- If `$ARGUMENTS` is a file path, read that file
- If `$ARGUMENTS` is a unified diff, extract changed lines and review them in context of the surrounding code
- If `$ARGUMENTS` is not provided, ask for clarification

## Process

1. **Read the code** — understand the script's purpose before raising any issues
2. **Run diagnostics** — ShellCheck and `bash -n` run automatically via hooks; interpret their output, don't relay it verbatim
3. **Categorise findings** — critical (must fix), moderate (should fix), minor (nice to have); do not pad minor categories
4. **Be specific** — every issue needs a file, line, and concrete suggested fix
5. **Acknowledge strengths** — note what is done well; a review with no positives is usually incomplete

## Output

Use the template in `references/review-template.md` for the exact output format. Key sections:

- **Summary** — one sentence verdict
- **Strengths** — what's done well
- **Issues** — categorised as Critical / Moderate / Minor with file, line, issue, fix
- **Suggestions** — anything useful that doesn't fit the issues table
- **Security Notes** — only if genuine concerns exist
- **Overall Assessment** — Approve / Approve with minor changes / Request changes / Needs major rework

## Additional Resources

### Reference Files

- `references/review-template.md` — Exact output format with severity definitions
- `references/guidelines.md` — What to raise and what not to

Always read all references and examples before producing a review.

### Examples

- `examples/sample-review.md` — Complete review example demonstrating expected output

## Integration

- **`shell-security`** skill — Deep security auditing (destructive commands, credential exposure, system file risks)
- **`shell-expert`** agent — Technical depth for complex analysis
- **`shell-debugging`** skill — When the script has runtime failures, not quality issues
- **`/shell-audit`** command — Comprehensive quality audit
