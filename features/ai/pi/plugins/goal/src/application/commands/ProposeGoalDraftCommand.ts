import { Schema as S } from "@effect/schema";
import { Effect } from "effect";
import type { Goal } from "../../domain/models/Goal.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";

export class ProposeGoalDraftCommand extends S.Class<ProposeGoalDraftCommand>("ProposeGoalDraftCommand")({
  objective: S.String.pipe(S.minLength(1)),
  context: S.optional(S.String),
  rationale: S.optional(S.String),
  successCriteria: S.optional(S.Array(S.String)),
}) {}

export const proposeGoalDraftHandler = (
  command: ProposeGoalDraftCommand
): Effect.Effect<Goal, Error, GoalLifecycleService> =>
  Effect.gen(function* () {
    const service = yield* GoalLifecycleService;
    return yield* service.createGoal(command.objective, command.context);
  });
