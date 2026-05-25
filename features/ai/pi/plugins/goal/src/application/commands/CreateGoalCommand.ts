/**
 * Create Goal Command - Application Layer
 * 
 * CQRS Command for creating a new goal.
 */
import { Effect } from "effect";
import { Schema as S } from "@effect/schema";
import { Goal } from "../../domain/models/Goal.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";

/**
 * Create Goal Command Input
 */
export class CreateGoalCommand extends S.Class<CreateGoalCommand>("CreateGoalCommand")({
  objective: S.String.pipe(S.minLength(1)),
  context: S.optional(S.String),
}) {}

/**
 * Create Goal Command Handler
 */
export const createGoalHandler = (command: CreateGoalCommand) =>
  Effect.gen(function* () {
    const lifecycleService = yield* GoalLifecycleService;
    return yield* lifecycleService.createGoal(command.objective, command.context);
  });
