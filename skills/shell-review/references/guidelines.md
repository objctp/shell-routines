# Code Review Guidelines

## When Not to Raise an Issue

Do not raise issues for:

- **Style preferences** with no correctness or security implication
- **POSIX portability concerns** when the script explicitly targets bash only (shebang is `#!/usr/bin/env bash` or `#!/bin/bash`)
- **Performance micro-optimisations** in non-hot code paths
- **ShellCheck false positives** like `SC2148` (missing shebang) when a shebang is clearly present

## Review Quality Standards

### Be Specific

Every issue needs:
- **File** — which file has the issue
- **Line** — exact line number
- **Issue** — clear description of what's wrong
- **Suggested Fix** — concrete, actionable solution

Vague comments like "improve error handling" are not acceptable.

### Acknowledge Strengths

A review with no positives is usually incomplete. Note what is done well:
- Good error handling
- Clear variable naming
- Proper use of builtins
- Security-conscious design
- Good documentation

### Categorise Appropriately

Use the severity definitions in `review-template.md` (Critical / Moderate / Minor). Do not pad the minor category to appear thorough — an empty Minor section is fine.

## When POSIX Portability Must Be Raised

POSIX compliance is a **Critical** review dimension when the shebang is `#!/bin/sh`, `#!/usr/bin/env sh`, or `#!/usr/bin/dash`. On these scripts, bashisms will fail at runtime under dash (Ubuntu/Debian's `/bin/sh`).

Raise POSIX issues when:
- The shebang targets `sh` and the script uses bash-only features (`[[ ]]`, arrays, `${var,,}`, `<<<`, `source`, `function` keyword, etc.)
- `checkbashisms` reports findings on a `#!/bin/sh` script

Do not raise POSIX issues when:
- The shebang explicitly targets bash (`#!/usr/bin/env bash` or `#!/bin/bash`) — bashisms are expected and correct

Consult `shell-best-practices` for POSIX feature restrictions and shebang guidance.
