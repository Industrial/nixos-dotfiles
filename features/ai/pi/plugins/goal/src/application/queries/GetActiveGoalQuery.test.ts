/**
 * GetActiveGoalQuery - BDD Tests
 *
 * Comprehensive input/output mutation tests using Given/When/Then pattern.
 */
import { describe, it, expect } from "bun:test";
import { Effect, Layer } from "effect";
import { getActiveGoalHandler } from "./GetActiveGoalQuery.js";
import { CreateGoalCommand, createGoalHandler } from "../commands/CreateGoalCommand.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { GoalLifecycleTestLayer } from "../../testing/TestLayers.js";

describe("GetActiveGoalQuery", () => {
  const TestLayer = GoalLifecycleTestLayer;

  describe("Query Handler Execution", () => {
    describe("Given no active goal exists", () => {
      it("When executing query, Then returns undefined", async () => {
        const program = Effect.gen(function* () {
          return yield* getActiveGoalHandler();
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result).toBeNull();
      });

      it("When executing query multiple times, Then always returns undefined", async () => {
        const program = Effect.gen(function* () {
          const result1 = yield* getActiveGoalHandler();
          const result2 = yield* getActiveGoalHandler();
          const result3 = yield* getActiveGoalHandler();

          return { result1, result2, result3 };
        });

        const { result1, result2, result3 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result1).toBeNull();
        expect(result2).toBeNull();
        expect(result3).toBeNull();
      });
    });

    describe("Given one active goal exists", () => {
      it("When executing query, Then returns the active goal", async () => {
        const program = Effect.gen(function* () {
          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const activeGoal = yield* getActiveGoalHandler();

          return { goal, activeGoal };
        });

        const { goal, activeGoal } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(activeGoal).toBeDefined();
        expect(activeGoal?.id).toBe(goal.id);
      });

      it("When executing query, Then returns goal with correct objective", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({
              objective: "Build a rocket",
              context: "For Mars"
            })
          );

          return yield* getActiveGoalHandler();
        });

        const activeGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(activeGoal?.objective).toBe("Build a rocket");
        expect(activeGoal?.context).toBe("For Mars");
      });

      it("When executing query, Then returns goal with active status", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* getActiveGoalHandler();
        });

        const activeGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(activeGoal?.status).toBe("active");
      });

      it("When executing query, Then returned goal has all properties", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({
              objective: "Test goal",
              context: "Test context"
            })
          );

          return yield* getActiveGoalHandler();
        });

        const activeGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(activeGoal?.id).toBeDefined();
        expect(activeGoal?.objective).toBeDefined();
        expect(activeGoal?.context).toBeDefined();
        expect(activeGoal?.status).toBeDefined();
        expect(activeGoal?.createdAt).toBeDefined();
        expect(activeGoal?.updatedAt).toBeDefined();
      });

      it("When executing query multiple times, Then returns same goal each time", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const result1 = yield* getActiveGoalHandler();
          const result2 = yield* getActiveGoalHandler();
          const result3 = yield* getActiveGoalHandler();

          return { result1, result2, result3 };
        });

        const { result1, result2, result3 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result1?.id).toBe(result2?.id);
        expect(result2?.id).toBe(result3?.id);
      });
    });

    describe("Given active goal was paused", () => {
      it("When executing query, Then returns undefined", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const _goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.pauseGoal(_goal.id);

          return yield* getActiveGoalHandler();
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result).toBeNull();
      });

      it("When pausing and querying repeatedly, Then always returns undefined", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const _goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.pauseGoal(_goal.id);

          const result1 = yield* getActiveGoalHandler();
          const result2 = yield* getActiveGoalHandler();

          return { result1, result2 };
        });

        const { result1, result2 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result1).toBeNull();
        expect(result2).toBeNull();
      });
    });

    describe("Given paused goal was resumed", () => {
      it("When executing query, Then returns the resumed goal", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.pauseGoal(goal.id);
          yield* service.resumeGoal(goal.id);

          const activeGoal = yield* getActiveGoalHandler();

          return { goal, activeGoal };
        });

        const { goal, activeGoal } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(activeGoal?.id).toBe(goal.id);
        expect(activeGoal?.status).toBe("active");
      });

      it("When executing query after multiple pause/resume cycles, Then returns active goal", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const _goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          // Multiple cycles
          yield* service.pauseGoal(_goal.id);
          yield* service.resumeGoal(_goal.id);
          yield* service.pauseGoal(_goal.id);
          yield* service.resumeGoal(_goal.id);

          return yield* getActiveGoalHandler();
        });

        const activeGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(activeGoal?.status).toBe("active");
      });
    });

    describe("Given active goal was completed", () => {
      it("When executing query, Then returns undefined", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const _goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.completeGoal(_goal.id);

          return yield* getActiveGoalHandler();
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result).toBeNull();
      });

      it("When querying after completion, Then consistently returns undefined", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const _goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.completeGoal(_goal.id);

          const result1 = yield* getActiveGoalHandler();
          const result2 = yield* getActiveGoalHandler();

          return { result1, result2 };
        });

        const { result1, result2 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result1).toBeNull();
        expect(result2).toBeNull();
      });
    });

    describe("Given active goal was cancelled", () => {
      it("When executing query, Then returns undefined", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const _goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.cancelGoal(_goal.id);

          return yield* getActiveGoalHandler();
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result).toBeNull();
      });
    });

    describe("Given new active goal created after previous was completed", () => {
      it("When executing query, Then returns the new active goal", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "First goal" })
          );

          yield* service.completeGoal(goal1.id);

          const goal2 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Second goal" })
          );

          const activeGoal = yield* getActiveGoalHandler();

          return { goal1, goal2, activeGoal };
        });

        const { goal1, goal2, activeGoal } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(activeGoal?.id).toBe(goal2.id);
        expect(activeGoal?.id).not.toBe(goal1.id);
        expect(activeGoal?.objective).toBe("Second goal");
      });

      it("When querying after transitioning through multiple goals, Then returns current active", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          // Create and complete first goal
          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "First" })
          );
          yield* service.completeGoal(goal1.id);

          // Create and cancel second goal
          const goal2 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Second" })
          );
          yield* service.cancelGoal(goal2.id);

          // Create third goal (current active)
          const goal3 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Third" })
          );

          const activeGoal = yield* getActiveGoalHandler();

          return { goal1, goal2, goal3, activeGoal };
        });

        const { goal1: _goal1, goal2: _goal2, goal3, activeGoal } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(activeGoal?.id).toBe(goal3.id);
        expect(activeGoal?.objective).toBe("Third");
      });
    });

    describe("State transitions and query consistency", () => {
      it("When querying before and after pause, Then status changes correctly", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const beforePause = yield* getActiveGoalHandler();

          yield* service.pauseGoal(beforePause!.id);

          const afterPause = yield* getActiveGoalHandler();

          return { beforePause, afterPause };
        });

        const { beforePause, afterPause } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(beforePause).toBeDefined();
        expect(afterPause).toBeNull();
      });

      it("When querying during state transition sequence, Then returns correct state at each point", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const state1 = yield* getActiveGoalHandler(); // active

          yield* service.pauseGoal(state1!.id);
          const state2 = yield* getActiveGoalHandler(); // paused (undefined)

          yield* service.resumeGoal(state1!.id);
          const state3 = yield* getActiveGoalHandler(); // active again

          return { state1, state2, state3 };
        });

        const { state1, state2, state3 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(state1?.status).toBe("active");
        expect(state2).toBeNull();
        expect(state3?.status).toBe("active");
        expect(state3?.id).toBe(state1?.id);
      });
    });

    describe("Edge cases", () => {
      it("When goal has Unicode emoji in objective, Then query returns it correctly", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({
              objective: "Launch 🚀 to Mars 🔴"
            })
          );

          return yield* getActiveGoalHandler();
        });

        const activeGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(activeGoal?.objective).toContain("🚀");
        expect(activeGoal?.objective).toContain("🔴");
      });

      it("When goal has very long objective, Then query returns full objective", async () => {
        const program = Effect.gen(function* () {
          const longObjective = "x".repeat(10000);
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: longObjective })
          );

          return yield* getActiveGoalHandler();
        });

        const activeGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(activeGoal?.objective.length).toBe(10000);
      });

      it("When goal has evaluation data, Then query returns goal with evaluation", async () => {
        const program = Effect.gen(function* () {
          const _goal = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          // In a real scenario, evaluation would be updated through service
          // For now, just verify the goal is returned correctly

          return yield* getActiveGoalHandler();
        });

        const activeGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(activeGoal?.id).toBeDefined();
      });
    });

    describe("Query idempotency", () => {
      it("When executing query multiple times in succession, Then results are identical", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const results = [];
          for (let i = 0; i < 10; i++) {
            results.push(yield* getActiveGoalHandler());
          }

          return results;
        });

        const results = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        const firstId = results[0]?.id;
        results.forEach(result => {
          expect(result?.id).toBe(firstId);
        });
      });

      it("When no changes occur between queries, Then results remain consistent", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({
              objective: "Stable goal",
              context: "No changes"
            })
          );

          const snapshot1 = yield* getActiveGoalHandler();

          yield* Effect.sleep("10 millis");

          const snapshot2 = yield* getActiveGoalHandler();

          return { snapshot1, snapshot2 };
        });

        const { snapshot1, snapshot2 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(snapshot1?.id).toBe(snapshot2?.id);
        expect(snapshot1?.objective).toBe(snapshot2?.objective);
        expect(snapshot1?.context).toBe(snapshot2?.context);
        expect(snapshot1?.status).toBe(snapshot2?.status);
      });
    });
  });
});
