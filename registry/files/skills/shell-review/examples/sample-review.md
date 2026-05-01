# Code Review: `auth.sh`

## Summary
Adds a user authentication function with input validation and basic password handling; approve pending two moderate fixes.

---

## [+] Strengths
- `local` used correctly for all function-scoped variables
- Error messages consistently directed to stderr
- Exit codes follow conventions: 0 = success, 1 = error

## [!] Issues

### Moderate

| File | Line | Issue | Suggested Fix |
|------|------|-------|---------------|
| `auth.sh` | 24 | Username accepted without pattern validation — allows injection characters | Add `[[ "$username" =~ ^[a-zA-Z0-9_]+$ ]] \|\| return 1` |
| `auth.sh` | 31 | Missing shebang | Add `#!/usr/bin/env bash` as line 1 |

### Minor

| File | Line | Issue | Suggested Fix |
|------|------|-------|---------------|
| `auth.sh` | 18 | Single-letter variable `u` loses context at a glance | Rename to `username` |

---

## [*] Suggestions
- Add rate limiting or a lockout counter for repeated failed attempts
- Document the expected format and permissions of the password file in a comment
- Add an audit log entry on each authentication attempt (success and failure)

## [SEC] Security Notes
- `read -s` is used for password input — correct, prevents terminal echo
- Plain-text password comparison is high risk; consider delegating to PAM or hashing with `openssl dgst`
- Ensure the password file is owned by root with permissions 0600

---

**Overall Assessment:** `Request changes`
