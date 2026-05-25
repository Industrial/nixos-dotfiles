/**
 * GoalIteration - Domain Entity
 * 
 * Represents a single execution attempt of a goal.
 */
import { Schema as S } from "@effect/schema";
import { Effect } from "effect";
import { GoalEvaluation } from "./Goal.js";

/**
 * Iteration outcome value object
 */
export class IterationOutcome extends S.Class<IterationOutcome>("IterationOutcome")({
  success: S.Boolean,
  message: S.String,
  actionsCompleted: S.Array(S.String),
  nextActions: S.Array(S.String),
}) {}

/**
 * GoalIteration - Entity
 * 
 * Represents one iteration/attempt at executing a goal.
 */
export class GoalIteration extends S.Class<GoalIteration>("GoalIteration")({
  id: S.String,
  goalId: S.String,
  iterationNumber: S.Number,
  startedAt: S.Number,
  completedAt: S.optional(S.Number),
  outcome: S.optional(IterationOutcome),
  evaluationData: S.optional(GoalEvaluation),
}) {
  /**
   * Domain logic: Check if iteration is completed
   */
  isCompleted(): boolean {
    return this.completedAt !== undefined;
  }

  /**
   * Domain logic: Check if iteration is in progress
   */
  isInProgress(): boolean {
    return !this.isCompleted();
  }

  /**
   * Domain logic: Complete the iteration with an outcome
   */
  complete(outcome: IterationOutcome): Effect.Effect<GoalIteration, Error, never> {
    if (this.isCompleted()) {
      return Effect.fail(new Error(`Iteration already completed: ${this.id}`));
    }
    return Effect.succeed(
      new GoalIteration({
        ...this,
        completedAt: Date.now(),
        outcome,
      })
    );
  }

  /**
   * Domain logic: Update evaluation data
   */
  updateEvaluation(evaluation: GoalEvaluation): GoalIteration {
    return new GoalIteration({
      ...this,
      evaluationData: evaluation,
    });
  }

  /**
   * Domain logic: Calculate duration in milliseconds
   */
  duration(): number | null {
    if (!this.completedAt) return null;
    return this.completedAt - this.startedAt;
  }
}

/**
 * Factory function to create a new iteration
 */
export const createIteration = (goalId: string, iterationNumber: number): GoalIteration => {
  const now = Date.now();
  return new GoalIteration({
    id: `iteration-${now}-${Math.random().toString(36).substring(2, 9)}`,
    goalId,
    iterationNumber,
    startedAt: now,
  });
};
