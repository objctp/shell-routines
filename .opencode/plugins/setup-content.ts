// Self-install bundled content for OpenCode consumers.
//
// OpenCode's plugin loader imports only the `./server` entrypoint of an npm
// plugin; it does not discover the bundled `agents/ commands/ skills/ scripts/`
// directories (those come from separate scanners that read config dirs only),
// and npm `postinstall` cannot run (OpenCode installs with `ignoreScripts`).
// So on load the plugin copies its own content into the OpenCode config
// directory, rewriting `${CLAUDE_PLUGIN_ROOT}` references to that directory so
// script-sourcing resolves to the copied location.
//
// All real work here is synchronous filesystem I/O; logging is fire-and-forget.
// `syncContent` never throws — any failure is logged and swallowed.

import {
  chmodSync,
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  readlinkSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import os from "node:os";
import type { PluginInput } from "@opencode-ai/plugin";

// `scripts/` is not scanned by OpenCode — it is synced only so the rewritten
// `${CLAUDE_PLUGIN_ROOT}/scripts/lib-*.sh` references resolve.
const DIRS = ["agents", "commands", "skills", "scripts"] as const;

// Text files whose `${CLAUDE_PLUGIN_ROOT}` tokens are rewritten at copy time.
// Everything else is copied verbatim.
const TEXT_EXT = new Set(["md", "sh", "bash", "zsh", "ksh", "txt", "json"]);

// The defaulted variant must be replaced first, otherwise the plain token would
// leave a stray `:-}` behind.
const TOKEN_DEFAULTED = "${CLAUDE_PLUGIN_ROOT:-}";
const TOKEN_PLAIN = "${CLAUDE_PLUGIN_ROOT}";

// Records the package version last synced into the config directory. Absent or
// mismatched ⇒ re-sync. Written only after a complete successful copy so a
// partial failure self-heals on the next load.
const MARKER_FILE = ".shell-routines.version";

export type SyncScope = "global" | "project";

export interface SyncOptions {
  /** Absolute path to the installed package directory (sibling of agents/commands/skills/scripts). */
  packageRoot: string;
  /** Package version, read from `<packageRoot>/package.json`. */
  version: string;
  /** OpenCode client, used for structured logging. */
  client: PluginInput["client"];
  /** Sync scope. Defaults to "global". */
  scope?: SyncScope;
  /** Project directory; required when scope is "project". */
  directory?: string;
  /** Override the destination config directory (used by tests). */
  configDirOverride?: string;
}

/**
 * Copy the plugin's bundled agents/commands/skills/scripts into the OpenCode
 * config directory so OpenCode's content scanners discover them, rewriting
 * `${CLAUDE_PLUGIN_ROOT}` references to the resolved config directory.
 *
 * Idempotent via a version marker written only after a complete, successful
 * sync. Never throws.
 */
export function syncContent(opts: SyncOptions): void {
  const { packageRoot, version, client, scope = "global", directory } = opts;

  const log = (
    level: "debug" | "info" | "warn" | "error",
    message: string,
    extra?: Record<string, unknown>,
  ) => {
    try {
      const ret = client.app.log({
        body: { service: "shell-routines", level, message, extra },
      });
      if (ret && typeof ret.catch === "function") ret.catch(() => {});
    } catch {
      // Logging must never break the plugin.
    }
  };

  // npm-installed plugins only. In file-plugin/dev mode the content already
  // lives where OpenCode discovers it, and the layout differs (no sibling
  // scripts/), so copying would produce a broken tree.
  if (!packageRoot.includes("node_modules")) {
    log("debug", "content sync skipped (not an npm install)");
    return;
  }

  // Fail safe on an unexpected package layout.
  if (!existsSync(path.join(packageRoot, "scripts"))) {
    log("warn", "content sync skipped (unexpected package layout)", {
      packageRoot,
    });
    return;
  }

  const configDir =
    opts.configDirOverride ??
    (scope === "project" && directory
      ? path.join(directory, ".opencode")
      : path.join(os.homedir(), ".config", "opencode"));

  const marker = path.join(configDir, MARKER_FILE);
  if (
    existsSync(marker) &&
    readFileSync(marker, "utf8").trim() === version
  ) {
    log("debug", "content sync skipped (already up to date)", { version });
    return;
  }

  mkdirSync(configDir, { recursive: true });

  try {
    for (const dir of DIRS) {
      syncDir(path.join(packageRoot, dir), path.join(configDir, dir), configDir);
    }
  } catch (error) {
    log("error", "content sync failed", { error: String(error) });
    return; // marker untouched → next load retries
  }

  writeFileSync(marker, version);
  log("info", "synced shell-routines skills/commands/agents/scripts", {
    configDir,
    version,
  });
}

function syncDir(src: string, dest: string, configDir: string): void {
  if (!existsSync(src)) return;
  mkdirSync(dest, { recursive: true });
  for (const entry of readdirSync(src)) {
    const srcPath = path.join(src, entry);
    const destPath = path.join(dest, entry);
    const stat = lstatSync(srcPath);

    if (stat.isSymbolicLink()) {
      // Dereference — defensive, since dist files are real but repo sources symlink.
      const target = path.resolve(
        path.dirname(srcPath),
        readlinkSync(srcPath),
      );
      syncDir(target, destPath, configDir);
    } else if (stat.isDirectory()) {
      syncDir(srcPath, destPath, configDir);
    } else {
      syncFile(srcPath, destPath, stat.mode, configDir);
    }
  }
}

function syncFile(
  src: string,
  dest: string,
  mode: number,
  configDir: string,
): void {
  const ext = path.extname(src).slice(1).toLowerCase();
  if (TEXT_EXT.has(ext)) {
    const rewritten = readFileSync(src, "utf8")
      .split(TOKEN_DEFAULTED)
      .join(configDir)
      .split(TOKEN_PLAIN)
      .join(configDir);
    writeFileSync(dest, rewritten);
  } else {
    cpSync(src, dest);
  }
  // Preserve the source mode (exec bit): batch examples stay 0644, runtime libs 0755.
  chmodSync(dest, mode & 0o777);
}
