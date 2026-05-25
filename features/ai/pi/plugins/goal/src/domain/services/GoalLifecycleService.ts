/**
 * Goal Lifecycle Service - Domain Service
 * 
 * Contains business logic for goal lifecycle management that doesn't
 * naturally fit within the Goal entity itself.
 */
import { Context, Effect } from "effect";
import { Goal } from "../models/Goal.js";

/**
 * Goal Lifecycle Service
 * 
 * Domain service implementing business rules for goal state transitions.
 */
export class GoalLifecycleService extends Context.Tag("GoalLifecycleService")<
  GoalLifecycleService,
  {
    /**
     * Create and persist a new goal
     */
    readonly createGoal: (
      objective: string,
      context?: string
    ) => Effect.Effect<Goal, Error, never>;

    /**
     * Pause an active goal
     */
    readonly pauseGoal: (goalId: string) => Effect.Effect<Goal, Error, never>;

    /**
     * Resume a paused goal
     */
    readonly resumeGoal: (goalId: string) => Effect.Effect<Goal, Error, never>;

    /**
     * Complete a goal
     */
    readonly completeGoal: (goalId: string) => Effect.Effect<Goal, Error, never>;

    /**
     * Cancel a goal
     */
    readonly cancelGoal: (goalId: string) => Effect.Effect<Goal, Error, never>;

    /**
     * Check if a new goal can be activated
     * Business rule: Only one active goal at a time
     */
    readonly canActivateGoal: () => Effect.Effect<boolean, Error, never>;
  }
>() {}
