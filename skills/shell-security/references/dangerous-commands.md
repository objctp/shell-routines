# Dangerous Commands Reference

Catalogue of destructive and dangerous shell commands with risk levels, explanations, and safer alternatives.

## Severity Levels

- **Fatal** — Can destroy system or cause catastrophic data loss
- **Severe** — Can cause significant damage or security breaches
- **Moderate** — Can cause issues under certain conditions

---

## Fatal Commands

### `rm -rf /`

**What:** Recursively deletes all files from root directory

**Why it's dangerous:**
- Deletes everything without confirmation
- Modern systems have `--preserve-root` protection, but it can be overridden
- Common accidents with variables: `rm -rf $VAR /important-dir` when VAR is empty

**Examples of dangerous usage:**
```bash
rm -rf /                  # Attempts to delete root
rm -rf --no-preserve-root /  # Overrides protection
rm -rf "$TARGET_DIR" /     # Space after variable if TARGET_DIR is empty
rm -rf $DIR/*             # Unquoted variable with glob
```

**Safer alternatives:**
```bash
# Add --preserve-root explicitly
rm -rf --preserve-root "$TARGET_DIR"

# Validate directory first
[[ -d "$TARGET_DIR" ]] || { echo "Error: Invalid directory" >&2; exit 1; }
rm -rf -- "$TARGET_DIR"

# Add confirmation for destructive operations
rm -rfI "$TARGET_DIR"  # -I prompts once before removing more than 3 files
```

**Auto-fix:** Yes (add `--preserve-root` flag)

**Fix command:**
```bash
sed -i 's/rm -rf /rm -rf --preserve-root /g' file.sh
```

> **Portability:** these `sed -i` one-liners use GNU syntax. On macOS/BSD use `sed -i ''` (or `sed -i.bak` and remove the backup).

---

### `dd` with destructive targets

**What:** Low-level copy command that can overwrite any device

**Why it's dangerous:**
- Writes directly to devices without safety checks
- One typo can destroy disk data: `dd if=/dev/zero of=/dev/sda`
- No confirmation prompts

**Examples of dangerous usage:**
```bash
dd if=/dev/zero of=/dev/sda         # Wipes entire disk
dd if=/dev/random of=/dev/sda1      # Corrupts partition
dd if=file of=/dev/sda bs=1M count=100  # Overwrites disk start
```

**Safer alternatives:**
```bash
# Use dedicated wipe tools with confirmation
wipe /dev/sda

# Or add extensive validation
DEVICE="/dev/sda"
[[ -b "$DEVICE" ]] || { echo "Not a block device" >&2; exit 1; }
echo "About to wipe $DEVICE - press Ctrl+C to abort"
read -r
dd if=/dev/zero of="$DEVICE"
```

**Auto-fix:** No (requires intent verification)

---

## Severe Commands

### Fork Bombs

**What:** Processes that spawn themselves recursively, exhausting system resources

**Why it's dangerous:**
- Crashes system by exhausting process table and memory
- Can prevent legitimate processes from running
- Requires system reboot to recover

**Examples of dangerous usage:**
```bash
:(){ :|:& };:        # Classic bash fork bomb
bomb() { bomb|bomb& }; bomb  # Named version
foo() { foo & }; foo  # Simpler variant
```

**Safer alternatives:**
```bash
# Use process limits with ulimit
ulimit -u 100  # Limit to 100 processes
# Then run the process with monitoring

# Or use proper job control with supervision
while true; do
    worker &
    (( count++ >= MAX_WORKERS )) && break
done
wait
```

**Auto-fix:** No (requires architecture review)

**Detect:** `grep -nE ':\s*\(\)\s*\{.*\|.*:&\s*\}\s*;' file.sh`

---

### `chmod -R 777` on system directories

**What:** Makes files world-writable, recursively

**Why it's dangerous:**
- Any user can modify system files
- Escalates privileges for attackers
- Breaks security boundaries

**Examples of dangerous usage:**
```bash
chmod -R 777 /etc              # Makes all config world-writable
chmod -R 777 /var/www          # Web root becomes modifiable by anyone
chmod 777 ~/.ssh               # SSH keys become readable
chmod -R a+rwx /app            # Same as 777
```

**Safer alternatives:**
```bash
# Use specific permissions
chmod -R 755 /var/www/html     # Directories: rwxr-xr-x
chmod 644 /var/www/html/*.php  # Files: rw-r--r--
chmod 700 ~/.ssh               # SSH directory: rwx------
chmod 600 ~/.ssh/id_rsa        # Private keys: rw-------

# Use setfacl for granular permissions
setfacl -m u:www-data:rw /app/file.txt
```

**Auto-fix:** Yes (replace 777 with 755 for directories)

**Fix command:**
```bash
sed -i -E 's/chmod\s+777/chmod 755/g; s/chmod\s+-R\s+777/chmod -R 755/g' file.sh
```

**Detect:** `grep -nE 'chmod\s+777|chmod\s+a+rwx|chmod\s+-R.*777' file.sh`

---

### `crontab -r`

**What:** Removes all cron jobs without confirmation

**Why it's dangerous:**
- Destroys scheduled tasks immediately
- No "undo" option
- Typo: `crontab -r` instead of `crontab -e` is common

**Examples of dangerous usage:**
```bash
crontab -r              # Deletes all cron jobs
crontab -r -u user      # Deletes another user's crontab
```

**Safer alternatives:**
```bash
# Always use -e to edit
crontab -e

# Backup before modifying
crontab -l > crontab.bak
crontab -e

# Use explicit confirmation
confirm_crontab_rm() {
    echo "This will delete ALL cron jobs. Type 'yes' to confirm:"
    read -r response
    [[ "$response" == "yes" ]] && crontab -r
}
```

**Auto-fix:** Partial (warn user, suggest backup)

---

### `kill -9 -1` or `killall -9`

**What:** Sends SIGKILL to all processes

**Why it's dangerous:**
- Terminates everything including shell itself
- Can cause data loss
- System becomes unstable

**Examples of dangerous usage:**
```bash
kill -9 -1              # Kill all processes
killall -9 program      # Kill ALL instances by name
pkill -9 -f pattern     # Kill processes matching pattern
```

**Safer alternatives:**
```bash
# Use SIGTERM first for graceful shutdown
killall program         # No -9, allows graceful shutdown

# Target specific process IDs
kill $PID

# Use pgrep to find exact processes
pgrep -f "exact_pattern" | xargs kill
```

**Auto-fix:** Partial (warn, suggest specific targeting)

**Detect:** `grep -nE 'kill\s+-9\s+-1|killall\s+-9|pkill\s+-9' file.sh`

---

## Moderate Risk

### `: > /etc/passwd` or `echo > /etc/passwd`

**What:** Truncates or overwrites critical system files

**Why it's dangerous:**
- Destroys system authentication
- Makes system unusable
- Requires recovery media to fix

**Examples of dangerous usage:**
```bash
> /etc/passwd              # Truncates password file
echo "line" >> /etc/sudoers # Corrupts sudoers (must use visudo)
cat > /etc/shadow          # Overwrites shadow file
: > /etc/hosts             # Clears hostname mappings
```

**Safer alternatives:**
```bash
# Use proper tools for system files
vipw        # Edit /etc/passwd safely
visudo      # Edit /etc/sudoers with validation
echo "127.0.0.1 localhost" > /tmp/hosts && mv /tmp/hosts /etc/hosts

# Validate before writing to system files
validate_hosts() {
    grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$1" || { echo "Invalid hosts file" >&2; return 1; }
}
```

**Auto-fix:** No (requires manual review of intent)

**Detect:** `grep -nE '>\s*/etc/(passwd|shadow|sudoers|hosts|group|crontab)' file.sh`

---

### `find / -exec rm {} \;`

**What:** Searches and deletes recursively from root

**Why it's dangerous:**
- Searches entire filesystem
- Any typo in delete command is catastrophic
- Slow and resource-intensive

**Examples of dangerous usage:**
```bash
find / -name "*.log" -exec rm {} \;    # Deletes all .log files system-wide
find / -exec rm {} +                   # Deletes everything find returns
find /var -type f -delete              # Deletes all files in /var
```

**Safer alternatives:**
```bash
# Limit search scope
find /var/log -name "*.log" -mtime +30 -delete

# Use -print0 and -0 for safe handling
find /var/log -name "*.log" -print0 | xargs -0 rm

# Add depth limit
find /path -maxdepth 3 -name "pattern" -exec rm {} \;

# Preview before deleting
find /path -name "pattern" -ls
find /path -name "pattern" -delete
```

**Auto-fix:** Partial (warn if searching from root)

**Detect:** `grep -nE 'find\s+/\s+-exec.*rm' file.sh`

---

### `mv ~ /dev/null` or `rm -rf .*`

**What:** Deletes home directory or traverses upwards

**Why it's dangerous:**
- `~` expands to home directory
- `.*` includes `..` which traverses to parent
- Can delete directories outside current path

**Examples of dangerous usage:**
```bash
rm -rf .*        # Deletes .* including ../.. (parent directories)
mv ~ /dev/null   # Moves home directory to null device
rm -rf $HOME/*   # If HOME is unset, might delete from /
rm -rf * .*      # Deletes current dir AND parent dirs
```

**Safer alternatives:**
```bash
# Be explicit about what to delete
rm -rf .[!.]* ..?*   # Excludes . and ..

# Always validate HOME
: "${HOME:?HOME variable is not set}"
rm -rf "$HOME"/temp/*

# Use find for precise control
find . -maxdepth 1 -name '.*' ! -name '.' ! -name '..' -delete
```

**Auto-fix:** Yes (warn about `.*` pattern)

**Detect:** `grep -nE 'rm\s+-rf.*\.\*|mv\s+.*~/dev/null' file.sh`

---

## Common Mistake Patterns

### Space After Variable

**What:** Unquoted variable with space after it

**Why it's dangerous:**
- Empty variable causes next argument to be deleted
- Example: `rm -rf $VAR /path` when VAR is empty becomes `rm -rf /path`

**Examples:**
```bash
rm -rf $TARGET_DIR /backup    # If TARGET_DIR is empty → deletes /backup
rm $FILE /important           # If FILE is empty → deletes /important
cat $FILE > /etc/config       # If FILE is empty → truncates config
```

**Safer alternatives:**
```bash
# Always quote variables
rm -rf -- "$TARGET_DIR" /backup

# Or validate first
: "${TARGET_DIR:?Variable is empty or unset}"
rm -rf -- "$TARGET_DIR" /backup
```

**Auto-fix:** Yes (add quotes)

---

### Wrong Directory in `cd`

**What:** Deletes files in wrong directory due to cd failure

**Why it's dangerous:**
- `cd` fails silently with `set +e`
- Subsequent commands run in wrong directory

**Examples:**
```bash
cd /nonexistent || rm -rf *    # cd fails, deletes current dir
cd /tmp; rm -rf *              # If cd fails, rm runs in current dir
cd "$DIR"; rm -rf *            # DIR might be empty or wrong
```

**Safer alternatives:**
```bash
# Always check cd success
cd /nonexistent || exit 1
rm -rf *

# Or use subshell
(
    cd /nonexistent || exit
    rm -rf *
)

# Use `set -e` to fail on errors
set -e
cd /nonexistent
rm -rf *  # Never reached if cd fails
```

**Auto-fix:** Partial (warn if cd not checked)

**Detect:** `grep -nE 'cd\s+[^|;]*$' file.sh` (cd at end of line without `||`)

---

### Unquoted Glob in `rm`

**What:** Glob expands unexpectedly

**Why it's dangerous:**
- Special characters in filenames cause expansion
- File named `-rf` could be parsed as flag

**Examples:**
```bash
rm $filename      # If filename="-rf" → becomes rm -rf
rm *             # Expands to all files, including dangerous ones
rm $@            # User can inject flags
```

**Safer alternatives:**
```bash
# Use -- to end option parsing
rm -- "$filename"

# Quote all variables
rm -- "$filename"
rm -- "$@"

# Use find for complex patterns
find . -maxdepth 1 -type f -name "pattern" -delete
```

**Auto-fix:** Yes (add `--` and quotes)

**Detect:** `grep -nE 'rm\s+[a-zA-Z_]\w+' file.sh`

---

## Dynamic Execution

### `eval` with variable expansion

**What:** Passing variables to `eval`, allowing arbitrary code execution

**Why it's dangerous:**
- If the variable contains user input, attackers can execute arbitrary commands
- Common in frameworks that build commands dynamically (test runners, build tools)
- Hard to audit because the executed code is not visible in the source

**Examples of dangerous usage:**
```bash
eval "$user_input"                    # Direct injection vector
eval "${cmd#eval }"                   # String manipulation before eval
eval "function $name() { $body; }"    # Dynamic function creation
eval "args=($input)"                  # Parsing via eval
```

**Safer alternatives:**
```bash
# Use arrays instead of eval for argument building
args=(--flag "$value")
command "${args[@]}"

# Use declare -f for function existence checks
declare -f "$func_name" >/dev/null || return 1

# Use parameter expansion for string parsing
result="${var%%pattern*}"

# For data parsing, use explicit parsers instead of eval
while IFS= read -r key value; do
  ...
done < "$config_file"
```

**Auto-fix:** No (requires context review -- many eval uses are intentional, e.g. test frameworks)

**Detect:** `grep -nE 'eval\s+\$|eval\s+"[^"]*\$\{' file.sh`

**Assessment guide:** Not all dynamic execution is a vulnerability. Classify each finding:

| Classification | Criteria | Examples |
|----------------|----------|---------|
| **By design** | Script is a developer tool, framework, or CLI that *inherently* executes user-supplied code. The eval/source is the feature, not a bug. | Test runners (`source "$test_file"`), mock frameworks (`eval "function $cmd()..."`), REPL shells, build tools |
| **Needs review** | Script processes external input (files, network, arguments) from untrusted sources. The eval/source handles data the developer does not fully control. | CGI scripts, CI pipelines reading PR content, scripts that `eval "$(curl ...)"` |
| **Safe** | Variable is internally generated and fully controlled. No external input reaches the eval. | `eval "args=($input)"` where `$input` came from `printf '%q'`, internal temp paths from `mktemp` |

**How to judge:** Read the script's purpose first. If it is a testing framework, plugin loader, or build tool, most dynamic execution findings will be "by design." If it is a deployment script, cron job, or web-facing tool, treat every finding as "needs review" unless proven otherwise. Report "by design" findings as informational, not as actionable security issues.

---

### Dynamic `source` with variable path

**What:** Sourcing files from variable paths

**Why it's dangerous:**
- If the path is user-controlled, an attacker can load malicious code
- Common in plugin loaders and configuration systems
- The sourced file executes in the current shell with full privileges

**Examples of dangerous usage:**
```bash
source "$config_file"                 # Variable path
. "$plugin_path"                      # Dot-source equivalent
source "${BASHUNIT_BOOTSTRAP:-}"      # Environment-controlled path
```

**Safer alternatives:**
```bash
# Validate path before sourcing
case "$config_file" in
  *.sh) ;;
  *) echo "Invalid config file" >&2; return 1 ;;
esac
[ -f "$config_file" ] || return 1
source "$config_file"

# Use allowlists for plugin loading
case "$plugin_name" in
  plugin_a|plugin_b|plugin_c) source "plugins/${plugin_name}.sh" ;;
  *) echo "Unknown plugin: $plugin_name" >&2; return 1 ;;
esac
```

**Auto-fix:** No (requires context review -- test runners inherently need to source test files)

**Detect:** `grep -nE 'source\s+\$\w+|\.\s+\$\w+' file.sh`

**Assessment guide:** Same criteria as eval above. `source "$test_file"` in a test runner is "by design." `source "$plugin"` in a web application is "needs review." Always read the script's purpose before classifying.

---

## Quick Reference Table

| Pattern | Severity | Auto-Fix | Grep to Detect |
|---------|----------|----------|----------------|
| `rm -rf /` | Fatal | Yes (add --preserve-root) | `grep -nE 'rm\s+-rf.*\s+/'` |
| `dd if=` | Fatal | No (manual review) | `grep -nE 'dd\s+if='` |
| Fork bomb | Fatal | No (architecture) | `grep -nE ':\s*\(\)\s*\{.*\|.*:&'` |
| `chmod 777` | Severe | Yes (use 755) | `grep -nE 'chmod\s+777'` |
| `crontab -r` | Severe | Partial (warn) | `grep -nE 'crontab\s+-r'` |
| `kill -9 -1` | Severe | Partial (warn) | `grep -nE 'kill\s+-9\s+-1'` |
| `> /etc/passwd` | Moderate | No (intent) | `grep -nE '>\s*/etc/'` |
| `find / -exec rm` | Moderate | Partial (warn) | `grep -nE 'find\s+/\s+-exec'` |
| `rm -rf .*` | Moderate | Yes (warn) | `grep -nE 'rm\s+-rf.*\.\*'` |
| `eval $var` | Moderate | No (context) | `grep -nE 'eval\s+\$\|eval\s+"[^"]*\$\{'` |
| `source $var` | Moderate | No (context) | `grep -nE 'source\s+\$\w+\|\.\s+\$\w+'` |
