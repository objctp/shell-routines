# Example: Debugging an Unbound Variable Error

## The Failing Script

```bash
#!/usr/bin/env bash
# deploy.sh - Deploy application to environment
set -euo pipefail

ENV="${1:-}"
DRY_RUN="${2:-false}"

validate_env() {
    local env="$1"
    case "$env" in
        staging|production) ;;
        *)
            echo "Error: invalid environment '$env'" >&2
            return 1
            ;;
    esac
}

build_image() {
    local tag="$1"
    docker build -t "$tag" .
}

push_image() {
    local tag="$1"
    docker push "$tag"
}

deploy() {
    local env="$1"
    local tag="myapp:${COMMIT_HASH}"
    build_image "$tag"
    push_image "$tag"
    kubectl set image "deployment/myapp-${env}" "myapp=${tag}"
}

# Main
validate_env "$ENV"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY RUN: would deploy to $ENV"
    exit 0
fi

deploy "$ENV"
echo "Deployed to $ENV"
```

## Step 1: Observe the Error

```bash
$ bash deploy.sh staging
deploy.sh: line 42: COMMIT_HASH: unbound variable
```

The script exits with an unbound variable error. The message tells us the variable name (`COMMIT_HASH`) and the line number (42, inside `deploy()`).

Exit code:

```bash
$ echo $?
1
```

## Step 2: Syntax Check

Before investigating further, confirm the script has no syntax errors:

```bash
$ bash -n deploy.sh
# No output -- syntax is valid
```

The problem is not a syntax issue. It is a runtime error caused by `set -u` (nounset) combined with a missing variable.

## Step 3: Enable Trace Mode

Add `set -x` to see the execution flow leading to the failure:

```bash
$ bash -x deploy.sh staging
+ ENV=staging
+ DRY_RUN=false
+ validate_env staging
+ local env=staging
+ case staging in
+ return 0
+ [[ false == \t\r\u\e ]]
+ deploy staging
+ local env=staging
+ local tag=myapp:
deploy.sh: line 42: COMMIT_HASH: unbound variable
```

The trace shows `tag=myapp:` -- the `COMMIT_HASH` variable is empty at expansion time, and because of `set -u`, bash treats it as an error rather than expanding to an empty string.

The root cause is clear: `COMMIT_HASH` is never set in the script. It was presumably meant to be injected from the environment or derived from git.

## Step 4: ShellCheck for Additional Issues

```bash
$ shellcheck deploy.sh

In deploy.sh line 42:
    local tag="myapp:${COMMIT_HASH}"
                         ^---------^ SC2153: Possible misspelling: COMMIT_HASH (not declared)
```

ShellCheck confirms the variable is undeclared. It also catches the missing guard.

## Step 5: Apply the Fix

The variable should either be derived or have a sensible default:

```bash
# Option A: Derive from git
COMMIT_HASH="${COMMIT_HASH:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"

# Option B: Require it explicitly
if [[ -z "${COMMIT_HASH:-}" ]]; then
    echo "Error: COMMIT_HASH must be set" >&2
    exit 1
fi
```

After applying option A near the top of the script:

```bash
#!/usr/bin/env bash
# deploy.sh - Deploy application to environment
set -euo pipefail

ENV="${1:-}"
DRY_RUN="${2:-false}"
COMMIT_HASH="${COMMIT_HASH:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
```

## Step 6: Verify the Fix

```bash
$ bash deploy.sh staging true
DRY RUN: would deploy to staging

$ bash -x deploy.sh staging true
+ ENV=staging
+ DRY_RUN=true
++ git rev-parse --short HEAD
+ COMMIT_HASH=a1b2c3d
+ validate_env staging
+ local env=staging
+ case staging in
+ return 0
+ [[ true == \t\r\u\e ]]
+ echo 'DRY RUN: would deploy to staging'
DRY RUN: would deploy to staging
+ exit 0
```

The script now resolves `COMMIT_HASH` from git and completes without errors.

