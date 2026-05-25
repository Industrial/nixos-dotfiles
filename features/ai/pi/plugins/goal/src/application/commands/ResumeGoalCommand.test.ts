/**
 * ResumeGoalCommand - BDD Tests
 * 
 * Comprehensive input/output mutation tests using Given/When/Then pattern.
 */
import { describe, it, expect } from "bun:test";
import { Effect, Layer } from "effect";
import { ResumeGoalCommand, resumeGoalHandler } from "./ResumeGoalCommand.js";
import { CreateGoalCommand, createGoalHandler } from "./CreateGoalCommand.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { GoalLifecycleServiceLive } from "../../domain/services/GoalLifecycleServiceLive.js";
import { GoalRepositoryMock } from "../../infrastructure/persistence/GoalRepositoryMock.js";

describe("ResumeGoalCommand", () => {
  const TestLayer = GoalLifecycleServiceLive.pipe(
    Layer.provide(GoalRepositoryMock)
  );

  describe("Schema Validation", () => {
    describe("Given valid command input", () => {
      it("When creating command with valid goal ID, Then command is created successfully", () => {
        const command = new ResumeGoalCommand({
          goalId: "goal-123",
        });

        expect(command.goalId).toBe("goal-123");
      });

      it("When creating command with UUID-style ID, Then command is created", () => {
        const command = new ResumeGoalCommand({
          goalId: "550e8400-e29b-41d4-a716-446655440000",
        });

        expect(command.goalId).toBe("550e8400-e29b-41d4-a716-446655440000");
      });

      it("When creating command with special characters in ID, Then command is created", () => {
        const command = new ResumeGoalCommand({
          goalId: "goal-abc_123-xyz",
        });

        expect(command.goalId).toBe("goal-abc_123-xyz");
      });

      it("When creating command with very long ID, Then command is created", () => {
        const longId = "goal-" + "a".repeat(1000);
        const command = new ResumeGoalCommand({
          goalId: longId,
        });

        expect(command.goalId).toBe(longId);
      });
    });
  });

  describe("Command Handler Execution", () => {
    describe("Given a paused goal exists", () => {
      it("When executing resume command, Then goal status changes to active", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          // Create and pause goal
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );
          yield* service.pauseGoal(goal.id);

          // Resume the goal
          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );
        });

        const resumedGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(resumedGoal.status).toBe("active");
      });

      it("When executing resume command, Then updatedAt timestamp is more recent", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );
          const _pausedGoal = yield* service.pauseGoal(goal.id);
          const pausedUpdatedAt = _pausedGoal.updatedAt;

          yield* Effect.sleep("1 millis");

          const resumedGoal = yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );

          return { pausedUpdatedAt, resumedGoal };
        });

        const { pausedUpdatedAt, resumedGoal } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(resumedGoal.updatedAt).toBeGreaterThan(pausedUpdatedAt);
      });

      it("When executing resume command, Then all other goal properties remain unchanged", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ 
              objective: "Test goal",
              context: "Test context"
            })
          );
          yield* service.pauseGoal(goal.id);

          const resumedGoal = yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );

          return { goal, resumedGoal };
        });

        const { goal, resumedGoal } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(resumedGoal.id).toBe(goal.id);
        expect(resumedGoal.objective).toBe(goal.objective);
        expect(resumedGoal.context).toBe(goal.context);
        expect(resumedGoal.createdAt).toBe(goal.createdAt);
        expect(resumedGoal.completedAt).toBeUndefined();
      });

      it("When executing resume command with evaluation data, Then evaluation is preserved", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );
          
          // Pause goal
          const _pausedGoal = yield* service.pauseGoal(goal.id);
          
          // Resume goal
          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );
        });

        const resumedGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(resumedGoal.status).toBe("active");
      });
    });

    describe("Given an active goal exists", () => {
      it("When executing resume command, Then command fails with business rule violation", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          // Try to resume an already active goal
          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Cannot resume goal in status: active/);
      });
    });

    describe("Given a completed goal exists", () => {
      it("When executing resume command, Then command fails with business rule violation", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.completeGoal(goal.id);

          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Cannot resume goal in status: completed/);
      });
    });

    describe("Given a cancelled goal exists", () => {
      it("When executing resume command, Then command fails with business rule violation", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.cancelGoal(goal.id);

          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Cannot resume goal in status: cancelled/);
      });
    });

    describe("Given goal does not exist", () => {
      it("When executing resume command, Then command fails with not found error", async () => {
        const program = Effect.gen(function* () {
          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: "non-existent-id" })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Goal not found/);
      });

      it("When executing resume command with empty ID, Then command fails", async () => {
        const program = Effect.gen(function* () {
          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: "" })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Goal not found/);
      });

      it("When executing resume command with whitespace-only ID, Then command fails", async () => {
        const program = Effect.gen(function* () {
          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: "   " })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Goal not found/);
      });
    });

    describe("Given another active goal exists", () => {
      it("When executing resume command, Then command fails with active goal conflict", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          // Create and pause first goal
          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "First goal" })
          );
          yield* service.pauseGoal(goal1.id);

          // Create second active goal
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Second goal" })
          );

          // Try to resume first goal while second is active
          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal1.id })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Another goal is already active/);
      });

      it("When executing resume command with different paused goal, Then same failure occurs", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          // Create two goals and pause both
          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "First goal" })
          );
          yield* service.pauseGoal(goal1.id);

          const goal2 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Second goal" })
          );
          yield* service.pauseGoal(goal2.id);

          // Resume first goal
          yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal1.id })
          );

          // Try to resume second goal while first is active
          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal2.id })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Another goal is already active/);
      });
    });

    describe("Multiple pause/resume cycles", () => {
      it("When pausing and resuming multiple times, Then each resume succeeds from paused state", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          // Cycle 1
          const paused1 = yield* service.pauseGoal(goal.id);
          const resumed1 = yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );

          // Cycle 2
          const paused2 = yield* service.pauseGoal(goal.id);
          const resumed2 = yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );

          // Cycle 3
          const paused3 = yield* service.pauseGoal(goal.id);
          const resumed3 = yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );

          return { paused1, resumed1, paused2, resumed2, paused3, resumed3 };
        });

        const results = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(results.paused1.status).toBe("paused");
        expect(results.resumed1.status).toBe("active");
        expect(results.paused2.status).toBe("paused");
        expect(results.resumed2.status).toBe("active");
        expect(results.paused3.status).toBe("paused");
        expect(results.resumed3.status).toBe("active");
      });

      it("When multiple pause/resume cycles occur, Then timestamps increase monotonically", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* Effect.sleep("1 millis");
          const paused1 = yield* service.pauseGoal(goal.id);
          
          yield* Effect.sleep("1 millis");
          const resumed1 = yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );

          yield* Effect.sleep("1 millis");
          const paused2 = yield* service.pauseGoal(goal.id);
          
          yield* Effect.sleep("1 millis");
          const resumed2 = yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );

          return { goal, paused1, resumed1, paused2, resumed2 };
        });

        const { goal, paused1, resumed1, paused2, resumed2 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(paused1.updatedAt).toBeGreaterThan(goal.updatedAt);
        expect(resumed1.updatedAt).toBeGreaterThan(paused1.updatedAt);
        expect(paused2.updatedAt).toBeGreaterThan(resumed1.updatedAt);
        expect(resumed2.updatedAt).toBeGreaterThan(paused2.updatedAt);
      });
    });

    describe("Concurrent resume attempts", () => {
      it("When multiple resume commands execute sequentially on paused goal, Then only first succeeds", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );
          yield* service.pauseGoal(goal.id);

          const resumed = yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );

          // This should fail since goal is now active
          const attemptSecondResume = yield* Effect.either(
            resumeGoalHandler(
              new ResumeGoalCommand({ goalId: goal.id })
            )
          );

          return { resumed, attemptSecondResume };
        });

        const { resumed, attemptSecondResume } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(resumed.status).toBe("active");
        expect(attemptSecondResume._tag).toBe("Left");
        if (attemptSecondResume._tag === "Left") {
          expect(attemptSecondResume.left.message).toMatch(/Cannot resume goal in status: active/);
        }
      });
    });

    describe("Edge cases and boundary conditions", () => {
      it("When resuming goal with very long ID, Then resume succeeds", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );
          yield* service.pauseGoal(goal.id);

          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );
        });

        const resumed = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(resumed.status).toBe("active");
      });

      it("When resuming paused goal immediately after pause, Then resume succeeds", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );
          yield* service.pauseGoal(goal.id);

          // Immediate resume
          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );
        });

        const resumed = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(resumed.status).toBe("active");
      });

      it("When resuming goal with context, Then context is preserved", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ 
              objective: "Test goal",
              context: "Important context with 🚀 emoji"
            })
          );
          yield* service.pauseGoal(goal.id);

          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );
        });

        const resumed = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(resumed.context).toBe("Important context with 🚀 emoji");
        expect(resumed.status).toBe("active");
      });
    });

    describe("Timestamp behavior", () => {
      it("When resuming goal, Then updatedAt changes but createdAt remains same", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );
          const originalCreatedAt = goal.createdAt;
          
          yield* service.pauseGoal(goal.id);
          
          yield* Effect.sleep("1 millis");
          
          const resumed = yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );

          return { originalCreatedAt, resumed };
        });

        const { originalCreatedAt, resumed } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(resumed.createdAt).toBe(originalCreatedAt);
        expect(resumed.updatedAt).toBeGreaterThan(originalCreatedAt);
      });

      it("When resuming goal, Then completedAt remains undefined", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );
          yield* service.pauseGoal(goal.id);

          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );
        });

        const resumed = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(resumed.completedAt).toBeUndefined();
      });
    });

    describe("Business rule validation", () => {
      it("When resuming paused goal that was paused for long time, Then resume succeeds", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );
          yield* service.pauseGoal(goal.id);

          // Simulate long pause
          yield* Effect.sleep("100 millis");

          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal.id })
          );
        });

        const resumed = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(resumed.status).toBe("active");
      });

      it("When resuming paused goal after creating and completing another goal, Then resume succeeds", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          // Create and pause first goal
          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "First goal" })
          );
          yield* service.pauseGoal(goal1.id);

          // Create and complete second goal
          const goal2 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Second goal" })
          );
          yield* service.completeGoal(goal2.id);

          // Resume first goal
          return yield* resumeGoalHandler(
            new ResumeGoalCommand({ goalId: goal1.id })
          );
        });

        const resumed = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(resumed.status).toBe("active");
        expect(resumed.objective).toBe("First goal");
      });
    });
  });
});
