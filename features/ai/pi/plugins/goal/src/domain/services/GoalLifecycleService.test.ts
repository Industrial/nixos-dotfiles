/**
 * GoalLifecycleService Tests
 * 
 * Tests the domain service using Mock repositories - no database required!
 */
import { describe, it, expect } from "bun:test";
import { Effect, Layer } from "effect";
import { GoalLifecycleService } from "./GoalLifecycleService.js";
import { GoalLifecycleServiceLive } from "./GoalLifecycleServiceLive.js";
import { GoalRepositoryMock } from "../../infrastructure/persistence/GoalRepositoryMock.js";

describe("GoalLifecycleService", () => {
  // Test layer using mock repository - no database!
  const TestLayer = GoalLifecycleServiceLive.pipe(
    Layer.provide(GoalRepositoryMock)
  );

  describe("createGoal", () => {
    it("should create a new goal when none is active", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        return yield* service.createGoal("Build a rocket", "For Mars mission");
      });

      const goal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(goal.objective).toBe("Build a rocket");
      expect(goal.context).toBe("For Mars mission");
      expect(goal.status).toBe("active");
    });

    it("should fail when an active goal already exists", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        
        // Create first goal
        yield* service.createGoal("First goal");
        
        // Try to create second goal - should fail
        return yield* service.createGoal("Second goal");
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow("Active goal already exists");
    });

    it("should allow creating goal after pausing the active one", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        
        // Create and pause first goal
        const goal1 = yield* service.createGoal("First goal");
        yield* service.pauseGoal(goal1.id);
        
        // Now we can create a second goal
        return yield* service.createGoal("Second goal");
      });

      const goal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(goal.objective).toBe("Second goal");
      expect(goal.status).toBe("active");
    });
  });

  describe("pauseGoal", () => {
    it("should pause an active goal", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        
        const goal = yield* service.createGoal("Test goal");
        return yield* service.pauseGoal(goal.id);
      });

      const pausedGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(pausedGoal.status).toBe("paused");
    });

    it("should fail to pause a non-existent goal", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        return yield* service.pauseGoal("non-existent-id");
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow("Goal not found");
    });
  });

  describe("resumeGoal", () => {
    it("should resume a paused goal", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        
        const goal = yield* service.createGoal("Test goal");
        yield* service.pauseGoal(goal.id);
        return yield* service.resumeGoal(goal.id);
      });

      const resumedGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(resumedGoal.status).toBe("active");
    });

    it("should fail when another goal is already active", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        
        // Create first goal and pause it
        const goal1 = yield* service.createGoal("First goal");
        yield* service.pauseGoal(goal1.id);
        
        // Create second goal (now active)
        yield* service.createGoal("Second goal");
        
        // Try to resume first goal - should fail
        return yield* service.resumeGoal(goal1.id);
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow("Another goal is already active");
    });
  });

  describe("completeGoal", () => {
    it("should complete a goal", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        
        const goal = yield* service.createGoal("Test goal");
        return yield* service.completeGoal(goal.id);
      });

      const completedGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(completedGoal.status).toBe("completed");
      expect(completedGoal.completedAt).toBeGreaterThan(0);
    });
  });

  describe("cancelGoal", () => {
    it("should cancel a goal", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        
        const goal = yield* service.createGoal("Test goal");
        return yield* service.cancelGoal(goal.id);
      });

      const cancelledGoal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(cancelledGoal.status).toBe("cancelled");
      expect(cancelledGoal.completedAt).toBeGreaterThan(0);
    });
  });

  describe("canActivateGoal", () => {
    it("should return true when no goal is active", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        return yield* service.canActivateGoal();
      });

      const canActivate = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(canActivate).toBe(true);
    });

    it("should return false when a goal is active", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalLifecycleService;
        
        yield* service.createGoal("Active goal");
        return yield* service.canActivateGoal();
      });

      const canActivate = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));
      
      expect(canActivate).toBe(false);
    });
  });
});
