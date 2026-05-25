/**
 * GetGoalQuery - BDD Tests
 * 
 * Comprehensive input/output mutation tests using Given/When/Then pattern.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { GetGoalQuery, getGoalHandler } from "./GetGoalQuery.js";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";
import { GoalRepositoryMock } from "../../infrastructure/persistence/GoalRepositoryMock.js";
import { createGoal, GoalEvaluation } from "../../domain/models/Goal.js";

describe("GetGoalQuery", () => {
  const TestLayer = GoalRepositoryMock;

  describe("Schema Validation", () => {
    describe("Given valid query input", () => {
      it("When creating query with valid goal ID, Then query is created successfully", () => {
        const query = new GetGoalQuery({
          goalId: "goal-123",
        });

        expect(query.goalId).toBe("goal-123");
      });

      it("When creating query with UUID-style ID, Then query is created", () => {
        const query = new GetGoalQuery({
          goalId: "550e8400-e29b-41d4-a716-446655440000",
        });

        expect(query.goalId).toBe("550e8400-e29b-41d4-a716-446655440000");
      });

      it("When creating query with special characters in ID, Then query is created", () => {
        const query = new GetGoalQuery({
          goalId: "goal-abc_123-xyz",
        });

        expect(query.goalId).toBe("goal-abc_123-xyz");
      });

      it("When creating query with very long ID, Then query is created", () => {
        const longId = "goal-" + "a".repeat(1000);
        const query = new GetGoalQuery({
          goalId: longId,
        });

        expect(query.goalId).toBe(longId);
      });
    });
  });

  describe("Query Handler Execution", () => {
    describe("Given an active goal exists", () => {
      it("When executing get query, Then goal is returned with all properties", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Test goal", "Test context");
          yield* repo.save(goal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: goal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.objective).toBe("Test goal");
        expect(result.context).toBe("Test context");
        expect(result.status).toBe("active");
        expect(result.id).toBeDefined();
        expect(result.createdAt).toBeGreaterThan(0);
        expect(result.updatedAt).toBe(result.createdAt);
        expect(result.completedAt).toBeUndefined();
        expect(result.evaluationData).toBeUndefined();
      });

      it("When executing get query, Then returned goal has correct timestamps", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Test goal");
          yield* repo.save(goal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: goal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.createdAt).toBe(result.updatedAt);
        expect(result.createdAt).toBeGreaterThan(0);
      });

      it("When executing get query, Then goal without context is returned correctly", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Test goal without context");
          yield* repo.save(goal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: goal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.objective).toBe("Test goal without context");
        expect(result.context).toBeUndefined();
      });

      it("When executing get query with Unicode in objective, Then goal is returned correctly", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Test 🚀 goal with émojis");
          yield* repo.save(goal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: goal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.objective).toContain("🚀");
        expect(result.objective).toContain("émojis");
      });
    });

    describe("Given a paused goal exists", () => {
      it("When executing get query, Then paused goal is returned with correct status", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;

          const goal = createGoal("Test goal");
          const pausedGoal = yield* goal.pause();
          yield* repo.save(pausedGoal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: pausedGoal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.status).toBe("paused");
        expect(result.updatedAt).toBeGreaterThanOrEqual(result.createdAt);
        expect(result.completedAt).toBeUndefined();
      });

      it("When executing get query on paused goal, Then all properties are preserved", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Original objective", "Original context");
          const pausedGoal = yield* goal.pause();
          yield* repo.save(pausedGoal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: pausedGoal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.objective).toBe("Original objective");
        expect(result.context).toBe("Original context");
        expect(result.status).toBe("paused");
      });
    });

    describe("Given a completed goal exists", () => {
      it("When executing get query, Then completed goal is returned with completion timestamp", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Test goal");
          const completedGoal = yield* goal.complete();
          yield* repo.save(completedGoal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: completedGoal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.status).toBe("completed");
        expect(result.completedAt).toBeGreaterThan(0);
        expect(result.completedAt).toBe(result.updatedAt);
      });

      it("When executing get query on completed goal, Then timestamps are consistent", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;

          const goal = createGoal("Test goal");
          const completedGoal = yield* goal.complete();
          yield* repo.save(completedGoal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: completedGoal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.createdAt).toBeLessThanOrEqual(result.updatedAt);
        expect(result.completedAt).toBe(result.updatedAt);
        expect(result.completedAt).toBeGreaterThanOrEqual(result.createdAt);
      });
    });

    describe("Given a cancelled goal exists", () => {
      it("When executing get query, Then cancelled goal is returned with completion timestamp", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Test goal");
          const cancelledGoal = yield* goal.cancel();
          yield* repo.save(cancelledGoal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: cancelledGoal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.status).toBe("cancelled");
        expect(result.completedAt).toBeGreaterThan(0);
        expect(result.completedAt).toBe(result.updatedAt);
      });

      it("When executing get query on cancelled goal, Then all data is preserved", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Cancelled goal", "Was not feasible");
          const cancelledGoal = yield* goal.cancel();
          yield* repo.save(cancelledGoal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: cancelledGoal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.objective).toBe("Cancelled goal");
        expect(result.context).toBe("Was not feasible");
        expect(result.status).toBe("cancelled");
      });
    });

    describe("Given goal does not exist", () => {
      it("When executing get query with non-existent ID, Then query fails with not found error", async () => {
        const program = Effect.gen(function* () {
          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: "non-existent-id" })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Goal not found/);
      });

      it("When executing get query with empty ID, Then query fails with not found error", async () => {
        const program = Effect.gen(function* () {
          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: "" })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Goal not found/);
      });

      it("When executing get query with malformed ID, Then query fails with not found error", async () => {
        const program = Effect.gen(function* () {
          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: "malformed-###-id" })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Goal not found/);
      });
    });

    describe("Given multiple goals exist", () => {
      it("When executing get query for specific goal, Then only that goal is returned", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal1 = createGoal("Goal 1");
          const goal2 = createGoal("Goal 2");
          const goal3 = createGoal("Goal 3");
          
          yield* repo.save(goal1);
          yield* repo.save(goal2);
          yield* repo.save(goal3);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: goal2.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.objective).toBe("Goal 2");
      });

      it("When executing get query multiple times, Then same goal data is returned", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Consistent goal");
          yield* repo.save(goal);

          const query = new GetGoalQuery({ goalId: goal.id });
          const result1 = yield* getGoalHandler(query);
          const result2 = yield* getGoalHandler(query);

          return { result1, result2 };
        });

        const { result1, result2 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result1.id).toBe(result2.id);
        expect(result1.objective).toBe(result2.objective);
        expect(result1.status).toBe(result2.status);
        expect(result1.createdAt).toBe(result2.createdAt);
      });
    });

    describe("Edge cases and boundary conditions", () => {
      it("When getting goal with evaluation data, Then evaluation data is returned", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;

          const goal = createGoal("Goal with evaluation");
          const evaluation = new GoalEvaluation({
            progress: 75,
            blockers: ["Waiting for review"],
            nextSteps: ["Address feedback", "Deploy"],
            notes: "Good progress",
          });
          const withEval = goal.updateEvaluation(evaluation);
          yield* repo.save(withEval);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: withEval.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.evaluationData).toBeDefined();
        expect(result.evaluationData?.progress).toBe(75);
        expect(result.evaluationData?.blockers).toContain("Waiting for review");
        expect(result.evaluationData?.nextSteps).toHaveLength(2);
      });

      it("When getting goal with very long objective, Then full objective is returned", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const longObjective = "a".repeat(10000);
          const goal = createGoal(longObjective);
          yield* repo.save(goal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: goal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.objective.length).toBe(10000);
      });

      it("When getting goal with newlines in objective, Then newlines are preserved", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Line 1\nLine 2\nLine 3");
          yield* repo.save(goal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: goal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.objective).toContain("\n");
        expect(result.objective.split("\n")).toHaveLength(3);
      });

      it("When getting goal that was updated, Then latest state is returned", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Original");
          yield* repo.save(goal);

          const pausedGoal = yield* goal.pause();
          yield* repo.update(pausedGoal);

          return yield* getGoalHandler(
            new GetGoalQuery({ goalId: goal.id })
          );
        });

        const result = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(result.status).toBe("paused");
      });
    });

    describe("Query idempotency", () => {
      it("When executing same query multiple times, Then results are identical", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Idempotent test");
          yield* repo.save(goal);

          const query = new GetGoalQuery({ goalId: goal.id });
          
          const results = yield* Effect.all([
            getGoalHandler(query),
            getGoalHandler(query),
            getGoalHandler(query),
          ]);

          return results;
        });

        const [r1, r2, r3] = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(r1).toEqual(r2);
        expect(r2).toEqual(r3);
      });

      it("When no state changes between queries, Then data remains consistent", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Consistent state");
          yield* repo.save(goal);

          const query = new GetGoalQuery({ goalId: goal.id });
          
          const before = yield* getGoalHandler(query);
          // Simulate time passing without changes
          yield* Effect.sleep("10 millis");
          const after = yield* getGoalHandler(query);

          return { before, after };
        });

        const { before, after } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(before.id).toBe(after.id);
        expect(before.objective).toBe(after.objective);
        expect(before.status).toBe(after.status);
        expect(before.createdAt).toBe(after.createdAt);
        expect(before.updatedAt).toBe(after.updatedAt);
      });
    });

    describe("Query isolation", () => {
      it("When one query fails, Then other queries are not affected", async () => {
        const program = Effect.gen(function* () {
          const repo = yield* GoalRepository;
          
          const goal = createGoal("Valid goal");
          yield* repo.save(goal);

          // Failing query
          const failingQuery = getGoalHandler(
            new GetGoalQuery({ goalId: "non-existent" })
          );

          // Successful query
          const successQuery = getGoalHandler(
            new GetGoalQuery({ goalId: goal.id })
          );

          // Run successful query even if failing query fails
          const result = yield* successQuery;

          return { result, failingQuery };
        });

        const { result, failingQuery } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.objective).toBe("Valid goal");
        
        await expect(
          Effect.runPromise(failingQuery.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow();
      });
    });
  });
});
