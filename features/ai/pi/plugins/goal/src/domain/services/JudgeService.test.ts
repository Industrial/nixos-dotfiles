/**
 * JudgeService - BDD Tests
 *
 * Tests for LLM-as-Judge evaluation service.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { JudgeService } from "./JudgeService.js";
import { JudgeServiceMock } from "./JudgeServiceMock.js";
import { JudgeStatus } from "../models/JudgeResult.js";
import { Goal } from "../models/Goal.js";

describe("JudgeService", () => {
  const TestLayer = JudgeServiceMock;

  describe("evaluateGoalProgress", () => {
    describe("Given a goal with clear completion criteria", () => {
      it("When evaluating completed goal, Then returns COMPLETE status", async () => {
        const goal = new Goal({
          id: "goal-123",
          objective: "Create a test file",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;
          return yield* service.evaluateGoalProgress(
            goal,
            "Test file has been created successfully",
            1
          );
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.status).toBe(JudgeStatus.COMPLETE);
        expect(result.goalId).toBe("goal-123");
        expect(result.turn).toBe(1);
        expect(result.isComplete()).toBe(true);
      });

      it("When evaluating in-progress goal, Then returns IN_PROGRESS status", async () => {
        const goal = new Goal({
          id: "goal-456",
          objective: "Build a complex feature",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;
          return yield* service.evaluateGoalProgress(
            goal,
            "Started implementation but not complete",
            3
          );
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.status).toBe(JudgeStatus.IN_PROGRESS);
        expect(result.shouldContinue()).toBe(true);
        expect(result.turn).toBe(3);
      });

      it("When evaluating blocked goal, Then returns BLOCKED status", async () => {
        const goal = new Goal({
          id: "goal-789",
          objective: "Deploy application",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;
          return yield* service.evaluateGoalProgress(
            goal,
            "Missing deployment credentials",
            2
          );
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.status).toBe(JudgeStatus.BLOCKED);
        expect(result.shouldContinue()).toBe(false);
        expect(result.recommendations.length).toBeGreaterThan(0);
      });

      it("When evaluating failed goal, Then returns FAILED status", async () => {
        const goal = new Goal({
          id: "goal-999",
          objective: "Impossible task",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;
          return yield* service.evaluateGoalProgress(
            goal,
            "Approach is fundamentally flawed",
            10
          );
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.status).toBe(JudgeStatus.FAILED);
        expect(result.isTerminal()).toBe(true);
      });
    });

    describe("Judge result properties", () => {
      it("When judge evaluates, Then result includes confidence score", async () => {
        const goal = new Goal({
          id: "goal-123",
          objective: "Test objective",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;
          return yield* service.evaluateGoalProgress(
            goal,
            "Making good progress",
            1
          );
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.confidence).toBeGreaterThanOrEqual(0);
        expect(result.confidence).toBeLessThanOrEqual(1);
      });

      it("When judge evaluates, Then result includes reasoning", async () => {
        const goal = new Goal({
          id: "goal-123",
          objective: "Test objective",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;
          return yield* service.evaluateGoalProgress(
            goal,
            "Some context",
            1
          );
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.reasoning).toBeDefined();
        expect(result.reasoning.length).toBeGreaterThan(0);
      });

      it("When judge evaluates, Then result includes recommendations", async () => {
        const goal = new Goal({
          id: "goal-123",
          objective: "Test objective",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;
          return yield* service.evaluateGoalProgress(
            goal,
            "Context",
            1
          );
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.recommendations).toBeDefined();
        expect(Array.isArray(result.recommendations)).toBe(true);
      });

      it("When judge evaluates, Then result includes timestamp", async () => {
        const goal = new Goal({
          id: "goal-123",
          objective: "Test objective",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const before = Date.now();

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;
          return yield* service.evaluateGoalProgress(goal, "Context", 1);
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        const after = Date.now();

        expect(result.timestamp).toBeGreaterThanOrEqual(before);
        expect(result.timestamp).toBeLessThanOrEqual(after);
      });
    });

    describe("Multiple evaluations", () => {
      it("When evaluating same goal multiple times, Then results track turn progression", async () => {
        const goal = new Goal({
          id: "goal-multi",
          objective: "Multi-turn objective",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;

          const result1 = yield* service.evaluateGoalProgress(
            goal,
            "Turn 1 context",
            1
          );
          const result2 = yield* service.evaluateGoalProgress(
            goal,
            "Turn 2 context",
            2
          );
          const result3 = yield* service.evaluateGoalProgress(
            goal,
            "Turn 3 context",
            3
          );

          return { result1, result2, result3 };
        });

        const { result1, result2, result3 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result1.turn).toBe(1);
        expect(result2.turn).toBe(2);
        expect(result3.turn).toBe(3);
      });

      it("When evaluating different goals, Then results are independent", async () => {
        const goal1 = new Goal({
          id: "goal-a",
          objective: "First goal",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const goal2 = new Goal({
          id: "goal-b",
          objective: "Second goal",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;

          const result1 = yield* service.evaluateGoalProgress(
            goal1,
            "Context A",
            1
          );
          const result2 = yield* service.evaluateGoalProgress(
            goal2,
            "Context B",
            1
          );

          return { result1, result2 };
        });

        const { result1, result2 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result1.goalId).toBe("goal-a");
        expect(result2.goalId).toBe("goal-b");
        expect(result1.goalId).not.toBe(result2.goalId);
      });
    });

    describe("Edge cases", () => {
      it("When evaluating with empty context, Then still returns valid result", async () => {
        const goal = new Goal({
          id: "goal-empty",
          objective: "Test with empty context",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;
          return yield* service.evaluateGoalProgress(goal, "", 1);
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result).toBeDefined();
        expect(result.status).toBeDefined();
        expect(result.reasoning.length).toBeGreaterThan(0);
      });

      it("When evaluating at turn 0, Then result is valid", async () => {
        const goal = new Goal({
          id: "goal-zero",
          objective: "Initial evaluation",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;
          return yield* service.evaluateGoalProgress(
            goal,
            "Initial state",
            0
          );
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.turn).toBe(0);
        expect(result).toBeDefined();
      });

      it("When evaluating with very long context, Then returns valid result", async () => {
        const goal = new Goal({
          id: "goal-long",
          objective: "Test with long context",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          status: "active" as const,
        });

        const longContext = "x".repeat(10000);

        const program = Effect.gen(function* () {
          const service = yield* JudgeService;
          return yield* service.evaluateGoalProgress(goal, longContext, 1);
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result).toBeDefined();
        expect(result.status).toBeDefined();
      });
    });
  });
});
