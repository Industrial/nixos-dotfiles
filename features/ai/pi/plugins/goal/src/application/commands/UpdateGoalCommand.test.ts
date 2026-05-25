/**
 * UpdateGoalCommand - BDD Tests
 *
 * Tests for updating goal properties during execution.
 * Allows modification of objective and context while goal is active or paused.
 */
import { describe, it, expect } from "bun:test";
import { Effect, Layer } from "effect";
import { UpdateGoalCommand, updateGoalHandler } from "./UpdateGoalCommand.js";
import { CreateGoalCommand, createGoalHandler } from "./CreateGoalCommand.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { GoalLifecycleTestLayer } from "../../testing/TestLayers.js";

describe("UpdateGoalCommand", () => {
  const TestLayer = GoalLifecycleTestLayer;

  describe("Schema Validation", () => {
    describe("Given valid command input", () => {
      it("When creating command with goal ID and objective, Then command is created", () => {
        const command = new UpdateGoalCommand({
          goalId: "goal-123",
          objective: "Updated objective",
        });

        expect(command.goalId).toBe("goal-123");
        expect(command.objective).toBe("Updated objective");
      });

      it("When creating command with goal ID and context, Then command is created", () => {
        const command = new UpdateGoalCommand({
          goalId: "goal-123",
          context: "Updated context",
        });

        expect(command.goalId).toBe("goal-123");
        expect(command.context).toBe("Updated context");
      });

      it("When creating command with both objective and context, Then both are set", () => {
        const command = new UpdateGoalCommand({
          goalId: "goal-123",
          objective: "New objective",
          context: "New context",
        });

        expect(command.objective).toBe("New objective");
        expect(command.context).toBe("New context");
      });
    });

    describe("Given invalid command input", () => {
      it("When creating command without goal ID, Then validation fails", () => {
        expect(() => {
          new UpdateGoalCommand({
            objective: "Test",
          } as any);
        }).toThrow();
      });

      it("When creating command with empty goal ID, Then validation fails", () => {
        expect(() => {
          new UpdateGoalCommand({
            goalId: "",
            objective: "Test",
          });
        }).toThrow();
      });

      it("When executing command without any updates, Then handler fails", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test" })
          );

          return yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
            })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/At least one field/);
      });
    });
  });

  describe("Command Handler Execution", () => {
    describe("Given an active goal exists", () => {
      it("When updating objective, Then objective is changed", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Original objective" })
          );

          return yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              objective: "Updated objective",
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.objective).toBe("Updated objective");
      });

      it("When updating context, Then context is changed", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({
              objective: "Test goal",
              context: "Original context",
            })
          );

          return yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              context: "Updated context",
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.context).toBe("Updated context");
      });

      it("When updating both objective and context, Then both are changed", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({
              objective: "Original objective",
              context: "Original context",
            })
          );

          return yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              objective: "New objective",
              context: "New context",
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.objective).toBe("New objective");
        expect(updated.context).toBe("New context");
      });

      it("When updating goal, Then updatedAt timestamp changes", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Original" })
          );

          yield* Effect.sleep("1 millis");

          const updated = yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              objective: "Updated",
            })
          );

          return { goal, updated };
        });

        const { goal, updated } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(updated.updatedAt).toBeGreaterThan(goal.updatedAt);
      });

      it("When updating goal, Then other properties remain unchanged", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({
              objective: "Original",
              context: "Original context",
            })
          );

          const updated = yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              objective: "Updated",
            })
          );

          return { goal, updated };
        });

        const { goal, updated } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(updated.id).toBe(goal.id);
        expect(updated.status).toBe(goal.status);
        expect(updated.createdAt).toBe(goal.createdAt);
        expect(updated.context).toBe(goal.context);
      });
    });

    describe("Given a paused goal exists", () => {
      it("When updating paused goal, Then update succeeds", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Original" })
          );

          yield* service.pauseGoal(goal.id);

          return yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              objective: "Updated while paused",
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.objective).toBe("Updated while paused");
        expect(updated.status).toBe("paused");
      });
    });

    describe("Given a completed goal exists", () => {
      it("When trying to update completed goal, Then error is thrown", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test" })
          );

          yield* service.completeGoal(goal.id);

          return yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              objective: "Should fail",
            })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Cannot update goal in terminal state/);
      });
    });

    describe("Given a cancelled goal exists", () => {
      it("When trying to update cancelled goal, Then error is thrown", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test" })
          );

          yield* service.cancelGoal(goal.id);

          return yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              objective: "Should fail",
            })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Cannot update goal in terminal state/);
      });
    });

    describe("Given goal does not exist", () => {
      it("When trying to update nonexistent goal, Then error is thrown", async () => {
        const program = Effect.gen(function* () {
          return yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: "nonexistent",
              objective: "Should fail",
            })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Goal not found/);
      });
    });

    describe("Edge cases", () => {
      it("When updating with very long objective, Then update succeeds", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Short" })
          );

          const longObjective = "x".repeat(10000);
          return yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              objective: longObjective,
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.objective.length).toBe(10000);
      });

      it("When updating with Unicode emoji, Then emoji is preserved", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Original" })
          );

          return yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              objective: "Launch 🚀 to Mars 🔴",
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.objective).toContain("🚀");
        expect(updated.objective).toContain("🔴");
      });

      it("When updating context to undefined, Then context is cleared", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({
              objective: "Test",
              context: "Original context",
            })
          );

          return yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              context: undefined,
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.context).toBeUndefined();
      });

      it("When updating multiple times, Then each update is tracked", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Version 1" })
          );

          yield* Effect.sleep("1 millis");
          const v2 = yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              objective: "Version 2",
            })
          );

          yield* Effect.sleep("1 millis");
          const v3 = yield* updateGoalHandler(
            new UpdateGoalCommand({
              goalId: goal.id,
              objective: "Version 3",
            })
          );

          return { goal, v2, v3 };
        });

        const { goal, v2, v3 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(goal.objective).toBe("Version 1");
        expect(v2.objective).toBe("Version 2");
        expect(v3.objective).toBe("Version 3");
        expect(v2.updatedAt).toBeGreaterThan(goal.updatedAt);
        expect(v3.updatedAt).toBeGreaterThan(v2.updatedAt);
      });
    });
  });
});
