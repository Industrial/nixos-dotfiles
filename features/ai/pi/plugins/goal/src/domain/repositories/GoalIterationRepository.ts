/**
 * Goal Iteration Repository - Domain Interface
 */
import { Context, Effect } from "effect";
import { GoalIteration } from "../models/GoalIteration.js";

/**
 * Goal Iteration Repository - Domain Interface
 * 
 * Manages persistence of goal iterations.
 */
export class GoalIterationRepository extends Context.Tag("GoalIterationRepository")<
  GoalIterationRepository,
  {
    /**
     * Save a new iteration to the repository
     */
    readonly save: (iteration: GoalIteration) => Effect.Effect<GoalIteration, Error, never>;

    /**
     * Find an iteration by its unique identifier
     */
    readonly findById: (id: string) => Effect.Effect<GoalIteration | null, Error, never>;

    /**
     * Find all iterations for a specific goal
     * Ordered by iteration number (descending)
     */
    readonly findByGoalId: (goalId: string) => Effect.Effect<readonly GoalIteration[], Error, never>;

    /**
     * Find the latest iteration for a goal
     */
    readonly findLatest: (goalId: string) => Effect.Effect<GoalIteration | null, Error, never>;

    /**
     * Update an existing iteration
     */
    readonly update: (iteration: GoalIteration) => Effect.Effect<GoalIteration, Error, never>;

    /**
     * Delete an iteration
     */
    readonly delete: (id: string) => Effect.Effect<void, Error, never>;

    /**
     * Delete all iterations for a goal (cascade delete)
     */
    readonly deleteByGoalId: (goalId: string) => Effect.Effect<void, Error, never>;

    /**
     * Count iterations for a goal
     */
    readonly countByGoalId: (goalId: string) => Effect.Effect<number, Error, never>;
  }
>() {}
