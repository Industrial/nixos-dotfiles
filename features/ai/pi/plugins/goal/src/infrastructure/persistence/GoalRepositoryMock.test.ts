/**
 * GoalRepositoryMock Tests
 * 
 * Tests the mock repository implementation itself.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";
import { GoalRepositoryMock } from "./GoalRepositoryMock.js";
import { createGoal } from "../../domain/models/Goal.js";

describe("GoalRepositoryMock", () => {
  const TestLayer = GoalRepositoryMock;

  describe("save", () => {
    it("should save a goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        const goal = createGoal("Test goal");
        return yield* repo.save(goal);
      });

      const savedGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(savedGoal.objective).toBe("Test goal");
    });
  });

  describe("findById", () => {
    it("should find a goal by ID", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        const goal = createGoal("Test goal");
        
        yield* repo.save(goal);
        return yield* repo.findById(goal.id);
      });

      const foundGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(foundGoal).not.toBeNull();
      expect(foundGoal?.objective).toBe("Test goal");
    });

    it("should return null for non-existent ID", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        return yield* repo.findById("non-existent");
      });

      const foundGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(foundGoal).toBeNull();
    });
  });

  describe("findAll", () => {
    it("should return all goals", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        
        yield* repo.save(createGoal("Goal 1"));
        yield* repo.save(createGoal("Goal 2"));
        yield* repo.save(createGoal("Goal 3"));
        
        return yield* repo.findAll();
      });

      const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(goals.length).toBe(3);
    });

    it("should filter by status", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        
        const goal1 = createGoal("Active goal");
        const goal2 = createGoal("Paused goal");
        const pausedGoal = yield* goal2.pause();
        
        yield* repo.save(goal1);
        yield* repo.save(pausedGoal);
        
        return yield* repo.findAll({ status: "active" });
      });

      const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(goals.length).toBe(1);
      expect(goals[0].status).toBe("active");
    });

    it("should respect limit and offset", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        
        for (let i = 0; i < 10; i++) {
          yield* repo.save(createGoal(`Goal ${i}`));
        }
        
        return yield* repo.findAll({ limit: 3, offset: 2 });
      });

      const goals = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(goals.length).toBe(3);
    });
  });

  describe("findActive", () => {
    it("should find active goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        
        const goal = createGoal("Active goal");
        yield* repo.save(goal);
        
        return yield* repo.findActive();
      });

      const activeGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(activeGoal).not.toBeNull();
      expect(activeGoal?.status).toBe("active");
    });

    it("should return null when no active goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        return yield* repo.findActive();
      });

      const activeGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(activeGoal).toBeNull();
    });
  });

  describe("update", () => {
    it("should update a goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        
        const goal = createGoal("Original");
        yield* repo.save(goal);
        
        const pausedGoal = yield* goal.pause();
        yield* repo.update(pausedGoal);
        
        return yield* repo.findById(goal.id);
      });

      const updatedGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(updatedGoal?.status).toBe("paused");
    });

    it("should fail to update non-existent goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        const goal = createGoal("Test");
        return yield* repo.update(goal);
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow("Goal not found");
    });
  });

  describe("delete", () => {
    it("should delete a goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        
        const goal = createGoal("To delete");
        yield* repo.save(goal);
        yield* repo.delete(goal.id);
        
        return yield* repo.findById(goal.id);
      });

      const deletedGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(deletedGoal).toBeNull();
    });
  });

  describe("exists", () => {
    it("should return true for existing goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        
        const goal = createGoal("Test");
        yield* repo.save(goal);
        
        return yield* repo.exists(goal.id);
      });

      const exists = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(exists).toBe(true);
    });

    it("should return false for non-existent goal", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        return yield* repo.exists("non-existent");
      });

      const exists = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(exists).toBe(false);
    });
  });

  describe("count", () => {
    it("should count all goals", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        
        yield* repo.save(createGoal("Goal 1"));
        yield* repo.save(createGoal("Goal 2"));
        
        return yield* repo.count();
      });

      const count = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(count).toBe(2);
    });

    it("should count goals by status", async () => {
      const program = Effect.gen(function* () {
        const repo = yield* GoalRepository;
        
        const goal1 = createGoal("Active");
        const goal2 = createGoal("Paused");
        const pausedGoal = yield* goal2.pause();
        
        yield* repo.save(goal1);
        yield* repo.save(pausedGoal);
        
        return yield* repo.count({ status: "active" });
      });

      const count = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(count).toBe(1);
    });
  });
});
