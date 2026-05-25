/**
 * JudgeServiceLive - BDD Tests (mocked OpenRouter)
 */
import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { Effect } from "effect";
import { JudgeService } from "./JudgeService.js";
import { JudgeServiceLive } from "./JudgeServiceLive.js";
import { JudgeStatus } from "../models/JudgeResult.js";
import { Goal } from "../models/Goal.js";

const originalFetch = globalThis.fetch;

describe("JudgeServiceLive", () => {
  beforeEach(() => {
    process.env.OPENROUTER_API_KEY = "test-key";
    process.env.PI_JUDGE_MODEL = "openrouter/free";
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    delete process.env.OPENROUTER_API_KEY;
    delete process.env.PI_JUDGE_MODEL;
  });

  describe("Given a mocked OpenRouter JSON response", () => {
    it("When evaluating progress, Then parses status and confidence from the model", async () => {
      globalThis.fetch = (async () =>
        new Response(
          JSON.stringify({
            choices: [
              {
                message: {
                  content: JSON.stringify({
                    status: "COMPLETE",
                    confidence: 0.92,
                    reasoning: "All acceptance criteria met",
                    recommendations: ["Ship it"],
                  }),
                },
              },
            ],
          }),
          { status: 200 }
        )) as typeof fetch;

      const goal = new Goal({
        id: "goal-judge-live",
        objective: "Ship feature",
        createdAt: Date.now(),
        updatedAt: Date.now(),
        status: "active",
      });

      const program = Effect.gen(function* () {
        const service = yield* JudgeService;
        return yield* service.evaluateGoalProgress(
          goal,
          "Feature has been implemented and verified",
          3
        );
      });

      const result = await Effect.runPromise(
        program.pipe(Effect.provide(JudgeServiceLive))
      );

      expect(result.status).toBe(JudgeStatus.COMPLETE);
      expect(result.confidence).toBeCloseTo(0.92, 2);
      expect(result.turn).toBe(3);
      expect(result.reasoning).toContain("acceptance");
    });

    it("When OPENROUTER_API_KEY is missing, Then fails with a clear error", async () => {
      delete process.env.OPENROUTER_API_KEY;

      const goal = new Goal({
        id: "goal-no-key",
        objective: "Test",
        createdAt: Date.now(),
        updatedAt: Date.now(),
        status: "active",
      });

      const program = Effect.gen(function* () {
        const service = yield* JudgeService;
        return yield* service.evaluateGoalProgress(goal, "context", 1);
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(JudgeServiceLive)))
      ).rejects.toThrow(/OPENROUTER_API_KEY/);
    });
  });
});
