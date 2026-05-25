/**
 * Goal Application Service
 * 
 * Orchestrates application-level operations using commands and queries.
 * This is the main entry point for the application layer.
 */
import { Context, Effect, Layer } from "effect";
import { Goal } from "../../domain/models/Goal.js";
import {
  CreateGoalCommand,
  createGoalHandler,
  PauseGoalCommand,
  pauseGoalHandler,
  ResumeGoalCommand,
  resumeGoalHandler,
  CompleteGoalCommand,
  completeGoalHandler,
} from "../commands/index.js";
import {
  GetGoalQuery,
  getGoalHandler,
  ListGoalsQuery,
  listGoalsHandler,
  getActiveGoalHandler,
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

/**
 * Live implementation of GoalApplicationService
 * 
 * Note: Handler functions need access to services from context,
 * so we return them as-is. They'll pull services when executed.
 */
export const GoalApplicationServiceLive = Layer.succeed(
  GoalApplicationService,
  GoalApplicationService.of({
    createGoal: createGoalHandler,
    pauseGoal: pauseGoalHandler,
    resumeGoal: resumeGoalHandler,
    completeGoal: completeGoalHandler,
    getGoal: getGoalHandler,
    listGoals: listGoalsHandler,
    getActiveGoal: getActiveGoalHandler,
  })
);
