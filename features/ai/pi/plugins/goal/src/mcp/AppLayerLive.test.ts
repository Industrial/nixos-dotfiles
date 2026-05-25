/**
 * Regression: AppLayerLive must satisfy all services for read-only MCP tools (e.g. goal_list).
 * Unit tests use AppLayerMock; integration tests use AgentTurnExecutorLive — neither matches MCP.
 */
import { describe, it, expect, afterAll } from "bun:test";
import { Effect } from "effect";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

describe("AppLayerLive (MCP production wiring)", () => {
  const dir = mkdtempSync(join(tmpdir(), "goal-applayer-"));
  const dbPath = join(dir, "mcp.db");

  afterAll(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("When listing goals with default subagent layer, Then succeeds without PromptGeneratorService error", async () => {
    const prevDb = process.env.PI_GOAL_DB_PATH;
    const prevDisable = process.env.PI_GOAL_SUBAGENT_DISABLE;
    process.env.PI_GOAL_DB_PATH = dbPath;
    delete process.env.PI_GOAL_SUBAGENT_DISABLE;

    const { AppLayerLive, GoalApplicationService } = await import("../index.js");

    try {
      const goals = await Effect.runPromise(
        Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.listGoals({});
        }).pipe(Effect.provide(AppLayerLive))
      );

      expect(Array.isArray(goals)).toBe(true);
    } finally {
      if (prevDb === undefined) delete process.env.PI_GOAL_DB_PATH;
      else process.env.PI_GOAL_DB_PATH = prevDb;
      if (prevDisable === undefined) delete process.env.PI_GOAL_SUBAGENT_DISABLE;
      else process.env.PI_GOAL_SUBAGENT_DISABLE = prevDisable;
    }
  });
});
