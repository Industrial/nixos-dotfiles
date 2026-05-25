/**
 * Integration: execute persists across MCP-style process boundaries (SQLite).
 */
import { describe, it, expect, afterAll } from "bun:test";
import { Effect } from "effect";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { MAX_GOAL_TURNS_LIFETIME } from "../../domain/execution/constants.js";

describe("ExecuteGoalCommand integration", () => {
  const dir = mkdtempSync(join(tmpdir(), "goal-plugin-"));
  const dbPath = join(dir, "test.db");

  afterAll(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("accumulates cumulative turns across separate Effect runs", async () => {
    const prev = process.env.PI_GOAL_DB_PATH;
    const prevSubagent = process.env.PI_GOAL_SUBAGENT_DISABLE;
    process.env.PI_GOAL_DB_PATH = dbPath;
    process.env.PI_GOAL_SUBAGENT_DISABLE = "1";

    const { GoalApplicationService } = await import("../../index.js");
    const { AppLayerIntegration } = await import("../../testing/AppLayerIntegration.js");

    try {
      const created = await Effect.runPromise(
        Effect.gen(function* () {
          const s = yield* GoalApplicationService;
          return yield* s.createGoal({ objective: "integration test" });
        }).pipe(Effect.provide(AppLayerIntegration))
      );

      const run1 = await Effect.runPromise(
        Effect.gen(function* () {
          const s = yield* GoalApplicationService;
          return yield* s.executeGoal(created.id, { maxTurns: 1 });
        }).pipe(Effect.provide(AppLayerIntegration))
      );

      const run2 = await Effect.runPromise(
        Effect.gen(function* () {
          const s = yield* GoalApplicationService;
          return yield* s.executeGoal(created.id, { maxTurns: 1 });
        }).pipe(Effect.provide(AppLayerIntegration))
      );

      expect(run1.cumulativeTurn).toBe(1);
      expect(run2.cumulativeTurn).toBe(2);
      expect(run2.nextPrompt).toBeDefined();
    } finally {
      if (prev === undefined) delete process.env.PI_GOAL_DB_PATH;
      else process.env.PI_GOAL_DB_PATH = prev;
      if (prevSubagent === undefined) delete process.env.PI_GOAL_SUBAGENT_DISABLE;
      else process.env.PI_GOAL_SUBAGENT_DISABLE = prevSubagent;
    }
  });

  it("When cumulative turns reach lifetime cap in SQLite, Then next execute fails", async () => {
    const prev = process.env.PI_GOAL_DB_PATH;
    const prevSubagent = process.env.PI_GOAL_SUBAGENT_DISABLE;
    const budgetDb = join(dir, "budget.db");
    process.env.PI_GOAL_DB_PATH = budgetDb;
    process.env.PI_GOAL_SUBAGENT_DISABLE = "1";

    const { GoalApplicationService } = await import("../../index.js");
    const { AppLayerIntegration } = await import("../../testing/AppLayerIntegration.js");
    const { GoalExecutionRepository, initialCheckpoint } = await import(
      "../../domain/repositories/GoalExecutionRepository.js"
    );

    try {
      const created = await Effect.runPromise(
        Effect.gen(function* () {
          const s = yield* GoalApplicationService;
          return yield* s.createGoal({ objective: "lifetime budget" });
        }).pipe(Effect.provide(AppLayerIntegration))
      );

      await Effect.runPromise(
        Effect.gen(function* () {
          const executions = yield* GoalExecutionRepository;
          yield* executions.upsert({
            ...initialCheckpoint(created.id),
            cumulativeTurn: MAX_GOAL_TURNS_LIFETIME,
          });
        }).pipe(Effect.provide(AppLayerIntegration))
      );

      await expect(
        Effect.runPromise(
          Effect.gen(function* () {
            const s = yield* GoalApplicationService;
            return yield* s.executeGoal(created.id, { maxTurns: 1 });
          }).pipe(Effect.provide(AppLayerIntegration))
        )
      ).rejects.toThrow(/turn budget exhausted/i);
    } finally {
      if (prev === undefined) delete process.env.PI_GOAL_DB_PATH;
      else process.env.PI_GOAL_DB_PATH = prev;
      if (prevSubagent === undefined) delete process.env.PI_GOAL_SUBAGENT_DISABLE;
      else process.env.PI_GOAL_SUBAGENT_DISABLE = prevSubagent;
    }
  });
});
