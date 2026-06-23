---
name: shell-batch-operations
description: Write batch shell scripts that consolidate many operations into one run emitting a single structured JSON result. Use when one action runs across 3+ similar inputs ("process all files", "rename many files") or a multi-stage shell pipeline is needed (extract → transform → aggregate), and the user need not see results between steps. Prefer this over repeated individual tool calls.
allowed-tools: Read, Write, Edit, Bash
---

# Batch Operations Skill

## When to Use Batch

Use batch when the user need not see results between steps — the script consolidates many operations into one JSON result. When intermediate visibility matters (debugging, per-step diagnosis), use individual tool calls instead.

For the full decision matrix and borderline cases, read `references/decision-tree.md`.

## The Batch Pattern

All batch scripts follow this structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

source "${CLAUDE_PLUGIN_ROOT}/scripts/lib-batch.sh"

declare -A RESULTS
declare -a METADATA
declare -a ERRORS

batch_add_metadata METADATA "script" "$(basename "$0")"
batch_add_metadata METADATA "started" "$(date -Iseconds)"

# — your processing logic here —

batch_add_metadata METADATA "completed" "$(date -Iseconds)"
batch_output RESULTS METADATA ERRORS
```

Progress goes to stderr; only the final JSON result reaches stdout.

## lib-batch.sh API

Sourced from `${CLAUDE_PLUGIN_ROOT}/scripts/lib-batch.sh`.

| Function                                          | Purpose                                 |
| ------------------------------------------------- | --------------------------------------- |
| `batch_add_result RESULTS "key" "value"`          | Store a named result                    |
| `batch_add_result_item RESULTS "item"`            | Append to a list                        |
| `batch_add_metadata METADATA "key" "value"`       | Add run metadata                        |
| `batch_add_error ERRORS "message"`                | Record a non-fatal error                |
| `batch_progress "message"`                        | Log to stderr (safe during JSON output) |
| `batch_step "label" current total`                | Log progress with percentage            |
| `batch_output RESULTS METADATA [ERRORS]`          | Emit final JSON to stdout               |
| `batch_process_files RESULTS METADATA ERRORS "pattern" callback` | Process files matching a glob pattern   |
| `batch_run_command RESULTS "key" command [args]`  | Run command, store exit code and output |

## Output Format

```json
{
  "results": {
    "file_count": 42,
    "total_lines": 12345
  },
  "metadata": {
    "script": "process-txt-files",
    "started": "2026-03-03T10:30:00+00:00",
    "completed": "2026-03-03T10:30:05+00:00"
  },
  "errors": ["File too large, skipping: ./huge.txt (50000000 bytes)"]
}
```

The `errors` key appears only when at least one error was recorded; with none, it is omitted entirely.

## Common Pitfalls

| Pitfall                               | Fix                                             |
| ------------------------------------- | ----------------------------------------------- |
| Logging to stdout                     | Use `batch_progress` or `echo >&2`              |
| Forgetting `batch_output`             | Always call it last with all three arrays       |
| Non-JSON-safe values in results       | The output builder escapes them; avoid raw newlines in values |
| Storing full file contents in results | Store summaries only                            |

## Reference Files

- `references/decision-tree.md` — Decision flowchart, matrix of common scenarios, and key factors (operation count, similarity, interactivity, error handling)
- `assets/batch-template.sh` — Starting point for new batch scripts: argument parsing, lib-batch.sh sourcing with fallback, error collection scaffolding, and standard output formatting
- `examples/file-batch.sh` — File iteration, per-file processing, and summary results
- `examples/data-pipeline.sh` — Multi-stage pipelines (extract, transform, analyse): temp-file-based stage handoff, intermediate error handling, and percentage calculations

Always read all references and examples before producing output.

## Integration

- **`shell-best-practices`** — Coding standards apply inside batch scripts
- **`shell-architect`** agent — Architecture advice for complex multi-script pipelines
- **`/shell-batch-exec`** command — Runs a batch script and parses the JSON result
