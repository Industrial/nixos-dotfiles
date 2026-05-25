/**
 * ExecutionContext - Domain Model
 *
 * Tracks goal execution state, turns, errors, and limits.
 * Prevents infinite loops and provides error tracking.
 */
import { Schema as S } from "@effect/schema";
import { JudgeResult } from "./JudgeResult.js";

/**
 * Execution error record
 */
export class ExecutionError extends S.Class<ExecutionError>("ExecutionError")({
  message: S.String,
  timestamp: S.Number,
  turn: S.Number,
  stack: S.optional(S.String),
}) {}

/**
 * ExecutionContext - Aggregate Root
 *
 * Immutable context for tracking goal execution progress.
 */
export class ExecutionContext extends S.Class<ExecutionContext>("ExecutionContext")({
  id: S.String,
  goalId: S.String,
  currentTurn: S.Number,
  maxTurns: S.Number,
  errors: S.Array(ExecutionError),
  judgeEvaluations: S.Array(JudgeResult),
  isComplete: S.Boolean,
  createdAt: S.Number,
  completedAt: S.optional(S.Number),
}) {
  /**
   * Increment the turn counter
   */
  incrementTurn(): ExecutionContext {
    return new ExecutionContext({
      ...this,
      currentTurn: this.currentTurn + 1,
    });
  }

  /**
   * Check if turn limit has been reached
   */
  hasReachedLimit(): boolean {
    return this.currentTurn >= this.maxTurns;
  }

  /**
   * Record an error that occurred during execution
   */
  recordError(error: Error): ExecutionContext {
    const executionError = new ExecutionError({
      message: error.message,
      timestamp: Date.now(),
      turn: this.currentTurn,
      stack: error.stack,
    });

    return new ExecutionContext({
      ...this,
      errors: [...this.errors, executionError],
    });
  }

  /**
   * Record a judge evaluation
   */
  recordJudgeEvaluation(evaluation: JudgeResult): ExecutionContext {
    return new ExecutionContext({
      ...this,
      judgeEvaluations: [...this.judgeEvaluations, evaluation],
    });
  }

  /**
   * Get the most recent judge evaluation
   */
  getLatestJudgeEvaluation(): JudgeResult | undefined {
    return this.judgeEvaluations[this.judgeEvaluations.length - 1];
  }

  /**
   * Mark execution as complete
   */
  markComplete(): ExecutionContext {
    return new ExecutionContext({
      ...this,
      isComplete: true,
      completedAt: Date.now(),
    });
  }

  /**
   * Check if execution can continue
   */
  canContinue(): boolean {
    return !this.isComplete && !this.hasReachedLimit();
  }

  /**
   * Get progress percentage (0.0 to 1.0)
   */
  getTurnProgress(): number {
    if (this.maxTurns === 0) return 1.0;
    return Math.min(this.currentTurn / this.maxTurns, 1.0);
  }
}

/**
 * Factory function to create a new execution context
 */
export const createExecutionContext = (
  goalId: string,
  maxTurns: number = 50
): ExecutionContext => {
  const now = Date.now();
  return new ExecutionContext({
    id: `exec-${now}-${Math.random().toString(36).substring(2, 9)}`,
    goalId,
    currentTurn: 0,
    maxTurns,
    errors: [],
    judgeEvaluations: [],
    isComplete: false,
    createdAt: now,
  });
};
