/**
 * ExecuteGoalCommand - BDD Tests
 *
 * Tests for executing goals in a continuation loop with error handling.
 */
import { describe, it, expect } from "bun:test";
import { Effect, Layer } from "effect";
import { ExecuteGoalCommand, executeGoalHandler } from "./ExecuteGoalCommand.js";
import { CreateGoalCommand, createGoalHandler } from "./CreateGoalCommand.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { GoalLifecycleServiceLive } from "../../domain/services/GoalLifecycleServiceLive.js";
import { JudgeServiceMock } from "../../domain/services/JudgeServiceMock.js";
import { GoalRepositoryMock } from "../../infrastructure/persistence/GoalRepositoryMock.js";

describe("ExecuteGoalCommand", () => {
  const TestLayer = GoalLifecycleServiceLive.pipe(
    Layer.provide(GoalRepositoryMock)
  )
    .pipe(Layer.merge(GoalRepositoryMock))
    .pipe(Layer.merge(JudgeServiceMock));

  describe("Schema Validation", () => {
    describe("Given valid command input", () => {
      it("When creating command with goal ID, Then command is created", () => {
        const command = new ExecuteGoalCommand({
          goalId: "goal-123",
        });

        expect(command.goalId).toBe("goal-123");
      });

      it("When creating command with custom max turns, Then max turns is set", () => {
        const command = new ExecuteGoalCommand({
          goalId: "goal-123",
          maxTurns: 10,
        });

        expect(command.maxTurns).toBe(10);
      });

      it("When creating command without max turns, Then uses default", () => {
        const command = new ExecuteGoalCommand({
          goalId: "goal-123",
        });

        expect(command.maxTurns).toBeUndefined(); // Handler will use default
      });
    });

    describe("Given invalid command input", () => {
      it("When creating command without goal ID, Then validation fails", () => {
        expect(() => {
          new ExecuteGoalCommand({} as any);
        }).toThrow();
      });

      it("When creating command with empty goal ID, Then validation fails", () => {
        expect(() => {
          new ExecuteGoalCommand({
            goalId: "",
          });
        }).toThrow();
      });
    });
  });

  describe("Command Handler Execution", () => {
    describe("Given an active goal exists", () => {
      it("When executing goal, Then execution context is created", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: goal.id,
              maxTurns: 1,
            })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.context).toBeDefined();
        expect(result.context.goalId).toBeDefined();
        expect(result.context.maxTurns).toBe(1);
      });

      it("When executing goal with immediate completion, Then completes successfully", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          // Execute with very small turn limit for testing
          return yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: goal.id,
              maxTurns: 1,
            })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.success).toBe(true);
        expect(result.context.isComplete).toBe(true);
      });

      it("When executing goal, Then context tracks turns", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: goal.id,
              maxTurns: 3,
            })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.context.currentTurn).toBeGreaterThan(0);
        expect(result.context.currentTurn).toBeLessThanOrEqual(3);
      });
    });

    describe("Given goal does not exist", () => {
      it("When executing nonexistent goal, Then error is thrown", async () => {
        const program = Effect.gen(function* () {
          return yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: "nonexistent",
            })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Goal not found/);
      });
    });

    describe("Given goal in terminal state", () => {
      it("When executing completed goal, Then error is thrown", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.completeGoal(goal.id);

          return yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: goal.id,
            })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Cannot execute goal in terminal state/);
      });

      it("When executing cancelled goal, Then error is thrown", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.cancelGoal(goal.id);

          return yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: goal.id,
            })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Cannot execute goal in terminal state/);
      });
    });

    describe("Turn limit handling", () => {
      it("When turn limit is reached, Then execution stops", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: goal.id,
              maxTurns: 5,
            })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.context.hasReachedLimit()).toBe(true);
        expect(result.success).toBe(true); // Reaching limit is not a failure
      });

      it("When custom max turns is set, Then respects limit", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: goal.id,
              maxTurns: 2,
            })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.context.maxTurns).toBe(2);
        expect(result.context.currentTurn).toBeLessThanOrEqual(2);
      });
    });

    describe("Execution result", () => {
      it("When execution completes, Then result contains context and success flag", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: goal.id,
              maxTurns: 1,
            })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result).toHaveProperty("success");
        expect(result).toHaveProperty("context");
        expect(result).toHaveProperty("goalId");
        expect(typeof result.success).toBe("boolean");
      });

      it("When execution completes, Then goal ID matches", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const executionResult = yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: goal.id,
              maxTurns: 1,
            })
          );

          return { goalId: goal.id, executionResult };
        });

        const { goalId, executionResult } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(executionResult.goalId).toBe(goalId);
      });
    });

    describe("Judge integration", () => {
      it("When executing goal, Then judge evaluations are recorded", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: goal.id,
              maxTurns: 3,
            })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.context.judgeEvaluations).toBeDefined();
        expect(result.context.judgeEvaluations.length).toBeGreaterThan(0);
      });

      it("When executing goal, Then each turn has judge evaluation", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: goal.id,
              maxTurns: 5,
            })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        // Should have judge evaluations for each turn
        expect(result.context.judgeEvaluations.length).toBeGreaterThan(0);

        // Each evaluation should have proper turn number
        result.context.judgeEvaluations.forEach((evaluation) => {
          expect(evaluation.turn).toBeGreaterThan(0);
          expect(evaluation.goalId).toBe(result.goalId);
        });
      });

      it("When executing goal, Then latest evaluation is accessible", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* executeGoalHandler(
            new ExecuteGoalCommand({
              goalId: goal.id,
              maxTurns: 2,
            })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        const latest = result.context.getLatestJudgeEvaluation();
        expect(latest).toBeDefined();
        expect(latest?.goalId).toBe(result.goalId);
      });
    });
  });
});
