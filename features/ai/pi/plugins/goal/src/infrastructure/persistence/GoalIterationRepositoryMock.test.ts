/**
 * GoalIterationRepositoryMock Tests
 * 
 * Comprehensive tests for the mock repository implementation.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { GoalIterationRepository } from "../../domain/repositories/GoalIterationRepository.js";
import { GoalIterationRepositoryMock } from "./GoalIterationRepositoryMock.js";
import { createIteration, IterationOutcome } from "../../domain/models/GoalIteration.js";

describe("GoalIterationRepositoryMock", () => {
  const TestLayer = GoalIterationRepositoryMock;

  describe("save", () => {
    it("should save an iteration", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        const iteration = createIteration("goal-123", 1);
        return yield* repo.save(iteration);
      });

      const savedIteration = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(savedIteration.goalId).toBe("goal-123");
      expect(savedIteration.iterationNumber).toBe(1);
    });

    it("should save multiple iterations for same goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        const iter1 = createIteration("goal-123", 1);
        const iter2 = createIteration("goal-123", 2);
        const iter3 = createIteration("goal-123", 3);
        
        yield* repo.save(iter1);
        yield* repo.save(iter2);
        yield* repo.save(iter3);
        
        return yield* repo.findByGoalId("goal-123");
      });

      const iterations = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(iterations.length).toBe(3);
    });

    it("should save iterations for different goals", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        yield* repo.save(createIteration("goal-1", 1));
        yield* repo.save(createIteration("goal-2", 1));
        yield* repo.save(createIteration("goal-3", 1));
        
        const goal1Iterations = yield* repo.findByGoalId("goal-1");
        const goal2Iterations = yield* repo.findByGoalId("goal-2");
        
        return { goal1Iterations, goal2Iterations };
      });

      const { goal1Iterations, goal2Iterations } = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );
      
      expect(goal1Iterations.length).toBe(1);
      expect(goal2Iterations.length).toBe(1);
    });
  });

  describe("findById", () => {
    it("should find an iteration by ID", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        const iteration = createIteration("goal-123", 1);
        
        yield* repo.save(iteration);
        return yield* repo.findById(iteration.id);
      });

      const foundIteration = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(foundIteration).not.toBeNull();
      expect(foundIteration?.goalId).toBe("goal-123");
      expect(foundIteration?.iterationNumber).toBe(1);
    });

    it("should return null for non-existent ID", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        return yield* repo.findById("non-existent");
      });

      const foundIteration = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(foundIteration).toBeNull();
    });

    it("should find completed iteration with outcome", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        const iteration = createIteration("goal-123", 1);
        const outcome = new IterationOutcome({
          success: true,
          message: "Completed successfully",
          actionsCompleted: ["Action 1"],
          nextActions: ["Next 1"],
        });
        
        const completed = yield* iteration.complete(outcome);
        yield* repo.save(completed);
        
        return yield* repo.findById(completed.id);
      });

      const foundIteration = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(foundIteration?.completedAt).toBeDefined();
      expect(foundIteration?.outcome?.success).toBe(true);
    });
  });

  describe("findByGoalId", () => {
    it("should find all iterations for a goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        yield* repo.save(createIteration("goal-123", 1));
        yield* repo.save(createIteration("goal-123", 2));
        yield* repo.save(createIteration("goal-123", 3));
        
        return yield* repo.findByGoalId("goal-123");
      });

      const iterations = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(iterations.length).toBe(3);
    });

    it("should return iterations ordered by iteration number descending", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        // Save in random order
        yield* repo.save(createIteration("goal-123", 2));
        yield* repo.save(createIteration("goal-123", 5));
        yield* repo.save(createIteration("goal-123", 1));
        yield* repo.save(createIteration("goal-123", 3));
        
        return yield* repo.findByGoalId("goal-123");
      });

      const iterations = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(iterations[0].iterationNumber).toBe(5);
      expect(iterations[1].iterationNumber).toBe(3);
      expect(iterations[2].iterationNumber).toBe(2);
      expect(iterations[3].iterationNumber).toBe(1);
    });

    it("should return empty array for goal with no iterations", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        return yield* repo.findByGoalId("non-existent-goal");
      });

      const iterations = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(iterations.length).toBe(0);
    });

    it("should only return iterations for specified goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        yield* repo.save(createIteration("goal-1", 1));
        yield* repo.save(createIteration("goal-1", 2));
        yield* repo.save(createIteration("goal-2", 1));
        
        return yield* repo.findByGoalId("goal-1");
      });

      const iterations = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(iterations.length).toBe(2);
      expect(iterations.every((i) => i.goalId === "goal-1")).toBe(true);
    });
  });

  describe("findLatest", () => {
    it("should find latest iteration for a goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        yield* repo.save(createIteration("goal-123", 1));
        yield* repo.save(createIteration("goal-123", 2));
        yield* repo.save(createIteration("goal-123", 3));
        
        return yield* repo.findLatest("goal-123");
      });

      const latestIteration = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(latestIteration).not.toBeNull();
      expect(latestIteration?.iterationNumber).toBe(3);
    });

    it("should return null for goal with no iterations", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        return yield* repo.findLatest("non-existent-goal");
      });

      const latestIteration = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(latestIteration).toBeNull();
    });

    it("should return the only iteration when goal has one", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        const iteration = createIteration("goal-123", 1);
        yield* repo.save(iteration);
        
        return yield* repo.findLatest("goal-123");
      });

      const latestIteration = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(latestIteration).not.toBeNull();
      expect(latestIteration?.iterationNumber).toBe(1);
    });

    it("should find latest among multiple goals", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        // Goal 1 has iterations 1, 2, 3
        yield* repo.save(createIteration("goal-1", 1));
        yield* repo.save(createIteration("goal-1", 2));
        yield* repo.save(createIteration("goal-1", 3));
        
        // Goal 2 has iterations 1, 2
        yield* repo.save(createIteration("goal-2", 1));
        yield* repo.save(createIteration("goal-2", 2));
        
        const latest1 = yield* repo.findLatest("goal-1");
        const latest2 = yield* repo.findLatest("goal-2");
        
        return { latest1, latest2 };
      });

      const { latest1, latest2 } = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );
      
      expect(latest1?.iterationNumber).toBe(3);
      expect(latest2?.iterationNumber).toBe(2);
    });
  });

  describe("update", () => {
    it("should update an iteration", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        const iteration = createIteration("goal-123", 1);
        yield* repo.save(iteration);
        
        const outcome = new IterationOutcome({
          success: true,
          message: "Updated",
          actionsCompleted: [],
          nextActions: [],
        });
        const updated = yield* iteration.complete(outcome);
        
        yield* repo.update(updated);
        
        return yield* repo.findById(iteration.id);
      });

      const foundIteration = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(foundIteration?.completedAt).toBeDefined();
      expect(foundIteration?.outcome?.message).toBe("Updated");
    });

    it("should fail to update non-existent iteration", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        const iteration = createIteration("goal-123", 1);
        return yield* repo.update(iteration);
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow("Iteration not found");
    });

    it("should preserve other iterations when updating one", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        const iter1 = createIteration("goal-123", 1);
        const iter2 = createIteration("goal-123", 2);
        
        yield* repo.save(iter1);
        yield* repo.save(iter2);
        
        const outcome = new IterationOutcome({
          success: true,
          message: "Test",
          actionsCompleted: [],
          nextActions: [],
        });
        const updated = yield* iter1.complete(outcome);
        yield* repo.update(updated);
        
        const all = yield* repo.findByGoalId("goal-123");
        return all;
      });

      const iterations = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(iterations.length).toBe(2);
      expect(iterations.find((i) => i.iterationNumber === 1)?.completedAt).toBeDefined();
      expect(iterations.find((i) => i.iterationNumber === 2)?.completedAt).toBeUndefined();
    });
  });

  describe("delete", () => {
    it("should delete an iteration", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        const iteration = createIteration("goal-123", 1);
        yield* repo.save(iteration);
        yield* repo.delete(iteration.id);
        
        return yield* repo.findById(iteration.id);
      });

      const deletedIteration = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(deletedIteration).toBeNull();
    });

    it("should not affect other iterations when deleting one", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        const iter1 = createIteration("goal-123", 1);
        const iter2 = createIteration("goal-123", 2);
        
        yield* repo.save(iter1);
        yield* repo.save(iter2);
        yield* repo.delete(iter1.id);
        
        return yield* repo.findByGoalId("goal-123");
      });

      const iterations = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(iterations.length).toBe(1);
      expect(iterations[0].iterationNumber).toBe(2);
    });
  });

  describe("deleteByGoalId", () => {
    it("should delete all iterations for a goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        yield* repo.save(createIteration("goal-123", 1));
        yield* repo.save(createIteration("goal-123", 2));
        yield* repo.save(createIteration("goal-123", 3));
        
        yield* repo.deleteByGoalId("goal-123");
        
        return yield* repo.findByGoalId("goal-123");
      });

      const iterations = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(iterations.length).toBe(0);
    });

    it("should only delete iterations for specified goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        yield* repo.save(createIteration("goal-1", 1));
        yield* repo.save(createIteration("goal-1", 2));
        yield* repo.save(createIteration("goal-2", 1));
        
        yield* repo.deleteByGoalId("goal-1");
        
        const goal1Iterations = yield* repo.findByGoalId("goal-1");
        const goal2Iterations = yield* repo.findByGoalId("goal-2");
        
        return { goal1Iterations, goal2Iterations };
      });

      const { goal1Iterations, goal2Iterations } = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );
      
      expect(goal1Iterations.length).toBe(0);
      expect(goal2Iterations.length).toBe(1);
    });

    it("should succeed even if goal has no iterations", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        yield* repo.deleteByGoalId("non-existent-goal");
        return yield* repo.findByGoalId("non-existent-goal");
      });

      const iterations = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(iterations.length).toBe(0);
    });
  });

  describe("countByGoalId", () => {
    it("should count iterations for a goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        yield* repo.save(createIteration("goal-123", 1));
        yield* repo.save(createIteration("goal-123", 2));
        yield* repo.save(createIteration("goal-123", 3));
        
        return yield* repo.countByGoalId("goal-123");
      });

      const count = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(count).toBe(3);
    });

    it("should return 0 for goal with no iterations", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        return yield* repo.countByGoalId("non-existent-goal");
      });

      const count = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(count).toBe(0);
    });

    it("should count only iterations for specified goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        yield* repo.save(createIteration("goal-1", 1));
        yield* repo.save(createIteration("goal-1", 2));
        yield* repo.save(createIteration("goal-2", 1));
        
        return yield* repo.countByGoalId("goal-1");
      });

      const count = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(count).toBe(2);
    });

    it("should update count after deletions", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        const iter1 = createIteration("goal-123", 1);
        const iter2 = createIteration("goal-123", 2);
        
        yield* repo.save(iter1);
        yield* repo.save(iter2);
        
        const countBefore = yield* repo.countByGoalId("goal-123");
        
        yield* repo.delete(iter1.id);
        
        const countAfter = yield* repo.countByGoalId("goal-123");
        
        return { countBefore, countAfter };
      });

      const { countBefore, countAfter } = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );
      
      expect(countBefore).toBe(2);
      expect(countAfter).toBe(1);
    });
  });

  describe("Completed vs In-Progress Iterations", () => {
    it("should store both completed and in-progress iterations", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        const inProgress = createIteration("goal-123", 1);
        const completed = createIteration("goal-123", 2);
        const outcome = new IterationOutcome({
          success: true,
          message: "Done",
          actionsCompleted: ["A"],
          nextActions: [],
        });
        const completedIteration = yield* completed.complete(outcome);
        
        yield* repo.save(inProgress);
        yield* repo.save(completedIteration);
        
        return yield* repo.findByGoalId("goal-123");
      });

      const iterations = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(iterations.length).toBe(2);
      
      const inProgress = iterations.find((i) => !i.completedAt);
      const completed = iterations.find((i) => i.completedAt);
      
      expect(inProgress).toBeDefined();
      expect(completed).toBeDefined();
      expect(completed?.outcome?.success).toBe(true);
    });

    it("should find latest even if it's in progress", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalIterationRepository;
        
        const completed = createIteration("goal-123", 1);
        const outcome = new IterationOutcome({
          success: true,
          message: "Done",
          actionsCompleted: [],
          nextActions: [],
        });
        const completedIteration = yield* completed.complete(outcome);
        
        const inProgress = createIteration("goal-123", 2);
        
        yield* repo.save(completedIteration);
        yield* repo.save(inProgress);
        
        return yield* repo.findLatest("goal-123");
      });

      const latest = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(latest?.iterationNumber).toBe(2);
      expect(latest?.completedAt).toBeUndefined();
    });
  });
});
