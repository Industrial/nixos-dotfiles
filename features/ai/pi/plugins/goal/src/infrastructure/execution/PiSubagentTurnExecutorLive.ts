/**
 * Runs one goal turn via pi-subagents (worker/oracle/etc.) by spawning the bridge CLI.
 */
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Effect, Layer } from "effect";
import { AgentExecutionPort } from "../../domain/ports/AgentExecutionPort.js";
import { TurnOutput } from "../../domain/models/TurnOutput.js";
import { ToolResult } from "../../domain/models/ToolResult.js";
import { PromptGeneratorService } from "../../domain/services/PromptGeneratorService.js";
import {
  isSubagentExecutionDisabled,
  resolveGoalSubagentAgent,
  resolveGoalSubagentCwd,
  resolvePiAgentDir,
  resolvePiSubagentsRoot,
  resolveSubagentArtifactsDir,
} from "./piSubagentsConfig.js";

function defaultBridgeScript(): string {
  const pluginRoot =
    process.env.PI_MCP_GOAL_PLUGIN_ROOT ??
    join(homedir(), ".dotfiles/features/ai/pi/plugins/goal");
  const piRoot = join(dirname(dirname(pluginRoot)));
  return join(piRoot, "bin/pi-goal-subagent-run");
}

interface BridgeOutput {
  text: string;
  exitCode: number;
  error?: string;
  finalOutput?: string;
  toolCalls?: number;
  artifactOutputPath?: string;
  delegated: boolean;
}

function resolveBridgeScript(): string {
  const fromEnv = process.env.PI_GOAL_SUBAGENT_BRIDGE;
  if (fromEnv && existsSync(fromEnv)) return fromEnv;
  const candidate = defaultBridgeScript();
  if (existsSync(candidate)) return candidate;
  return join(
    dirname(fileURLToPath(import.meta.url)),
    "../../../../../bin/pi-goal-subagent-run"
  );
}

async function runSubagentBridge(input: {
  task: string;
  cwd: string;
  agent: string;
  runId: string;
  goalId: string;
  turn: number;
}): Promise<BridgeOutput> {
  const piSubagentsRoot = resolvePiSubagentsRoot();
  if (!piSubagentsRoot) {
    throw new Error(
      "pi-subagents not found. Install via settings.json packages (npm:pi-subagents) or set PI_SUBAGENTS_ROOT."
    );
  }

  const bridgeScript = resolveBridgeScript();
  if (!existsSync(bridgeScript)) {
    throw new Error(`pi-goal-subagent-run bridge not found at ${bridgeScript}`);
  }

  const payload = {
    ...input,
    piSubagentsRoot,
    piAgentDir: resolvePiAgentDir(),
    artifactsDir: resolveSubagentArtifactsDir(),
  };

  const proc = Bun.spawn(["bun", bridgeScript], {
    stdin: Buffer.from(JSON.stringify(payload)),
    stdout: "pipe",
    stderr: "pipe",
    cwd: input.cwd,
    env: {
      ...process.env,
      PI_CODING_AGENT_DIR: resolvePiAgentDir(),
    },
  });

  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);

  if (!stdout.trim()) {
    throw new Error(
      `pi-goal-subagent-run produced no output (exit ${exitCode}): ${stderr.slice(0, 500)}`
    );
  }

  let parsed: BridgeOutput;
  try {
    parsed = JSON.parse(stdout) as BridgeOutput;
  } catch {
    throw new Error(
      `Invalid bridge JSON (exit ${exitCode}): ${stdout.slice(0, 300)}`
    );
  }

  if (exitCode !== 0 && !parsed.error) {
    parsed.error = stderr.trim() || `Bridge exited with code ${exitCode}`;
  }

  return parsed;
}

export const PiSubagentTurnExecutorLive = Layer.effect(
  AgentExecutionPort,
  Effect.succeed({
    runTurn: (input) =>
      Effect.gen(function* () {
        if (isSubagentExecutionDisabled()) {
          return yield* Effect.fail(
            new Error("Subagent execution disabled (PI_GOAL_SUBAGENT_DISABLE=1)")
          );
        }

        const prompts = yield* PromptGeneratorService;
        const prompt =
          input.turn <= 1
            ? yield* prompts.generateInitialPrompt(input.goal)
            : yield* prompts.generateContinuationPrompt(input.continuation);

        const task = [
          `You are executing turn ${input.turn} of a persisted Pi goal.`,
          "",
          `Goal objective: ${input.goal.objective}`,
          input.goal.context ? `Goal context: ${input.goal.context}` : "",
          "",
          prompt,
        ]
          .filter(Boolean)
          .join("\n");

        const cwd = resolveGoalSubagentCwd();
        const agent = resolveGoalSubagentAgent();
        const runId = `goal-${input.goal.id}-t${input.turn}`;

        const bridge = yield* Effect.tryPromise({
          try: () =>
            runSubagentBridge({
              task,
              cwd,
              agent,
              runId,
              goalId: input.goal.id,
              turn: input.turn,
            }),
          catch: (e) =>
            e instanceof Error ? e : new Error(String(e)),
        });

        const toolResults: ToolResult[] = [];
        if (bridge.toolCalls && bridge.toolCalls > 0) {
          toolResults.push(
            new ToolResult({
              toolName: "pi-subagent",
              success: bridge.exitCode === 0,
              output: `Subagent (${agent}) completed ${bridge.toolCalls} tool call(s)`,
              executionTimeMs: 0,
              timestamp: Date.now(),
              metadata: { agent, runId },
            })
          );
        }

        return new TurnOutput({
          text: bridge.text,
          toolResults,
          nextPrompt: prompt,
          delegated: bridge.delegated && bridge.exitCode === 0,
        });
      }),
  })
);
