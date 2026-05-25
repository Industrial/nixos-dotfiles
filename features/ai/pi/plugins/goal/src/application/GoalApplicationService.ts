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
import { getGoalHandler, GetGoalQuery } from "./queries/GetGoalQuery.js";
import { listGoalsHandler, ListGoalsQuery } from "./queries/ListGoalsQuery.js";
import {
  getGoalExecutionStatusHandler,
  GetGoalExecutionStatusQuery,
} from "./queries/GetGoalExecutionStatusQuery.js";
import { getGoalStatisticsHandler } from "./queries/GetGoalStatisticsQuery.js";
import { GoalRepository } from "../domain/repositories/GoalRepository.js";
import { GoalExecutionRepository } from "../domain/repositories/GoalExecutionRepository.js";
import { GoalIterationRepository } from "../domain/repositories/GoalIterationRepository.js";
import { GoalLifecycleService } from "../domain/services/GoalLifecycleService.js";
import { JudgeService } from "../domain/services/JudgeService.js";
import { AgentExecutionPort } from "../domain/ports/AgentExecutionPort.js";
import { EventStore } from "../domain/repositories/EventStore.js";
import { PromptGeneratorService } from "../domain/services/PromptGeneratorService.js";

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
  }): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService | EventStore>;

  /**
   * Pause an active goal
   */
  pauseGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService | EventStore>;

  /**
   * Resume a paused goal
   */
  resumeGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService | EventStore>;

  /**
   * Mark a goal as complete
   */
  completeGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService | EventStore>;

  /**
   * Cancel a goal
   */
  cancelGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService | EventStore>;

  /**
   * Execute a goal in continuation loop
   */
  executeGoal(
    goalId: string,
    options?: { maxTurns?: number }
  ): Effect.Effect<
    ExecutionResult,
    Error,
    | GoalRepository
    | JudgeService
    | GoalLifecycleService
    | GoalIterationRepository
    | AgentExecutionPort
    | GoalExecutionRepository
    | EventStore
    | PromptGeneratorService
  >;

  /**
   * Get the currently active goal
   */
  getActiveGoal(): Effect.Effect<Goal | undefined, Error, GoalRepository>;

  /**
   * Get goal statistics
   */
  getGoalStatistics(): Effect.Effect<GoalStatistics, Error, GoalRepository>;

  getGoal(goalId: string): Effect.Effect<Goal, Error, GoalRepository>;

  listGoals(params?: {
    status?: Goal["status"];
    limit?: number;
    offset?: number;
  }): Effect.Effect<readonly Goal[], Error, GoalRepository>;

  getExecutionStatus(goalId: string): Effect.Effect<
    {
      goal: { id: string; objective: string; status: string };
      execution: {
        cumulativeTurn: number;
        status: string;
        updatedAt: number;
        lastJudge: unknown;
      } | null;
      latestIteration: {
        id: string;
        iterationNumber: number;
        completedAt: number | undefined;
        outcome: unknown;
      } | null;
      iterationCount: number;
    },
    Error,
    GoalRepository | GoalExecutionRepository | GoalIterationRepository
  >;
}

/**
 * Implementation of GoalApplicationService
 */
class GoalApplicationServiceImpl implements GoalApplicationService {
  createGoal(params: {
    objective: string;
    context?: string;
  }): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService | EventStore> {
    return createGoalHandler(new CreateGoalCommand(params));
  }

  pauseGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService | EventStore> {
    return pauseGoalHandler(new PauseGoalCommand({ goalId }));
  }

  resumeGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService | EventStore> {
    return resumeGoalHandler(new ResumeGoalCommand({ goalId }));
  }

  completeGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService | EventStore> {
    return completeGoalHandler(new CompleteGoalCommand({ goalId }));
  }

  cancelGoal(
    goalId: string
  ): Effect.Effect<Goal, Error, GoalRepository | GoalLifecycleService | EventStore> {
    return cancelGoalHandler(new CancelGoalCommand({ goalId }));
  }

  executeGoal(
    goalId: string,
    options?: { maxTurns?: number }
  ): Effect.Effect<
    ExecutionResult,
    Error,
    | GoalRepository
    | JudgeService
    | GoalLifecycleService
    | GoalIterationRepository
    | AgentExecutionPort
    | GoalExecutionRepository
    | EventStore
    | PromptGeneratorService
  > {
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

  getGoal(goalId: string): Effect.Effect<Goal, Error, GoalRepository> {
    return getGoalHandler(new GetGoalQuery({ goalId }));
  }

  listGoals(params?: {
    status?: Goal["status"];
    limit?: number;
    offset?: number;
  }): Effect.Effect<readonly Goal[], Error, GoalRepository> {
    return listGoalsHandler(
      new ListGoalsQuery({
        status: params?.status,
        limit: params?.limit,
        offset: params?.offset,
      })
    );
  }

  getExecutionStatus(goalId: string) {
    return getGoalExecutionStatusHandler(
      new GetGoalExecutionStatusQuery({ goalId })
    );
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
