import type { DialectResult } from "./types";

// :::: Shell classification :::: ///////////////////////////

const SHELL_EXTENSIONS = new Set(["sh", "bash", "zsh", "ksh"]);
const SHEBANG_PATTERN = /^#!.*\b(bash|sh|zsh|ksh)\b/;
const DASH_PATTERN = /#!.*\bdash\b/;
const SH_ONLY_PATTERN = /#!.*\bsh\b/;
const BASH_FAMILY_PATTERN = /#!.*\b(bash|zsh|ksh)\b/;

/** A shell file if the extension matches or the shebang names a shell. */
export function isShellFile(ext: string, firstLine: string): boolean {
  return SHELL_EXTENSIONS.has(ext) || SHEBANG_PATTERN.test(firstLine);
}

/** Classify the shell dialect from the shebang. Defaults to bash. */
export function detectDialect(firstLine: string): DialectResult {
  if (DASH_PATTERN.test(firstLine)) {
    return { dialect: "dash", isPosix: true };
  }
  if (SH_ONLY_PATTERN.test(firstLine) && !BASH_FAMILY_PATTERN.test(firstLine)) {
    return { dialect: "sh", isPosix: true };
  }
  return { dialect: "bash", isPosix: false };
}
