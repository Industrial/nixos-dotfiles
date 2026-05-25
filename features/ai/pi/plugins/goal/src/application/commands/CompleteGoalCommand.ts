/**
 * Complete Goal Command - Application Layer
 */
import { Effect } from "effect";
import { Schema as S } from "@effect/schema";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";

/**
 * Complete Goal Command Input
 */
export class CompleteGoalCommand extends S.Class<CompleteGoalCommand>("CompleteGoalCommand")({
  goalId: S.String,
}) {}

/**
 * Complete Goal Command Handler
 */
export const completeGoalHandler = (command: CompleteGoalCommand) =>
  Effect.gen(function* () {
    const lifecycleService = yield* GoalLifecycleService;
    return yield* lifecycleService.completeGoal(command.goalId);
  });
