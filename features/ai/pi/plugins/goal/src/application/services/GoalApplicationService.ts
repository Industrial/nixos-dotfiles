/**
 * Goal Application Service - Interface
 * 
 * Orchestrates application-level operations using commands and queries.
 * This is the main entry point for the application layer.
 */
import { Context, Effect } from "effect";
import { Goal } from "../../domain/models/Goal.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";
import { EventStore } from "../../domain/repositories/EventStore.js";
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
    readonly createGoal: (
      command: CreateGoalCommand
    ) => Effect.Effect<Goal, Error, GoalLifecycleService | EventStore>;
    readonly pauseGoal: (
      command: PauseGoalCommand
    ) => Effect.Effect<Goal, Error, GoalLifecycleService | EventStore>;
    readonly resumeGoal: (
      command: ResumeGoalCommand
    ) => Effect.Effect<Goal, Error, GoalLifecycleService | EventStore>;
    readonly completeGoal: (
      command: CompleteGoalCommand
    ) => Effect.Effect<Goal, Error, GoalLifecycleService | EventStore>;

    // Queries
    readonly getGoal: (query: GetGoalQuery) => Effect.Effect<Goal, Error, GoalRepository>;
    readonly listGoals: (query: ListGoalsQuery) => Effect.Effect<readonly Goal[], Error, GoalRepository>;
    readonly getActiveGoal: () => Effect.Effect<Goal | null, Error, GoalRepository>;
  }
>() {}


