import { Schema as S } from "@effect/schema";
import { Effect } from "effect";
import type { Goal } from "../../domain/models/Goal.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { EventStore } from "../../domain/repositories/EventStore.js";

export class CancelGoalCommand extends S.Class<CancelGoalCommand>("CancelGoalCommand")({
  goalId: S.String,
  reason: S.optional(S.String),
}) {}

export const cancelGoalHandler = (
  command: CancelGoalCommand
): Effect.Effect<Goal, Error, GoalLifecycleService | EventStore> =>
  Effect.gen(function* () {
    const service = yield* GoalLifecycleService;
    return yield* service.cancelGoal(command.goalId);
  });
