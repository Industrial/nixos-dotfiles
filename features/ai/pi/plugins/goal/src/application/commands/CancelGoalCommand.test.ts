/**
 * CancelGoalCommand - BDD Tests
 *
 * Tests for cancelling/clearing goals.
 * Cancelling moves a goal to terminal "cancelled" status.
 */
import { describe, it, expect } from "bun:test";
import { Effect, Layer } from "effect";
import { CancelGoalCommand, cancelGoalHandler } from "./CancelGoalCommand.js";
import { CreateGoalCommand, createGoalHandler } from "./CreateGoalCommand.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { GoalLifecycleTestLayer } from "../../testing/TestLayers.js";

describe("CancelGoalCommand", () => {
  const TestLayer = GoalLifecycleTestLayer;

  describe("Schema Validation", () => {
    describe("Given valid command input", () => {
      it("When creating command with goal ID, Then command is created successfully", () => {
        const command = new CancelGoalCommand({
          goalId: "goal-123",
        });

        expect(command.goalId).toBe("goal-123");
        expect(command.reason).toBeUndefined();
      });

      it("When creating command with reason, Then reason is set", () => {
        const command = new CancelGoalCommand({
          goalId: "goal-123",
          reason: "Goals changed",
        });

        expect(command.goalId).toBe("goal-123");
        expect(command.reason).toBe("Goals changed");
      });
    });
  });

  describe("Command Handler Execution", () => {
    describe("Given an active goal exists", () => {
      it("When cancelling goal, Then status changes to cancelled", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: goal.id })
          );
        });

        const cancelledGoal = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(cancelledGoal.status).toBe("cancelled");
      });

      it("When cancelling goal, Then completedAt timestamp is set", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: goal.id })
          );
        });

        const cancelledGoal = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(cancelledGoal.completedAt).toBeDefined();
        expect(cancelledGoal.completedAt).toBeGreaterThan(0);
      });

      it("When cancelling goal, Then updatedAt timestamp is updated", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* Effect.sleep("1 millis");

          const cancelled = yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: goal.id })
          );

          return { goal, cancelled };
        });

        const { goal, cancelled } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(cancelled.updatedAt).toBeGreaterThan(goal.updatedAt);
      });

      it("When cancelling goal, Then completedAt equals updatedAt", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: goal.id })
          );
        });

        const cancelledGoal = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(cancelledGoal.completedAt).toBe(cancelledGoal.updatedAt);
      });

      it("When cancelling goal, Then all other properties remain unchanged", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({
              objective: "Test goal",
              context: "Test context",
            })
          );

          const cancelled = yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: goal.id })
          );

          return { goal, cancelled };
        });

        const { goal, cancelled } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(cancelled.id).toBe(goal.id);
        expect(cancelled.objective).toBe(goal.objective);
        expect(cancelled.context).toBe(goal.context);
        expect(cancelled.createdAt).toBe(goal.createdAt);
      });
    });

    describe("Given a paused goal exists", () => {
      it("When cancelling paused goal, Then cancellation succeeds", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.pauseGoal(goal.id);

          return yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: goal.id })
          );
        });

        const cancelledGoal = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(cancelledGoal.status).toBe("cancelled");
      });
    });

    describe("Given a completed goal exists", () => {
      it("When attempting to cancel completed goal, Then operation fails", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.completeGoal(goal.id);

          return yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: goal.id })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/terminal state/);
      });
    });

    describe("Given goal does not exist", () => {
      it("When cancelling nonexistent goal, Then operation fails", async () => {
        const program = Effect.gen(function* () {
          return yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: "nonexistent-id" })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Goal not found/);
      });
    });

    describe("Given cancelled goal exists", () => {
      it("When attempting to cancel again, Then operation fails", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: goal.id })
          );

          return yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: goal.id })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/terminal state/);
      });
    });

    describe("State transitions", () => {
      it("When cancelling after pause/resume cycle, Then cancellation succeeds", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.pauseGoal(goal.id);
          yield* service.resumeGoal(goal.id);

          return yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: goal.id })
          );
        });

        const cancelledGoal = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(cancelledGoal.status).toBe("cancelled");
      });
    });

    describe("Edge cases", () => {
      it("When cancelling goal with Unicode emoji in objective, Then properties preserved", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({
              objective: "Launch 🚀 to Mars 🔴",
            })
          );

          return yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: goal.id })
          );
        });

        const cancelledGoal = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(cancelledGoal.objective).toContain("🚀");
        expect(cancelledGoal.status).toBe("cancelled");
      });

      it("When cancelling goal with reason, Then reason can be stored", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* cancelGoalHandler(
            new CancelGoalCommand({
              goalId: goal.id,
              reason: "Priorities changed",
            })
          );
        });

        const cancelledGoal = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(cancelledGoal.status).toBe("cancelled");
        // Note: Reason storage would require model changes
      });
    });

    describe("Timestamp behavior", () => {
      it("When cancelling goal, Then completedAt is current time", async () => {
        const program = Effect.gen(function* () {
          const before = Date.now();

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const cancelled = yield* cancelGoalHandler(
            new CancelGoalCommand({ goalId: goal.id })
          );

          const after = Date.now();

          return { cancelled, before, after };
        });

        const { cancelled, before, after } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(cancelled.completedAt!).toBeGreaterThanOrEqual(before);
        expect(cancelled.completedAt!).toBeLessThanOrEqual(after);
      });
    });
  });
});
