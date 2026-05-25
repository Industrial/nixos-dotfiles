/**
 * Smoke tests — real OpenRouter `openrouter/free` (gated by env).
 *
 * Run: OPENROUTER_API_KEY=... GOAL_SMOKE_TEST=1 bun test src/goal.smoke.test.ts
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { JudgeService } from "./domain/services/JudgeService.js";
import { JudgeServiceLive } from "./domain/services/JudgeServiceLive.js";
import { Goal } from "./domain/models/Goal.js";
import { JudgeStatus } from "./domain/models/JudgeResult.js";

const smokeEnabled =
  process.env.GOAL_SMOKE_TEST === "1" && Boolean(process.env.OPENROUTER_API_KEY);

describe("Goal plugin smoke (openrouter/free)", () => {
  it("JudgeServiceLive evaluates via openrouter/free", async () => {
    if (!smokeEnabled) {
      console.warn(
        "Skipping smoke: set GOAL_SMOKE_TEST=1 and OPENROUTER_API_KEY"
      );
      return;
    }

    process.env.PI_JUDGE_MODEL = "openrouter/free";

    const goal = new Goal({
      id: "goal-smoke",
      objective: "Reply with a one-word acknowledgment only",
      createdAt: Date.now(),
      updatedAt: Date.now(),
      status: "active",
    });

    const program = Effect.gen(function* () {
      const service = yield* JudgeService;
      return yield* service.evaluateGoalProgress(
        goal,
        "The agent replied: acknowledged",
        1
      );
    });

    const result = await Effect.runPromise(
      program.pipe(Effect.provide(JudgeServiceLive))
    );

    expect(result.goalId).toBe("goal-smoke");
    expect(result.confidence).toBeGreaterThanOrEqual(0);
    expect(result.confidence).toBeLessThanOrEqual(1);
    expect(Object.values(JudgeStatus)).toContain(result.status);
    expect(result.reasoning.length).toBeGreaterThan(0);
  }, 120_000);
});
