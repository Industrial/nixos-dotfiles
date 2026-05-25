/**
 * ContinuationContext - Domain Model
 *
 * Tracks auto-continuation execution state across multiple turns.
 * Maintains history of outputs and judge evaluations for context-aware prompting.
 */
import { Schema as S } from "@effect/schema";
import { Goal } from "./Goal.js";
import { JudgeResult } from "./JudgeResult.js";

/**
 * ContinuationContext - Aggregate Root
 *
 * Immutable context for tracking goal execution across multiple turns.
 * Used by PromptGeneratorService to create context-aware continuation prompts.
 */
export class ContinuationContext extends S.Class<ContinuationContext>("ContinuationContext")({
  id: S.String,
  goal: Goal,
  turnOutputs: S.Array(S.String),
  judgeEvaluations: S.Array(JudgeResult),
  currentTurn: S.Number,
  createdAt: S.Number,
}) {
  /**
   * Record output from a turn
   */
  recordTurnOutput(output: string): ContinuationContext {
    return new ContinuationContext({
      ...this,
      turnOutputs: [...this.turnOutputs, output],
    });
  }

  /**
   * Record a judge evaluation
   */
  recordJudgeEvaluation(evaluation: JudgeResult): ContinuationContext {
    return new ContinuationContext({
      ...this,
      judgeEvaluations: [...this.judgeEvaluations, evaluation],
    });
  }

  /**
   * Increment the turn counter
   */
  incrementTurn(): ContinuationContext {
    return new ContinuationContext({
      ...this,
      currentTurn: this.currentTurn + 1,
    });
  }

  /**
   * Get the most recent output
   */
  getLatestOutput(): string | undefined {
    return this.turnOutputs[this.turnOutputs.length - 1];
  }

  /**
   * Get the most recent judge evaluation
   */
  getLatestJudgeEvaluation(): JudgeResult | undefined {
    return this.judgeEvaluations[this.judgeEvaluations.length - 1];
  }

  /**
   * Get recent output history (most recent N outputs)
   */
  getOutputHistory(limit: number): readonly string[] {
    if (this.turnOutputs.length <= limit) {
      return this.turnOutputs;
    }
    return this.turnOutputs.slice(-limit);
  }
}

/**
 * Factory function to create a new continuation context
 */
export const createContinuationContext = (goal: Goal): ContinuationContext => {
  const now = Date.now();
  return new ContinuationContext({
    id: `cont-${now}-${Math.random().toString(36).substring(2, 9)}`,
    goal,
    turnOutputs: [],
    judgeEvaluations: [],
    currentTurn: 0,
    createdAt: now,
  });
};
