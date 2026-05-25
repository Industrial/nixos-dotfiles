/**
 * ExecutionContext - Domain Model Tests
 *
 * Tests for tracking goal execution state, turns, and errors.
 */
import { describe, it, expect } from "bun:test";
import { createExecutionContext } from "./ExecutionContext.js";

describe("ExecutionContext", () => {
  describe("createExecutionContext factory", () => {
    it("should create context with initial state", () => {
      const ctx = createExecutionContext("goal-123");

      expect(ctx.goalId).toBe("goal-123");
      expect(ctx.currentTurn).toBe(0);
      expect(ctx.maxTurns).toBe(50); // Default limit
      expect(ctx.errors).toEqual([]);
      expect(ctx.isComplete).toBe(false);
      expect(ctx.createdAt).toBeGreaterThan(0);
    });

    it("should allow custom max turns", () => {
      const ctx = createExecutionContext("goal-123", 10);

      expect(ctx.maxTurns).toBe(10);
    });

    it("should generate unique IDs for different contexts", () => {
      const ctx1 = createExecutionContext("goal-1");
      const ctx2 = createExecutionContext("goal-2");

      expect(ctx1.id).not.toBe(ctx2.id);
    });
  });

  describe("incrementTurn", () => {
    it("should increment turn counter", () => {
      const ctx = createExecutionContext("goal-123");
      const updated = ctx.incrementTurn();

      expect(updated.currentTurn).toBe(1);
    });

    it("should preserve other properties", () => {
      const ctx = createExecutionContext("goal-123", 20);
      const updated = ctx.incrementTurn();

      expect(updated.goalId).toBe(ctx.goalId);
      expect(updated.maxTurns).toBe(20);
      expect(updated.id).toBe(ctx.id);
    });

    it("should allow incrementing multiple times", () => {
      const ctx = createExecutionContext("goal-123");
      const turn1 = ctx.incrementTurn();
      const turn2 = turn1.incrementTurn();
      const turn3 = turn2.incrementTurn();

      expect(turn3.currentTurn).toBe(3);
    });
  });

  describe("hasReachedLimit", () => {
    it("should return false when under limit", () => {
      const ctx = createExecutionContext("goal-123", 10);
      const turn5 = ctx.incrementTurn().incrementTurn().incrementTurn().incrementTurn().incrementTurn();

      expect(turn5.hasReachedLimit()).toBe(false);
    });

    it("should return true when at limit", () => {
      const ctx = createExecutionContext("goal-123", 3);
      const turn3 = ctx.incrementTurn().incrementTurn().incrementTurn();

      expect(turn3.hasReachedLimit()).toBe(true);
    });

    it("should return true when over limit", () => {
      const ctx = createExecutionContext("goal-123", 2);
      const turn3 = ctx.incrementTurn().incrementTurn().incrementTurn();

      expect(turn3.hasReachedLimit()).toBe(true);
      expect(turn3.currentTurn).toBe(3);
    });

    it("should return false at turn 0", () => {
      const ctx = createExecutionContext("goal-123", 10);

      expect(ctx.hasReachedLimit()).toBe(false);
    });
  });

  describe("recordError", () => {
    it("should add error to errors array", () => {
      const ctx = createExecutionContext("goal-123");
      const error = new Error("Something failed");
      const updated = ctx.recordError(error);

      expect(updated.errors).toHaveLength(1);
      expect(updated.errors[0].message).toBe("Something failed");
    });

    it("should preserve existing errors", () => {
      const ctx = createExecutionContext("goal-123");
      const error1 = new Error("First error");
      const error2 = new Error("Second error");

      const updated1 = ctx.recordError(error1);
      const updated2 = updated1.recordError(error2);

      expect(updated2.errors).toHaveLength(2);
      expect(updated2.errors[0].message).toBe("First error");
      expect(updated2.errors[1].message).toBe("Second error");
    });

    it("should track error timestamps", () => {
      const ctx = createExecutionContext("goal-123");
      const error = new Error("Test error");
      const updated = ctx.recordError(error);

      expect(updated.errors[0].timestamp).toBeGreaterThan(0);
      expect(updated.errors[0].timestamp).toBeGreaterThanOrEqual(ctx.createdAt);
    });

    it("should track turn number when error occurred", () => {
      const ctx = createExecutionContext("goal-123");
      const turn5 = ctx.incrementTurn().incrementTurn().incrementTurn().incrementTurn().incrementTurn();
      const error = new Error("Error at turn 5");
      const updated = turn5.recordError(error);

      expect(updated.errors[0].turn).toBe(5);
    });
  });

  describe("markComplete", () => {
    it("should set isComplete to true", () => {
      const ctx = createExecutionContext("goal-123");
      const completed = ctx.markComplete();

      expect(completed.isComplete).toBe(true);
    });

    it("should preserve other properties", () => {
      const ctx = createExecutionContext("goal-123", 20);
      const turn3 = ctx.incrementTurn().incrementTurn().incrementTurn();
      const completed = turn3.markComplete();

      expect(completed.currentTurn).toBe(3);
      expect(completed.goalId).toBe("goal-123");
      expect(completed.maxTurns).toBe(20);
    });

    it("should set completion timestamp", () => {
      const ctx = createExecutionContext("goal-123");
      const before = Date.now();
      const completed = ctx.markComplete();
      const after = Date.now();

      expect(completed.completedAt).toBeGreaterThanOrEqual(before);
      expect(completed.completedAt).toBeLessThanOrEqual(after);
    });
  });

  describe("canContinue", () => {
    it("should return true when under limit and not complete", () => {
      const ctx = createExecutionContext("goal-123", 10);

      expect(ctx.canContinue()).toBe(true);
    });

    it("should return false when complete", () => {
      const ctx = createExecutionContext("goal-123", 10);
      const completed = ctx.markComplete();

      expect(completed.canContinue()).toBe(false);
    });

    it("should return false when limit reached", () => {
      const ctx = createExecutionContext("goal-123", 2);
      const atLimit = ctx.incrementTurn().incrementTurn();

      expect(atLimit.canContinue()).toBe(false);
    });

    it("should return true after errors if not complete or at limit", () => {
      const ctx = createExecutionContext("goal-123", 10);
      const withError = ctx.recordError(new Error("Test"));

      expect(withError.canContinue()).toBe(true);
    });
  });

  describe("getTurnProgress", () => {
    it("should calculate progress percentage", () => {
      const ctx = createExecutionContext("goal-123", 10);
      const turn5 = ctx.incrementTurn().incrementTurn().incrementTurn().incrementTurn().incrementTurn();

      expect(turn5.getTurnProgress()).toBe(0.5); // 5/10
    });

    it("should return 0 at start", () => {
      const ctx = createExecutionContext("goal-123", 10);

      expect(ctx.getTurnProgress()).toBe(0);
    });

    it("should return 1.0 when at limit", () => {
      const ctx = createExecutionContext("goal-123", 5);
      const turn5 = ctx.incrementTurn().incrementTurn().incrementTurn().incrementTurn().incrementTurn();

      expect(turn5.getTurnProgress()).toBe(1.0);
    });
  });

  describe("Edge cases", () => {
    it("should handle zero max turns", () => {
      const ctx = createExecutionContext("goal-123", 0);

      expect(ctx.hasReachedLimit()).toBe(true);
      expect(ctx.canContinue()).toBe(false);
    });

    it("should handle very large max turns", () => {
      const ctx = createExecutionContext("goal-123", 1000000);

      expect(ctx.hasReachedLimit()).toBe(false);
      expect(ctx.canContinue()).toBe(true);
    });

    it("should handle many errors", () => {
      let ctx = createExecutionContext("goal-123");

      for (let i = 0; i < 100; i++) {
        ctx = ctx.recordError(new Error(`Error ${i}`));
      }

      expect(ctx.errors).toHaveLength(100);
    });
  });
});
