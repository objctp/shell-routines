import { readFileSync } from "node:fs";
import path from "node:path";
import type {
  Hooks,
  Plugin,
  PluginInput,
  PluginOptions,
} from "@opencode-ai/plugin";
import { detectDialect, isShellFile } from "./shell-routines/dialect";
import { runQualityChecks } from "./shell-routines/quality-checks";
import { syncContent } from "./shell-routines/setup-content";
import type { ShellToolInput, ShellToolOutput } from "./shell-routines/types";

async function hasCmd($: PluginInput["$"], cmd: string): Promise<boolean> {
  const r = await $`command -v ${cmd}`.nothrow();
  return r.exitCode === 0;
}

export const ShellHooksPlugin: Plugin = async (
  { $, client, directory }: PluginInput,
  options?: PluginOptions,
): Promise<Hooks> => {
  // :::: Self-install bundled content (npm plugins only) :::: //////////////
  // Failures are logged and swallowed — they must never block the hook below.
  const explicitScope =
    options?.scope === "project" || options?.scope === "global"
      ? options.scope
      : undefined;
  try {
    const packageRoot = path.resolve(import.meta.dirname, "..");
    const pkg = JSON.parse(
      readFileSync(path.join(packageRoot, "package.json"), "utf8"),
    );
    syncContent({
      packageRoot,
      version: pkg.version,
      packageName: pkg.name,
      client,
      scope: explicitScope,
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

  // :::: Detect available quality tools :::: ///////////////////////////////
  const hasShellcheck = await hasCmd($, "shellcheck");
  const hasCheckbashisms = await hasCmd($, "checkbashisms");

  return {
    "tool.execute.after": async (
      input: ShellToolInput,
      output: ShellToolOutput,
    ) => {
      if (input.tool !== "write" && input.tool !== "edit") return;

      const filePath: string | undefined = input.args?.file_path ??
        input.args?.filePath;
      if (!filePath) return;

      // Canonicalise and verify the file exists.
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

      // Read first line once — needed for shebang check and dialect detection.
      let firstLine: string;
      try {
        firstLine = await $`head -1 ${resolved}`.nothrow().text();
      } catch {
        return;
      }

      if (!isShellFile(ext, firstLine)) return;

      const { dialect, isPosix } = detectDialect(firstLine);

      const findings = await runQualityChecks({
        $,
        resolved,
        dialect,
        isPosix,
        hasShellcheck,
        hasCheckbashisms,
      });

      if (findings.length > 0) {
        output.output += "\n\n---\n**Shell quality checks:**\n" +
          findings.join("\n\n");
      }
    },
  };
};

// OpenCode resolves the `exports["./server"]` entry in dist/package.json and
// expects a V1 plugin module that default-exports `{ id, server }`.
export default {
  id: "shell-routines",
  server: ShellHooksPlugin,
};
