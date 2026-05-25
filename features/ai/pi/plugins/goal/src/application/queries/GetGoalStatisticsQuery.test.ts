/**
 * GetGoalStatisticsQuery - BDD Tests
 *
 * Tests for retrieving aggregate statistics about goals.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { GetGoalStatisticsQuery, getGoalStatisticsHandler } from "./GetGoalStatisticsQuery.js";
import { CreateGoalCommand, createGoalHandler } from "../commands/CreateGoalCommand.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { GoalLifecycleTestLayer } from "../../testing/TestLayers.js";

describe("GetGoalStatisticsQuery", () => {
  const TestLayer = GoalLifecycleTestLayer;

  describe("Query Handler Execution", () => {
    describe("Given no goals exist", () => {
      it("When querying statistics, Then all counts are zero", async () => {
        const program = Effect.gen(function* () {
          return yield* getGoalStatisticsHandler(
            new GetGoalStatisticsQuery({})
          );
        });

        const stats = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(stats.totalCount).toBe(0);
        expect(stats.activeCount).toBe(0);
        expect(stats.pausedCount).toBe(0);
        expect(stats.completedCount).toBe(0);
        expect(stats.cancelledCount).toBe(0);
        expect(stats.draftCount).toBe(0);
      });
    });

    describe("Given one active goal exists", () => {
      it("When querying statistics, Then counts reflect active goal", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* getGoalStatisticsHandler(
            new GetGoalStatisticsQuery({})
          );
        });

        const stats = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(stats.totalCount).toBe(1);
        expect(stats.activeCount).toBe(1);
        expect(stats.pausedCount).toBe(0);
        expect(stats.completedCount).toBe(0);
      });
    });

    describe("Given goals in various states", () => {
      it("When querying statistics, Then all states are counted correctly", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          // Create and complete first goal
          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 1" })
          );
          yield* service.completeGoal(goal1.id);

          // Create and cancel second goal
          const goal2 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 2" })
          );
          yield* service.cancelGoal(goal2.id);

          // Create and pause third goal
          const goal3 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 3" })
          );
          yield* service.pauseGoal(goal3.id);

          // Create fourth goal (active)
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 4" })
          );

          return yield* getGoalStatisticsHandler(
            new GetGoalStatisticsQuery({})
          );
        });

        const stats = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(stats.totalCount).toBe(4);
        expect(stats.activeCount).toBe(1);
        expect(stats.pausedCount).toBe(1);
        expect(stats.completedCount).toBe(1);
        expect(stats.cancelledCount).toBe(1);
      });
    });

    describe("Given completed goals", () => {
      it("When querying statistics, Then completion rate is calculated", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          // Create and complete 2 goals
          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 1" })
          );
          yield* service.completeGoal(goal1.id);

          const goal2 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 2" })
          );
          yield* service.completeGoal(goal2.id);

          // Create and cancel 1 goal
          const goal3 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 3" })
          );
          yield* service.cancelGoal(goal3.id);

          // Create 1 active goal
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 4" })
          );

          return yield* getGoalStatisticsHandler(
            new GetGoalStatisticsQuery({})
          );
        });

        const stats = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(stats.totalCount).toBe(4);
        expect(stats.completedCount).toBe(2);
        expect(stats.completionRate).toBe(0.5); // 2 out of 4
      });

      it("When all goals are completed, Then completion rate is 1.0", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 1" })
          );
          yield* service.completeGoal(goal1.id);

          const goal2 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 2" })
          );
          yield* service.completeGoal(goal2.id);

          return yield* getGoalStatisticsHandler(
            new GetGoalStatisticsQuery({})
          );
        });

        const stats = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(stats.completionRate).toBe(1.0);
      });

      it("When no goals are completed, Then completion rate is 0.0", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 1" })
          );

          return yield* getGoalStatisticsHandler(
            new GetGoalStatisticsQuery({})
          );
        });

        const stats = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(stats.completionRate).toBe(0.0);
      });
    });

    describe("Edge cases", () => {
      it("When querying with many goals, Then statistics are accurate", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          // Create goals and transition them to different states
          // Must complete/pause each before creating next due to "one active goal" rule

          // 5 completed
          for (let i = 1; i <= 5; i++) {
            const goal = yield* createGoalHandler(
              new CreateGoalCommand({ objective: `Goal ${i}` })
            );
            yield* service.completeGoal(goal.id);
          }

          // 2 paused
          for (let i = 6; i <= 7; i++) {
            const goal = yield* createGoalHandler(
              new CreateGoalCommand({ objective: `Goal ${i}` })
            );
            yield* service.pauseGoal(goal.id);
          }

          // 1 cancelled
          const goal8 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 8" })
          );
          yield* service.cancelGoal(goal8.id);

          // 2 active (but can only have 1 active, so pause first one)
          const goal9 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 9" })
          );
          yield* service.pauseGoal(goal9.id);

          // Resume goal9 to make it active
          yield* service.resumeGoal(goal9.id);

          return yield* getGoalStatisticsHandler(
            new GetGoalStatisticsQuery({})
          );
        });

        const stats = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(stats.totalCount).toBe(9);
        expect(stats.completedCount).toBe(5);
        expect(stats.pausedCount).toBe(2);
        expect(stats.cancelledCount).toBe(1);
        expect(stats.activeCount).toBe(1);
        expect(stats.completionRate).toBeCloseTo(0.556, 2); // 5/9
      });
    });
  });
});
