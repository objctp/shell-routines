---
name: shell-batch-exec
description: Run a batch script, parse its JSON output, display structured results
argument-hint: script [args...]
allowed-tools: [Read, Bash]
disable-model-invocation: true
---

# Execute Batch Script

Execute a batch script and parse its JSON output for structured results. This command works with scripts built using the `shell-batch-operations` skill template that output JSON via `batch_output()`.

## Arguments

- **$1** (required): Path to the batch script to execute
- **$2 ...** (optional): Additional arguments passed to the script

## How It Works

1. Validate the script at `$1` — confirm it exists and is executable:
   - Check file: !`test -f "$1" && echo "EXISTS" || echo "MISSING"`
   - Check executable: !`test -x "$1" && echo "EXECUTABLE" || echo "NOT_EXECUTABLE"`
2. If validation passes, execute the script and capture output:
   - Run: !`bash "$1" $2 $3 2>&1`
3. Parse the JSON stdout and display:
   - Results section (key-value pairs from `results`)
   - Metadata section (script name, timestamps)
   - Errors section (any entries in `errors` array)
4. If validation fails or output is malformed, report the issue and suggest fixes

## Examples

```bash
# Execute a batch script
/shell-batch-exec scripts/process-files.sh

# Execute with arguments
/shell-batch-exec scripts/data-pipeline.sh access.log

# Execute from current directory
/shell-batch-exec ./my-batch-script.sh
```

## See Also

- **`shell-batch-operations`** skill — Full documentation on batch pattern, output format, and `batch_output()` contract
- **`batch-template.sh`** — Script template with batch utilities
- **`lib-batch.sh`** — Batch utility functions reference
