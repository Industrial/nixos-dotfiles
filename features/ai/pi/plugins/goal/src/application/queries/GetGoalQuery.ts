/**
 * Get Goal Query - Application Layer
 * 
 * CQRS Query for retrieving a single goal.
 */
import { Effect } from "effect";
import { Schema as S } from "@effect/schema";
import { Goal } from "../../domain/models/Goal.js";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";

/**
 * Get Goal Query Input
 */
export class GetGoalQuery extends S.Class<GetGoalQuery>("GetGoalQuery")({
  goalId: S.String,
}) {}

/**
 * Get Goal Query Handler
 */
export const getGoalHandler = (query: GetGoalQuery) =>
  Effect.gen(function* () {
    const goalRepo = yield* GoalRepository;
    const goal = yield* goalRepo.findById(query.goalId);
    
    if (!goal) {
      return yield* Effect.fail(new Error(`Goal not found: ${query.goalId}`));
    }
    
    return goal;
  });
