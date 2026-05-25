/**
 * Goal Application Service - Live Implementation
 */
import { Layer } from "effect";
import { GoalApplicationService } from "./GoalApplicationService.js";
import {
  createGoalHandler,
  pauseGoalHandler,
  resumeGoalHandler,
  completeGoalHandler,
} from "../commands/index.js";
import {
  getGoalHandler,
  listGoalsHandler,
  getActiveGoalHandler,
} from "../queries/index.js";

/**
 * Live implementation of GoalApplicationService
 * 
 * Provides actual command and query handlers that depend on
 * domain services and repositories.
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
