/**
 * Goal Application Service - Interface
 * 
 * Orchestrates application-level operations using commands and queries.
 * This is the main entry point for the application layer.
 */
import { Context, Effect } from "effect";
import { Goal } from "../../domain/models/Goal.js";
import {
  CreateGoalCommand,
  PauseGoalCommand,
  ResumeGoalCommand,
  CompleteGoalCommand,
} from "../commands/index.js";
import {
  GetGoalQuery,
  ListGoalsQuery,
} from "../queries/index.js";

/**
 * Goal Application Service
 * 
 * Provides high-level operations for goal management.
 */
export class GoalApplicationService extends Context.Tag("GoalApplicationService")<
  GoalApplicationService,
  {
    // Commands
    readonly createGoal: (command: CreateGoalCommand) => Effect.Effect<Goal, Error, never>;
    readonly pauseGoal: (command: PauseGoalCommand) => Effect.Effect<Goal, Error, never>;
    readonly resumeGoal: (command: ResumeGoalCommand) => Effect.Effect<Goal, Error, never>;
    readonly completeGoal: (command: CompleteGoalCommand) => Effect.Effect<Goal, Error, never>;

    // Queries
    readonly getGoal: (query: GetGoalQuery) => Effect.Effect<Goal, Error, never>;
    readonly listGoals: (query: ListGoalsQuery) => Effect.Effect<readonly Goal[], Error, never>;
    readonly getActiveGoal: () => Effect.Effect<Goal | null, Error, never>;
  }
>() {}


