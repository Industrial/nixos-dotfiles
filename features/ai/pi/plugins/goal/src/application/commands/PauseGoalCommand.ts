/**
 * Pause Goal Command - Application Layer
 */
import { Effect } from "effect";
import { Schema as S } from "@effect/schema";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";

/**
 * Pause Goal Command Input
 */
export class PauseGoalCommand extends S.Class<PauseGoalCommand>("PauseGoalCommand")({
  goalId: S.String,
}) {}

/**
 * Pause Goal Command Handler
 */
export const pauseGoalHandler = (command: PauseGoalCommand) =>
  Effect.gen(function* () {
    const lifecycleService = yield* GoalLifecycleService;
    return yield* lifecycleService.pauseGoal(command.goalId);
  });
