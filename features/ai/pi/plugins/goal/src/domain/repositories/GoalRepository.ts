/**
 * Goal Repository - Domain Interface
 * 
 * Defines the contract for Goal persistence following DDD Repository pattern.
 * This is a domain interface - no implementation details leak into the domain layer.
 */
import { Context, Effect } from "effect";
import { Goal } from "../models/Goal.js";

/**
 * Goal query filters value object
 */
export interface GoalFilters {
  readonly status?: "active" | "paused" | "completed" | "cancelled";
  readonly limit?: number;
  readonly offset?: number;
}

/**
 * Goal Repository - Domain Interface
 * 
 * The repository acts as a collection abstraction for the Goal aggregate.
 * Infrastructure layer provides the actual implementation.
 */
export class GoalRepository extends Context.Tag("GoalRepository")<
  GoalRepository,
  {
    /**
     * Save a new goal to the repository
     */
    readonly save: (goal: Goal) => Effect.Effect<Goal, Error, never>;

    /**
     * Find a goal by its unique identifier
     * Returns null if not found
     */
    readonly findById: (id: string) => Effect.Effect<Goal | null, Error, never>;

    /**
     * Find all goals matching the given filters
     */
    readonly findAll: (filters?: GoalFilters) => Effect.Effect<readonly Goal[], Error, never>;

    /**
     * Find the currently active goal (if any)
     * Returns null if no active goal exists
     */
    readonly findActive: () => Effect.Effect<Goal | null, Error, never>;

    /**
     * Update an existing goal in the repository
     * Throws error if goal doesn't exist
     */
    readonly update: (goal: Goal) => Effect.Effect<Goal, Error, never>;

    /**
     * Delete a goal from the repository
     */
    readonly delete: (id: string) => Effect.Effect<void, Error, never>;

    /**
     * Check if a goal exists
     */
    readonly exists: (id: string) => Effect.Effect<boolean, Error, never>;

    /**
     * Count goals matching the given filters
     */
    readonly count: (filters?: GoalFilters) => Effect.Effect<number, Error, never>;
  }
>() {}
