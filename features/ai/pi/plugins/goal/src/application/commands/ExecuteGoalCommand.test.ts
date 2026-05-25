/**
 * ExecuteGoalCommand - BDD Tests
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { ExecuteGoalCommand, executeGoalHandler } from "./ExecuteGoalCommand.js";
import { CreateGoalCommand, createGoalHandler } from "./CreateGoalCommand.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { AppLayerMock } from "../../index.js";
import {
  MAX_GOAL_TURNS_LIFETIME,
  computeMaxTurnsThisCall,
} from "../../domain/execution/constants.js";
import {
  GoalExecutionRepository,
  initialCheckpoint,
} from "../../domain/repositories/GoalExecutionRepository.js";

describe("ExecuteGoalCommand", () => {
  const TestLayer = AppLayerMock;

  describe("Schema Validation", () => {
    it("When creating command with goal ID, Then command is created", () => {
      const command = new ExecuteGoalCommand({ goalId: "goal-123" });
      expect(command.goalId).toBe("goal-123");
    });
  });

  describe("Command Handler Execution", () => {
    it("When executing with default maxTurns, Then runs one turn", async () => {
      const program = Effect.gen(function* () {
        const goal = yield* createGoalHandler(
          new CreateGoalCommand({ objective: "Test goal" })
        );
        return yield* executeGoalHandler(new ExecuteGoalCommand({ goalId: goal.id }));
      });

      const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      expect(result.turnsThisCall).toBe(1);
      expect(result.cumulativeTurn).toBe(1);
      expect(result.phaseComplete).toBe(true);
    });

    it("When turn limit hit without tool work, Then success is false", async () => {
      const program = Effect.gen(function* () {
        const goal = yield* createGoalHandler(
          new CreateGoalCommand({ objective: "Test goal" })
        );
        return yield* executeGoalHandler(
          new ExecuteGoalCommand({ goalId: goal.id, maxTurns: 3 })
        );
      });

      const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      expect(result.turnLimitReached).toBe(true);
      expect(result.goalAchieved).toBe(false);
      expect(result.success).toBe(false);
      expect(result.stoppedReason).toBe("turn_limit");
    });

    it("When maxTurns exceeds lifetime cap, Then validation fails", async () => {
      const program = Effect.gen(function* () {
        const goal = yield* createGoalHandler(
          new CreateGoalCommand({ objective: "Test goal" })
        );
        return yield* executeGoalHandler(
          new ExecuteGoalCommand({
            goalId: goal.id,
            maxTurns: MAX_GOAL_TURNS_LIFETIME + 1,
          })
        );
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow(/cannot exceed/);
    });

    it("When lifetime budget is exhausted, Then execute fails before running turns", async () => {
      const program = Effect.gen(function* () {
        const goal = yield* createGoalHandler(
          new CreateGoalCommand({ objective: "Budget test" })
        );
        const executions = yield* GoalExecutionRepository;
        yield* executions.upsert({
          ...initialCheckpoint(goal.id),
          cumulativeTurn: MAX_GOAL_TURNS_LIFETIME,
        });
        return yield* executeGoalHandler(
          new ExecuteGoalCommand({ goalId: goal.id, maxTurns: 1 })
        );
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow(/turn budget exhausted/i);
    });

    it("When maxTurns is 1000 with no prior turns, Then clamps to lifetime cap per call", () => {
      expect(computeMaxTurnsThisCall(1000, 0)).toBe(MAX_GOAL_TURNS_LIFETIME);
    });

    it("When goal does not exist, Then error is thrown", async () => {
      const program = executeGoalHandler(
        new ExecuteGoalCommand({ goalId: "nonexistent" })
      );
      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow(/Goal not found/);
    });

    it("When goal is paused, Then error is thrown", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        const goal = yield* createGoalHandler(
          new CreateGoalCommand({ objective: "Test goal" })
        );
        yield* service.pauseGoal(goal.id);
        return yield* executeGoalHandler(
          new ExecuteGoalCommand({ goalId: goal.id, maxTurns: 1 })
        );
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow(/must be active/);
    });

    it("When executing completed goal, Then error is thrown", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        const goal = yield* createGoalHandler(
          new CreateGoalCommand({ objective: "Test goal" })
        );
        yield* service.completeGoal(goal.id);
        return yield* executeGoalHandler(
          new ExecuteGoalCommand({ goalId: goal.id })
        );
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow(/terminal state/);
    });

    it("When executing, Then returns nextPrompt for delegation", async () => {
      const program = Effect.gen(function* () {
        const goal = yield* createGoalHandler(
          new CreateGoalCommand({ objective: "Test goal" })
        );
        return yield* executeGoalHandler(
          new ExecuteGoalCommand({ goalId: goal.id, maxTurns: 1 })
        );
      });

      const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      expect(result.nextPrompt).toBeDefined();
      expect(result.nextPrompt!.length).toBeGreaterThan(0);
    });

    it("When executing, Then persists iteration records", async () => {
      const program = Effect.gen(function* () {
        const goal = yield* createGoalHandler(
          new CreateGoalCommand({ objective: "Test goal" })
        );
        return yield* executeGoalHandler(
          new ExecuteGoalCommand({ goalId: goal.id, maxTurns: 2 })
        );
      });

      const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      expect(result.context.judgeEvaluations.length).toBe(2);
    });
  });
});
