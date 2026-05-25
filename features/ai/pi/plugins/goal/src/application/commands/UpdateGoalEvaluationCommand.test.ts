/**
 * UpdateGoalEvaluationCommand - BDD Tests
 *
 * Tests for updating goal evaluation data during execution.
 * Tracks progress, blockers, next steps, and notes.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { UpdateGoalEvaluationCommand, updateGoalEvaluationHandler } from "./UpdateGoalEvaluationCommand.js";
import { CreateGoalCommand, createGoalHandler } from "./CreateGoalCommand.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { GoalLifecycleTestLayer } from "../../testing/TestLayers.js";

describe("UpdateGoalEvaluationCommand", () => {
  const TestLayer = GoalLifecycleTestLayer;

  describe("Schema Validation", () => {
    describe("Given valid command input", () => {
      it("When creating command with progress, Then command is created", () => {
        const command = new UpdateGoalEvaluationCommand({
          goalId: "goal-123",
          progress: 50,
          blockers: [],
          nextSteps: ["Continue work"],
        });

        expect(command.goalId).toBe("goal-123");
        expect(command.progress).toBe(50);
      });

      it("When creating command with all fields, Then all are set", () => {
        const command = new UpdateGoalEvaluationCommand({
          goalId: "goal-123",
          progress: 75,
          completionEstimate: 2,
          blockers: ["Waiting for review"],
          nextSteps: ["Address feedback", "Deploy"],
          notes: "Good progress overall",
        });

        expect(command.progress).toBe(75);
        expect(command.completionEstimate).toBe(2);
        expect(command.blockers).toEqual(["Waiting for review"]);
        expect(command.nextSteps).toEqual(["Address feedback", "Deploy"]);
        expect(command.notes).toBe("Good progress overall");
      });
    });

    describe("Given invalid command input", () => {
      it("When creating command with progress < 0, Then validation fails", () => {
        expect(() => {
          new UpdateGoalEvaluationCommand({
            goalId: "goal-123",
            progress: -1,
            blockers: [],
            nextSteps: [],
          });
        }).toThrow();
      });

      it("When creating command with progress > 100, Then validation fails", () => {
        expect(() => {
          new UpdateGoalEvaluationCommand({
            goalId: "goal-123",
            progress: 101,
            blockers: [],
            nextSteps: [],
          });
        }).toThrow();
      });

      it("When creating command without goal ID, Then validation fails", () => {
        expect(() => {
          new UpdateGoalEvaluationCommand({
            progress: 50,
            blockers: [],
            nextSteps: [],
          } as any);
        }).toThrow();
      });
    });
  });

  describe("Command Handler Execution", () => {
    describe("Given an active goal exists", () => {
      it("When updating evaluation, Then evaluation data is set", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 50,
              blockers: ["Need approval"],
              nextSteps: ["Get sign-off"],
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.evaluationData).toBeDefined();
        expect(updated.evaluationData?.progress).toBe(50);
        expect(updated.evaluationData?.blockers).toEqual(["Need approval"]);
        expect(updated.evaluationData?.nextSteps).toEqual(["Get sign-off"]);
      });

      it("When updating evaluation multiple times, Then latest values are stored", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 25,
              blockers: ["Blocker 1"],
              nextSteps: ["Step 1"],
            })
          );

          return yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 75,
              blockers: ["Blocker 2"],
              nextSteps: ["Step 2"],
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.evaluationData?.progress).toBe(75);
        expect(updated.evaluationData?.blockers).toEqual(["Blocker 2"]);
        expect(updated.evaluationData?.nextSteps).toEqual(["Step 2"]);
      });

      it("When updating evaluation, Then updatedAt timestamp changes", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* Effect.sleep("1 millis");

          const updated = yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 50,
              blockers: [],
              nextSteps: [],
            })
          );

          return { goal, updated };
        });

        const { goal, updated } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(updated.updatedAt).toBeGreaterThan(goal.updatedAt);
      });

      it("When updating evaluation, Then other goal properties remain unchanged", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({
              objective: "Test goal",
              context: "Test context",
            })
          );

          const updated = yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 50,
              blockers: [],
              nextSteps: [],
            })
          );

          return { goal, updated };
        });

        const { goal, updated } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(updated.id).toBe(goal.id);
        expect(updated.objective).toBe(goal.objective);
        expect(updated.context).toBe(goal.context);
        expect(updated.status).toBe(goal.status);
        expect(updated.createdAt).toBe(goal.createdAt);
      });
    });

    describe("Given evaluation with completion estimate", () => {
      it("When setting completion estimate, Then it is stored", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 50,
              completionEstimate: 3.5,
              blockers: [],
              nextSteps: [],
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.evaluationData?.completionEstimate).toBe(3.5);
      });
    });

    describe("Given evaluation with notes", () => {
      it("When setting notes, Then they are stored", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 50,
              blockers: [],
              nextSteps: [],
              notes: "Making good progress, team is aligned",
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.evaluationData?.notes).toBe("Making good progress, team is aligned");
      });
    });

    describe("Given a paused goal exists", () => {
      it("When updating evaluation on paused goal, Then update succeeds", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.pauseGoal(goal.id);

          return yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 30,
              blockers: ["Paused for review"],
              nextSteps: ["Resume after review"],
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.status).toBe("paused");
        expect(updated.evaluationData?.progress).toBe(30);
      });
    });

    describe("Given a completed goal exists", () => {
      it("When trying to update evaluation on completed goal, Then error is thrown", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.completeGoal(goal.id);

          return yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 100,
              blockers: [],
              nextSteps: [],
            })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Cannot update goal in terminal state/);
      });
    });

    describe("Given goal does not exist", () => {
      it("When trying to update evaluation, Then error is thrown", async () => {
        const program = Effect.gen(function* () {
          return yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: "nonexistent",
              progress: 50,
              blockers: [],
              nextSteps: [],
            })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Goal not found/);
      });
    });

    describe("Edge cases", () => {
      it("When updating with empty blockers array, Then stored correctly", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 80,
              blockers: [],
              nextSteps: ["Final push"],
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.evaluationData?.blockers).toEqual([]);
      });

      it("When updating with many blockers, Then all are stored", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const blockers = Array.from({ length: 10 }, (_, i) => `Blocker ${i + 1}`);

          return yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 20,
              blockers,
              nextSteps: [],
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.evaluationData?.blockers).toHaveLength(10);
      });

      it("When updating with Unicode in notes, Then preserved correctly", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 50,
              blockers: [],
              nextSteps: [],
              notes: "Progress is going 🚀 smoothly!",
            })
          );
        });

        const updated = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(updated.evaluationData?.notes).toContain("🚀");
      });

      it("When tracking progress from 0 to 100, Then all values work", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const p0 = yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 0,
              blockers: [],
              nextSteps: [],
            })
          );

          const p50 = yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 50,
              blockers: [],
              nextSteps: [],
            })
          );

          const p100 = yield* updateGoalEvaluationHandler(
            new UpdateGoalEvaluationCommand({
              goalId: goal.id,
              progress: 100,
              blockers: [],
              nextSteps: [],
            })
          );

          return { p0, p50, p100 };
        });

        const { p0, p50, p100 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(p0.evaluationData?.progress).toBe(0);
        expect(p50.evaluationData?.progress).toBe(50);
        expect(p100.evaluationData?.progress).toBe(100);
      });
    });
  });
});
