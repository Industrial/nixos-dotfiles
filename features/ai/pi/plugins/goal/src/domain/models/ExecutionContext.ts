/**
 * ExecutionContext - Domain Model
 *
 * Tracks goal execution state, turns, errors, and limits.
 */
import { Schema as S } from "@effect/schema";
import type { StoppedReason } from "../execution/StoppedReason.js";
import { JudgeResult } from "./JudgeResult.js";
import { ToolResult } from "./ToolResult.js";

export class ExecutionError extends S.Class<ExecutionError>("ExecutionError")({
  message: S.String,
  timestamp: S.Number,
  turn: S.Number,
  stack: S.optional(S.String),
}) {}

export class ExecutionContext extends S.Class<ExecutionContext>("ExecutionContext")({
  id: S.String,
  goalId: S.String,
  /** Cumulative turn counter across all goal_execute calls */
  currentTurn: S.Number,
  /** Turns allowed in this MCP call only */
  maxTurns: S.Number,
  /** Turn counter at start of this call */
  turnsAtStart: S.Number,
  errors: S.Array(ExecutionError),
  judgeEvaluations: S.Array(JudgeResult),
  toolResults: S.Array(ToolResult),
  /** @deprecated Use phaseComplete — kept for backward compatibility */
  isComplete: S.Boolean,
  phaseComplete: S.Boolean,
  goalAchieved: S.Boolean,
  turnLimitReached: S.Boolean,
  stoppedReason: S.optional(S.String),
  nextPrompt: S.optional(S.String),
  createdAt: S.Number,
  completedAt: S.optional(S.Number),
}) {
  private clone(
    patch: Partial<{
      currentTurn: number;
      errors: readonly ExecutionError[];
      judgeEvaluations: readonly JudgeResult[];
      toolResults: readonly ToolResult[];
      isComplete: boolean;
      phaseComplete: boolean;
      goalAchieved: boolean;
      turnLimitReached: boolean;
      stoppedReason: string | undefined;
      nextPrompt: string | undefined;
      completedAt: number | undefined;
    }>
  ): ExecutionContext {
    return new ExecutionContext({
      id: this.id,
      goalId: this.goalId,
      currentTurn: patch.currentTurn ?? this.currentTurn,
      maxTurns: this.maxTurns,
      turnsAtStart: this.turnsAtStart,
      errors: patch.errors ?? this.errors,
      judgeEvaluations: patch.judgeEvaluations ?? this.judgeEvaluations,
      toolResults: patch.toolResults ?? this.toolResults,
      isComplete: patch.isComplete ?? this.isComplete,
      phaseComplete: patch.phaseComplete ?? this.phaseComplete,
      goalAchieved: patch.goalAchieved ?? this.goalAchieved,
      turnLimitReached: patch.turnLimitReached ?? this.turnLimitReached,
      stoppedReason:
        patch.stoppedReason !== undefined
          ? patch.stoppedReason
          : this.stoppedReason,
      nextPrompt:
        patch.nextPrompt !== undefined ? patch.nextPrompt : this.nextPrompt,
      createdAt: this.createdAt,
      completedAt:
        patch.completedAt !== undefined
          ? patch.completedAt
          : this.completedAt,
    });
  }

  incrementTurn(): ExecutionContext {
    return this.clone({ currentTurn: this.currentTurn + 1 });
  }

  turnsThisCall(): number {
    return this.currentTurn - this.turnsAtStart;
  }

  hasReachedLimit(): boolean {
    return this.turnsThisCall() >= this.maxTurns;
  }

  recordError(error: Error): ExecutionContext {
    const executionError = new ExecutionError({
      message: error.message,
      timestamp: Date.now(),
      turn: this.currentTurn,
      stack: error.stack,
    });

    return this.clone({ errors: [...this.errors, executionError] });
  }

  recordJudgeEvaluation(evaluation: JudgeResult): ExecutionContext {
    return this.clone({
      judgeEvaluations: [...this.judgeEvaluations, evaluation],
    });
  }

  getLatestJudgeEvaluation(): JudgeResult | undefined {
    return this.judgeEvaluations[this.judgeEvaluations.length - 1];
  }

  recordToolResult(result: ToolResult): ExecutionContext {
    return this.clone({ toolResults: [...this.toolResults, result] });
  }

  getToolResultsForTurn(_turn: number): readonly ToolResult[] {
    return this.toolResults;
  }

  finishPhase(params: {
    stoppedReason: StoppedReason;
    goalAchieved: boolean;
    nextPrompt?: string;
  }): ExecutionContext {
    return this.clone({
      isComplete: true,
      phaseComplete: true,
      goalAchieved: params.goalAchieved,
      turnLimitReached: params.stoppedReason === "turn_limit",
      stoppedReason: params.stoppedReason,
      nextPrompt: params.nextPrompt,
      completedAt: Date.now(),
    });
  }

  /** @deprecated Use finishPhase */
  markComplete(): ExecutionContext {
    return this.finishPhase({
      stoppedReason: "none",
      goalAchieved: false,
    });
  }

  canContinue(): boolean {
    return !this.phaseComplete && !this.hasReachedLimit();
  }

  getTurnProgress(): number {
    if (this.maxTurns === 0) return 1.0;
    return Math.min(this.turnsThisCall() / this.maxTurns, 1.0);
  }
}

export const createExecutionContext = (
  goalId: string,
  maxTurnsPerCall: number = 50,
  cumulativeTurnAtStart: number = 0
): ExecutionContext => {
  const now = Date.now();
  return new ExecutionContext({
    id: `exec-${now}-${Math.random().toString(36).substring(2, 9)}`,
    goalId,
    currentTurn: cumulativeTurnAtStart,
    maxTurns: maxTurnsPerCall,
    turnsAtStart: cumulativeTurnAtStart,
    errors: [],
    judgeEvaluations: [],
    toolResults: [],
    isComplete: false,
    phaseComplete: false,
    goalAchieved: false,
    turnLimitReached: false,
    createdAt: now,
  });
};
