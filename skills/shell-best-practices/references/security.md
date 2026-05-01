# Writing Secure Shell Scripts

Preventive patterns to apply while writing shell scripts. For auditing existing scripts for security vulnerabilities (destructive commands, credential exposure, system file risks), use `shell-security` instead.

## Command Injection Prevention

### NEVER use eval
```bash
# BAD - User can execute arbitrary commands
eval "echo $user_input"

# GOOD - Use arrays or direct execution
echo "$user_input"
```

### NEVER pipe to sh/bash
```bash
# BAD - Downloads and executes untrusted code
curl http://example.com/script.sh | sh

# GOOD - Download, review, then execute
curl -O http://example.com/script.sh
less script.sh
sh script.sh
```

### ALWAYS quote variables in command positions
```bash
# BAD - Word splitting and globbing
func $user_var

# GOOD - Properly quoted
func "$user_var"
```

## Input Validation

### Validate filenames against path traversal
```bash
validate_filename() {
    local filename="$1"

    # Reject paths with directory traversal
    if [[ "$filename" == *".."* ]]; then
        echo "Error: invalid filename" >&2
        return 1
    fi

    # Reject absolute paths if not expected
    if [[ "$filename" == /* ]]; then
        echo "Error: absolute paths not allowed" >&2
        return 1
    fi

    # Only allow safe characters
    if [[ ! "$filename" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "Error: filename contains invalid characters" >&2
        return 1
    fi
}
```

For type/range validation helpers (e.g. `is_number`, `validate_port`), see `references/patterns.md`.

### Sanitise environment variables
```bash
# Clear PATH before using untrusted input
if [[ "$untrusted_mode" == "true" ]]; then
    export PATH="/usr/bin:/bin"
fi
```

## Secrets Handling

### NEVER hardcode credentials
```bash
# BAD
api_key="sk-live-1234567890abcdef"

# GOOD - Read from environment
api_key="${API_KEY:-}"
[[ -n "$api_key" ]] || { echo "Error: API_KEY not set" >&2; exit 1; }
```

### Prevent secrets in process list
```bash
# BAD - Secret visible in ps
curl -H "Authorization: Bearer $secret_token" https://api.example.com

# GOOD - Use file for secrets
echo "Authorization: Bearer $secret_token" > "$tmp_headers"
curl -H @"$tmp_headers" https://api.example.com
rm -f "$tmp_headers"
```

### Prevent secrets in logs
```bash
# Redirect debug output that may contain secrets
process_with_secrets 2>/dev/null

# Or filter sensitive patterns
process_with_secrets 2>&1 | grep -v "password\|token\|secret"
```

## Temporary Files

### ALWAYS use mktemp
```bash
# BAD - Predictable filename, race condition
tmp_file="/tmp/my_script_$$"

# GOOD - Atomic, unpredictable
tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT
```

### Set restrictive permissions on temp files
```bash
tmp_file=$(mktemp)
chmod 600 "$tmp_file"
```

## File Permissions

### Use restrictive defaults
```bash
# Create files with owner-only permissions
umask 077

# Or set explicitly
output_file=$(mktemp)
chmod 600 "$output_file"
```

### Avoid world-writable locations
```bash
# BAD - /tmp is world-writable
output="/tmp/data.txt"

# GOOD - Use user's cache
output="$HOME/.cache/script/data.txt"
mkdir -p "$(dirname "$output")"
```

## Safe Command Execution

### Use arrays for arguments
```bash
# BAD - Word splitting
files="*.txt"
cat $files

# GOOD - Proper expansion
files=("*.txt")
cat "${files[@]}"
```

### Use set -f to disable globbing
```bash
# Disable glob expansion when processing untrusted input
set -f
process_untrusted "$user_input"
set +f
```

## Signal Handling

### Clean up on interruption
```bash
cleanup() {
    rm -f "$tmp_file"
    rm -rf "$tmp_dir"
    echo "Cleaned up temporary files" >&2
}

trap cleanup EXIT INT TERM HUP

tmp_file=$(mktemp)
tmp_dir=$(mktemp -d)
```

### Prevent partial state on exit
```bash
cleanup() {
    # Remove incomplete output
    [[ -f "${output}.partial" ]] && rm -f "${output}.partial"
}

trap cleanup EXIT

# Write to partial file, rename on success
output="result.txt"
process_data > "${output}.partial"
mv "${output}.partial" "$output"
```
