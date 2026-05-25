/**
 * GoalIteration Entity Tests
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { GoalIteration, createIteration, IterationOutcome } from "./GoalIteration.js";

describe("GoalIteration Entity", () => {
  describe("createIteration factory", () => {
    it("should create a new iteration", () => {
      const iteration = createIteration("goal-123", 1);
      
      expect(iteration.goalId).toBe("goal-123");
      expect(iteration.iterationNumber).toBe(1);
      expect(iteration.startedAt).toBeGreaterThan(0);
      expect(iteration.completedAt).toBeUndefined();
      expect(iteration.outcome).toBeUndefined();
    });

    it("should generate unique IDs", () => {
      const iter1 = createIteration("goal-123", 1);
      const iter2 = createIteration("goal-123", 2);
      
      expect(iter1.id).not.toBe(iter2.id);
    });
  });

  describe("business logic methods", () => {
    describe("isCompleted", () => {
      it("should return false for new iterations", () => {
        const iteration = createIteration("goal-123", 1);
        expect(iteration.isCompleted()).toBe(false);
      });

      it("should return true for completed iterations", () => {
        const iteration = new GoalIteration({
          ...createIteration("goal-123", 1),
          completedAt: Date.now(),
        });
        expect(iteration.isCompleted()).toBe(true);
      });
    });

    describe("isInProgress", () => {
      it("should return true for new iterations", () => {
        const iteration = createIteration("goal-123", 1);
        expect(iteration.isInProgress()).toBe(true);
      });

      it("should return false for completed iterations", () => {
        const iteration = new GoalIteration({
          ...createIteration("goal-123", 1),
          completedAt: Date.now(),
        });
        expect(iteration.isInProgress()).toBe(false);
      });
    });

    describe("duration", () => {
      it("should return null for in-progress iterations", () => {
        const iteration = createIteration("goal-123", 1);
        expect(iteration.duration()).toBeNull();
      });

      it("should calculate duration for completed iterations", () => {
        const startedAt = Date.now() - 5000; // 5 seconds ago
        const completedAt = Date.now();
        const iteration = new GoalIteration({
          ...createIteration("goal-123", 1),
          startedAt,
          completedAt,
        });
        
        const duration = iteration.duration();
        expect(duration).toBeGreaterThanOrEqual(4900); // ~5 seconds
        expect(duration).toBeLessThanOrEqual(5100);
      });
    });
  });

  describe("complete", () => {
    it("should complete an iteration with outcome", async () => {
      const iteration = createIteration("goal-123", 1);
      const outcome = new IterationOutcome({
        success: true,
        message: "Completed successfully",
        actionsCompleted: ["Created PR", "Ran tests"],
        nextActions: ["Wait for review"],
      });
      
      const completed = await Effect.runPromise(iteration.complete(outcome));
      
      expect(completed.completedAt).toBeGreaterThan(0);
      expect(completed.outcome).toEqual(outcome);
    });

    it("should fail to complete an already completed iteration", async () => {
      const iteration = new GoalIteration({
        ...createIteration("goal-123", 1),
        completedAt: Date.now(),
      });
      const outcome = new IterationOutcome({
        success: true,
        message: "Test",
        actionsCompleted: [],
        nextActions: [],
      });
      
      await expect(Effect.runPromise(iteration.complete(outcome))).rejects.toThrow(
        "Iteration already completed"
      );
    });
  });
});
