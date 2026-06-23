# Security Detection Patterns

Conceptual map of detection categories used by the security audit. For the actual grep commands, run `scripts/security-audit.sh` or read its source.

For detailed explanations, safer alternatives, and auto-fix commands, consult `dangerous-commands.md`.

## Detection Categories

| Category | What It Catches |
|----------|----------------|
| Destructive commands | `rm -rf /`, `dd` to block devices, `mkfs` |
| Fork bombs | Recursive function pipes (`:()\{:\|:&\};:`) |
| System file writes | Redirects to `/etc/passwd`, `/etc/shadow`, `/etc/sudoers` |
| Hardcoded credentials | `password=`, `api_key=`, `secret=`, `token=` with literal values |
| Credential formats | AWS keys (`AKIA...`), GitHub tokens (`ghp_...`), OpenAI keys (`sk-...`), Google keys (`AIza...`), Slack tokens (`xoxb-...`) |
| Insecure permissions | `chmod 777`, `chmod a+rwx`, recursive variants |
| Trap injection | `trap` commands containing `$` variable expansion |
| Dangerous sudo | `sudo rm`, `sudo dd`, `sudo mkfs`, `sudo chmod` |
| System config writes | Appends to `/etc/ssh/`, `/etc/systemd/`, `/etc/network/` |
| Dynamic execution | `eval $var`, `source $path`, indirect `${cmd}` |
## Running the Audit

Execute the bundled script to scan a file or directory:

```bash
scripts/security-audit.sh path/to/script.sh
scripts/security-audit.sh path/to/directory/
```

The script exits non-zero if any issues are found. Each finding includes the line number and matching code. Use the line numbers to look up detailed explanations and fix commands in `dangerous-commands.md`.
