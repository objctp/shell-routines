# Sensitive Files Reference

Files and directories that require careful handling in shell scripts due to security implications.

## Overview

| Category | Risk Level | Examples |
|----------|------------|----------|
| **Authentication & Credentials** | ● Severe | SSH keys, API tokens, certificates |
| **System Configuration** | ◆ Fatal | /etc/passwd, /etc/sudoers, /etc/shadow |
| **User Configuration** | ▲ Moderate | ~/.bashrc, ~/.ssh/config |
| **Data & Secrets** | ● Severe | .env files, certificates, vault passwords |
| **Package & Build** | ▲ Moderate | package.json, requirements.txt |
| **Temporary & Cache** | ▲ Moderate | /tmp files, cache directories |
| **Git & Version Control** | ▲ Moderate | .git/config, .git-credentials |

---

## Authentication & Credentials

### SSH Keys and Config

**Files:**
- `~/.ssh/id_rsa` — Private RSA key
- `~/.ssh/id_ed25519` — Private Ed25519 key
- `~/.ssh/config` — SSH client configuration
- `~/.ssh/known_hosts` — Server fingerprint cache
- `~/.ssh/authorized_keys` — Public keys for login
- `/etc/ssh/ssh_host_*_key` — Host private keys

**Risks:**
- Private key leakage allows unauthorised access
- Modified config can redirect connections
- Corrupted authorized_keys prevents login

**Safe handling:**
```bash
# Check file existence before operations
[[ -f ~/.ssh/id_rsa ]] || { echo "Key not found" >&2; exit 1; }

# Set restrictive permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/config
chmod 644 ~/.ssh/known_hosts

# Backup before modifying
cp ~/.ssh/config ~/.ssh/config.bak
# ... modify ...
```

---

### GPG Keys

**Files:**
- `~/.gnupg/private-keys-v1.d/*.key` — Private key rings
- `~/.gnupg/pubring.kbx` — Public key ring
- `~/.gnupg/gpg-agent.conf` — Agent configuration

**Risks:**
- Private key compromise defeats encryption
- Agent misconfiguration can expose keys

**Safe handling:**
```bash
# Use gpg CLI instead of direct file manipulation
gpg --export-secret-keys KEYID > backup.gpg
# NOT: cp ~/.gnupg/private-keys-v1.d/* /backup/
```

---

### AWS Credentials

**Files:**
- `~/.aws/credentials` — AWS access keys
- `~/.aws/config` — AWS configuration
- `/etc/cloud/templates/credentials*` — Cloud credentials

**Risks:**
- Credential exposure enables AWS account takeover
- Hard-coded credentials in scripts

**Safe handling:**
```bash
# Use AWS CLI or SDK credential sources
aws s3 ls  # Uses ~/.aws/credentials or IAM role

# Never hard-code
# DON'T: export AWS_ACCESS_KEY_ID="AKIA..."

# Use environment variables only in controlled environments
export AWS_PROFILE=production
```

---

### Docker Credentials

**Files:**
- `~/.docker/config.json` — Docker registry auth tokens
- `/var/lib/docker/containers/*/config.json` — Container configs

**Risks:**
- Registry tokens allow image push/pull
- Contains base64-encoded passwords

**Safe handling:**
```bash
# Use docker login command
docker login registry.example.com

# NOT: echo '{"auths":{"..."}' > ~/.docker/config.json
```

---

### Git Credentials

**Files:**
- `~/.git-credentials` — Stored credentials
- `~/.netrc` — Generic credentials (FTP, HTTP)
- `.git/config` — Repository URLs (may contain tokens)

**Risks:**
- Stored passwords can be extracted
- Tokens in remote URLs

**Safe handling:**
```bash
# Use credential helpers
git config --global credential.helper osxkeychain  # macOS
git config --global credential.helper cache  # In-memory

# Avoid embedding tokens in URLs
# DON'T: git remote add origin https://token@github.com/repo.git
# DO: git remote add origin https://github.com/repo.git
```

---

## System Configuration

### User Database

**Files:**
- `/etc/passwd` — User account information
- `/etc/shadow` — Password hashes
- `/etc/group` — Group definitions
- `/etc/gshadow` — Group passwords

**Risks:**
- System breakage if corrupted
- Security breach if passwords exposed
- Privilege escalation if modified

**Safe handling:**
```bash
# Use proper tools
vipw            # Edit /etc/passwd
vigr            # Edit /etc/group

# NEVER write directly
# DON'T: echo "user:x:1000:1000::/home/user:/bin/bash" >> /etc/passwd

# For automation, use useradd/usermod
useradd -m -s /bin/bash newuser
```

---

### Sudo Configuration

**Files:**
- `/etc/sudoers` — Sudo access rules
- `/etc/sudoers.d/*` — Additional rules

**Risks:**
- Syntax error prevents sudo usage
- Overly permissive rules enable escalation
- Comments or edits can break sudo

**Safe handling:**
```bash
# ALWAYS use visudo
visudo          # Edits with validation

# For automation
visudo -c -f /etc/sudoers.d/newfile  # Check before deploy

# DON'T: echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
```

---

### System Services

**Files:**
- `/etc/crontab` — System cron jobs
- `/etc/cron.*/*` — Scheduled tasks
- `/etc/systemd/system/*` — Service units
- `/etc/hosts` — Hostname mappings

**Risks:**
- Service disruption if corrupted
- Unauthorised task execution
- Privilege escalation

**Safe handling:**
```bash
# Use systemd tools
systemctl edit service-name  # Creates override
systemctl daemon-reload     # After editing units

# For cron
crontab -e                  # User crontabs
# System crontabs: edit and validate syntax
```

---

## User Configuration

### Shell Configuration

**Files:**
- `~/.bashrc` — Bash interactive shell config
- `~/.bash_profile` — Bash login shell config
- `~/.profile` — POSIX shell config
- `~/.zshrc` — Zsh configuration
- `/etc/profile` — System-wide profile

**Risks:**
- Malicious code in startup files
- PATH manipulation leading to trojan horses
- Environment variable leakage

**Safe handling:**
```bash
# Validate before sourcing
validate_shell_rc() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    [[ -r "$file" ]] || return 1
    # Check for suspicious patterns
    grep -qE 'eval\s+\$|exec\s+\$|alias\s+sudo=' "$file" && return 1
}

# Safer sourcing
validate_shell_rc ~/.bashrc && source ~/.bashrc
```

---

### Application Config

**Files:**
- `~/.config/*` — Application configuration (XDG)
- `~/.local/share/*` — Application data
- `~/Library/Preferences/*` — macOS preferences

**Risks:**
- Contains API keys, tokens
- May have executable snippets

**Safe handling:**
```bash
# Mask sensitive values when viewing
grep -vE '(password|token|key)\s*=' ~/.config/app.conf
```

---

## Data & Secrets

### Environment Files

**Files:**
- `.env` — Environment variables
- `.env.local` — Local overrides
- `.env.production` — Production secrets
- `*.key` — Private key files
- `*.pem` — Certificate files
- `secrets.*` — Secret storage
- `credentials.json` — Google Cloud credentials
- `.vault_pass` — Ansible vault password

**Risks:**
- Credential exposure if committed
- API key leakage
- Database connection strings

**Safe handling:**
```bash
# Add to .gitignore
cat >> .gitignore << 'EOF'
.env
.env.*
*.key
*.pem
secrets.*
credentials.json
.vault_pass
EOF

# Load with validation
load_env() {
    local env_file=".env"
    [[ -f "$env_file" ]] || { echo "No .env file" >&2; return 1; }
    set -a  # Auto-export
    source "$env_file"
    set +a
    # Verify required variables
    : "${DATABASE_URL:?DATABASE_URL not set in .env}"
    : "${API_KEY:?API_KEY not set in .env}"
}

# Use sed to mask secrets when logging
mask_secrets() {
    sed -E 's/(password|token|key)=[^[:space:]]+/\1=[REDACTED]/g'
}
```

---

### Certificates

**Files:**
- `*.crt` — Certificates
- `*.pem` — PEM-encoded certificates/keys
- `*.key` — Private keys
- `*.p12` — PKCS#12 bundles
- `*.jks` — Java key stores

**Risks:**
- Private key exposure
- Certificate expiration
- Man-in-the-middle if wrong cert

**Safe handling:**
```bash
# Verify certificate expiry
check_cert_expiry() {
    local cert="$1"
    local days=30
    local expiry
    expiry=$(openssl x509 -enddate -noout -in "$cert" | cut -d= -f2)
    expiry_date=$(date -d "$expiry" +%s)
    current_date=$(date +%s)
    (( (expiry_date - current_date) / 86400 < days )) && echo "Cert expiring soon"
}

# Validate permissions
chmod 600 *.key
chmod 644 *.crt
```

---

## Package & Build Files

### Dependency Files

**Files:**
- `package.json` / `package-lock.json` — Node.js
- `requirements.txt` / `Pipfile.lock` — Python
- `Gemfile` / `Gemfile.lock` — Ruby
- `go.mod` / `go.sum` — Go
- `Cargo.toml` / `Cargo.lock` — Rust
- `composer.json` — PHP

**Risks:**
- May contain embedded credentials
- Supply chain attacks via malicious packages
- Lock file manipulation

**Safe handling:**
```bash
# Scan for secrets before committing
scan_package_files() {
    grep -rE '(api_key|password|secret|token)\s*=\s*["\047]' package.json requirements.txt
}

# Use lock files for reproducibility
# Commit lock files, verify no unexpected changes
```

---

## Temporary & Cache Files

### Temporary Directories

**Files:**
- `/tmp/*` — System temporary files
- `/var/tmp/*` — Persistent temporary files
- `~/.cache/*` — User cache
- `*.swp` — Vim swap files
- `*~` — Backup files

**Risks:**
- May contain sensitive data
- Permissions issues
- Race conditions in creation

**Safe handling:**
```bash
# Use mktemp for secure temp file creation
tmpfile=$(mktemp) || exit 1
chmod 600 "$tmpfile"
# ... use file ...
rm -f "$tmpfile"

# For directories
tmpdir=$(mktemp -d) || exit 1
chmod 700 "$tmpdir"

# NOT: tmpfile=/tmp/myfile_$$
```

---

## Git & Version Control

### Git Configuration

**Files:**
- `.git/config` — Repository configuration
- `.git/hooks/*` — Git hooks
- `.git/HEAD` — Current branch
- `.git/refs/*` — Branch references

**Risks:**
- Hooks can execute arbitrary code
- Config may contain credentials
- Refs can be manipulated

**Safe handling:**
```bash
# Verify hooks before running
for hook in .git/hooks/*; do
    [[ -x "$hook" ]] && echo "Executable hook: $hook"
    # Review hook content
done

# Don't commit hooks
echo ".git/hooks/" >> .gitignore

# Check for credentials in config
grep -iE '(credential|token|password)' .git/config
```

---

## Safe File Handling Checklist

```bash
# Template for safe file operations

safe_file_operation() {
    local file="$1"
    local operation="$2"  # read, write, delete

    # Check file type
    case "$file" in
        /etc/passwd|/etc/shadow|/etc/sudoers)
            echo "FATAL: Refusing to operate on critical system file: $file" >&2
            return 1
            ;;
        ~/.ssh/id_*|*.pem|*.key)
            if [[ "$operation" == "write" ]]; then
                echo "ERROR: Refusing to overwrite sensitive file: $file" >&2
                return 1
            fi
            ;;
        .env|*.env|secrets.*)
            echo "WARNING: Operating on secrets file: $file" >&2
            ;;
    esac

    # Check file existence
    if [[ "$operation" == "write" ]] && [[ -f "$file" ]]; then
        echo "ERROR: File exists, refusing to overwrite: $file" >&2
        return 1
    fi

    # Check permissions
    if [[ -e "$file" ]] && ! [[ -r "$file" ]]; then
        echo "ERROR: File not readable: $file" >&2
        return 1
    fi

    # Perform operation
    case "$operation" in
        read)
            cat "$file"
            ;;
        write)
            echo "$operation" > "$file"
            ;;
        delete)
            rm -i "$file"  # Confirm before delete
            ;;
    esac
}
```

---

## Quick Reference

| File Pattern | Permission | Owner | Notes |
|--------------|------------|-------|-------|
| `~/.ssh/id_*` | 600 | user | Private keys |
| `~/.ssh/*.pub` | 644 | user | Public keys |
| `~/.ssh/config` | 600 | user | SSH config |
| `~/.gnupg/` | 700 | user | GPG home |
| `.env` | 600 | user | Secrets |
| `*.key` | 600 | user | Private keys |
| `*.pem` | 600 | user | Keys/certs |
| `*.crt` | 644 | user | Certificates |
| `/etc/shadow` | 000 | root | Password hashes |
| `/etc/sudoers` | 440 | root | Sudo config |
