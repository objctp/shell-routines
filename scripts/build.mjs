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
// Only the runtime libs (lib-*.sh) ship in dist/.
const DEV_SCRIPTS = new Set(["build.mjs", "changelog.sh"]);
const isRuntimeScript = (name) => !DEV_SCRIPTS.has(name);

// ── OpenCode npm package ────────────────────────────────
// dist/ is scope-agnostic. OpenCode installs components into
// .opencode/ (project) or ~/.config/opencode/ (global).

// Agents (OpenCode format)
mkdirSync(join(DIST, "agents"), { recursive: true });
for (const entry of readdirSync(join(ROOT, "opencode","agents"))) {
  copyDereferenced(
    join(ROOT, "opencode","agents", entry),
    join(DIST, "agents", entry),
  );
}

// Plugins (TypeScript)
mkdirSync(join(DIST, "plugins"), { recursive: true });
for (const entry of readdirSync(join(ROOT, "opencode","plugins"))) {
  copyDereferenced(
    join(ROOT, "opencode","plugins", entry),
    join(DIST, "plugins", entry),
  );
}

// Commands (symlinks → resolve to real files)
mkdirSync(join(DIST, "commands"), { recursive: true });
for (const entry of readdirSync(join(ROOT, "opencode","commands"))) {
  copyDereferenced(
    join(ROOT, "opencode","commands", entry),
    join(DIST, "commands", entry),
  );
}

// Skills (symlinks → resolve to real files)
mkdirSync(join(DIST, "skills"), { recursive: true });
for (const entry of readdirSync(join(ROOT, "opencode","skills"))) {
  copyDereferenced(
    join(ROOT, "opencode","skills", entry),
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
  exports: {
    // OpenCode's plugin loader resolves `./server` from the `exports` map to
    // discover the entrypoint. Without this, `opencode plugin install` reports
    // "does not expose plugin entrypoints or oc-themes in package.json".
    "./server": {
      import: "./plugins/shell-hooks.ts",
    },
  },
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

console.log("Build complete. Output in dist/");
