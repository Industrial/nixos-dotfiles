/**
 * ListGoalsQuery - BDD Tests
 *
 * Comprehensive input/output mutation tests using Given/When/Then pattern.
 */
import { describe, it, expect } from "bun:test";
import { Effect, Layer } from "effect";
import { ListGoalsQuery, listGoalsHandler } from "./ListGoalsQuery.js";
import { CreateGoalCommand, createGoalHandler } from "../commands/CreateGoalCommand.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { GoalLifecycleServiceLive } from "../../domain/services/GoalLifecycleServiceLive.js";
import { GoalRepositoryMock } from "../../infrastructure/persistence/GoalRepositoryMock.js";

describe("ListGoalsQuery", () => {
  const TestLayer = GoalLifecycleServiceLive.pipe(
    Layer.provide(GoalRepositoryMock)
  ).pipe(Layer.merge(GoalRepositoryMock));

  describe("Schema Validation", () => {
    describe("Given valid query input", () => {
      it("When creating query with no parameters, Then query is created", () => {
        const query = new ListGoalsQuery({});

        expect(query.status).toBeUndefined();
        expect(query.limit).toBeUndefined();
        expect(query.offset).toBeUndefined();
      });

      it("When creating query with status only, Then query is created", () => {
        const query = new ListGoalsQuery({
          status: "active",
        });

        expect(query.status).toBe("active");
        expect(query.limit).toBeUndefined();
        expect(query.offset).toBeUndefined();
      });

      it("When creating query with limit only, Then query is created", () => {
        const query = new ListGoalsQuery({
          limit: 10,
        });

        expect(query.limit).toBe(10);
        expect(query.status).toBeUndefined();
      });

      it("When creating query with offset only, Then query is created", () => {
        const query = new ListGoalsQuery({
          offset: 5,
        });

        expect(query.offset).toBe(5);
      });

      it("When creating query with all parameters, Then all are set", () => {
        const query = new ListGoalsQuery({
          status: "completed",
          limit: 20,
          offset: 10,
        });

        expect(query.status).toBe("completed");
        expect(query.limit).toBe(20);
        expect(query.offset).toBe(10);
      });

      it("When creating query with different status values, Then query is created", () => {
        const statuses = ["active", "paused", "completed", "cancelled"] as const;

        statuses.forEach(status => {
          const query = new ListGoalsQuery({ status });
          expect(query.status).toBe(status);
        });
      });

      it("When creating query with limit 0, Then query is created", () => {
        const query = new ListGoalsQuery({ limit: 0 });
        expect(query.limit).toBe(0);
      });

      it("When creating query with large limit, Then query is created", () => {
        const query = new ListGoalsQuery({ limit: 999999 });
        expect(query.limit).toBe(999999);
      });
    });
  });

  describe("Query Handler Execution", () => {
    describe("Given no goals exist", () => {
      it("When executing query, Then returns empty array", async () => {
        const program = Effect.gen(function* () {
          return yield* listGoalsHandler(new ListGoalsQuery({}));
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals).toBeInstanceOf(Array);
        expect(goals.length).toBe(0);
      });

      it("When executing query with status filter, Then returns empty array", async () => {
        const program = Effect.gen(function* () {
          return yield* listGoalsHandler(
            new ListGoalsQuery({ status: "active" })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(0);
      });

      it("When executing query with pagination, Then returns empty array", async () => {
        const program = Effect.gen(function* () {
          return yield* listGoalsHandler(
            new ListGoalsQuery({ limit: 10, offset: 0 })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(0);
      });
    });

    describe("Given one goal exists", () => {
      it("When executing query without filters, Then returns array with one goal", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* listGoalsHandler(new ListGoalsQuery({}));
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(1);
        expect(goals[0].objective).toBe("Test goal");
      });

      it("When executing query with matching status filter, Then returns the goal", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* listGoalsHandler(
            new ListGoalsQuery({ status: "active" })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(1);
        expect(goals[0].status).toBe("active");
      });

      it("When executing query with non-matching status filter, Then returns empty array", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* listGoalsHandler(
            new ListGoalsQuery({ status: "completed" })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(0);
      });

      it("When executing query with limit 1, Then returns one goal", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* listGoalsHandler(
            new ListGoalsQuery({ limit: 1 })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(1);
      });

      it("When executing query with offset 0, Then returns the goal", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* listGoalsHandler(
            new ListGoalsQuery({ offset: 0 })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(1);
      });

      it("When executing query with offset 1, Then returns empty array", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* listGoalsHandler(
            new ListGoalsQuery({ offset: 1 })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(0);
      });
    });

    describe("Given multiple goals exist with different statuses", () => {
      it("When executing query without filters, Then returns all goals", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          // Create active goal
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 1" })
          );

          // Create and pause second goal
          const goal2 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 2" })
          );
          yield* service.pauseGoal(goal2.id);

          // Create and complete third goal
          const goal3 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 3" })
          );
          yield* service.completeGoal(goal3.id);

          return yield* listGoalsHandler(new ListGoalsQuery({}));
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(3);
      });

      it("When executing query with active status filter, Then returns only active goals", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Active 1" })
          );

          const paused = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Paused" })
          );
          yield* service.pauseGoal(paused.id);

          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Active 2" })
          );

          return yield* listGoalsHandler(
            new ListGoalsQuery({ status: "active" })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(2);
        expect(goals.every(g => g.status === "active")).toBe(true);
      });

      it("When executing query with paused status filter, Then returns only paused goals", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Active" })
          );

          const paused1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Paused 1" })
          );
          yield* service.pauseGoal(paused1.id);

          const paused2 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Paused 2" })
          );
          yield* service.pauseGoal(paused2.id);

          return yield* listGoalsHandler(
            new ListGoalsQuery({ status: "paused" })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(2);
        expect(goals.every(g => g.status === "paused")).toBe(true);
      });

      it("When executing query with completed status filter, Then returns only completed goals", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const completed1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Completed 1" })
          );
          yield* service.completeGoal(completed1.id);

          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Active" })
          );

          const completed2 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Completed 2" })
          );
          yield* service.completeGoal(completed2.id);

          return yield* listGoalsHandler(
            new ListGoalsQuery({ status: "completed" })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(2);
        expect(goals.every(g => g.status === "completed")).toBe(true);
      });

      it("When executing query with cancelled status filter, Then returns only cancelled goals", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const cancelled = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Cancelled" })
          );
          yield* service.cancelGoal(cancelled.id);

          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Active" })
          );

          return yield* listGoalsHandler(
            new ListGoalsQuery({ status: "cancelled" })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(1);
        expect(goals[0].status).toBe("cancelled");
      });
    });

    describe("Pagination behavior", () => {
      it("When executing query with limit less than total, Then returns limited results", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          // Create 5 goals
          for (let i = 1; i <= 5; i++) {
            const goal = yield* createGoalHandler(
              new CreateGoalCommand({ objective: `Goal ${i}` })
            );
            if (i < 5) {
              yield* service.pauseGoal(goal.id);
            }
          }

          return yield* listGoalsHandler(
            new ListGoalsQuery({ limit: 3 })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(3);
      });

      it("When executing query with limit greater than total, Then returns all results", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 1" })
          );
          yield* service.pauseGoal(goal1.id);

          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 2" })
          );

          return yield* listGoalsHandler(
            new ListGoalsQuery({ limit: 100 })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(2);
      });

      it("When executing query with offset and limit, Then returns correct page", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          // Create 5 goals
          for (let i = 1; i <= 5; i++) {
            const goal = yield* createGoalHandler(
              new CreateGoalCommand({ objective: `Goal ${i}` })
            );
            if (i < 5) {
              yield* service.pauseGoal(goal.id);
            }
          }

          // Get page 2 (offset 2, limit 2)
          return yield* listGoalsHandler(
            new ListGoalsQuery({ limit: 2, offset: 2 })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(2);
      });

      it("When executing query with offset beyond total, Then returns empty array", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 1" })
          );

          return yield* listGoalsHandler(
            new ListGoalsQuery({ offset: 10 })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(0);
      });

      it("When executing queries for sequential pages, Then results do not overlap", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          // Create 6 goals
          for (let i = 1; i <= 6; i++) {
            const goal = yield* createGoalHandler(
              new CreateGoalCommand({ objective: `Goal ${i}` })
            );
            if (i < 6) {
              yield* service.pauseGoal(goal.id);
            }
          }

          const page1 = yield* listGoalsHandler(
            new ListGoalsQuery({ limit: 2, offset: 0 })
          );

          const page2 = yield* listGoalsHandler(
            new ListGoalsQuery({ limit: 2, offset: 2 })
          );

          const page3 = yield* listGoalsHandler(
            new ListGoalsQuery({ limit: 2, offset: 4 })
          );

          return { page1, page2, page3 };
        });

        const { page1, page2, page3 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(page1.length).toBe(2);
        expect(page2.length).toBe(2);
        expect(page3.length).toBe(2);

        // Verify no ID overlaps
        const allIds = [
          ...page1.map(g => g.id),
          ...page2.map(g => g.id),
          ...page3.map(g => g.id),
        ];
        const uniqueIds = new Set(allIds);
        expect(uniqueIds.size).toBe(6);
      });
    });

    describe("Combined filters", () => {
      it("When executing query with status and limit, Then both filters apply", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          // Create 3 active goals
          for (let i = 1; i <= 3; i++) {
            yield* createGoalHandler(
              new CreateGoalCommand({ objective: `Active ${i}` })
            );
          }

          // Pause the first two
          const allGoals = yield* listGoalsHandler(new ListGoalsQuery({}));
          yield* service.pauseGoal(allGoals[0].id);
          yield* service.pauseGoal(allGoals[1].id);

          return yield* listGoalsHandler(
            new ListGoalsQuery({ status: "paused", limit: 1 })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(1);
        expect(goals[0].status).toBe("paused");
      });

      it("When executing query with status, limit, and offset, Then all filters apply", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          // Create 5 active goals
          for (let i = 1; i <= 5; i++) {
            const goal = yield* createGoalHandler(
              new CreateGoalCommand({ objective: `Goal ${i}` })
            );
            if (i !== 5) {
              yield* service.completeGoal(goal.id);
            }
          }

          return yield* listGoalsHandler(
            new ListGoalsQuery({ status: "completed", limit: 2, offset: 1 })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(2);
        expect(goals.every(g => g.status === "completed")).toBe(true);
      });
    });

    describe("Edge cases", () => {
      it("When goals have Unicode emoji in objectives, Then query returns them correctly", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Launch 🚀" })
          );

          return yield* listGoalsHandler(new ListGoalsQuery({}));
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals[0].objective).toContain("🚀");
      });

      it("When goals have very long objectives, Then query returns full text", async () => {
        const program = Effect.gen(function* () {
          const longObjective = "x".repeat(10000);
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: longObjective })
          );

          return yield* listGoalsHandler(new ListGoalsQuery({}));
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals[0].objective.length).toBe(10000);
      });

      it("When query with limit 0, Then returns empty array", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test" })
          );

          return yield* listGoalsHandler(
            new ListGoalsQuery({ limit: 0 })
          );
        });

        const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goals.length).toBe(0);
      });
    });

    describe("Query idempotency", () => {
      it("When executing same query multiple times, Then results are consistent", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const result1 = yield* listGoalsHandler(new ListGoalsQuery({}));
          const result2 = yield* listGoalsHandler(new ListGoalsQuery({}));
          const result3 = yield* listGoalsHandler(new ListGoalsQuery({}));

          return { result1, result2, result3 };
        });

        const { result1, result2, result3 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result1.length).toBe(result2.length);
        expect(result2.length).toBe(result3.length);
        expect(result1[0].id).toBe(result2[0].id);
        expect(result2[0].id).toBe(result3[0].id);
      });

      it("When no data changes between queries, Then results remain identical", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;

          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 1" })
          );

          const paused = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 2" })
          );
          yield* service.pauseGoal(paused.id);

          const snapshot1 = yield* listGoalsHandler(new ListGoalsQuery({}));

          yield* Effect.sleep("10 millis");

          const snapshot2 = yield* listGoalsHandler(new ListGoalsQuery({}));

          return { snapshot1, snapshot2 };
        });

        const { snapshot1, snapshot2 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(snapshot1.length).toBe(snapshot2.length);
        expect(snapshot1.map(g => g.id)).toEqual(snapshot2.map(g => g.id));
      });
    });
  });
});
