/**
 * JudgeResult - Domain Model Tests
 *
 * Tests for judge evaluation results from LLM-as-Judge pattern.
 */
import { describe, it, expect } from "bun:test";
import { JudgeResult, JudgeStatus } from "./JudgeResult.js";

describe("JudgeResult", () => {
  describe("Schema Validation", () => {
    describe("Given valid judge result data", () => {
      it("When creating result with COMPLETE status, Then result is created", () => {
        const result = new JudgeResult({
          status: JudgeStatus.COMPLETE,
          confidence: 0.95,
          reasoning: "Goal objective has been fully achieved",
          recommendations: ["Verify final output", "Document results"],
          goalId: "goal-123",
          turn: 5,
          timestamp: Date.now(),
        });

        expect(result.status).toBe(JudgeStatus.COMPLETE);
        expect(result.confidence).toBe(0.95);
        expect(result.reasoning).toBe("Goal objective has been fully achieved");
        expect(result.recommendations).toHaveLength(2);
      });

      it("When creating result with IN_PROGRESS status, Then result is created", () => {
        const result = new JudgeResult({
          status: JudgeStatus.IN_PROGRESS,
          confidence: 0.7,
          reasoning: "Making progress but not complete",
          recommendations: ["Continue with current approach"],
          goalId: "goal-123",
          turn: 3,
          timestamp: Date.now(),
        });

        expect(result.status).toBe(JudgeStatus.IN_PROGRESS);
        expect(result.confidence).toBe(0.7);
      });

      it("When creating result with BLOCKED status, Then result is created", () => {
        const result = new JudgeResult({
          status: JudgeStatus.BLOCKED,
          confidence: 0.8,
          reasoning: "Missing required information",
          recommendations: ["Request clarification", "Gather more context"],
          goalId: "goal-123",
          turn: 2,
          timestamp: Date.now(),
        });

        expect(result.status).toBe(JudgeStatus.BLOCKED);
        expect(result.recommendations).toContain("Request clarification");
      });

      it("When creating result with FAILED status, Then result is created", () => {
        const result = new JudgeResult({
          status: JudgeStatus.FAILED,
          confidence: 0.9,
          reasoning: "Approach is fundamentally flawed",
          recommendations: ["Restart with different strategy"],
          goalId: "goal-123",
          turn: 10,
          timestamp: Date.now(),
        });

        expect(result.status).toBe(JudgeStatus.FAILED);
        expect(result.confidence).toBe(0.9);
      });

      it("When creating result with empty recommendations, Then result is created", () => {
        const result = new JudgeResult({
          status: JudgeStatus.COMPLETE,
          confidence: 1.0,
          reasoning: "Goal achieved",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.recommendations).toEqual([]);
      });

      it("When creating result with minimum confidence, Then result is created", () => {
        const result = new JudgeResult({
          status: JudgeStatus.IN_PROGRESS,
          confidence: 0.0,
          reasoning: "Very uncertain",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.confidence).toBe(0.0);
      });

      it("When creating result with maximum confidence, Then result is created", () => {
        const result = new JudgeResult({
          status: JudgeStatus.COMPLETE,
          confidence: 1.0,
          reasoning: "Absolutely certain",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.confidence).toBe(1.0);
      });
    });

    describe("Given invalid judge result data", () => {
      it("When creating result without status, Then validation fails", () => {
        expect(() => {
          new JudgeResult({
            confidence: 0.8,
            reasoning: "Test",
            recommendations: [],
            goalId: "goal-123",
            turn: 1,
            timestamp: Date.now(),
          } as any);
        }).toThrow();
      });

      it("When creating result without confidence, Then validation fails", () => {
        expect(() => {
          new JudgeResult({
            status: JudgeStatus.COMPLETE,
            reasoning: "Test",
            recommendations: [],
            goalId: "goal-123",
            turn: 1,
            timestamp: Date.now(),
          } as any);
        }).toThrow();
      });

      it("When creating result with confidence below 0, Then validation fails", () => {
        expect(() => {
          new JudgeResult({
            status: JudgeStatus.COMPLETE,
            confidence: -0.1,
            reasoning: "Test",
            recommendations: [],
            goalId: "goal-123",
            turn: 1,
            timestamp: Date.now(),
          });
        }).toThrow();
      });

      it("When creating result with confidence above 1, Then validation fails", () => {
        expect(() => {
          new JudgeResult({
            status: JudgeStatus.COMPLETE,
            confidence: 1.1,
            reasoning: "Test",
            recommendations: [],
            goalId: "goal-123",
            turn: 1,
            timestamp: Date.now(),
          });
        }).toThrow();
      });

      it("When creating result without reasoning, Then validation fails", () => {
        expect(() => {
          new JudgeResult({
            status: JudgeStatus.COMPLETE,
            confidence: 0.8,
            recommendations: [],
            goalId: "goal-123",
            turn: 1,
            timestamp: Date.now(),
          } as any);
        }).toThrow();
      });

      it("When creating result with empty reasoning, Then validation fails", () => {
        expect(() => {
          new JudgeResult({
            status: JudgeStatus.COMPLETE,
            confidence: 0.8,
            reasoning: "",
            recommendations: [],
            goalId: "goal-123",
            turn: 1,
            timestamp: Date.now(),
          });
        }).toThrow();
      });

      it("When creating result without goalId, Then validation fails", () => {
        expect(() => {
          new JudgeResult({
            status: JudgeStatus.COMPLETE,
            confidence: 0.8,
            reasoning: "Test",
            recommendations: [],
            turn: 1,
            timestamp: Date.now(),
          } as any);
        }).toThrow();
      });

      it("When creating result with empty goalId, Then validation fails", () => {
        expect(() => {
          new JudgeResult({
            status: JudgeStatus.COMPLETE,
            confidence: 0.8,
            reasoning: "Test",
            recommendations: [],
            goalId: "",
            turn: 1,
            timestamp: Date.now(),
          });
        }).toThrow();
      });

      it("When creating result without turn, Then validation fails", () => {
        expect(() => {
          new JudgeResult({
            status: JudgeStatus.COMPLETE,
            confidence: 0.8,
            reasoning: "Test",
            recommendations: [],
            goalId: "goal-123",
            timestamp: Date.now(),
          } as any);
        }).toThrow();
      });

      it("When creating result with negative turn, Then validation fails", () => {
        expect(() => {
          new JudgeResult({
            status: JudgeStatus.COMPLETE,
            confidence: 0.8,
            reasoning: "Test",
            recommendations: [],
            goalId: "goal-123",
            turn: -1,
            timestamp: Date.now(),
          });
        }).toThrow();
      });

      it("When creating result without timestamp, Then validation fails", () => {
        expect(() => {
          new JudgeResult({
            status: JudgeStatus.COMPLETE,
            confidence: 0.8,
            reasoning: "Test",
            recommendations: [],
            goalId: "goal-123",
            turn: 1,
          } as any);
        }).toThrow();
      });
    });
  });

  describe("Status checks", () => {
    describe("isComplete method", () => {
      it("When status is COMPLETE, Then isComplete returns true", () => {
        const result = new JudgeResult({
          status: JudgeStatus.COMPLETE,
          confidence: 0.95,
          reasoning: "Done",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isComplete()).toBe(true);
      });

      it("When status is IN_PROGRESS, Then isComplete returns false", () => {
        const result = new JudgeResult({
          status: JudgeStatus.IN_PROGRESS,
          confidence: 0.7,
          reasoning: "Working",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isComplete()).toBe(false);
      });

      it("When status is BLOCKED, Then isComplete returns false", () => {
        const result = new JudgeResult({
          status: JudgeStatus.BLOCKED,
          confidence: 0.8,
          reasoning: "Stuck",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isComplete()).toBe(false);
      });

      it("When status is FAILED, Then isComplete returns false", () => {
        const result = new JudgeResult({
          status: JudgeStatus.FAILED,
          confidence: 0.9,
          reasoning: "Failed",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isComplete()).toBe(false);
      });
    });

    describe("isTerminal method", () => {
      it("When status is COMPLETE, Then isTerminal returns true", () => {
        const result = new JudgeResult({
          status: JudgeStatus.COMPLETE,
          confidence: 0.95,
          reasoning: "Done",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isTerminal()).toBe(true);
      });

      it("When status is FAILED, Then isTerminal returns true", () => {
        const result = new JudgeResult({
          status: JudgeStatus.FAILED,
          confidence: 0.9,
          reasoning: "Failed",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isTerminal()).toBe(true);
      });

      it("When status is IN_PROGRESS, Then isTerminal returns false", () => {
        const result = new JudgeResult({
          status: JudgeStatus.IN_PROGRESS,
          confidence: 0.7,
          reasoning: "Working",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isTerminal()).toBe(false);
      });

      it("When status is BLOCKED, Then isTerminal returns false", () => {
        const result = new JudgeResult({
          status: JudgeStatus.BLOCKED,
          confidence: 0.8,
          reasoning: "Stuck",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isTerminal()).toBe(false);
      });
    });

    describe("shouldContinue method", () => {
      it("When status is IN_PROGRESS, Then shouldContinue returns true", () => {
        const result = new JudgeResult({
          status: JudgeStatus.IN_PROGRESS,
          confidence: 0.7,
          reasoning: "Working",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.shouldContinue()).toBe(true);
      });

      it("When status is COMPLETE, Then shouldContinue returns false", () => {
        const result = new JudgeResult({
          status: JudgeStatus.COMPLETE,
          confidence: 0.95,
          reasoning: "Done",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.shouldContinue()).toBe(false);
      });

      it("When status is BLOCKED, Then shouldContinue returns false", () => {
        const result = new JudgeResult({
          status: JudgeStatus.BLOCKED,
          confidence: 0.8,
          reasoning: "Stuck",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.shouldContinue()).toBe(false);
      });

      it("When status is FAILED, Then shouldContinue returns false", () => {
        const result = new JudgeResult({
          status: JudgeStatus.FAILED,
          confidence: 0.9,
          reasoning: "Failed",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.shouldContinue()).toBe(false);
      });
    });
  });

  describe("Confidence analysis", () => {
    describe("isHighConfidence method", () => {
      it("When confidence is 0.85, Then isHighConfidence returns true", () => {
        const result = new JudgeResult({
          status: JudgeStatus.COMPLETE,
          confidence: 0.85,
          reasoning: "Very confident",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isHighConfidence()).toBe(true);
      });

      it("When confidence is 1.0, Then isHighConfidence returns true", () => {
        const result = new JudgeResult({
          status: JudgeStatus.COMPLETE,
          confidence: 1.0,
          reasoning: "Absolutely certain",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isHighConfidence()).toBe(true);
      });

      it("When confidence is 0.84, Then isHighConfidence returns false", () => {
        const result = new JudgeResult({
          status: JudgeStatus.IN_PROGRESS,
          confidence: 0.84,
          reasoning: "Moderate confidence",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isHighConfidence()).toBe(false);
      });

      it("When confidence is 0.5, Then isHighConfidence returns false", () => {
        const result = new JudgeResult({
          status: JudgeStatus.IN_PROGRESS,
          confidence: 0.5,
          reasoning: "Uncertain",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isHighConfidence()).toBe(false);
      });

      it("When confidence is 0.0, Then isHighConfidence returns false", () => {
        const result = new JudgeResult({
          status: JudgeStatus.IN_PROGRESS,
          confidence: 0.0,
          reasoning: "No confidence",
          recommendations: [],
          goalId: "goal-123",
          turn: 1,
          timestamp: Date.now(),
        });

        expect(result.isHighConfidence()).toBe(false);
      });
    });
  });
});
