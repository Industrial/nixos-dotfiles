/**
 * GoalLifecycleServiceMock - BDD Tests
 *
 * Tests the mock implementation of the lifecycle service.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { GoalLifecycleService } from "./GoalLifecycleService.js";
import { GoalLifecycleServiceMock } from "./GoalLifecycleServiceMock.js";

describe("GoalLifecycleServiceMock", () => {
  describe("createGoal", () => {
    describe("Given no existing goals", () => {
      it("When creating goal, Then goal is created successfully", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          return yield* service.createGoal("Test goal");
        });

        const goal = await Effect.runPromise(
          program.pipe(Effect.provide(GoalLifecycleServiceMock))
        );

        expect(goal.objective).toBe("Test goal");
        expect(goal.status).toBe("active");
      });

      it("When creating goal with context, Then both fields are set", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          return yield* service.createGoal("Test goal", "Test context");
        });

        const goal = await Effect.runPromise(
          program.pipe(Effect.provide(GoalLifecycleServiceMock))
        );

        expect(goal.objective).toBe("Test goal");
        expect(goal.context).toBe("Test context");
      });
    });

    describe("Given an active goal exists", () => {
      it("When creating another goal, Then creation fails", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          yield* service.createGoal("First goal");

          return yield* service.createGoal("Second goal");
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(GoalLifecycleServiceMock)))
        ).rejects.toThrow(/Active goal already exists/);
      });
    });

    describe("Given a paused goal exists", () => {
      it("When creating new goal, Then creation succeeds", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal1 = yield* service.createGoal("First goal");
          yield* service.pauseGoal(goal1.id);

          return yield* service.createGoal("Second goal");
        });

        const goal = await Effect.runPromise(
          program.pipe(Effect.provide(GoalLifecycleServiceMock))
        );

        expect(goal.objective).toBe("Second goal");
        expect(goal.status).toBe("active");
      });
    });
  });

  describe("pauseGoal", () => {
    describe("Given an active goal exists", () => {
      it("When pausing goal, Then status changes to paused", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* service.createGoal("Test goal");
          return yield* service.pauseGoal(goal.id);
        });

        const pausedGoal = await Effect.runPromise(
          program.pipe(Effect.provide(GoalLifecycleServiceMock))
        );

        expect(pausedGoal.status).toBe("paused");
      });
    });

    describe("Given goal does not exist", () => {
      it("When pausing goal, Then operation fails", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          return yield* service.pauseGoal("nonexistent");
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(GoalLifecycleServiceMock)))
        ).rejects.toThrow(/Goal not found/);
      });
    });
  });

  describe("resumeGoal", () => {
    describe("Given a paused goal exists", () => {
      it("When resuming goal, Then status changes to active", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* service.createGoal("Test goal");
          yield* service.pauseGoal(goal.id);

          return yield* service.resumeGoal(goal.id);
        });

        const resumedGoal = await Effect.runPromise(
          program.pipe(Effect.provide(GoalLifecycleServiceMock))
        );

        expect(resumedGoal.status).toBe("active");
      });
    });

    describe("Given another active goal exists", () => {
      it("When resuming paused goal, Then operation fails", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal1 = yield* service.createGoal("First goal");
          yield* service.pauseGoal(goal1.id);

          const goal2 = yield* service.createGoal("Second goal");

          return yield* service.resumeGoal(goal1.id);
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(GoalLifecycleServiceMock)))
        ).rejects.toThrow(/Another goal is already active/);
      });
    });

    describe("Given goal does not exist", () => {
      it("When resuming goal, Then operation fails", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          return yield* service.resumeGoal("nonexistent");
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(GoalLifecycleServiceMock)))
        ).rejects.toThrow(/Goal not found/);
      });
    });
  });

  describe("completeGoal", () => {
    describe("Given an active goal exists", () => {
      it("When completing goal, Then status changes to completed", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* service.createGoal("Test goal");
          return yield* service.completeGoal(goal.id);
        });

        const completedGoal = await Effect.runPromise(
          program.pipe(Effect.provide(GoalLifecycleServiceMock))
        );

        expect(completedGoal.status).toBe("completed");
        expect(completedGoal.completedAt).toBeDefined();
      });
    });

    describe("Given goal does not exist", () => {
      it("When completing goal, Then operation fails", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          return yield* service.completeGoal("nonexistent");
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(GoalLifecycleServiceMock)))
        ).rejects.toThrow(/Goal not found/);
      });
    });
  });

  describe("cancelGoal", () => {
    describe("Given an active goal exists", () => {
      it("When cancelling goal, Then status changes to cancelled", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* service.createGoal("Test goal");
          return yield* service.cancelGoal(goal.id);
        });

        const cancelledGoal = await Effect.runPromise(
          program.pipe(Effect.provide(GoalLifecycleServiceMock))
        );

        expect(cancelledGoal.status).toBe("cancelled");
        expect(cancelledGoal.completedAt).toBeDefined();
      });
    });

    describe("Given goal does not exist", () => {
      it("When cancelling goal, Then operation fails", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          return yield* service.cancelGoal("nonexistent");
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(GoalLifecycleServiceMock)))
        ).rejects.toThrow(/Goal not found/);
      });
    });
  });

  describe("canActivateGoal", () => {
    describe("Given no active goal exists", () => {
      it("When checking if can activate, Then returns true", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          return yield* service.canActivateGoal();
        });

        const canActivate = await Effect.runPromise(
          program.pipe(Effect.provide(GoalLifecycleServiceMock))
        );

        expect(canActivate).toBe(true);
      });
    });

    describe("Given an active goal exists", () => {
      it("When checking if can activate, Then returns false", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          yield* service.createGoal("Test goal");

          return yield* service.canActivateGoal();
        });

        const canActivate = await Effect.runPromise(
          program.pipe(Effect.provide(GoalLifecycleServiceMock))
        );

        expect(canActivate).toBe(false);
      });
    });

    describe("Given a paused goal exists", () => {
      it("When checking if can activate, Then returns true", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* service.createGoal("Test goal");
          yield* service.pauseGoal(goal.id);

          return yield* service.canActivateGoal();
        });

        const canActivate = await Effect.runPromise(
          program.pipe(Effect.provide(GoalLifecycleServiceMock))
        );

        expect(canActivate).toBe(true);
      });
    });
  });

  describe("Integration scenarios", () => {
    it("When creating, pausing, and resuming goal, Then all operations succeed", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;

        const created = yield* service.createGoal("Test goal");
        const paused = yield* service.pauseGoal(created.id);
        const resumed = yield* service.resumeGoal(created.id);

        return { created, paused, resumed };
      });

      const { created, paused, resumed } = await Effect.runPromise(
        program.pipe(Effect.provide(GoalLifecycleServiceMock))
      );

      expect(created.status).toBe("active");
      expect(paused.status).toBe("paused");
      expect(resumed.status).toBe("active");
      expect(resumed.id).toBe(created.id);
    });

    it("When creating multiple goals with pause/complete between, Then all succeed", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;

        const goal1 = yield* service.createGoal("First");
        yield* service.completeGoal(goal1.id);

        const goal2 = yield* service.createGoal("Second");
        yield* service.pauseGoal(goal2.id);

        const goal3 = yield* service.createGoal("Third");

        return { goal1, goal2, goal3 };
      });

      const { goal1, goal2, goal3 } = await Effect.runPromise(
        program.pipe(Effect.provide(GoalLifecycleServiceMock))
      );

      expect(goal1.id).not.toBe(goal2.id);
      expect(goal2.id).not.toBe(goal3.id);
    });
  });
});
