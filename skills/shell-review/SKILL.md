---
name: shell-review
description: Review a working bash script for quality, correctness, standards compliance, and security, producing a structured report with severity-ranked findings and concrete fixes. Use when assessing a finished script ("review my script", "pre-merge review", "is this good bash?"). For runtime failures use shell-debugging; for deep security auditing use shell-security.
allowed-tools: Read, Grep, Glob, Bash
argument-hint: [file-or-diff]
---

# Shell Review Skill

Produces a structured, actionable review of bash/shell scripts.

**Scope**: Quality assessment of working scripts — correctness, standards, security, and style.

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

**Done when** every finding has a file, line, and concrete fix; each passes the *when-not-to-raise* filter in `guidelines.md`; strengths are noted; severity follows the definitions in `review-template.md`; and an Overall Assessment is given.

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
