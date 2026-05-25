/**
 * Goal - Domain Entity
 * 
 * Represents a persistent, long-running objective in the system.
 * Contains business logic related to goal lifecycle management.
 */
import { Schema as S } from "@effect/schema";
import { Effect } from "effect";

/**
 * Goal status enumeration
 */
export const GoalStatus = S.Literal("active", "paused", "completed", "cancelled");
export type GoalStatus = S.Schema.Type<typeof GoalStatus>;

/**
 * Goal evaluation data structure
 */
export class GoalEvaluation extends S.Class<GoalEvaluation>("GoalEvaluation")({
  progress: S.Number.pipe(S.between(0, 100)),
  completionEstimate: S.optional(S.Number),
  blockers: S.Array(S.String),
  nextSteps: S.Array(S.String),
  notes: S.optional(S.String),
}) {}

/**
 * Goal - Aggregate Root
 * 
 * Main domain entity representing a goal with its full lifecycle and business rules.
 */
export class Goal extends S.Class<Goal>("Goal")({
  id: S.String,
  objective: S.String,
  context: S.optional(S.String),
  status: GoalStatus,
  createdAt: S.Number,
  updatedAt: S.Number,
  completedAt: S.optional(S.Number),
  evaluationData: S.optional(GoalEvaluation),
}) {
  /**
   * Domain logic: Check if goal is active
   */
  isActive(): boolean {
    return this.status === "active";
  }

  /**
   * Domain logic: Check if goal can be resumed
   */
  canResume(): boolean {
    return this.status === "paused";
  }

  /**
   * Domain logic: Check if goal can be paused
   */
  canPause(): boolean {
    return this.status === "active";
  }

  /**
   * Domain logic: Check if goal is terminal (completed or cancelled)
   */
  isTerminal(): boolean {
    return this.status === "completed" || this.status === "cancelled";
  }

  /**
   * Domain logic: Pause the goal
   */
  pause(): Effect.Effect<Goal, Error, never> {
    if (!this.canPause()) {
      return Effect.fail(
        new Error(`Cannot pause goal in status: ${this.status}`)
      );
    }
    return Effect.succeed(
      new Goal({
        ...this,
        status: "paused",
        updatedAt: Date.now(),
      })
    );
  }

  /**
   * Domain logic: Resume the goal
   */
  resume(): Effect.Effect<Goal, Error, never> {
    if (!this.canResume()) {
      return Effect.fail(
        new Error(`Cannot resume goal in status: ${this.status}`)
      );
    }
    return Effect.succeed(
      new Goal({
        ...this,
        status: "active",
        updatedAt: Date.now(),
      })
    );
  }

  /**
   * Domain logic: Complete the goal
   */
  complete(): Effect.Effect<Goal, Error, never> {
    if (this.isTerminal()) {
      return Effect.fail(
        new Error(`Goal already in terminal state: ${this.status}`)
      );
    }
    return Effect.succeed(
      new Goal({
        ...this,
        status: "completed",
        updatedAt: Date.now(),
        completedAt: Date.now(),
      })
    );
  }

  /**
   * Domain logic: Cancel the goal
   */
  cancel(): Effect.Effect<Goal, Error, never> {
    if (this.isTerminal()) {
      return Effect.fail(
        new Error(`Goal already in terminal state: ${this.status}`)
      );
    }
    return Effect.succeed(
      new Goal({
        ...this,
        status: "cancelled",
        updatedAt: Date.now(),
        completedAt: Date.now(),
      })
    );
  }

  /**
   * Domain logic: Update evaluation data
   */
  updateEvaluation(evaluation: GoalEvaluation): Goal {
    return new Goal({
      ...this,
      evaluationData: evaluation,
      updatedAt: Date.now(),
    });
  }
}

/**
 * Factory function to create a new goal
 */
export const createGoal = (objective: string, context?: string): Goal => {
  const now = Date.now();
  return new Goal({
    id: `goal-${now}-${Math.random().toString(36).substring(2, 9)}`,
    objective,
    context,
    status: "active",
    createdAt: now,
    updatedAt: now,
  });
};
