# Code Review Output Template

Use this format exactly. Omit any section that has no content rather than writing "None."

---

# Code Review: `[filename]`

## Summary
[One sentence: what the script does and the overall verdict.]

## [+] Strengths
- [Specific thing done well, with line reference if helpful]

## [!] Issues

### Critical
*Issues that cause incorrect behaviour, security vulnerabilities, or data loss.*

| File | Line | Issue | Suggested Fix |
|------|------|-------|---------------|
| `file.sh` | 42 | Unquoted `$filename` in `rm` — word-splits on spaces | `rm -- "$filename"` |

### Moderate
*Issues that should be addressed before production use.*

| File | Line | Issue | Suggested Fix |
|------|------|-------|---------------|
| `file.sh` | 15 | No `trap` for temp file cleanup | Add `trap 'rm -f "$tmp"' EXIT` |

### Minor
*Low-priority improvements.*

| File | Line | Issue | Suggested Fix |
|------|------|-------|---------------|
| `file.sh` | 8 | `$i` — name gives no context | Rename to `$filename` or `$entry` |

## [*] Suggestions
[Anything useful that doesn't fit the issues table — architecture, testing gaps, missing documentation.]

## [SEC] Security Notes
[Only include if there are genuine security concerns. Do not write this section to appear thorough.]

---

**Overall Assessment:** `Approve` / `Approve with minor changes` / `Request changes` / `Needs major rework`

---

# Severity Definitions

| Level | Meaning |
|-------|---------|
| **Critical** | Data loss, security vulnerability, incorrect output, unhandled failure mode |
| **Moderate** | Likely to cause problems under real conditions; blocks production readiness |
| **Minor** | Code quality, readability, or convention — no functional impact |
