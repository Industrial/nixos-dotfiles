/**
 * PromptGeneratorService - BDD Tests
 *
 * Tests for context-aware prompt generation for goal execution.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { PromptGeneratorService } from "./PromptGeneratorService.js";
import { PromptGeneratorServiceMock } from "./PromptGeneratorServiceMock.js";
import { Goal } from "../models/Goal.js";
import { createContinuationContext } from "../models/ContinuationContext.js";
import { JudgeResult, JudgeStatus } from "../models/JudgeResult.js";

describe("PromptGeneratorService", () => {
  const TestLayer = PromptGeneratorServiceMock;

  describe("generateInitialPrompt", () => {
    describe("Given a goal with objective", () => {
      it("When generating initial prompt, Then includes goal objective", async () => {
        const goal = new Goal({
          id: "goal-123",
          objective: "Build a REST API",
          status: "active" as const,
          createdAt: Date.now(),
          updatedAt: Date.now(),
        });

        const program = Effect.gen(function* () {
          const service = yield* PromptGeneratorService;
          return yield* service.generateInitialPrompt(goal);
        });

        const prompt = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(prompt).toContain("Build a REST API");
        expect(prompt.length).toBeGreaterThan(0);
      });

      it("When generating initial prompt with context, Then includes context", async () => {
        const goal = new Goal({
          id: "goal-456",
          objective: "Refactor authentication module",
          context: "Current auth uses JWT, needs OAuth2",
          status: "active" as const,
          createdAt: Date.now(),
          updatedAt: Date.now(),
        });

        const program = Effect.gen(function* () {
          const service = yield* PromptGeneratorService;
          return yield* service.generateInitialPrompt(goal);
        });

        const prompt = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(prompt).toContain("Refactor authentication module");
        expect(prompt).toContain("OAuth2");
      });
    });

    describe("Given a goal without context", () => {
      it("When generating initial prompt, Then generates valid prompt", async () => {
        const goal = new Goal({
          id: "goal-789",
          objective: "Simple task",
          status: "active" as const,
          createdAt: Date.now(),
          updatedAt: Date.now(),
        });

        const program = Effect.gen(function* () {
          const service = yield* PromptGeneratorService;
          return yield* service.generateInitialPrompt(goal);
        });

        const prompt = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(prompt).toContain("Simple task");
        expect(prompt.length).toBeGreaterThan(0);
      });
    });
  });

  describe("generateContinuationPrompt", () => {
    describe("Given a continuation context with history", () => {
      it("When generating continuation prompt, Then includes previous output", async () => {
        const goal = new Goal({
          id: "goal-123",
          objective: "Build API",
          status: "active" as const,
          createdAt: Date.now(),
          updatedAt: Date.now(),
        });

        const context = createContinuationContext(goal)
          .recordTurnOutput("Created basic API structure");

        const program = Effect.gen(function* () {
          const service = yield* PromptGeneratorService;
          return yield* service.generateContinuationPrompt(context);
        });

        const prompt = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(prompt).toContain("Build API");
        expect(prompt).toContain("Created basic API structure");
      });

      it("When generating continuation prompt with judge feedback, Then includes recommendations", async () => {
        const goal = new Goal({
          id: "goal-456",
          objective: "Test goal",
          status: "active" as const,
          createdAt: Date.now(),
          updatedAt: Date.now(),
        });

        const judgeEval = new JudgeResult({
          status: JudgeStatus.IN_PROGRESS,
          confidence: 0.7,
          reasoning: "Good progress",
          recommendations: ["Add error handling", "Write tests"],
          goalId: "goal-456",
          turn: 1,
          timestamp: Date.now(),
        });

        const context = createContinuationContext(goal)
          .recordTurnOutput("Implemented feature")
          .recordJudgeEvaluation(judgeEval);

        const program = Effect.gen(function* () {
          const service = yield* PromptGeneratorService;
          return yield* service.generateContinuationPrompt(context);
        });

        const prompt = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(prompt).toContain("error handling");
        expect(prompt).toContain("tests");
      });

      it("When generating continuation prompt with multiple turns, Then summarizes history", async () => {
        const goal = new Goal({
          id: "goal-789",
          objective: "Complex task",
          status: "active" as const,
          createdAt: Date.now(),
          updatedAt: Date.now(),
        });

        let context = createContinuationContext(goal);
        for (let i = 1; i <= 5; i++) {
          context = context.recordTurnOutput(`Turn ${i} output`);
        }

        const program = Effect.gen(function* () {
          const service = yield* PromptGeneratorService;
          return yield* service.generateContinuationPrompt(context);
        });

        const prompt = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(prompt).toContain("Complex task");
        expect(prompt.length).toBeGreaterThan(0);
      });
    });
  });

  describe("generateRecoveryPrompt", () => {
    describe("Given a blocked goal", () => {
      it("When generating recovery prompt, Then includes blockers", async () => {
        const goal = new Goal({
          id: "goal-blocked",
          objective: "Deploy application",
          status: "active" as const,
          createdAt: Date.now(),
          updatedAt: Date.now(),
        });

        const judgeEval = new JudgeResult({
          status: JudgeStatus.BLOCKED,
          confidence: 0.85,
          reasoning: "Missing deployment credentials",
          recommendations: ["Request credentials", "Setup deployment pipeline"],
          goalId: "goal-blocked",
          turn: 2,
          timestamp: Date.now(),
        });

        const context = createContinuationContext(goal)
          .recordTurnOutput("Attempted deployment")
          .recordJudgeEvaluation(judgeEval);

        const program = Effect.gen(function* () {
          const service = yield* PromptGeneratorService;
          return yield* service.generateRecoveryPrompt(context);
        });

        const prompt = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(prompt).toContain("blocked");
        expect(prompt).toContain("credentials");
      });
    });
  });

  describe("generateCompletionPrompt", () => {
    describe("Given a potentially complete goal", () => {
      it("When generating completion prompt, Then asks for verification", async () => {
        const goal = new Goal({
          id: "goal-complete",
          objective: "Write documentation",
          status: "active" as const,
          createdAt: Date.now(),
          updatedAt: Date.now(),
        });

        const context = createContinuationContext(goal)
          .recordTurnOutput("Documentation completed");

        const program = Effect.gen(function* () {
          const service = yield* PromptGeneratorService;
          return yield* service.generateCompletionPrompt(context);
        });

        const prompt = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(prompt).toContain("Write documentation");
        expect(prompt.toLowerCase()).toMatch(/verif|complete|done/);
      });
    });
  });

  describe("Prompt coherence", () => {
    it("When generating multiple prompts for same goal, Then maintains context coherence", async () => {
      const goal = new Goal({
        id: "goal-coherence",
        objective: "Coherence test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const program = Effect.gen(function* () {
        const service = yield* PromptGeneratorService;

        const initial = yield* service.generateInitialPrompt(goal);

        const context1 = createContinuationContext(goal)
          .recordTurnOutput("First output");
        const continuation1 = yield* service.generateContinuationPrompt(context1);

        const context2 = context1.recordTurnOutput("Second output");
        const continuation2 = yield* service.generateContinuationPrompt(context2);

        return { initial, continuation1, continuation2 };
      });

      const { initial, continuation1, continuation2 } = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      // All prompts should reference the goal objective
      expect(initial).toContain("Coherence test");
      expect(continuation1).toContain("Coherence test");
      expect(continuation2).toContain("Coherence test");
    });
  });
});
