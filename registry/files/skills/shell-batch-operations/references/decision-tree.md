# Batch vs Individual Operations Decision Tree

Visual guide for deciding when to write batch scripts vs using individual tool calls.

## Decision Flowchart

1. **1-2 operations** → Individual calls
2. **10+ operations** → Batch script
3. **3-10 operations** → Evaluate:
   - Same operation on different inputs → Batch script
   - Different operations + interactive → Individual calls
   - Different operations + non-interactive → Batch script

## Decision Matrix

| Scenario                          | Operations | Data Type | Interactive | Recommendation   |
| --------------------------------- | ---------- | --------- | ----------- | ---------------- |
| Count files in directory          | 1          | N/A       | No          | Individual call  |
| Find and count lines in each .txt | 2-N        | Files     | No          | **Batch script** |
| Debug failing deployment          | 3+         | Commands  | Yes         | Individual calls |
| Rename 100 files by pattern       | N          | Files     | No          | **Batch script** |
| Check service status              | 1          | N/A       | Maybe       | Individual call  |
| Extract, transform, load data     | 3+         | Pipeline  | No          | **Batch script** |
| Generate 10 reports               | N          | Files     | No          | **Batch script** |

## Key Decision Factors

### 1. Number of Operations

- **1-2 operations**: Individual calls (overhead of script not worth it)
- **3-10 operations**: Depends on other factors
- **10+ operations**: Almost always batch

### 2. Operation Similarity

- **Same operation, different inputs**: Batch (file processing, bulk operations)
- **Different operations**: Depends on complexity and interactivity

### 3. Interactivity Needs

- **Need to see results between steps**: Individual calls
- **Can proceed without human input**: Batch
- **Debugging/diagnosing**: Individual calls

### 4. Token Constraints

- **Constrained context**: Batch (saves up to 98.7% tokens)
- **Plenty of context**: Either approach works

### 5. Error Handling

- **Operations may fail unpredictably**: Individual calls for diagnosis
- **Predictable operations with known error modes**: Batch with error collection

## Examples

### Batch Script Example

```bash
# User: "Find all .txt files, count lines, return top 10 by size"
# → 3+ operations, same data type, no interactivity needed

#!/usr/bin/env bash
set -euo pipefail
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib-batch.sh"

declare -A RESULTS
declare -a METADATA
declare -a ERRORS

while IFS= read -r -d '' file; do
    lines=$(wc -l < "$file")
    batch_add_result RESULTS "${file}" "$lines"
done < <(find . -name "*.txt" -print0)

# Sort and get top 10...
# (implementation details)

batch_output RESULTS METADATA ERRORS
```

### Individual Calls Example

```bash
# User: "Debug why the deploy script fails"
# → Multiple commands, but need to see each result

1. Bash: cat deploy.log → "Error: permission denied"
2. Bash: ls -la deploy.sh → "Permissions: rw-r--r--"
3. Bash: chmod +x deploy.sh
4. Bash: ./deploy.sh → "Success!"
```

## Quick Reference

**Use batch when:**

- ✓ 3+ sequential operations
- ✓ Same operation on multiple inputs
- ✓ No interactivity needed
- ✓ Token budget constrained
- ✓ Deterministic operations

**Use individual when:**

- ✓ Single operation
- ✓ Need to see intermediate results
- ✓ Debugging/diagnosing
- ✓ Interactive workflow
- ✓ Unpredictable failures
