// OpenCode loads only a plugin's `./server` entrypoint — it does not discover
// the bundled agents/commands/skills/scripts (separate scanners read config
// dirs only), and `postinstall` can't run (OpenCode installs with
// ignoreScripts). So on load the plugin copies its own content into the config
// dir matching the install scope, rewriting ${CLAUDE_PLUGIN_ROOT} → that dir.
//
// All work is synchronous FS I/O; logging is fire-and-forget. Never throws.

import {
  chmodSync,
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  readlinkSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import os from "node:os";
import type { PluginInput } from "@opencode-ai/plugin";

// scripts/ isn't scanned by OpenCode — synced only so the rewritten
// ${CLAUDE_PLUGIN_ROOT}/scripts/lib-*.sh references resolve.
const DIRS = ["agents", "commands", "skills", "scripts"] as const;

const TEXT_EXT = new Set(["md", "sh", "bash", "zsh", "ksh", "txt", "json"]);

// Replace the defaulted variant first, or the plain token leaves a stray `:-}`.
const TOKEN_DEFAULTED = "${CLAUDE_PLUGIN_ROOT:-}";
const TOKEN_PLAIN = "${CLAUDE_PLUGIN_ROOT}";

// State lives in OpenCode's state dir (next to plugin-meta.json), not the config
// dir, so it never pollutes ~/.config/opencode or a project's .opencode/.
// Keyed by destination dir: global and each project-local sync are independent.
const STATE_DIR = path.join(
  os.homedir(),
  ".local",
  "state",
  "opencode",
  "shell-routines",
);
const STATE_FILE = "sync-state.json";

// <=1.3.1 wrote this into the config dir; remove on sight to migrate.
const LEGACY_MARKER = ".shell-routines.version";

const PROJECT_CONFIGS = [
  "opencode.json",
  "opencode.jsonc",
  ".opencode/opencode.json",
  ".opencode/opencode.jsonc",
];

export type SyncScope = "global" | "project";

export interface SyncOptions {
  packageRoot: string;
  version: string;
  /** Used to auto-detect scope from the project's config files. */
  packageName: string;
  client: PluginInput["client"];
  /** Overrides auto-detected scope. */
  scope?: SyncScope;
  /** Project directory; required when scope resolves to "project". */
  directory?: string;
  /** Override the destination config directory (tests). */
  configDirOverride?: string;
  /** Override the state directory (tests). */
  stateDirOverride?: string;
}

/**
 * Copy agents/commands/skills/scripts into the config dir matching the install
 * scope (auto-detected: listed in a project config ⇒ project-local, else
 * global), rewriting ${CLAUDE_PLUGIN_ROOT} → that dir. Idempotent via a
 * per-target version record in the state dir. Never throws.
 */
export function syncContent(opts: SyncOptions): void {
  const {
    packageRoot,
    version,
    packageName,
    client,
    directory,
    configDirOverride,
    stateDirOverride,
  } = opts;

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

  // File-plugin/dev mode already exposes content where OpenCode finds it, and
  // its layout differs (no sibling scripts/).
  if (!packageRoot.includes("node_modules")) {
    log("debug", "content sync skipped (not an npm install)");
    return;
  }

  if (!existsSync(path.join(packageRoot, "scripts"))) {
    log("warn", "content sync skipped (unexpected package layout)", {
      packageRoot,
    });
    return;
  }

  const scope = opts.scope ?? detectInstallScope(directory, packageName);
  const configDir = configDirOverride ??
    (scope === "project" && directory
      ? path.join(directory, ".opencode")
      : path.join(os.homedir(), ".config", "opencode"));

  const stateDir = stateDirOverride ?? STATE_DIR;
  const stateFile = path.join(stateDir, STATE_FILE);
  const synced: Record<string, string> = readState(stateFile);
  if (synced[configDir] === version) {
    log("debug", "content sync skipped (already up to date)", {
      configDir,
      version,
    });
    return;
  }

  mkdirSync(configDir, { recursive: true });
  removeLegacyMarker(configDir);

  try {
    for (const dir of DIRS) {
      syncDir(path.join(packageRoot, dir), path.join(configDir, dir), configDir);
    }
  } catch (error) {
    log("error", "content sync failed", { error: String(error), configDir });
    return; // state untouched → next load retries
  }

  synced[configDir] = version;
  mkdirSync(stateDir, { recursive: true });
  writeFileSync(stateFile, JSON.stringify(synced, null, 2) + "\n");
  log("info", "synced shell-routines skills/commands/agents/scripts", {
    configDir,
    scope,
    version,
  });
}

/** "project" if packageName is in any project config's `plugin` array, else "global". */
function detectInstallScope(
  directory: string | undefined,
  packageName: string,
): SyncScope {
  if (!directory) return "global";
  for (const rel of PROJECT_CONFIGS) {
    const file = path.join(directory, rel);
    if (!existsSync(file)) continue;
    try {
      const cfg = JSON.parse(stripJsonc(readFileSync(file, "utf8"))) as {
        plugin?: unknown[];
      };
      if (
        Array.isArray(cfg.plugin) &&
        cfg.plugin.some((e) => matchesPlugin(e, packageName))
      ) {
        return "project";
      }
    } catch {
      // Unreadable config — keep checking the rest.
    }
  }
  return "global";
}

function matchesPlugin(entry: unknown, packageName: string): boolean {
  const spec = Array.isArray(entry) ? entry[0] : entry;
  return typeof spec === "string" && spec.startsWith(packageName);
}

function stripJsonc(text: string): string {
  return text
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/(^|[^:\\])\/\/.*$/gm, "$1");
}

function readState(stateFile: string): Record<string, string> {
  try {
    if (existsSync(stateFile)) {
      return JSON.parse(readFileSync(stateFile, "utf8")) as Record<
        string,
        string
      >;
    }
  } catch {
    // Corrupt state — empty so a re-sync repairs it.
  }
  return {};
}

function removeLegacyMarker(configDir: string): void {
  const legacy = path.join(configDir, LEGACY_MARKER);
  try {
    if (existsSync(legacy)) unlinkSync(legacy);
  } catch {
    // best effort
  }
}

function syncDir(src: string, dest: string, configDir: string): void {
  if (!existsSync(src)) return;
  mkdirSync(dest, { recursive: true });
  for (const entry of readdirSync(src)) {
    const srcPath = path.join(src, entry);
    const destPath = path.join(dest, entry);
    const stat = lstatSync(srcPath);

    if (stat.isSymbolicLink()) {
      // Dereference — defensive; dist files are real but repo sources symlink.
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
  // Preserve source mode: examples stay 0644, runtime libs 0755.
  chmodSync(dest, mode & 0o777);
}
