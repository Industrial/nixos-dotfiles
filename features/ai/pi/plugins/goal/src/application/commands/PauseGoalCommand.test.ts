/**
 * PauseGoalCommand - BDD Tests
 * 
 * Comprehensive input/output mutation tests using Given/When/Then pattern.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { PauseGoalCommand, pauseGoalHandler } from "./PauseGoalCommand.js";
import { CreateGoalCommand, createGoalHandler } from "./CreateGoalCommand.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { GoalLifecycleTestLayer } from "../../testing/TestLayers.js";

describe("PauseGoalCommand", () => {
  const TestLayer = GoalLifecycleTestLayer;

  describe("Schema Validation", () => {
    describe("Given valid command input", () => {
      it("When creating command with valid goal ID, Then command is created successfully", () => {
        const command = new PauseGoalCommand({
          goalId: "goal-123",
        });

        expect(command.goalId).toBe("goal-123");
      });

      it("When creating command with UUID-style ID, Then command is created", () => {
        const command = new PauseGoalCommand({
          goalId: "550e8400-e29b-41d4-a716-446655440000",
        });

        expect(command.goalId).toBe("550e8400-e29b-41d4-a716-446655440000");
      });

      it("When creating command with special characters in ID, Then command is created", () => {
        const command = new PauseGoalCommand({
          goalId: "goal-abc_123-xyz",
        });

        expect(command.goalId).toBe("goal-abc_123-xyz");
      });
    });
  });

  describe("Command Handler Execution", () => {
    describe("Given an active goal exists", () => {
      it("When executing pause command, Then goal status changes to paused", async () => {
        const program = Effect.gen(function* () {
          // Create active goal
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          // Pause the goal
          return yield* pauseGoalHandler(
            new PauseGoalCommand({ goalId: goal.id })
          );
        });

        const pausedGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(pausedGoal.status).toBe("paused");
      });

      it("When executing pause command, Then updatedAt timestamp is more recent", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const originalUpdatedAt = goal.updatedAt;

          yield* Effect.sleep("1 millis");

          const pausedGoal = yield* pauseGoalHandler(
            new PauseGoalCommand({ goalId: goal.id })
          );

          return { originalUpdatedAt, pausedGoal };
        });

        const { originalUpdatedAt, pausedGoal } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(pausedGoal.updatedAt).toBeGreaterThan(originalUpdatedAt);
      });

      it("When executing pause command, Then all other goal properties remain unchanged", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ 
              objective: "Test goal",
              context: "Test context"
            })
          );

          const pausedGoal = yield* pauseGoalHandler(
            new PauseGoalCommand({ goalId: goal.id })
          );

          return { goal, pausedGoal };
        });

        const { goal, pausedGoal } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(pausedGoal.id).toBe(goal.id);
        expect(pausedGoal.objective).toBe(goal.objective);
        expect(pausedGoal.context).toBe(goal.context);
        expect(pausedGoal.createdAt).toBe(goal.createdAt);
        expect(pausedGoal.completedAt).toBeUndefined();
      });
    });

    describe("Given a paused goal exists", () => {
      it("When executing pause command, Then command fails with business rule violation", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          // Pause once
          yield* pauseGoalHandler(
            new PauseGoalCommand({ goalId: goal.id })
          );

          // Try to pause again
          return yield* pauseGoalHandler(
            new PauseGoalCommand({ goalId: goal.id })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Cannot pause goal in status: paused/);
      });
    });

    describe("Given a completed goal exists", () => {
      it("When executing pause command, Then command fails with business rule violation", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.completeGoal(goal.id);

          return yield* pauseGoalHandler(
            new PauseGoalCommand({ goalId: goal.id })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Cannot pause goal in status: completed/);
      });
    });

    describe("Given a cancelled goal exists", () => {
      it("When executing pause command, Then command fails with business rule violation", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.cancelGoal(goal.id);

          return yield* pauseGoalHandler(
            new PauseGoalCommand({ goalId: goal.id })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Cannot pause goal in status: cancelled/);
      });
    });

    describe("Given goal does not exist", () => {
      it("When executing pause command, Then command fails with not found error", async () => {
        const program = Effect.gen(function* () {
          return yield* pauseGoalHandler(
            new PauseGoalCommand({ goalId: "non-existent-id" })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Goal not found/);
      });

      it("When executing pause command with empty ID, Then command fails", async () => {
        const program = Effect.gen(function* () {
          return yield* pauseGoalHandler(
            new PauseGoalCommand({ goalId: "" })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Goal not found/);
      });
    });

    describe("Multiple pause/resume cycles", () => {
      it("When pausing and resuming multiple times, Then each pause succeeds from active state", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          // Cycle 1
          const paused1 = yield* pauseGoalHandler(
            new PauseGoalCommand({ goalId: goal.id })
          );
          const resumed1 = yield* service.resumeGoal(goal.id);

          // Cycle 2
          const paused2 = yield* pauseGoalHandler(
            new PauseGoalCommand({ goalId: goal.id })
          );

          return { paused1, resumed1, paused2 };
        });

        const { paused1, resumed1, paused2 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(paused1.status).toBe("paused");
        expect(resumed1.status).toBe("active");
        expect(paused2.status).toBe("paused");
      });
    });

    describe("Concurrent pause attempts", () => {
      it("When multiple pause commands execute sequentially, Then only first succeeds", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const paused = yield* pauseGoalHandler(
            new PauseGoalCommand({ goalId: goal.id })
          );

          // This should fail
          const attemptSecondPause = pauseGoalHandler(
            new PauseGoalCommand({ goalId: goal.id })
          );

          return { paused, attemptSecondPause };
        });

        const { paused, attemptSecondPause } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(paused.status).toBe("paused");
        
        await expect(
          Effect.runPromise(attemptSecondPause.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow();
      });
    });
  });
});
