import { Schema as S } from "@effect/schema";
import { Effect } from "effect";
import type { Goal } from "../../domain/models/Goal.js";
import { createGoalDraft } from "../../domain/models/Goal.js";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";

export class ProposeGoalDraftCommand extends S.Class<ProposeGoalDraftCommand>("ProposeGoalDraftCommand")({
  objective: S.String.pipe(S.minLength(1)),
  context: S.optional(S.String),
  rationale: S.optional(S.String),
  successCriteria: S.optional(S.Array(S.String)),
}) {}

export const proposeGoalDraftHandler = (
  command: ProposeGoalDraftCommand
): Effect.Effect<Goal, Error, GoalRepository> =>
  Effect.gen(function* () {
    const repo = yield* GoalRepository;

    // Create draft goal (doesn't enforce "one active goal" rule)
    const draft = createGoalDraft(command.objective, command.context);

    // Save draft to repository
    yield* repo.save(draft);

    return draft;
  });
