/**
 * GoalApplicationService - Application Facade
 *
 * Main application service that coordinates all goal operations.
 * Provides a simplified API for the Pi extension layer.
 */
import { Context, Effect, Layer } from "effect";
import { Goal } from "../domain/models/Goal.js";
import {
  GoalStatistics,
  GetGoalStatisticsQuery,
} from "./queries/GetGoalStatisticsQuery.js";
import { ExecutionResult } from "./commands/ExecuteGoalCommand.js";
import { createGoalHandler, CreateGoalCommand } from "./commands/CreateGoalCommand.js";
import { pauseGoalHandler, PauseGoalCommand } from "./commands/PauseGoalCommand.js";
import { resumeGoalHandler, ResumeGoalCommand } from "./commands/ResumeGoalCommand.js";
import { completeGoalHandler, CompleteGoalCommand } from "./commands/CompleteGoalCommand.js";
import { cancelGoalHandler, CancelGoalCommand } from "./commands/CancelGoalCommand.js";
import { executeGoalHandler, ExecuteGoalCommand } from "./commands/ExecuteGoalCommand.js";
import { getActiveGoalHandler } from "./queries/GetActiveGoalQuery.js";
import { getGoalStatisticsHandler } from "./queries/GetGoalStatisticsQuery.js";
import { GoalRepository } from "../domain/repositories/GoalRepository.js";
import { GoalLifecycleService } from "../domain/services/GoalLifecycleService.js";
import { JudgeService } from "../domain/services/JudgeService.js";

/**
 * Main application service interface
 *
 * Facade that simplifies access to all goal functionality.
 * Used by Pi extension commands and other integrations.
 */
export interface GoalApplicationService {
  /**
   * Create a new goal
   */
  createGoal(params: {
    objective: string;
    context?: string;
  }): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService>;

  /**
   * Pause an active goal
   */
  pauseGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService>;

  /**
   * Resume a paused goal
   */
  resumeGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService>;

  /**
   * Mark a goal as complete
   */
  completeGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService>;

  /**
   * Cancel a goal
   */
  cancelGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService>;

  /**
   * Execute a goal in continuation loop
   */
  executeGoal(
    goalId: string,
    options?: { maxTurns?: number }
  ): Effect.Effect<ExecutionResult, Error, GoalRepository | JudgeService>;

  /**
   * Get the currently active goal
   */
  getActiveGoal(): Effect.Effect<Goal | undefined, Error, GoalRepository>;

  /**
   * Get goal statistics
   */
  getGoalStatistics(): Effect.Effect<GoalStatistics, Error, GoalRepository>;
}

/**
 * Implementation of GoalApplicationService
 */
class GoalApplicationServiceImpl implements GoalApplicationService {
  createGoal(params: {
    objective: string;
    context?: string;
  }): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService> {
    return createGoalHandler(new CreateGoalCommand(params));
  }

  pauseGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService> {
    return pauseGoalHandler(new PauseGoalCommand({ goalId }));
  }

  resumeGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService> {
    return resumeGoalHandler(new ResumeGoalCommand({ goalId }));
  }

  completeGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService> {
    return completeGoalHandler(new CompleteGoalCommand({ goalId }));
  }

  cancelGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService> {
    return cancelGoalHandler(new CancelGoalCommand({ goalId }));
  }

  executeGoal(
    goalId: string,
    options?: { maxTurns?: number }
  ): Effect.Effect<ExecutionResult, Error, GoalRepository | JudgeService> {
    return executeGoalHandler(
      new ExecuteGoalCommand({
        goalId,
        maxTurns: options?.maxTurns,
      })
    );
  }

  getActiveGoal(): Effect.Effect<Goal | undefined, Error, GoalRepository> {
    return getActiveGoalHandler().pipe(
      Effect.map((goal) => (goal === null ? undefined : goal))
    );
  }

  getGoalStatistics(): Effect.Effect<GoalStatistics, Error, GoalRepository> {
    return getGoalStatisticsHandler(new GetGoalStatisticsQuery());
  }
}

/**
 * GoalApplicationService tag for dependency injection
 */
export const GoalApplicationService = Context.GenericTag<GoalApplicationService>(
  "@goal/GoalApplicationService"
);

/**
 * Factory function to create GoalApplicationService
 */
export const createGoalApplicationService = (): Effect.Effect<
  GoalApplicationService,
  never,
  never
> => {
  return Effect.succeed(new GoalApplicationServiceImpl());
};

/**
 * GoalApplicationService Layer
 */
export const GoalApplicationServiceLive = Layer.effect(
  GoalApplicationService,
  createGoalApplicationService()
);
