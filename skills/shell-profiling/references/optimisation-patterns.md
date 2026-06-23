# Shell Optimisation Patterns

Each pattern shows a "before" (slow) and "after" (fast) version with an explanation.

---

## Subshell Elimination

Every `$(...)` or backtick invocation forks a child process. In a loop of 10,000 iterations, that is 10,000 extra processes.

### Replace external commands with parameter expansion

**Before:**

```bash
for path in "${paths[@]}"; do
    base=$(basename "$path")
    dir=$(dirname "$path")
    ext="${path##*.}"
    echo "$dir/$base has extension $ext"
done
```

**After:**

```bash
for path in "${paths[@]}"; do
    base="${path##*/}"
    dir="${path%/*}"
    ext="${path##*.}"
    echo "$dir/$base has extension $ext"
done
```

**Why:** `basename` and `dirname` each fork a process. Parameter expansion `${path##*/}` and `${path%/*}` are bash builtins -- no fork, no exec, no I/O.

### Use `read` with here-string instead of piping to commands

**Before:**

```bash
echo "$line" | cut -d: -f2
```

**After:**

```bash
IFS=: read -r _ field2 _ <<< "$line"
echo "$field2"
```

**Why:** The pipe (`|`) creates a subshell for both sides. The here-string (`<<<`) is a builtin that avoids the fork.

### Process substitution vs pipe into loops

**Before:**

```bash
total=0
grep 'pattern' data.txt | while IFS= read -r line; do
    (( total += line ))
done
echo "$total"  # 0 -- subshell lost the variable
```

**After:**

```bash
total=0
while IFS= read -r line; do
    (( total += line ))
done < <(grep 'pattern' data.txt)
echo "$total"  # correct value
```

**Why:** The pipe runs `while` in a subshell, losing variable changes. Process substitution `<(...)` runs `grep` in a subshell instead, keeping the `while` loop in the main shell.

---

## Builtin vs External Commands

### `[[ ]]` vs `[ ]` vs `test`

**Before:**

```bash
if [ "$status" = "ok" ] && [ "$count" -gt 0 ]; then
    echo "valid"
fi
```

**After:**

```bash
if [[ "$status" == "ok" && "$count" -gt 0 ]]; then
    echo "valid"
fi
```

**Why:** `[[ ]]` is a bash builtin that supports `&&` and `||` inside the expression, avoiding multiple `[ ]` invocations and the associated parsing overhead. It also handles empty variables without quoting.

### bash string manipulation vs sed/awk

**Before:**

```bash
lower=$(echo "$name" | tr 'A-Z' 'a-z')
no_spaces=$(echo "$lower" | sed 's/ /_/g')
clean=$(echo "$no_spaces" | sed 's/[^a-z0-9_]//g')
```

**After:**

```bash
lower="${name,,}"
no_spaces="${lower// /_}"
clean="${no_spaces//[^a-z0-9_]/}"
```

**Why:** Each pipe to `tr` or `sed` forks a process and opens a pipe. The bash parameter expansions `${var,,}`, `${var//pattern/replacement}` are builtins that operate on the string in memory. Three external processes become zero.

### `mapfile`/`readarray` vs `while read` loop

**Before:**

```bash
lines=()
while IFS= read -r line; do
    lines+=("$line")
done < file.txt
```

**After:**

```bash
mapfile -t lines < file.txt
```

**Why:** `mapfile` reads the entire file into an array in a single builtin operation. The `while read` loop invokes the `read` builtin once per line, with per-iteration overhead.

### Arithmetic `(( ))` vs `expr`

**Before:**

```bash
result=$(expr "$a" + "$b")
remainder=$(expr "$a" % "$b")
```

**After:**

```bash
(( result = a + b ))
(( remainder = a % b ))
```

**Why:** `expr` is an external command that forks a process for each arithmetic operation. `(( ))` is a bash builtin.

---

## I/O Optimisation

### Redirect once vs per-line

**Before:**

```bash
for item in "${items[@]}"; do
    echo "$item" >> output.txt
done
```

**After:**

```bash
exec 3>output.txt
for item in "${items[@]}"; do
    echo "$item" >&3
done
exec 3>&-
```

**Why:** Each `>>` opens the file, seeks to the end, writes, and closes. Redirecting via `exec 3>` opens the file once; subsequent `>&3` writes skip the open/close cycle.

### Avoid useless `cat`

**Before:**

```bash
cat file.txt | grep 'pattern'
cat file.txt | while IFS= read -r line; do ...
```

**After:**

```bash
grep 'pattern' file.txt
while IFS= read -r line; do ... done < file.txt
```

**Why:** `cat file | cmd` spawns a `cat` process and creates a pipe, both unnecessary when the command can read the file directly via redirection.

### Batch reads vs line-by-line

**Before:**

```bash
while IFS= read -r line; do
    echo "$line"
done < large_file.txt > output.txt
```

**After:**

```bash
# If the operation is a simple transformation, use a single tool pass
sed 's/old/new/g' large_file.txt > output.txt

# Or for more complex processing, use awk
awk '{gsub(/old/, "new"); print}' large_file.txt > output.txt
```

**Why:** Reading line-by-line in bash has per-iteration overhead (buffer management, builtin invocation). A single `sed` or `awk` pass processes the entire file in C without returning to the shell between lines.

---

## Loop Optimisation

### Process substitution instead of piping into loops

See **Subshell Elimination** above — `command | while ...` loses variables; use `while ... done < <(command)`.

### `shopt -s lastpipe`

**Before:**

```bash
# Variables set in the last command of a pipe are lost
printf '%s\n' "${items[@]}" | sort | while IFS= read -r item; do
    (( count++ ))
done
echo "$count"  # empty
```

**After:**

```bash
shopt -s lastpipe
count=0
printf '%s\n' "${items[@]}" | sort | while IFS= read -r item; do
    (( count++ ))
done
echo "$count"  # correct value
```

**Why:** `lastpipe` runs the last command of a pipeline in the current shell (not a subshell), preserving variable assignments. Requires job control to be disabled (which it is in scripts by default).

### `xargs -P` for parallel work

**Before:**

```bash
for url in "${urls[@]}"; do
    curl -s "$url" > /dev/null
done
```

**After:**

```bash
printf '%s\n' "${urls[@]}" | xargs -P 8 -I{} curl -s "{}" > /dev/null
```

**Why:** The sequential loop processes one URL at a time. `xargs -P 8` runs up to 8 curl processes in parallel, bounded to avoid overwhelming the system.

---

## String Processing

### Parameter expansion vs external tools for simple transformations

**Before:**

```bash
trimmed=$(echo "$var" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
```

**After:**

```bash
# Bash 4.4+ does not trim by default, so read into a temporary
read -r trimmed <<< "$var"
```

**Why:** The `sed` pipeline forks two processes. `read` with here-string is a single builtin.

### Single-pass awk vs multi-tool pipeline

**Before:**

```bash
grep 'ERROR' log.txt | cut -d' ' -f3 | sort | uniq -c | sort -rn | head -10
```

**After:**

```bash
awk '/ERROR/ {count[$3]++} END {for (k in count) print count[k], k}' log.txt \
    | sort -rn | head -10
```

**Why:** The before version pipes through 5 processes (grep, cut, sort, uniq, sort). The after version does filtering, field extraction, and counting in a single `awk` pass, reducing the pipeline to 2 processes (awk + sort).

### Replace entire bash loop with a single awk pass

For data-heavy scripts, the single highest-impact optimisation is often replacing the entire bash loop with awk.

**Before:**

```bash
declare -A counts
total=0
while IFS= read -r line; do
    date=$(echo "$line" | cut -d' ' -f1)
    if [[ "$date" < "$start" || "$date" > "$end" ]]; then continue; fi
    severity=$(echo "$line" | grep -o '\[[A-Z]\+\]' | tr -d '[]')
    if [[ "$severity" != "ERROR" ]]; then continue; fi
    service=$(echo "$line" | cut -d' ' -f4)
    (( counts["$service"]++ ))
    (( total++ ))
done < "$logfile"
```

**After:**

```bash
awk -v start="$start" -v end="$end" '
    $1 >= start && $1 <= end && $3 == "[ERROR]" {
        count[$4]++
        total++
    }
    END {
        printf "Total errors: %d\n", total
        for (svc in count)
            printf "  %s: %d\n", svc, count[svc]
    }
' "$logfile"
```

**Why:** The bash version spawns 3-4 external processes per line (echo, cut, grep, tr) across potentially hundreds of thousands of iterations. The awk version processes the entire file in C without returning to the shell between lines, typically achieving 50-100x speedups on large files. The trade-off is moving logic out of bash into awk, which reduces readability for team members unfamiliar with awk.

### `printf %s` concatenation vs repeated echo

**Before:**

```bash
echo "Header" > output.txt
echo "$line1" >> output.txt
echo "$line2" >> output.txt
echo "Footer" >> output.txt
```

**After:**

```bash
{
    printf '%s\n' "Header"
    printf '%s\n' "$line1" "$line2"
    printf '%s\n' "Footer"
} > output.txt
```

**Why:** Grouping with `{ }` redirects once for the entire block. `printf '%s\n'` can print multiple arguments in a single call, reducing the number of builtin invocations. Using `printf` instead of `echo` also avoids portability issues with escape sequences.
