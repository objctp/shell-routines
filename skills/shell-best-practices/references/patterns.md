# Common Bash Patterns

## Argument Parsing

### Basic positional arguments
```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <input> <output>" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage

input="$1"
output="$2"
```

### getopts (flag-based)
```bash
#!/usr/bin/env bash
set -euo pipefail

verbose=0
output_file=""

while getopts "vo:" opt; do
    case "$opt" in
        v) verbose=1 ;;
        o) output_file="$OPTARG" ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 2 ;;
    esac
done

shift $((OPTIND - 1))
```

## Temporary Files

### Safe temp file with cleanup
```bash
tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT

# Process with temp file
process_data > "$tmp_file"
result=$(cat "$tmp_file")
```

### Safe temp directory
```bash
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# Create files in temp directory
output="$tmp_dir/output.txt"
```

## Arrays

### Iteration
```bash
items=("apple" "banana" "cherry")
for item in "${items[@]}"; do
    echo "$item"
done
```

### Building array from command output
```bash
readarray -t files < <(find . -name "*.txt" -type f)
for file in "${files[@]}"; do
    process "$file"
done
```

### Associative arrays (bash 4+)
```bash
declare -A config
config[host]="localhost"
config[port]="8080"

for key in "${!config[@]}"; do
    echo "$key = ${config[$key]}"
done
```

## String Manipulation

### Parameter expansion (bash 4+)
```bash
string="Hello, World!"

# Uppercase
echo "${string^^}"  # HELLO, WORLD!

# Lowercase
echo "${string,,}"  # hello, world!

# Remove suffix
path="/path/to/file.txt"
echo "${path%.txt}"  # /path/to/file

# Remove prefix
echo "${path##*/}"  # file.txt

# Replace first match
echo "${string/World/Bash}"  # Hello, Bash!

# Replace all matches
echo "${string//l/L}"  # HeLLo, WorLd!
```

### Use braces for variable expansion
```bash
# BAD - ambiguous without braces
echo "$var_name"      # Is this ${var_name} or ${var}_name?

# GOOD - braces make intent explicit
echo "${var}_name"
echo "${var_name}"

# GOOD - braces required for array, length, and manipulation
echo "${items[@]}"
echo "${#items[@]}"
echo "${var:-default}"
```

### Indirect expansion
```bash
# Access variable whose name is stored in another variable
var_name="colour"
colour="blue"

echo "${!var_name}"  # blue

# Use case: dynamic config lookup
declare -A config
config[host]="localhost"
config[port]="8080"

for key in host port; do
    echo "${config[$key]}"
done
```

### Numeric vs string comparison
```bash
# BAD - '>' inside [[ ]] is lexicographic: "9" < "7"
if [[ $count > 7 ]]; then ...

# GOOD - use (( )) for arithmetic
if (( count > 7 )); then ...

# GOOD - or -gt inside [[ ]]
if [[ $count -gt 7 ]]; then ...
```

### Exact equality vs pattern matching in [[ ]]
```bash
bar="*.txt"

# BAD - unquoted RHS enables glob pattern matching
[[ "file.txt" = $bar ]] && echo yes   # matches!

# GOOD - quote RHS for exact string equality
[[ "file.txt" = "$bar" ]] && echo yes # no match

# For intentional glob matching, leave RHS unquoted
[[ "file.txt" == *.txt ]]              # matches
```

### IFS splitting drops trailing empty fields
```bash
# BAD - trailing empty field silently lost
IFS=, read -ra arr <<< "a,b,"
echo "${#arr[@]}"  # 2, not 3

# GOOD - use -d '' to preserve trailing empties
IFS=, read -d '' -ra arr <<< "a,b,"
echo "${#arr[@]}"  # 3

# GOOD - for CSV rows, handle trailing empties explicitly
line="a,b,"
IFS=, read -ra arr <<< "$line"
expected=3
while (( ${#arr[@]} < expected )); do
    arr+=("")
done
```

## File Operations

### Check file existence and type
```bash
if [[ -f "$file" ]]; then
    echo "Regular file exists"
elif [[ -d "$file" ]]; then
    echo "Directory exists"
elif [[ -e "$file" ]]; then
    echo "Something exists (not regular file or directory)"
else
    echo "Does not exist"
fi
```

**Note**: `[[ -e ]]` returns false for broken symlinks. Use `[[ -L ]]` to test symlink existence regardless of target:
```bash
# BAD - broken symlinks report as non-existent
if [[ -e "$link" ]]; then ... fi   # false for broken symlink

# GOOD - test the link itself
if [[ -L "$link" ]]; then ... fi   # true for any symlink

# GOOD - check both link existence AND target
if [[ -L "$link" && -e "$link" ]]; then
    echo "Symlink with valid target"
elif [[ -L "$link" ]]; then
    echo "Broken symlink"
fi
```

### Read file line by line
```bash
while IFS= read -r line; do
    process_line "$line"
done < "$input_file"
```

### Process files in directory
```bash
for file in *.txt; do
    [[ -f "$file" ]] || continue
    process "$file"
done
```

### Use `--` before variable file arguments
```bash
# BAD - filename starting with '-' parsed as option
rm "$file"
cp "$src" "$dst"

# GOOD - '--' ends option parsing
rm -- "$file"
cp -- "$src" "$dst"

# GOOD - './' prefix prevents dash interpretation
mv "./$file" "$dest"
```

### Safely rewrite a file in-place
```bash
# BAD - file truncated before cat reads it
cat file | sort > file        # file is now empty
grep pattern file > file      # file is now empty

# GOOD - write to temp file, then replace
sort file > tmp && mv tmp file

# GOOD - use sponge (moreutils) for in-place
sort file | sponge file
```

### Redirect stderr to /dev/null, never close it
```bash
# BAD - closing stderr can cause programs to crash or misbehave
cmd 2>&-

# GOOD - redirect to /dev/null instead
cmd 2>/dev/null

# GOOD - suppress both stdout and stderr
cmd >/dev/null 2>&1
```

### Preserve variables set inside a read loop
```bash
# BAD - pipe creates subshell; counter lost
count=0
cat file | while IFS= read -r line; do
    ((count++))
done
echo "$count"  # always 0

# GOOD - process substitution keeps same shell
count=0
while IFS= read -r line; do
    ((count++))
done < <(cat file)
echo "$count"  # correct count
```

## Parallel Processing

### Simple parallel with xargs
```bash
find . -name "*.log" -print0 | \
    xargs -0 -P 4 -I {} process_log "{}"
```

### Background jobs with wait
```bash
pids=()
for item in "${items[@]}"; do
    process "$item" &
    pids+=($!)
done

# Wait for all background jobs
for pid in "${pids[@]}"; do
    wait "$pid"
done
```

## Progress Indication

### Simple counter
```bash
total=$(wc -l < "$file")
current=0

while IFS= read -r line; do
    ((current++))
    printf "\rProcessing: %d/%d" "$current" "$total"
    process "$line"
done
printf "\n"
```

## Exit Code Handling

### Check command success
```bash
if ! command_that_might_fail; then
    echo "Command failed" >&2
    exit 1
fi
```

### Capture and check exit code
```bash
if output=$(some_command); then
    echo "Success: $output"
else
    exit_code=$?
    echo "Failed with code: $exit_code" >&2
    exit "$exit_code"
fi
```

## Input Validation

### Validate numeric input
```bash
is_number() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]]
}

# Usage
if is_number "$port"; then
    echo "Valid port number"
fi
```

### Validate within range
```bash
validate_port() {
    local port="$1"
    (( port >= 1 && port <= 65535 ))
}
```

### Validate required arguments
```bash
validate_inputs() {
    local name="$1"
    local port="$2"

    [[ -n "$name" ]] || { echo "Error: name is required" >&2; return 1; }
    validate_port "$port" || { echo "Error: port out of range" >&2; return 1; }
}
```
