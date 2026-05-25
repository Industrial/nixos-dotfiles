/**
 * GoalApplicationServiceLive - BDD Tests
 *
 * Tests the live implementation that delegates to command/query handlers.
 */
import { describe, it, expect } from "bun:test";
import { Effect, Layer } from "effect";
import { GoalApplicationService } from "./GoalApplicationService.js";
import { GoalApplicationServiceLive } from "./GoalApplicationServiceLive.js";
import { GoalLifecycleTestLayer } from "../../testing/TestLayers.js";
import {
  CreateGoalCommand,
  PauseGoalCommand,
  ResumeGoalCommand,
  CompleteGoalCommand,
} from "../commands/index.js";
import { GetGoalQuery, ListGoalsQuery } from "../queries/index.js";

describe("GoalApplicationServiceLive", () => {
  // Build complete dependency tree:
  // 1. GoalRepositoryMock - base dependency
  // 2. GoalLifecycleServiceLive - requires GoalRepository
  // 3. GoalApplicationServiceLive - handlers need both GoalLifecycleService and GoalRepository
  const lifecycleLayer = GoalLifecycleTestLayer;

  const TestLayer = Layer.mergeAll(
    GoalApplicationServiceLive,
    lifecycleLayer
  );

  describe("Service delegation", () => {
    describe("Given live service is provided", () => {
      it("When creating goal, Then delegates to createGoalHandler", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test delegation" })
          );
        });

        const goal = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(goal.objective).toBe("Test delegation");
        expect(goal.status).toBe("active");
      });

      it("When pausing goal, Then delegates to pauseGoalHandler", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test" })
          );

          return yield* service.pauseGoal(
            new PauseGoalCommand({ goalId: goal.id })
          );
        });

        const pausedGoal = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(pausedGoal.status).toBe("paused");
      });

      it("When resuming goal, Then delegates to resumeGoalHandler", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test" })
          );

          yield* service.pauseGoal(new PauseGoalCommand({ goalId: goal.id }));

          return yield* service.resumeGoal(
            new ResumeGoalCommand({ goalId: goal.id })
          );
        });

        const resumedGoal = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(resumedGoal.status).toBe("active");
      });

      it("When completing goal, Then delegates to completeGoalHandler", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test" })
          );

          return yield* service.completeGoal(
            new CompleteGoalCommand({ goalId: goal.id })
          );
        });

        const completedGoal = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(completedGoal.status).toBe("completed");
        expect(completedGoal.completedAt).toBeDefined();
      });

      it("When getting goal, Then delegates to getGoalHandler", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const created = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test fetch" })
          );

          return yield* service.getGoal(
            new GetGoalQuery({ goalId: created.id })
          );
        });

        const goal = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(goal.objective).toBe("Test fetch");
      });

      it("When listing goals, Then delegates to listGoalsHandler", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal1 = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Goal 1" })
          );

          // Complete first goal so we can create second
          yield* service.completeGoal(
            new CompleteGoalCommand({ goalId: goal1.id })
          );

          yield* service.createGoal(
            new CreateGoalCommand({ objective: "Goal 2" })
          );

          return yield* service.listGoals(new ListGoalsQuery({}));
        });

        const goals = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(goals.length).toBeGreaterThanOrEqual(2);
      });

      it("When getting active goal, Then delegates to getActiveGoalHandler", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const created = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Active test" })
          );

          const active = yield* service.getActiveGoal();

          return { created, active };
        });

        const { created, active } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(active?.id).toBe(created.id);
        expect(active?.status).toBe("active");
      });
    });
  });

  describe("Integration with domain layer", () => {
    it("When performing lifecycle operations, Then domain logic is enforced", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;

        const goal1 = yield* service.createGoal(
          new CreateGoalCommand({ objective: "First" })
        );

        // Should fail: cannot create second active goal
        const attemptSecond = yield* Effect.either(
          service.createGoal(
            new CreateGoalCommand({ objective: "Second" })
          )
        );

        return { goal1, attemptSecond };
      });

      const { goal1, attemptSecond } = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(goal1).toBeDefined();
      expect(attemptSecond._tag).toBe("Left");
      if (attemptSecond._tag === "Left") {
        expect(attemptSecond.left.message).toMatch(/Active goal already exists/);
      }
    });

    it("When querying after state changes, Then reflects current state", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;

        const goal = yield* service.createGoal(
          new CreateGoalCommand({ objective: "State test" })
        );

        const active1 = yield* service.getActiveGoal();

        yield* service.pauseGoal(new PauseGoalCommand({ goalId: goal.id }));

        const active2 = yield* service.getActiveGoal();

        yield* service.resumeGoal(new ResumeGoalCommand({ goalId: goal.id }));

        const active3 = yield* service.getActiveGoal();

        return { active1, active2, active3, goalId: goal.id };
      });

      const { active1, active2, active3, goalId } = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(active1?.id).toBe(goalId);
      expect(active2).toBeNull();
      expect(active3?.id).toBe(goalId);
    });
  });

  describe("Error handling", () => {
    it("When operating on nonexistent goal, Then errors propagate correctly", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.getGoal(
          new GetGoalQuery({ goalId: "does-not-exist" })
        );
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow(/Goal not found/);
    });

    it("When pausing nonexistent goal, Then error is thrown", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.pauseGoal(
          new PauseGoalCommand({ goalId: "does-not-exist" })
        );
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow(/Goal not found/);
    });
  });

  describe("Query consistency", () => {
    it("When listing and getting individually, Then data matches", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;

        const created = yield* service.createGoal(
          new CreateGoalCommand({
            objective: "Consistency test",
            context: "Test context",
          })
        );

        const listed = yield* service.listGoals(new ListGoalsQuery({}));
        const fetched = yield* service.getGoal(
          new GetGoalQuery({ goalId: created.id })
        );

        return { created, listed, fetched };
      });

      const { created, listed, fetched } = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      const listedGoal = listed.find((g) => g.id === created.id);
      expect(listedGoal).toBeDefined();
      expect(listedGoal?.objective).toBe(fetched.objective);
      expect(listedGoal?.context).toBe(fetched.context);
      expect(listedGoal?.status).toBe(fetched.status);
    });
  });
});
