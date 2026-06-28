import type { PluginInput } from "@opencode-ai/plugin";
import type { Dialect } from "./types";

export interface QualityCheckDeps {
  $: PluginInput["$"];
  /** Absolute, verified-existing path to the shell file. */
  resolved: string;
  dialect: Dialect;
  isPosix: boolean;
  hasShellcheck: boolean;
  hasCheckbashisms: boolean;
}

/**
 * Run all enabled quality checks against a resolved shell file and return the
 * human-readable findings (empty if clean). Each check is independently
 * fault-tolerant — a missing tool or failed command never aborts the others.
 */
export async function runQualityChecks(
  deps: QualityCheckDeps,
): Promise<string[]> {
  const { $, resolved, dialect, isPosix, hasShellcheck, hasCheckbashisms } =
    deps;
  const findings: string[] = [];

  // :::: ShellCheck — findings on stdout, exits non-zero on issues :::: /////
  if (hasShellcheck) {
    try {
      const sc = await $`shellcheck -s ${dialect} ${resolved} 2>&1`
        .nothrow().text();
      if (sc.trim()) {
        findings.push(
          `ShellCheck findings in ${resolved} (shell=${dialect}):\n${sc.trim()}`,
        );
      }
      // deno-lint-ignore no-empty
    } catch {}
  }

  // :::: Syntax — bash -n (skipped for POSIX shells) :::: //////////////////
  if (!isPosix) {
    try {
      const syntax = await $`bash -n ${resolved} 2>&1`.nothrow().text();
      if (syntax.trim()) {
        findings.push(`Syntax error in ${resolved}: ${syntax.trim()}`);
      }
      // deno-lint-ignore no-empty
    } catch {}
  }

  // :::: POSIX bashisms — only for dash/sh shebangs :::: ////////////////////
  if (isPosix && hasCheckbashisms) {
    try {
      const bashisms = await $`checkbashisms ${resolved} 2>&1`.nothrow()
        .text();
      if (bashisms.trim()) {
        findings.push(
          `POSIX compatibility issue in ${resolved} — bashisms detected:\n${bashisms.trim()}\n` +
            "Note: /bin/sh is dash on Ubuntu/Debian. These will fail at runtime.",
        );
      }
      // deno-lint-ignore no-empty
    } catch {}
  }

  // :::: Unresolved markers — TODO/FIXME/HACK/XXX/BUG :::: //////////////////
  try {
    const todos =
      await $`grep -n -E '(^|[^[:alnum:]_])(TODO|FIXME|HACK|XXX|BUG):' ${resolved}`
        .nothrow()
        .text();
    if (todos.trim()) {
      findings.push(`Unresolved markers in ${resolved}:\n${todos.trim()}`);
    }
    // deno-lint-ignore no-empty
  } catch {}

  // :::: Batch script patterns — lib-batch.sh contracts :::: ///////////////
  try {
    const content = await $`cat ${resolved}`.nothrow().text();
    if (content.includes("lib-batch.sh")) {
      if (!content.includes("batch_output")) {
        findings.push(
          `Batch script detected in ${resolved}: ensure batch_output() is called to return JSON results`,
        );
      }
      if (!content.includes("declare -A RESULTS")) {
        findings.push(
          `Batch script detected in ${resolved}: declare RESULTS array with: declare -A RESULTS`,
        );
      }
    }
    // deno-lint-ignore no-empty
  } catch {}

  return findings;
}
