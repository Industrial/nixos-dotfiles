/**
 * ContinuationContext - Domain Model Tests
 *
 * Tests for tracking auto-continuation execution state and history.
 */
import { describe, it, expect } from "bun:test";
import { createContinuationContext } from "./ContinuationContext.js";
import { Goal } from "./Goal.js";
import { JudgeResult, JudgeStatus } from "./JudgeResult.js";

describe("ContinuationContext", () => {
  describe("createContinuationContext factory", () => {
    it("should create context with initial state", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test objective",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx = createContinuationContext(goal);

      expect(ctx.goal).toBe(goal);
      expect(ctx.turnOutputs).toEqual([]);
      expect(ctx.judgeEvaluations).toEqual([]);
      expect(ctx.currentTurn).toBe(0);
    });

    it("should generate unique IDs", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx1 = createContinuationContext(goal);
      const ctx2 = createContinuationContext(goal);

      expect(ctx1.id).not.toBe(ctx2.id);
    });
  });

  describe("recordTurnOutput", () => {
    it("should add output to history", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx = createContinuationContext(goal);
      const updated = ctx.recordTurnOutput("Turn 1 output");

      expect(updated.turnOutputs).toHaveLength(1);
      expect(updated.turnOutputs[0]).toBe("Turn 1 output");
    });

    it("should preserve existing outputs", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx = createContinuationContext(goal);
      const turn1 = ctx.recordTurnOutput("Output 1");
      const turn2 = turn1.recordTurnOutput("Output 2");

      expect(turn2.turnOutputs).toHaveLength(2);
      expect(turn2.turnOutputs[0]).toBe("Output 1");
      expect(turn2.turnOutputs[1]).toBe("Output 2");
    });

    it("should track multiple outputs", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      let ctx = createContinuationContext(goal);

      for (let i = 1; i <= 5; i++) {
        ctx = ctx.recordTurnOutput(`Output ${i}`);
      }

      expect(ctx.turnOutputs).toHaveLength(5);
      expect(ctx.turnOutputs[4]).toBe("Output 5");
    });
  });

  describe("recordJudgeEvaluation", () => {
    it("should add evaluation to history", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx = createContinuationContext(goal);
      const judgeEval = new JudgeResult({
        status: JudgeStatus.IN_PROGRESS,
        confidence: 0.8,
        reasoning: "Making progress",
        recommendations: ["Continue"],
        goalId: "goal-123",
        turn: 1,
        timestamp: Date.now(),
      });

      const updated = ctx.recordJudgeEvaluation(judgeEval);

      expect(updated.judgeEvaluations).toHaveLength(1);
      expect(updated.judgeEvaluations[0]).toBe(judgeEval);
    });

    it("should preserve existing evaluations", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx = createContinuationContext(goal);
      const eval1 = new JudgeResult({
        status: JudgeStatus.IN_PROGRESS,
        confidence: 0.7,
        reasoning: "First",
        recommendations: [],
        goalId: "goal-123",
        turn: 1,
        timestamp: Date.now(),
      });
      const eval2 = new JudgeResult({
        status: JudgeStatus.COMPLETE,
        confidence: 0.9,
        reasoning: "Second",
        recommendations: [],
        goalId: "goal-123",
        turn: 2,
        timestamp: Date.now(),
      });

      const updated = ctx
        .recordJudgeEvaluation(eval1)
        .recordJudgeEvaluation(eval2);

      expect(updated.judgeEvaluations).toHaveLength(2);
      expect(updated.judgeEvaluations[1]).toBe(eval2);
    });
  });

  describe("incrementTurn", () => {
    it("should increment turn counter", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx = createContinuationContext(goal);
      const updated = ctx.incrementTurn();

      expect(updated.currentTurn).toBe(1);
    });

    it("should preserve other properties", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx = createContinuationContext(goal)
        .recordTurnOutput("Output 1");
      const updated = ctx.incrementTurn();

      expect(updated.turnOutputs).toEqual(["Output 1"]);
      expect(updated.goal).toBe(goal);
    });
  });

  describe("getLatestOutput", () => {
    it("should return undefined when no outputs", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx = createContinuationContext(goal);

      expect(ctx.getLatestOutput()).toBeUndefined();
    });

    it("should return most recent output", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx = createContinuationContext(goal)
        .recordTurnOutput("Output 1")
        .recordTurnOutput("Output 2")
        .recordTurnOutput("Output 3");

      expect(ctx.getLatestOutput()).toBe("Output 3");
    });
  });

  describe("getLatestJudgeEvaluation", () => {
    it("should return undefined when no evaluations", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx = createContinuationContext(goal);

      expect(ctx.getLatestJudgeEvaluation()).toBeUndefined();
    });

    it("should return most recent evaluation", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const eval1 = new JudgeResult({
        status: JudgeStatus.IN_PROGRESS,
        confidence: 0.7,
        reasoning: "First",
        recommendations: [],
        goalId: "goal-123",
        turn: 1,
        timestamp: Date.now(),
      });
      const eval2 = new JudgeResult({
        status: JudgeStatus.COMPLETE,
        confidence: 0.95,
        reasoning: "Second",
        recommendations: [],
        goalId: "goal-123",
        turn: 2,
        timestamp: Date.now(),
      });

      const ctx = createContinuationContext(goal)
        .recordJudgeEvaluation(eval1)
        .recordJudgeEvaluation(eval2);

      const latest = ctx.getLatestJudgeEvaluation();
      expect(latest).toBe(eval2);
      expect(latest?.status).toBe(JudgeStatus.COMPLETE);
    });
  });

  describe("getOutputHistory", () => {
    it("should return recent outputs up to limit", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      let ctx = createContinuationContext(goal);
      for (let i = 1; i <= 10; i++) {
        ctx = ctx.recordTurnOutput(`Output ${i}`);
      }

      const recent = ctx.getOutputHistory(3);

      expect(recent).toHaveLength(3);
      expect(recent[0]).toBe("Output 8");
      expect(recent[1]).toBe("Output 9");
      expect(recent[2]).toBe("Output 10");
    });

    it("should return all outputs when under limit", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx = createContinuationContext(goal)
        .recordTurnOutput("Output 1")
        .recordTurnOutput("Output 2");

      const history = ctx.getOutputHistory(5);

      expect(history).toHaveLength(2);
      expect(history).toEqual(["Output 1", "Output 2"]);
    });

    it("should return empty array when no outputs", () => {
      const goal = new Goal({
        id: "goal-123",
        objective: "Test",
        status: "active" as const,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      const ctx = createContinuationContext(goal);
      const history = ctx.getOutputHistory(3);

      expect(history).toEqual([]);
    });
  });
});
