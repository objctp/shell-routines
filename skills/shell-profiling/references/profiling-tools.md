# Profiling Tools Reference

## Built-in Timing

### `time` (bash keyword)

Measures the elapsed, user, and system time for a pipeline or command.

**Syntax:**

```bash
time bash script.sh
time ( ./slow_section; ./another_section )
```

**Output fields:**

| Field   | Meaning                                  |
| ------- | ---------------------------------------- |
| real    | Wall-clock elapsed time                  |
| user    | CPU time spent in user mode              |
| sys     | CPU time spent in kernel mode            |

**Caveats:**

- `time` is a bash reserved word, not an external command -- it works with pipelines and compound commands
- Output goes to stderr by default; redirect with `{ time cmd; } 2>timing.log`
- The output format varies between bash's built-in `time` and `/usr/bin/time`

### `/usr/bin/time`

External command providing detailed resource reporting beyond the bash built-in.

**Syntax:**

```bash
# Verbose output -- page faults, context switches, peak memory
/usr/bin/time -v bash script.sh

# Custom format
/usr/bin/time -f "Elapsed: %e s\nCPU: %P\nMax RSS: %M kB" bash script.sh
```

**Useful format specifiers:**

| Specifier | Meaning                          |
| --------- | -------------------------------- |
| `%e`      | Elapsed real time (seconds)      |
| `%U`      | User mode CPU time (seconds)     |
| `%S`      | Kernel mode CPU time (seconds)   |
| `%P`      | CPU percentage                   |
| `%M`      | Maximum resident set size (kB)   |
| `%W`      | Number of times swapped out      |
| `%c`      | Voluntary context switches        |
| `%w`      | Involuntary context switches      |

**Platform:** Linux, macOS (GNU or BSD variant; format specifiers differ between them).

**GNU vs BSD differences:** On macOS, the BSD variant of `/usr/bin/time` uses `-l` for verbose output (equivalent to `-v` on GNU) and supports fewer format specifiers. For consistent cross-platform behaviour, install the GNU version via `brew install coreutils` and use `gtime`.

### `times` builtin

Reports cumulative user and system times for the current shell and its children.

```bash
# After running some commands
times
# Output:
# 0m0.012s 0m0.008s   <- shell itself
# 0m0.345s 0m0.120s   <- children
```

Useful for measuring accumulated time across a script's lifetime. Less granular than `time`.

### `$SECONDS`

Integer variable that increments every second since shell start or since last assignment.

```bash
SECONDS=0
run_expensive_operation
echo "Took $SECONDS seconds"
```

**Precision:** Whole seconds only. Suitable for operations lasting more than a few seconds.

**Portability:** Bash-specific (not POSIX).

### `$EPOCHREALTIME`

Microsecond-precision timestamp (seconds.microseconds since epoch). Available in bash 5.0+.

```bash
start=$EPOCHREALTIME
run_operation
end=$EPOCHREALTIME
# Compute elapsed microseconds
elapsed=$(( 10#${end%.*} * 1000000 + 10#${end#*.} - 10#${start%.*} * 1000000 - 10#${start#*.} ))
echo "Took ${elapsed} us ($(( elapsed / 1000 )) ms)"
```

**Precision:** Microseconds. The best built-in option for sub-second measurement.

**Portability:** Bash 5.0+. Not available in bash 4.x. Use `date +%s.%N` as a fallback (requires spawning an external command).

---

## Xtrace Profiling

### PS4 with EPOCHREALTIME

Configure PS4 to include a timestamp in every xtrace line:

```bash
PS4='+ ${EPOCHREALTIME} ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:-main} '
set -x
```

**Output format:**

```
+ 1709654321.123456 script.sh:42 process_line + awk '{print $3}'
+ 1709654321.234567 script.sh:43 process_line + grep -c error
```

Each line begins with the timestamp, source file, line number, and function name.

**Bash 4.x fallback** (no EPOCHREALTIME):

```bash
PS4='+ $(date +%s.%N) ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:-main} '
```

Warning: this spawns a `date` process per trace line, adding measurable overhead. Use only for coarse analysis.

### BASH_XTRACEFD

Redirect xtrace output to a separate file descriptor so it does not mix with stderr:

```bash
# Open a file for trace output
exec 42>/tmp/script.trace.log

# Tell bash to write xtrace to fd 42
BASH_XTRACEFD=42

# Enable tracing
PS4='+ ${EPOCHREALTIME} ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:-main} '
set -x

# ... script runs ...

# Disable and close
set +x
exec 42>&-
```

**Why this matters:** Without BASH_XTRACEFD, xtrace output goes to stderr alongside actual error messages, making both harder to read. A dedicated file keeps the trace clean for post-processing.

### Post-processing Trace Output

Compute per-line elapsed time from the EPOCHREALTIME stamps:

```bash
# Extract timestamp, file:line, function -- compute deltas
awk '
BEGIN { prev = 0 }
/^+/ {
    ts = $2
    delta = ts - prev
    if (prev > 0) {
        printf "%.6f s  %s %s\n", delta, $3, $4
    }
    prev = ts
}
' /tmp/script.trace.log | sort -rn | head -20
```

This produces a ranked list of the slowest lines, e.g.:

```
0.451234 s  script.sh:87 process_line
0.210876 s  script.sh:45 extract_fields
0.002345 s  script.sh:12 main
```

---

## Syscall and External Analysis

### `strace` (Linux)

Trace system calls made by a script and its child processes.

**Summary mode** -- aggregate counts and timing per syscall:

```bash
strace -c -f bash script.sh
```

Output shows calls, errors, and total time per syscall. Useful for spotting excessive `fork`, `execve`, `read`, `write`, or `stat` calls.

**Per-call timing:**

```bash
strace -T -f -e trace=read,write,open,close bash script.sh 2>&1 | grep '<'
```

Each syscall line shows its duration in angle brackets: `<0.000012>`.

**Filter to specific syscalls:**

```bash
strace -c -e trace=file bash script.sh    # file-related only
strace -c -e trace=process bash script.sh  # fork/exec/clone only
strace -c -e trace=network bash script.sh  # socket/connect only
```

**Platform:** Linux only.

### `ltrace`

Trace library calls (malloc, strcmp, fopen, etc.) in addition to syscalls:

```bash
ltrace -c bash script.sh
ltrace -e malloc+free bash script.sh
```

Useful when performance problems stem from library-level operations rather than raw syscalls.

**Platform:** Linux only.

### `perf` (Linux)

Hardware performance counters for CPU-bound analysis:

```bash
perf stat bash script.sh
perf record -g bash script.sh
perf report
```

Provides cache miss rates, branch mispredictions, and instruction-level profiling. Overkill for most shell scripts. Relevant when the shell invokes compiled programs doing heavy computation (e.g., image processing, numerical analysis, compression) and the bottleneck is suspected to be inside that compiled program rather than in the shell logic itself. For pure bash scripts, `strace -c` or xtrace profiling will identify bottlenecks more directly.

**Platform:** Linux only.

### macOS Alternatives

macOS does not provide `strace`. Use these alternatives:

| Tool         | Purpose                                    | Availability              |
| ------------ | ------------------------------------------ | ------------------------- |
| `dtruss`     | Syscall tracing (requires sudo)            | macOS built-in            |
| `sample`     | Sampling profiler for a running process    | Xcode command-line tools  |
| `Instruments`| GUI profiler (Time, System Trace templates)| Xcode                     |
| `dtrace`     | D scripting language for dynamic tracing   | macOS (SIP may restrict)  |

**dtruss example:**

```bash
sudo dtruss -c bash script.sh
```

---

## Benchmarking

### hyperfine

Statistical benchmarking tool that handles warm-up runs, outlier detection, and formatting.

```bash
# Compare two versions
hyperfine \
    --warmup 3 \
    --runs 10 \
    'bash script_before.sh' \
    'bash script_after.sh'

# Export results
hyperfine --export-markdown results.md 'bash script.sh'
```

**Key features:**

- Automatic warm-up runs (discard initial slow runs caused by caching)
- Statistical analysis (mean, median, standard deviation)
- Outlier detection
- Markdown/JSON/CSV export

**Install:**

```bash
# macOS
brew install hyperfine

# Linux
cargo install hyperfine
# or: apt install hyperfine (on Debian/Ubuntu)
```

**Platform:** Cross-platform (Rust binary).

### Manual Iteration-based Benchmarking

When hyperfine is unavailable, use a manual loop:

```bash
#!/usr/bin/env bash
# bench.sh -- manual benchmark harness

runs=10
results=()

# Discard first run (warm-up)
bash script.sh >/dev/null 2>&1

for (( i = 1; i <= runs; i++ )); do
    start=$EPOCHREALTIME
    bash script.sh >/dev/null 2>&1
    end=$EPOCHREALTIME
    elapsed=$(( 10#${end%.*} * 1000000 + 10#${end#*.} - 10#${start%.*} * 1000000 - 10#${start#*.} ))
    results+=("$elapsed")
done

# Compute median
IFS=$'\n' sorted=($(sort -n <<<"${results[*]}")); unset IFS
mid=$(( runs / 2 ))
median=${sorted[$mid]}
echo "Median: $(( median / 1000 )) ms across $runs runs"
```

### Statistical Considerations

- **Discard the first run.** Filesystem caches and interpreter loading inflate the initial measurement.
- **Prefer median over mean.** Outliers (background processes, I/O spikes) distort the mean; the median is more robust.
- **Run at least 5 iterations.** Fewer than 5 makes statistical analysis unreliable. 10--20 is ideal.
- **Control the environment.** Close other applications, disable cron jobs, and avoid running benchmarks on shared hardware.
- **Report the spread.** Alongside the median, report min/max or standard deviation so readers can assess consistency.
