/**
 * Resume Goal Command - Application Layer
 */
import { Effect } from "effect";
import { Schema as S } from "@effect/schema";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";

/**
 * Resume Goal Command Input
 */
export class ResumeGoalCommand extends S.Class<ResumeGoalCommand>("ResumeGoalCommand")({
  goalId: S.String,
}) {}

/**
 * Resume Goal Command Handler
 */
export const resumeGoalHandler = (command: ResumeGoalCommand) =>
  Effect.gen(function* () {
    const lifecycleService = yield* GoalLifecycleService;
    return yield* lifecycleService.resumeGoal(command.goalId);
  });
