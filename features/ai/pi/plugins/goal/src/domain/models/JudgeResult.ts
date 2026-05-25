/**
 * JudgeResult - Domain Model
 *
 * Represents evaluation result from LLM-as-Judge pattern.
 * Judge model evaluates goal progress independently to prevent bias.
 */
import { Schema as S } from "@effect/schema";

/**
 * Judge evaluation status
 */
export enum JudgeStatus {
  COMPLETE = "COMPLETE",
  IN_PROGRESS = "IN_PROGRESS",
  BLOCKED = "BLOCKED",
  FAILED = "FAILED",
}

/**
 * Result from judge evaluation
 *
 * Follows LLM-as-Judge pattern where separate LLM evaluates
 * goal progress to maintain objectivity.
 */
export class JudgeResult extends S.Class<JudgeResult>("JudgeResult")({
  status: S.Enums(JudgeStatus),
  confidence: S.Number.pipe(S.greaterThanOrEqualTo(0), S.lessThanOrEqualTo(1)),
  reasoning: S.String.pipe(S.minLength(1)),
  recommendations: S.Array(S.String),
  goalId: S.String.pipe(S.minLength(1)),
  turn: S.Number.pipe(S.greaterThanOrEqualTo(0)),
  timestamp: S.Number,
}) {
  /**
   * Check if goal is complete
   */
  isComplete(): boolean {
    return this.status === JudgeStatus.COMPLETE;
  }

  /**
   * Check if in terminal state (complete or failed)
   */
  isTerminal(): boolean {
    return (
      this.status === JudgeStatus.COMPLETE || this.status === JudgeStatus.FAILED
    );
  }

  /**
   * Check if execution should continue
   */
  shouldContinue(): boolean {
    return this.status === JudgeStatus.IN_PROGRESS;
  }

  /**
   * Check if confidence is high (>= 85% threshold from research)
   */
  isHighConfidence(): boolean {
    return this.confidence >= 0.85;
  }
}
