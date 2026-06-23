#!/usr/bin/env bash
# secure-script-example.sh
# Demonstrates secure alternatives to common dangerous patterns

set -euo pipefail

###
### :::: Configuration :::: ###########
###

# Require environment variables for secrets
: "${DATABASE_URL:?DATABASE_URL environment variable not set}"
: "${API_KEY:?API_KEY environment variable not set}"
: "${APP_HOME:?APP_HOME environment variable not set}"

# Directory paths with validation
BACKUP_DIR="${APP_HOME}/backups"
TEMP_DIR="${APP_HOME}/tmp"
LOG_DIR="${APP_HOME}/logs"

###
### :::: Initialization :::: ##########
###

# Create directories with secure permissions
function init_directories() {
  local dir
  for dir in "$BACKUP_DIR" "$TEMP_DIR" "$LOG_DIR"; do
    if [[ ! -d "$dir" ]]; then
      mkdir -p "$dir"
      chmod 700 "$dir"
    fi
  done
}

###
### :::: Safe File Operations :::: ####
###

# Safe file deletion with validation
function safe_delete() {
  local target="$1"
  local force="${2:-false}"

  # Validate target exists
  if [[ ! -e "$target" ]]; then
    echo "Warning: Target does not exist: $target" >&2
    return 1
  fi

  # Validate target is within allowed directory
  local real_target
  real_target=$(realpath "$target")
  if [[ ! "$real_target" =~ ^"$APP_HOME" ]]; then
    echo "Error: Refusing to delete outside APP_HOME: $target" >&2
    return 1
  fi

  # Confirm deletion unless forced
  if [[ "$force" != "true" ]]; then
    echo "Delete: $target"
    read -r -p "Confirm? [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]] || return 1
  fi

  # Delete with safety flags
  rm -rf --preserve-root -- "$target"
}

# Safe temporary file creation
function safe_tempfile() {
  local prefix="${1:-script}"
  local tmpfile

  tmpfile=$(mktemp "${TEMP_DIR}/${prefix}.XXXXXX") || return 1
  chmod 600 "$tmpfile"
  echo "$tmpfile"
}

# Safe file writing with backup
function safe_write() {
  local file="$1"
  local content="$2"

  # Validate file path
  if [[ ! "$file" =~ ^"$APP_HOME" ]] && [[ ! "$file" =~ ^"$TEMP_DIR" ]]; then
    echo "Error: Refusing to write outside APP_HOME: $file" >&2
    return 1
  fi

  # Create backup if file exists
  if [[ -f "$file" ]]; then
    local backup
    backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$file" "$backup"
    echo "Backup created: $backup"
  fi

  # Write content
  printf '%s\n' "$content" >"$file"
  chmod 600 "$file"
}

###
### :::: Secure Permissions :::: ######
###

# Set specific permissions instead of 777
function set_permissions() {
  local target="$1"

  # Directories: 755 (rwxr-xr-x)
  find "$target" -type d -exec chmod 755 {} \;

  # Files: 644 (rw-r--r--)
  find "$target" -type f -exec chmod 644 {} \;

  # Executable scripts: 755
  find "$target" -type f -name "*.sh" -exec chmod 755 {} \;

  # Sensitive files: 600
  find "$target" -type f \( -name "*.key" -o -name "*.pem" -o -name ".env" \) -exec chmod 600 {} \;
}

###
### :::: Secure Database Operations :::: #####
###

# Use MySQL with config file instead of command-line password
function mysql_query() {
  local query="$1"

  # Create temporary MySQL config
  local my_cnf
  my_cnf=$(safe_tempfile mysql) || return 1

  # Write credentials to temp config (will be deleted)
  cat >"$my_cnf" <<EOF
[client]
user="${DB_USER:-root}"
password="${DB_PASSWORD}"
host="${DB_HOST:-localhost}"
EOF

  # Execute query with config file
  mysql --defaults-file="$my_cnf" -e "$query"
  local status=$?

  # Securely delete config
  shred -u "$my_cnf"

  return "$status"
}

###
### :::: Safe Cleanup :::: ############
###

# Clean temporary files within scope only
function cleanup_temp_files() {
  local days="${1:-7}"

  # Only clean within TEMP_DIR
  find "$TEMP_DIR" -type f -mtime +"$days" -delete

  # Clean old backups (keep last 10)
  find "$BACKUP_DIR" -maxdepth 1 -name 'backup-*.tar.gz' -printf '%T@ %p\0' |
    sort -zrn |
    tail -zn +11 |
    cut -zd ' ' -f2- |
    xargs -r0 rm --
}

###
### :::: Signal Handling :::: #########
###

# Secure trap handler (use function, not eval)
function cleanup_handler() {
  local exit_code=$?

  echo "Cleaning up..." >&2

  # Remove temp files
  [[ -d "${TEMP_DIR:-}" ]] && rm -rf -- "${TEMP_DIR:?}"/*

  # Log exit
  [[ -d "${LOG_DIR:-}" ]] && echo "Script exited with code: $exit_code" >>"$LOG_DIR/exit.log"

  exit "$exit_code"
}

# Register cleanup handler (function reference, not string)
trap cleanup_handler EXIT

###
### :::: Input Validation :::: ########
###

# Validate directory path
function validate_directory() {
  local dir="$1"
  local create="${2:-false}"

  # Check if absolute path
  [[ "$dir" = /* ]] || {
    echo "Error: Path must be absolute: $dir" >&2
    return 1
  }

  # Check if within allowed paths
  if [[ ! "$dir" =~ ^"$APP_HOME" ]] && [[ ! "$dir" =~ ^/tmp ]]; then
    echo "Error: Path outside allowed directories: $dir" >&2
    return 1
  fi

  # Create if requested
  if [[ "$create" == "true" ]] && [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    chmod 755 "$dir"
  fi

  return 0
}

# Validate filename (prevent path traversal)
function validate_filename() {
  local filename="$1"

  # Reject path traversal attempts
  if [[ "$filename" =~ \.\. ]]; then
    echo "Error: Path traversal detected: $filename" >&2
    return 1
  fi

  # Reject absolute paths (should be relative)
  if [[ "$filename" = /* ]]; then
    echo "Error: Absolute path not allowed: $filename" >&2
    return 1
  fi

  # Reject special characters
  if [[ "$filename" =~ [[:space:]] ]]; then
    echo "Error: Spaces not allowed in filename: $filename" >&2
    return 1
  fi

  return 0
}

###
### :::: Safe Command Execution :::: ##
###

# Execute command with timeout and resource limits
function safe_execute() {
  local timeout="${1:-300}" # 5 minutes default
  shift
  local cmd=("$@")

  # Set resource limits
  ulimit -t "$timeout" # CPU time
  ulimit -v 4194304    # Max 4GB virtual memory
  ulimit -u 100        # Max 100 processes

  # Execute with timeout
  timeout "$timeout" "${cmd[@]}"
}

###
### :::: Example Usage :::: ###########
###

function main() {
  # Initialize
  init_directories

  # Example: Safe file operations
  local tempfile
  tempfile=$(safe_tempfile data)
  echo "Processing data in $tempfile"

  # Example: Safe deletion
  # safe_delete "$APP_HOME/old_data" false  # Ask for confirmation
  # safe_delete "$APP_HOME/cache" true      # Force deletion

  # Example: Set secure permissions
  # set_permissions "$APP_HOME/public"

  # Example: Cleanup
  cleanup_temp_files 30

  echo "Operations completed successfully"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

###
### :::: Security Checklist :::: ###########
###

# ✔ set -euo pipefail for error handling
# ✔ Environment variables for secrets (no hardcoding)
# ✔ Path validation before operations
# ✔ realpath for canonical paths
# ✔ --preserve-root for rm
# ✔ mktemp for temporary files
# ✔ Specific permissions (no 777)
# ✔ Function references in trap (not eval)
# ✔ Input validation (path traversal prevention)
# ✔ Resource limits for commands
# ✔ Secure credential handling (MySQL config file)
# ✔ Cleanup handlers for temp files
# ✔ Confirmation prompts for destructive operations
