/**
 * List Goals Query - Application Layer
 */
import { Effect } from "effect";
import { Schema as S } from "@effect/schema";
import { Goal, GoalStatus } from "../../domain/models/Goal.js";
import { GoalRepository, GoalFilters } from "../../domain/repositories/GoalRepository.js";

/**
 * List Goals Query Input
 */
export class ListGoalsQuery extends S.Class<ListGoalsQuery>("ListGoalsQuery")({
  status: S.optional(GoalStatus),
  limit: S.optional(S.Number),
  offset: S.optional(S.Number),
}) {}

/**
 * List Goals Query Handler
 */
export const listGoalsHandler = (query: ListGoalsQuery) =>
  Effect.gen(function* () {
    const goalRepo = yield* GoalRepository;
    
    const filters: GoalFilters = {
      status: query.status,
      limit: query.limit,
      offset: query.offset,
    };
    
    return yield* goalRepo.findAll(filters);
  });
