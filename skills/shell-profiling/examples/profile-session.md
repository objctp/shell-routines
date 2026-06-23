# Example: Profiling a Slow Log-Processing Script

## Scenario

A script that filters log entries by date range, extracts fields, and computes a summary is running slowly on a 500,000-line log file. The script produces correct output but takes over 30 seconds. The goal is to bring it under 5 seconds.

## The Script

```bash
#!/usr/bin/env bash
set -euo pipefail

# analyse-logs.sh -- Summarise error counts by service
# Usage: analyse-logs.sh <start-date> <end-date> <logfile>
# Dates in YYYY-MM-DD format

start_date="${1:?Usage: $0 <start-date> <end-date> <logfile>}"
end_date="${2:?Usage: $0 <start-date> <end-date> <logfile>}"
logfile="${3:?Usage: $0 <start-date> <end-date> <logfile>}"

declare -A service_counts
total_errors=0

while IFS= read -r line; do
    # Extract date from line: "2025-01-15 08:23:41 [ERROR] ..."
    line_date=$(echo "$line" | cut -d' ' -f1)

    # Check date range
    if [[ "$line_date" < "$start_date" || "$line_date" > "$end_date" ]]; then
        continue
    fi

    # Extract severity
    severity=$(echo "$line" | grep -o '\[[A-Z]\+\]' | tr -d '[]')

    if [[ "$severity" != "ERROR" ]]; then
        continue
    fi

    # Extract service name (field after severity)
    service=$(echo "$line" | cut -d' ' -f4)

    # Count
    (( service_counts["$service"]++ ))
    (( total_errors++ ))
done < "$logfile"

# Print summary
echo "Error summary: $start_date to $end_date"
echo "Total errors: $total_errors"
echo ""
for service in "${!service_counts[@]}"; do
    echo "  $service: ${service_counts[$service]}"
done
```

## Step 1: Baseline Measurement

Run with `time` to establish the baseline:

```bash
$ time bash analyse-logs.sh 2025-01-01 2025-01-31 access.log

Error summary: 2025-01-01 to 2025-01-31
Total errors: 3421
  auth-service: 1204
  payment-gateway: 987
  user-api: 623
  ...

real    0m32.456s
user    0m28.123s
sys     0m4.102s
```

32 seconds. The high user time relative to wall-clock time suggests CPU-bound work, likely from spawning many external processes.

## Step 2: Xtrace Profiling with Timestamps

Add timestamped tracing to a copy of the script. Insert these lines after `set -euo pipefail`:

```bash
exec 42>/tmp/analyse-logs.trace.log
BASH_XTRACEFD=42
PS4='+ ${EPOCHREALTIME} ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:-main} '
set -x
```

Run the script again. The trace log now contains timestamped entries:

```bash
$ head -5 /tmp/analyse-logs.trace.log
+ 1709654321.001234 analyse-logs.sh:12 main
+ 1709654321.001456 analyse-logs.sh:19 main + IFS= read -r line
+ 1709654321.002001 analyse-logs.sh:22 main ++ echo '2025-01-15 08:23:41 [ERROR] auth-service ...'
+ 1709654321.002345 analyse-logs.sh:22 main ++ cut '-d ' -f1
+ 1709654321.003100 analyse-logs.sh:22 main + line_date=2025-01-15
```

## Step 3: Identify the Hotspot

Post-process the trace to find the slowest lines:

```bash
scripts/trace-aggregate.sh /tmp/analyse-logs.trace.log 10
```

Output:

```
12.3450 s  analyse-logs.sh:22 (called 500000 times)
 8.7650 s  analyse-logs.sh:25 (called 350000 times)
 5.4320 s  analyse-logs.sh:29 (called 142000 times)
 3.2100 s  analyse-logs.sh:33 (called 3421 times)
 ...
```

Line 22 (`echo "$line" | cut -d' ' -f1`) is called 500,000 times and accounts for 12 seconds. Line 25 (`grep -o`) accounts for another 8.7 seconds. Together, these subshell invocations in the tight loop dominate execution time.

> In this case, xtrace profiling was sufficient to identify the hotspot. For I/O-bound problems where the bottleneck is file operations or network calls, the deep-dive step (Step 5 in the workflow: `strace -c`, `/usr/bin/time -v`) would be the next step to quantify syscall overhead.

## Step 4: Apply Optimisation

Replace the external commands with parameter expansion and bash builtins. Here is the optimised loop body:

**Before (lines 19--38):**

```bash
while IFS= read -r line; do
    line_date=$(echo "$line" | cut -d' ' -f1)

    if [[ "$line_date" < "$start_date" || "$line_date" > "$end_date" ]]; then
        continue
    fi

    severity=$(echo "$line" | grep -o '\[[A-Z]\+\]' | tr -d '[]')

    if [[ "$severity" != "ERROR" ]]; then
        continue
    fi

    service=$(echo "$line" | cut -d' ' -f4)
    (( service_counts["$service"]++ ))
    (( total_errors++ ))
done < "$logfile"
```

**After:**

```bash
while IFS=' ' read -r line_date _time severity_raw service_rest; do
    # Filter date range
    if [[ "$line_date" < "$start_date" || "$line_date" > "$end_date" ]]; then
        continue
    fi

    # Check severity -- severity_raw looks like "[ERROR]"
    if [[ "$severity_raw" != "[ERROR]" ]]; then
        continue
    fi

    # Extract service name (first word of remaining fields)
    read -r service _ <<< "$service_rest"
    (( service_counts["$service"]++ ))
    (( total_errors++ ))
done < "$logfile"
```

**What changed:**

1. `IFS=' ' read -r line_date _time severity_raw service_rest` splits the line into fields in a single `read` call, replacing three `$(echo ... | cut)` and one `$(echo ... | grep | tr)` pipeline -- four subshell invocations per line reduced to zero.
2. The severity check compares directly against `[ERROR]` instead of extracting and stripping brackets.
3. The service extraction uses a second `read` with here-string instead of `cut`.

## Step 5: Benchmark Before/After

Using hyperfine:

```bash
$ hyperfine --warmup 2 --runs 5 \
    'bash analyse-logs-before.sh 2025-01-01 2025-01-31 access.log' \
    'bash analyse-logs-after.sh 2025-01-01 2025-01-31 access.log'

Benchmark 1: bash analyse-logs-before.sh ...
  Time (mean +/- sd):     32.118 s +/-  0.891 s

Benchmark 2: bash analyse-logs-after.sh ...
  Time (mean +/- sd):      3.452 s +/-  0.134 s

Summary
  bash analyse-logs-after.sh ran 9.30 +/- 0.48 times faster than bash analyse-logs-before.sh
```

## Step 6: Summary

| Metric          | Before    | After    | Improvement        |
| --------------- | --------- | -------- | ------------------ |
| Wall-clock time | 32.1 s    | 3.5 s    | 9.3x faster        |
| Subshells/line  | 4         | 0        | eliminated         |
| External cmds   | cut, grep, tr | read only | builtin only   |

**Pattern applied:** Subshell elimination -- replaced `$(echo ... | cmd)` pipelines with `read` field splitting and parameter expansion.

**Trade-off:** The optimised version requires that log lines follow the expected space-delimited format. If the format changes (e.g., quoted fields containing spaces), the `read`-based splitting would need adjustment. This is acceptable because the original `cut -d' '` approach had the same limitation.

## Further Optimisation (Optional)

For even faster performance on very large files, replace the bash loop entirely with a single `awk` pass:

```bash
awk -v start="$start_date" -v end="$end_date" '
    $1 >= start && $1 <= end && $3 == "[ERROR]" {
        count[$4]++
        total++
    }
    END {
        printf "Error summary: %s to %s\n", start, end
        printf "Total errors: %d\n\n", total
        for (svc in count)
            printf "  %s: %d\n", svc, count[svc]
    }
' "$logfile"
```

This processes the file in C without returning to the shell between lines. Typical result: under 0.5 seconds for 500,000 lines. The trade-off is moving logic out of bash into awk, which reduces readability for team members unfamiliar with awk.
