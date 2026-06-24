import { readFileSync } from "node:fs";
import path from "node:path";
import type {
  Hooks,
  Plugin,
  PluginInput,
  PluginOptions,
} from "@opencode-ai/plugin";
import { syncContent } from "./setup-content.ts";

const SHELL_EXTENSIONS = new Set(["sh", "bash", "zsh", "ksh"]);
const SHEBANG_PATTERN = /^#!.*\b(bash|sh|zsh|ksh)\b/;
const DASH_PATTERN = /#!.*\bdash\b/;
const SH_ONLY_PATTERN = /#!.*\bsh\b/;
const BASH_FAMILY_PATTERN = /#!.*\b(bash|zsh|ksh)\b/;

async function hasCmd($: PluginInput["$"], cmd: string): Promise<boolean> {
  const r = await $`command -v ${cmd}`.nothrow();
  return r.exitCode === 0;
}

export const ShellHooksPlugin: Plugin = async (
  { $, client, directory }: PluginInput,
  options?: PluginOptions,
): Promise<Hooks> => {
  // Self-install bundled skills/commands/agents/scripts into the OpenCode config
  // directory so OpenCode discovers them (npm plugins only). Failures are logged
  // and swallowed — they must never block the quality-check hook below.
  try {
    const packageRoot = path.resolve(import.meta.dirname, "..");
    const pkg = JSON.parse(
      readFileSync(path.join(packageRoot, "package.json"), "utf8"),
    );
    syncContent({
      packageRoot,
      version: pkg.version,
      client,
      scope: options?.scope === "project" ? "project" : "global",
      directory,
    });
  } catch (error) {
    try {
      void client.app.log({
        body: {
          service: "shell-routines",
          level: "warn",
          message: "content sync failed",
          extra: { error: String(error) },
        },
      });
      // deno-lint-ignore no-empty
    } catch {}
  }

  const hasShellcheck = await hasCmd($, "shellcheck");
  const hasCheckbashisms = await hasCmd($, "checkbashisms");
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

      if (!SHELL_EXTENSIONS.has(ext) && !SHEBANG_PATTERN.test(firstLine)) {
        return;
      }

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

      if (!isPosix) {
        try {
          const syntax = await $`bash -n ${resolved} 2>&1`.nothrow().text();
          if (syntax.trim()) {
            findings.push(`Syntax error in ${resolved}: ${syntax.trim()}`);
          }
          // deno-lint-ignore no-empty
        } catch {}
      }

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

      if (findings.length > 0) {
        output.output += "\n\n---\n**Shell quality checks:**\n" +
          findings.join("\n\n");
      }
    },
  };
};

// OpenCode resolves the `exports["./server"]` entry in dist/package.json and
// expects a V1 plugin module that default-exports `{ id, server }`. The named
// export above is kept for direct imports and tests.
export default {
  id: "shell-routines",
  server: ShellHooksPlugin,
};
