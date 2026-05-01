import type { Hooks, Plugin, PluginInput } from "@opencode-ai/plugin";

const SHELL_EXTENSIONS = new Set(["sh", "bash", "zsh", "ksh"]);
const SHEBANG_PATTERN = /#!.*\b(bash|sh|zsh|ksh)\b/;
const DASH_PATTERN = /#!.*\bdash\b/;
const SH_ONLY_PATTERN = /#!.*\bsh\b/;
const BASH_FAMILY_PATTERN = /#!.*\b(bash|zsh|ksh)\b/;

// deno-lint-ignore require-await
export const ShellHooksPlugin: Plugin = async (
  { $ }: PluginInput,
): Promise<Hooks> => {
  return {
    "tool.execute.after": async (
      input: {
        tool: string;
        sessionID: string;
        callID: string;
        args: { file_path?: string; filePath?: string; [key: string]: unknown };
      },
      output: { title: string; output: string; metadata: unknown },
    ) => {
      if (input.tool !== "write" && input.tool !== "edit") return;

      const filePath: string | undefined = input.args?.file_path ??
        input.args?.filePath;
      if (!filePath) return;

      // Canonicalise and verify file exists
      let resolved: string;
      try {
        resolved = await $`realpath ${filePath}`.nothrow().text();
        resolved = resolved.trim();
      } catch {
        return;
      }
      if (!resolved) return;

      const exists = await $`test -f ${resolved}`.nothrow();
      if (exists.exitCode !== 0) return;

      const ext = resolved.split(".").pop()?.toLowerCase() ?? "";

      // Read first line once — needed for shebang check and dialect detection
      let firstLine: string;
      try {
        firstLine = await $`head -1 ${resolved}`.nothrow().text();
      } catch {
        return;
      }

      // If extension is not a shell type, verify via shebang
      if (!SHELL_EXTENSIONS.has(ext) && !SHEBANG_PATTERN.test(firstLine)) {
        return;
      }

      // Detect dialect
      let dialect = "bash";
      let isPosix = false;
      if (DASH_PATTERN.test(firstLine)) {
        dialect = "dash";
        isPosix = true;
      } else if (
        SH_ONLY_PATTERN.test(firstLine) && !BASH_FAMILY_PATTERN.test(firstLine)
      ) {
        dialect = "sh";
        isPosix = true;
      }

      const findings: string[] = [];

      // ShellCheck — findings on stdout, exits non-zero on issues
      try {
        const sc = await $`shellcheck -s ${dialect} ${resolved}`.nothrow()
          .text();
        if (sc.trim()) {
          findings.push(
            `ShellCheck findings in ${resolved} (shell=${dialect}):\n${sc.trim()}`,
          );
        }
        // deno-lint-ignore no-empty
      } catch {}

      // bash -n syntax check — non-POSIX only
      if (!isPosix) {
        try {
          const syntax = await $`bash -n ${resolved} 2>&1`.nothrow().text();
          if (syntax.trim()) {
            findings.push(`Syntax error in ${resolved}: ${syntax.trim()}`);
          }
          // deno-lint-ignore no-empty
        } catch {}
      }

      // checkbashisms — POSIX scripts only
      if (isPosix) {
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

      // TODO/FIXME/HACK/XXX/BUG markers
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

      // Batch script pattern validation
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

      // OpenCode tool.execute.after mutates output in-place (unlike Claude Code
      // PostToolUse which has a separate additionalContext channel).  We append
      // findings rather than replace so the LLM still sees the original tool
      // result (e.g. "File written successfully") alongside the diagnostics.
      // NOTE: output.output mutations only affect native tools (bash/read/
      // write/edit).  MCP tools silently discard mutations — see issue #13573, #13574.
      if (findings.length > 0) {
        output.output += "\n\n---\n**Shell quality checks:**\n" +
          findings.join("\n\n");
      }
    },
  };
};
