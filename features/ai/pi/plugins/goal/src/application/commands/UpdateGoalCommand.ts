/**
 * UpdateGoalCommand - Application Layer
 *
 * Command to update goal properties (objective, context) during execution.
 */
import { Schema as S } from "@effect/schema";
import { Effect } from "effect";
import { Goal } from "../../domain/models/Goal.js";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";

export class UpdateGoalCommand extends S.Class<UpdateGoalCommand>("UpdateGoalCommand")({
  goalId: S.String.pipe(S.minLength(1)),
  objective: S.optional(S.String),
  context: S.optional(S.String),
}) {}

export const updateGoalHandler = (
  command: UpdateGoalCommand
): Effect.Effect<Goal, Error, GoalRepository> =>
  Effect.gen(function* () {
    // Validate at least one field is provided for update
    // Note: explicit undefined is allowed (clears the field)
    const hasObjective = "objective" in command;
    const hasContext = "context" in command;

    if (!hasObjective && !hasContext) {
      return yield* Effect.fail(
        new Error("At least one field (objective or context) must be provided for update")
      );
    }

    const repo = yield* GoalRepository;

    // Fetch existing goal
    const existingGoal = yield* repo.findById(command.goalId);
    if (!existingGoal) {
      return yield* Effect.fail(
        new Error(`Goal not found: ${command.goalId}`)
      );
    }

    // Check if goal is in terminal state
    if (existingGoal.isTerminal()) {
      return yield* Effect.fail(
        new Error(`Cannot update goal in terminal state: ${existingGoal.status}`)
      );
    }

    // Update goal properties
    // Note: undefined explicitly clears optional fields (like context)
    // objective is required, so if provided it must be a string (Effect Schema ensures this)
    const updatedGoal = new Goal({
      ...existingGoal,
      objective: hasObjective ? (command.objective as string) : existingGoal.objective,
      context: hasContext ? command.context : existingGoal.context,
      updatedAt: Date.now(),
    });

    // Save updated goal
    yield* repo.update(updatedGoal);

    return updatedGoal;
  });
