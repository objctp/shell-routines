import {
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  readlinkSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import process from "node:process";

const ROOT = resolve(import.meta.dirname, "..");
const DIST = join(ROOT, "dist");

// Clean dist
if (existsSync(DIST)) {
  rmSync(DIST, { recursive: true });
}
mkdirSync(DIST, { recursive: true });

// Recursive copy that resolves symlinks into real files
function copyDereferenced(src, dest) {
  const stat = lstatSync(src);

  if (stat.isSymbolicLink()) {
    const realPath = resolve(dirname(src), readlinkSync(src));
    copyDereferenced(realPath, dest);
    return;
  }

  if (stat.isDirectory()) {
    mkdirSync(dest, { recursive: true });
    for (const entry of readdirSync(src)) {
      copyDereferenced(join(src, entry), join(dest, entry));
    }
    return;
  }

  cpSync(src, dest);
}

// Dev/build tooling that lives in scripts/ but is not consumer-facing.
// Only the runtime libs (lib-*.sh) ship in dist/ and the OCX registry.
const DEV_SCRIPTS = new Set(["build.mjs", "changelog.sh"]);
const isRuntimeScript = (name) => !DEV_SCRIPTS.has(name);

// ── OpenCode npm package ────────────────────────────────
// dist/ is scope-agnostic. OpenCode installs components into
// .opencode/ (project) or ~/.config/opencode/ (global).

// Agents (OpenCode format)
mkdirSync(join(DIST, "agents"), { recursive: true });
for (const entry of readdirSync(join(ROOT, ".opencode", "agents"))) {
  copyDereferenced(
    join(ROOT, ".opencode", "agents", entry),
    join(DIST, "agents", entry),
  );
}

// Plugins (TypeScript)
mkdirSync(join(DIST, "plugins"), { recursive: true });
for (const entry of readdirSync(join(ROOT, ".opencode", "plugins"))) {
  copyDereferenced(
    join(ROOT, ".opencode", "plugins", entry),
    join(DIST, "plugins", entry),
  );
}

// Commands (symlinks → resolve to real files)
mkdirSync(join(DIST, "commands"), { recursive: true });
for (const entry of readdirSync(join(ROOT, ".opencode", "commands"))) {
  copyDereferenced(
    join(ROOT, ".opencode", "commands", entry),
    join(DIST, "commands", entry),
  );
}

// Skills (symlinks → resolve to real files)
mkdirSync(join(DIST, "skills"), { recursive: true });
for (const entry of readdirSync(join(ROOT, ".opencode", "skills"))) {
  copyDereferenced(
    join(ROOT, ".opencode", "skills", entry),
    join(DIST, "skills", entry),
  );
}

// Scripts (shared libraries referenced by skills)
mkdirSync(join(DIST, "scripts"), { recursive: true });
for (const f of readdirSync(join(ROOT, "scripts")).filter(isRuntimeScript)) {
  copyDereferenced(
    join(ROOT, "scripts", f),
    join(DIST, "scripts", f),
  );
}

// Copy config and docs
cpSync(join(ROOT, "opencode.json"), join(DIST, "opencode.json"));
cpSync(join(ROOT, "README.md"), join(DIST, "README.md"));
cpSync(join(ROOT, "LICENSE"), join(DIST, "LICENSE"));

// Generate npm package.json for dist/ (not a copy of root)
const rootPkg = JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8"));
const distPkg = {
  name: rootPkg.name,
  version: rootPkg.version,
  description: rootPkg.description,
  author: rootPkg.author,
  homepage: rootPkg.homepage,
  repository: rootPkg.repository,
  license: rootPkg.license,
  keywords: rootPkg.keywords,
  files: [
    "agents/",
    "commands/",
    "plugins/",
    "skills/",
    "scripts/",
    "opencode.json",
    "README.md",
    "LICENSE",
  ],
};
writeFileSync(
  join(DIST, "package.json"),
  JSON.stringify(distPkg, null, 2) + "\n",
);

// ── Registry sync ────────────────────────────────────────
// Populates registry/files/ from source for OCX distribution.
// File paths in registry.jsonc are relative to registry/files/.

const REGISTRY_FILES = join(ROOT, "registry", "files");
const registryOnly = process.argv.includes("--registry-only");

function syncRegistry() {
  // Clean registry/files/
  if (existsSync(REGISTRY_FILES)) {
    rmSync(REGISTRY_FILES, { recursive: true });
  }

  // Plugin
  copyDereferenced(
    join(ROOT, ".opencode", "plugins", "shell-hooks.ts"),
    join(REGISTRY_FILES, "plugins", "shell-hooks.ts"),
  );

  // Agents (OpenCode format from .opencode/agents/)
  for (const f of readdirSync(join(ROOT, ".opencode", "agents"))) {
    copyDereferenced(
      join(ROOT, ".opencode", "agents", f),
      join(REGISTRY_FILES, "agents", f),
    );
  }

  // Commands
  for (const f of readdirSync(join(ROOT, "commands"))) {
    copyDereferenced(
      join(ROOT, "commands", f),
      join(REGISTRY_FILES, "commands", f),
    );
  }

  // Skills (each is a directory)
  for (const skill of readdirSync(join(ROOT, "skills"))) {
    copyDereferenced(
      join(ROOT, "skills", skill),
      join(REGISTRY_FILES, "skills", skill),
    );
  }

  // Shared scripts
  for (const f of readdirSync(join(ROOT, "scripts")).filter(isRuntimeScript)) {
    copyDereferenced(
      join(ROOT, "scripts", f),
      join(REGISTRY_FILES, "scripts", f),
    );
  }

  const count = countFiles(REGISTRY_FILES);
  console.log(`Registry synced: ${count} files in registry/files/`);
}

function countFiles(dir) {
  let n = 0;
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    const s = lstatSync(p);
    if (s.isDirectory()) n += countFiles(p);
    else n++;
  }
  return n;
}

if (registryOnly) {
  syncRegistry();
} else {
  console.log("Build complete. Output in dist/");
  syncRegistry();
}
