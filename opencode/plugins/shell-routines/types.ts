// Shared types for the shell-routines plugin.

// :::: Tool hook shapes :::: ///////////////////////////////

export type ShellToolInput = {
  tool: string;
  sessionID: string;
  callID: string;
  args: { file_path?: string; filePath?: string; [key: string]: unknown };
};

export type ShellToolOutput = {
  title: string;
  output: string;
  metadata: unknown;
};

// :::: Dialect classification :::: /////////////////////////

export type Dialect = "bash" | "dash" | "sh";

export type DialectResult = {
  dialect: Dialect;
  isPosix: boolean;
};
