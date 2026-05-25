import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

/** Default subagent for goal turns (see pi-subagents agents/worker.md) */
export const DEFAULT_GOAL_SUBAGENT = "worker";

/**
 * Resolve pi-subagents package root (same install as settings.json npm:pi-subagents).
 */
export function resolvePiSubagentsRoot(): string | null {
  const candidates = [
    process.env.PI_SUBAGENTS_ROOT,
    process.env.PI_GOAL_SUBAGENTS_ROOT,
    join(
      homedir(),
      ".dotfiles/features/ai/pi/.pi/agent/npm/node_modules/pi-subagents"
    ),
  ].filter((p): p is string => Boolean(p));

  for (const candidate of candidates) {
    if (existsSync(join(candidate, "package.json"))) {
      return candidate;
    }
  }
  return null;
}

export function resolveGoalSubagentCwd(): string {
  return (
    process.env.PI_GOAL_SUBAGENT_CWD ??
    process.env.BEADS_MCP_CWD ??
    join(homedir(), ".dotfiles")
  );
}

export function resolvePiAgentDir(): string {
  return (
    process.env.PI_CODING_AGENT_DIR ??
    join(homedir(), ".dotfiles/features/ai/pi/.pi/agent")
  );
}

export function resolveGoalSubagentAgent(): string {
  return process.env.PI_GOAL_SUBAGENT_AGENT ?? DEFAULT_GOAL_SUBAGENT;
}

export function isSubagentExecutionDisabled(): boolean {
  return process.env.PI_GOAL_SUBAGENT_DISABLE === "1";
}

export function resolveSubagentArtifactsDir(): string {
  return (
    process.env.PI_GOAL_SUBAGENT_ARTIFACTS_DIR ??
    join(homedir(), ".pi/state/goal/subagent-artifacts")
  );
}
