# Dangerous Command Review Example

This example demonstrates how the `shell-security` skill reviews a script containing dangerous commands and offers fixes.

## Input Script

```bash
#!/usr/bin/env bash
# deploy.sh - Deploy application to production

set -e

# Configuration
TARGET_DIR="/var/www/app"
BACKUP_DIR="/var/backups/app"
API_KEY="sk-1234567890abcdefghijklmnop"
DB_PASSWORD="SuperSecretPass123"

# Clean previous deployment
rm -rf /var/www/app_old
rm -rf $TARGET_DIR

# Create backup
tar -czf "$BACKUP_DIR/backup-$(date +%Y%m%d).tar.gz" "$TARGET_DIR"

# Extract new files
tar -xzf deploy.tar.gz -C "$TARGET_DIR"

# Set permissions
chmod -R 777 "$TARGET_DIR"

# Update database
mysql -u root -p"$DB_PASSWORD" -e "UPDATE users SET active=1"

# Clean up temporary files
find / -name "*.tmp" -exec rm {} \;

# Restart service
systemctl restart app-service
```

## Review Output

```
Scanning deploy.sh for security issues (unique coverage)...

Found 6 issues:

1. ◆  Line 13: rm -rf targeting system directory
   What: rm -rf /var/www/app_old
   Risk: Deletes directory without validation, could delete wrong path
   Fix: Add validation and --preserve-root flag
   [Apply fix] [Show diff] [Skip]

   Proposed fix:
   ```bash
   [[ -d "/var/www/app_old" ]] || { echo "Directory not found" >&2; exit 1; }
   rm -rf --preserve-root /var/www/app_old
   ```

2. ● Line 14: Unquoted variable in rm command
   What: rm -rf $TARGET_DIR
   Risk: If TARGET_DIR is empty, may delete unexpected files
   Fix: Quote variable and add --preserve-root
   [Apply fix] [Show diff] [Skip]

   Proposed fix:
   ```bash
   rm -rf --preserve-root "$TARGET_DIR"
   ```

3. ● Line 9: Hardcoded API key
   What: API_KEY="sk-1234567890abcdefghijklmnop"
   Risk: Credential exposed in version control
   Fix: Use environment variable
   [Apply fix] [Show diff] [Skip]

   Proposed fix:
   ```bash
   API_KEY="${API_KEY:?API_KEY environment variable not set}"
   ```

4. ● Line 10: Hardcoded database password
   What: DB_PASSWORD="SuperSecretPass123"
   Risk: Credential exposed in version control
   Fix: Use environment variable or credential store
   [Apply fix] [Show diff] [Skip]

   Proposed fix:
   ```bash
   # Use MySQL config file instead
   db_password="${DB_PASSWORD:?DB_PASSWORD not set}"
   mysql -u root -p"$db_password" -e "..."
   # OR: use ~/.my.cnf for credentials
   ```

5. ● Line 23: chmod 777 on application directory
   What: chmod -R 777 "$TARGET_DIR"
   Risk: Makes directory world-writable, security vulnerability
   Fix: Use specific permissions (755 for dirs, 644 for files)
   [Apply fix] [Show diff] [Skip]

   Proposed fix:
   ```bash
   find "$TARGET_DIR" -type d -exec chmod 755 {} \;
   find "$TARGET_DIR" -type f -exec chmod 644 {} \;
   ```

6. ▲  Line 29: find from root directory
   What: find / -name "*.tmp" -exec rm {} \;
   Risk: Searches entire filesystem, slow and risky
   Fix: Limit search scope to specific directories
   [Apply fix] [Show diff] [Skip]

   Proposed fix:
   ```bash
   find "$TARGET_DIR" -name "*.tmp" -delete
   find /tmp -maxdepth 1 -name "*.tmp" -delete
   ```

---
Severity Summary:
◆  Fatal:    1
●  Severe:   4
▲  Moderate: 1

Note: ShellCheck will catch other issues (unquoted variables on line 26, etc.)
Run shellcheck deploy.sh for additional linting.
```

## Remediation Workflow

When the user selects `[Apply fix]` for all issues:

```
✔ Applying fixes...

1. ✔ Added validation to rm -rf /var/www/app_old
2. ✔ Added quotes and --preserve-root to rm -rf $TARGET_DIR
3. ✔ Replaced hardcoded API_KEY with environment variable
4. ✔ Replaced hardcoded DB_PASSWORD with environment variable
5. ✔ Replaced chmod 777 with specific permissions
6. ✔ Limited find scope to TARGET_DIR

All fixes applied. Review the changes:
git diff deploy.sh
```

## Fixed Script

```bash
#!/usr/bin/env bash
# deploy.sh - Deploy application to production

set -euo pipefail

# Configuration - use environment variables for secrets
: "${TARGET_DIR:=/var/www/app}"
: "${BACKUP_DIR:=/var/backups/app}"
: "${API_KEY:?API_KEY environment variable not set}"
: "${DB_PASSWORD:?DB_PASSWORD environment variable not set}"

# Validate directories exist
for dir in "$TARGET_DIR" "$BACKUP_DIR"; do
    [[ -d "$dir" ]] || { echo "Error: Directory not found: $dir" >&2; exit 1; }
done

# Clean previous deployment (with validation)
if [[ -d "/var/www/app_old" ]]; then
    rm -rf --preserve-root /var/www/app_old
fi

# Create backup
tar -czf "$BACKUP_DIR/backup-$(date +%Y%m%d).tar.gz" "$TARGET_DIR"

# Extract new files
tar -xzf deploy.tar.gz -C "$TARGET_DIR"

# Set permissions (specific, not 777)
find "$TARGET_DIR" -type d -exec chmod 755 {} \;
find "$TARGET_DIR" -type f -exec chmod 644 {} \;

# Update database (credentials from environment)
mysql -u root -p"$DB_PASSWORD" -e "UPDATE users SET active=1"

# Clean up temporary files (limited scope)
find "$TARGET_DIR" -name "*.tmp" -delete
find /tmp -maxdepth 1 -name "*.tmp" -delete

# Restart service
systemctl restart app-service
```

## Additional ShellCheck Findings

After shell-security fixes, ShellCheck may report:

```
Line 35: mysql -u root -p"$DB_PASSWORD" -e "..."
         ^-- SC2154: DB_PASSWORD is referenced but not assigned.
         (This is expected - we require it as environment variable)

Line 35: mysql -u root -p"$DB_PASSWORD" -e "..."
         ^-- SC2016: Expressions don't expand in single quotes.
         (Use double quotes for variable expansion in command)
```

## Warning Format Template

When the skill detects issues, it uses this format:

> Symbols are coloured in `security-audit.sh` output: ◆ purple (Fatal), ● red (Severe), ▲ yellow (Moderate), ✔ light green (OK).

```markdown
◆/●/▲ **[Severity] [Issue type detected]**

**What was detected:**
Line N: `code_snippet`

**Why this matters:**
- Risk explanation
- Impact assessment
- Common scenarios that cause problems

**Safer alternative:**
```bash
# Fixed code with explanation
```

Shall I apply this fix? (This will [describe what the fix does])
```
