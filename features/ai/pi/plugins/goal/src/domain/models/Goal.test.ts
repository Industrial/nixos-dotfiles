/**
 * Goal Entity Tests
 * 
 * Tests the domain logic within the Goal entity itself.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { Goal, createGoal, GoalEvaluation } from "./Goal.js";

describe("Goal Entity", () => {
  describe("createGoal factory", () => {
    it("should create a new goal with active status", () => {
      const goal = createGoal("Build a rocket", "For Mars mission");
      
      expect(goal.objective).toBe("Build a rocket");
      expect(goal.context).toBe("For Mars mission");
      expect(goal.status).toBe("active");
      expect(goal.createdAt).toBeGreaterThan(0);
      expect(goal.updatedAt).toBe(goal.createdAt);
      expect(goal.completedAt).toBeUndefined();
    });

    it("should create goal without context", () => {
      const goal = createGoal("Build a rocket");
      
      expect(goal.objective).toBe("Build a rocket");
      expect(goal.context).toBeUndefined();
      expect(goal.status).toBe("active");
    });

    it("should generate unique IDs", () => {
      const goal1 = createGoal("Task 1");
      const goal2 = createGoal("Task 2");
      
      expect(goal1.id).not.toBe(goal2.id);
    });
  });

  describe("business logic methods", () => {
    describe("isActive", () => {
      it("should return true for active goals", () => {
        const goal = createGoal("Test");
        expect(goal.isActive()).toBe(true);
      });

      it("should return false for paused goals", () => {
        const goal = new Goal({
          ...createGoal("Test"),
          status: "paused",
        });
        expect(goal.isActive()).toBe(false);
      });
    });

    describe("canPause", () => {
      it("should return true for active goals", () => {
        const goal = createGoal("Test");
        expect(goal.canPause()).toBe(true);
      });

      it("should return false for already paused goals", () => {
        const goal = new Goal({
          ...createGoal("Test"),
          status: "paused",
        });
        expect(goal.canPause()).toBe(false);
      });
    });

    describe("canResume", () => {
      it("should return true for paused goals", () => {
        const goal = new Goal({
          ...createGoal("Test"),
          status: "paused",
        });
        expect(goal.canResume()).toBe(true);
      });

      it("should return false for active goals", () => {
        const goal = createGoal("Test");
        expect(goal.canResume()).toBe(false);
      });
    });

    describe("isTerminal", () => {
      it("should return true for completed goals", () => {
        const goal = new Goal({
          ...createGoal("Test"),
          status: "completed",
        });
        expect(goal.isTerminal()).toBe(true);
      });

      it("should return true for cancelled goals", () => {
        const goal = new Goal({
          ...createGoal("Test"),
          status: "cancelled",
        });
        expect(goal.isTerminal()).toBe(true);
      });

      it("should return false for active goals", () => {
        const goal = createGoal("Test");
        expect(goal.isTerminal()).toBe(false);
      });
    });
  });

  describe("state transitions", () => {
    describe("pause", () => {
      it("should pause an active goal", async () => {
        const goal = createGoal("Test");
        
        const pausedGoal = await Effect.runPromise(goal.pause());
        
        expect(pausedGoal.status).toBe("paused");
        expect(pausedGoal.updatedAt).toBeGreaterThanOrEqual(goal.updatedAt);
      });

      it("should fail to pause a non-active goal", async () => {
        const goal = new Goal({
          ...createGoal("Test"),
          status: "paused",
        });
        
        await expect(Effect.runPromise(goal.pause())).rejects.toThrow(
          "Cannot pause goal in status: paused"
        );
      });
    });

    describe("resume", () => {
      it("should resume a paused goal", async () => {
        const goal = new Goal({
          ...createGoal("Test"),
          status: "paused",
        });
        
        const resumedGoal = await Effect.runPromise(goal.resume());
        
        expect(resumedGoal.status).toBe("active");
        expect(resumedGoal.updatedAt).toBeGreaterThanOrEqual(goal.updatedAt);
      });

      it("should fail to resume a non-paused goal", async () => {
        const goal = createGoal("Test");
        
        await expect(Effect.runPromise(goal.resume())).rejects.toThrow(
          "Cannot resume goal in status: active"
        );
      });
    });

    describe("complete", () => {
      it("should complete an active goal", async () => {
        const goal = createGoal("Test");
        
        const completedGoal = await Effect.runPromise(goal.complete());
        
        expect(completedGoal.status).toBe("completed");
        expect(completedGoal.completedAt).toBeGreaterThan(0);
        expect(completedGoal.updatedAt).toBeGreaterThanOrEqual(goal.updatedAt);
      });

      it("should fail to complete an already completed goal", async () => {
        const goal = new Goal({
          ...createGoal("Test"),
          status: "completed",
          completedAt: Date.now(),
        });
        
        await expect(Effect.runPromise(goal.complete())).rejects.toThrow(
          "Goal already in terminal state: completed"
        );
      });
    });

    describe("cancel", () => {
      it("should cancel an active goal", async () => {
        const goal = createGoal("Test");
        
        const cancelledGoal = await Effect.runPromise(goal.cancel());
        
        expect(cancelledGoal.status).toBe("cancelled");
        expect(cancelledGoal.completedAt).toBeGreaterThan(0);
        expect(cancelledGoal.updatedAt).toBeGreaterThanOrEqual(goal.updatedAt);
      });

      it("should fail to cancel a completed goal", async () => {
        const goal = new Goal({
          ...createGoal("Test"),
          status: "completed",
          completedAt: Date.now(),
        });
        
        await expect(Effect.runPromise(goal.cancel())).rejects.toThrow(
          "Goal already in terminal state: completed"
        );
      });
    });
  });

  describe("updateEvaluation", () => {
    it("should update evaluation data", () => {
      const goal = createGoal("Test");
      const evaluation = new GoalEvaluation({
        progress: 50,
        blockers: ["Need approval"],
        nextSteps: ["Get sign-off", "Begin implementation"],
      });
      
      const updatedGoal = goal.updateEvaluation(evaluation);
      
      expect(updatedGoal.evaluationData).toEqual(evaluation);
      expect(updatedGoal.updatedAt).toBeGreaterThanOrEqual(goal.updatedAt);
    });
  });
});
