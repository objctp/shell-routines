---
name: shell-batch-operations
description: This skill should be used when the task involves processing multiple files, running the same operation across many inputs, building multi-stage shell pipelines, or performing bulk transformations that return a single structured JSON result. Trigger on "process all files", "for each file do", "bulk operation", "rename many files", "find and transform", "shell pipeline", "count all", "iterate over", "run this for every", "apply to each", or any task applying the same operation to 3+ similar inputs. Prefer this over repeated individual tool calls when intermediate results are not needed for user decisions.
allowed-tools: Read, Write, Edit, Bash
---

# Batch Operations Skill

## When to Use Batch vs Individual Calls

**Does the user need to see results between steps?** If not, use batch.

| Signal                                              | Approach         |
| --------------------------------------------------- | ---------------- |
| Same operation on multiple inputs                   | Batch            |
| Multi-stage pipeline (extract → transform → load)   | Batch            |
| Bulk file processing, renaming, transformation      | Batch            |
| Debugging — need to see each step                   | Individual calls |
| Single or two-step operation                        | Individual calls |
| Unpredictable failures requiring per-step diagnosis | Individual calls |

For a full decision matrix, see `references/decision-tree.md`.

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
| `batch_process_files RESULTS METADATA ERRORS ...` | Process files matching a glob pattern   |
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
  "errors": []
}
```

## Common Pitfalls

| Pitfall                               | Fix                                             |
| ------------------------------------- | ----------------------------------------------- |
| Logging to stdout                     | Use `batch_progress` or `echo >&2`              |
| Forgetting `batch_output`             | Always call it last with all three arrays       |
| Non-JSON-safe values in results       | `_json_escape` handles this; avoid raw newlines |
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
