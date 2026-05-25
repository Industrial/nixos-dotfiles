/**
 * Get Active Goal Query - Application Layer
 */
import { Effect } from "effect";
import { Goal } from "../../domain/models/Goal.js";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";

/**
 * Get Active Goal Query Handler
 * No input needed - returns the currently active goal if any
 */
export const getActiveGoalHandler = () =>
  Effect.gen(function* () {
    const goalRepo = yield* GoalRepository;
    return yield* goalRepo.findActive();
  });
