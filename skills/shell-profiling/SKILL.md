---
name: shell-profiling
description: Profile a slow-but-correct bash script; measure a baseline, trace with xtrace timing to find the hotspot, apply shell-specific optimisations, and benchmark the result. Use when a script works correctly but runs too slowly, or to measure/compare execution speed ("profile this script", "why is my script slow", "find the bottleneck"). For runtime errors use shell-debugging; for quality review use shell-review.
allowed-tools: Read, Grep, Glob, Bash
argument-hint: [script-path]
---

# Shell Profiling Skill

Guides systematic performance profiling of bash scripts to identify bottlenecks and apply targeted optimisations.

## Scope

This skill handles **performance problems** -- scripts that work correctly but run too slowly. It covers:

- Timing measurement at multiple granularities (whole-script, per-section, per-line)
- Xtrace-based profiling with microsecond-precision timestamps
- Syscall and library-call analysis
- Statistical benchmarking and comparison
- Shell-specific optimisation patterns (subshells, builtins, I/O, loops, string processing)

This skill does **not** cover:

- Runtime failures or error diagnosis -- use `shell-debugging`
- General code quality or style -- use `shell-review`
- Writing standards or scaffolding -- use `shell-best-practices`

## Workflow

The profiling cycle is: **measure the original, instrument a temporary copy to diagnose, discard the copy, apply fixes to the original, benchmark the result.** Never leave profiling instrumentation in the target script.

### 1. Define Target

Before profiling, decide what acceptable performance looks like (e.g., "under 5 seconds" or "twice as fast"). This prevents over-optimisation and gives a clear stopping condition.

### 2. Measure baseline

Run the original script with `time` to establish a baseline. No modifications to the script:

```bash
time bash script.sh args
```

For per-section granularity, use `EPOCHREALTIME` inside the script (add temporarily, remove after measurement). See `references/profiling-tools.md` for all timing methods and their trade-offs.

### 3. Trace with Timing

Create a temporary copy of the script and add xtrace instrumentation to it. The original script remains untouched:

```bash
cp script.sh /tmp/script.profiling.sh
```

Insert after the shebang and `set` lines in the copy:

```bash
exec 42>/tmp/trace.log
BASH_XTRACEFD=42
PS4='+ ${EPOCHREALTIME} ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:-main} '
set -x
```

Run the instrumented copy, then discard it. See `references/profiling-tools.md` for BASH_XTRACEFD setup and capture patterns.

### 4. Identify Hotspot

Process the trace output to find the lines consuming the most time. Use `scripts/trace-aggregate.sh` for deterministic aggregation:

```bash
scripts/trace-aggregate.sh /tmp/trace.log
```

Output shows cumulative time per source location with call counts, sorted by descending time.

Look for locations with the highest cumulative time and call counts, particularly tight loops, subshell invocations, or external command calls.

### 5. Deep-dive

When the hotspot involves system calls or I/O, use deeper analysis tools. These run against the original script without modification:

```bash
# Syscall summary (Linux)
strace -c -f bash script.sh

# Detailed resource usage
/usr/bin/time -v bash script.sh
```

See `references/profiling-tools.md` for platform-specific alternatives (macOS: `dtruss`, `sample`, Instruments).

### 6. Apply Optimisation

Apply fixes to the **original script** (not the instrumented copy). Consult `references/optimisation-patterns.md` for shell-specific fixes:

- Subshell elimination -- replace `$(cmd)` with parameter expansion
- Builtin selection -- use bash builtins over external commands
- I/O reduction -- batch reads, redirect once, avoid unnecessary pipes
- Loop tuning -- process substitution, `lastpipe`, pre-allocated arrays
- String processing -- single-pass awk vs multi-tool pipelines

### 7. Benchmark

Measure the improvement statistically against the original baseline:

```bash
# With hyperfine (recommended)
hyperfine 'bash script_before.sh' 'bash script_after.sh'

# With bench.sh (no hyperfine required)
scripts/bench.sh -r 10 -w 1 -- bash script_before.sh
scripts/bench.sh -r 10 -w 1 -- bash script_after.sh
```

Discard the first run (warm-up), compare median not mean.

If the result still misses the target set in step 1, return to step 3 with the next hotspot; stop once the target is met or all viable patterns are exhausted.

### 8. Report

Present a before/after comparison:

- Baseline timing vs optimised timing
- Percentage improvement
- Which patterns were applied
- Any trade-offs introduced (readability, portability)

Clean up temporary files (`/tmp/trace.log`, `/tmp/script.profiling.sh`).

## References

- `references/profiling-tools.md` -- Comprehensive catalogue of timing, tracing, syscall, and benchmarking tools with syntax examples, output interpretation, and platform availability
- `references/optimisation-patterns.md` -- Shell-specific performance patterns with before/after code snippets, covering subshells, builtins, I/O, loops, and string processing

Always read all references, scripts, and examples before producing output.

## Scripts

- `scripts/trace-aggregate.sh` -- Aggregates xtrace timestamps into cumulative per-line timings with call counts. Usage: `trace-aggregate.sh <trace-file> [top-n]`
- `scripts/bench.sh` -- Manual benchmark harness with warm-up runs, median/min/max/spread statistics. Usage: `bench.sh [-r runs] [-w warmup] [--] <command...>`

## Examples

- `examples/profile-session.md` -- End-to-end walkthrough: profiling a slow log-processing script from baseline measurement through hotspot identification, optimisation, and benchmarking

## Integration

- **`shell-debugging`** -- For scripts that produce errors or incorrect output (profiling assumes the script works correctly)
- **`shell-best-practices`** -- General writing standards, quoting, error handling (apply alongside performance optimisations)
- **`shell-review`** -- Quality assessment after optimisation is complete
- **`shell-architect`** agent -- Architectural decisions affecting performance (batch vs individual processing, parallelism strategy, data flow)
