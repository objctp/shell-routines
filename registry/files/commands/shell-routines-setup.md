---
name: shell-routines-setup
description: Configure Bash LSP development environment and tools
allowed-tools: [Bash]
disable-model-invocation: true
---

# Bash LSP Setup

Configure the Bash/Shell development environment. Detect and install required tools, verify the LSP configuration, and validate the hook pipeline.

## Prerequisites

Node.js is required for bash-language-server. Check first:

- Node.js: !`command -v node >/dev/null 2>&1 && node --version || echo "MISSING"`
- npm: !`command -v npm >/dev/null 2>&1 && npm --version || echo "MISSING"`

If Node.js is missing, stop and ask the user whether to install the latest LTS version before continuing.

## How It Works

### 1. Detect installed tools

Check which tools are already present before installing:

- bash-language-server: !`command -v bash-language-server >/dev/null 2>&1 && bash-language-server --version || echo "MISSING"`
- shellcheck: !`command -v shellcheck >/dev/null 2>&1 && shellcheck --version || echo "MISSING"`
- shfmt: !`command -v shfmt >/dev/null 2>&1 && shfmt --version || echo "MISSING"`
- bashunit: !`command -v bashunit >/dev/null 2>&1 && bashunit --version || echo "MISSING"`
- checkbashisms: !`command -v checkbashisms >/dev/null 2>&1 && checkbashisms --version || echo "MISSING"`
- hyperfine: !`command -v hyperfine >/dev/null 2>&1 && hyperfine --version || echo "MISSING"`

### 2. Install missing tools

**Ask the user for confirmation before installing anything.** List the missing tools and the commands that will install them, then wait for approval:

- **bash-language-server** (via npm): `npm install -g bash-language-server`
- **shellcheck, shfmt, bashunit, hyperfine** (via brew): `brew install shellcheck shfmt bashunit hyperfine`
- **checkbashisms** (via devscripts): `brew install devscripts`

Only proceed with installation after the user confirms. Skip any tool already installed. Report what was installed vs what was already present.

### 3. Verify LSP configuration

Confirm the plugin's LSP config is in place:

- Check `.lsp.json`: !`test -f "${CLAUDE_PLUGIN_ROOT}/.lsp.json" && echo "LSP_CONFIG_OK" || echo "LSP_CONFIG_MISSING"`

If missing, report that the plugin installation may be incomplete.

### 4. Validate hook pipeline

Test that the hook pipeline works end-to-end by creating a temporary shell script and running ShellCheck and shfmt against it:

- Test ShellCheck: !`echo '#!/usr/bin/env bash\ngreet() { local name="$1"; echo "Hello, ${name}!"; }\ngreet "World"' > /tmp/test_lsp.sh && shellcheck /tmp/test_lsp.sh && echo "SHELLCHECK_OK" || echo "SHELLCHECK_FAIL"`
- Test shfmt: !`shfmt -d /tmp/test_lsp.sh && echo "SHFMT_OK" || echo "SHFMT_FAIL"`
- Clean up: !`rm -f /tmp/test_lsp.sh`

If both pass, the environment is ready. If either fails, report the specific tool and suggest troubleshooting steps.

## See Also

- **README.md** — Full prerequisites list and installation alternatives
- **`.lsp.json`** — LSP server configuration for bash-language-server
- **Hooks** — PostToolUse hook runs ShellCheck, shfmt, `bash -n`, and `checkbashisms` automatically
