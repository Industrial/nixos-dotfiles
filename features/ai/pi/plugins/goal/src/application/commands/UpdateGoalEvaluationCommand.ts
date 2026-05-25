/**
 * UpdateGoalEvaluationCommand - Application Layer
 *
 * Command to update goal evaluation data (progress, blockers, next steps).
 */
import { Schema as S } from "@effect/schema";
import { Effect } from "effect";
import type { Goal } from "../../domain/models/Goal.js";
import { GoalEvaluation } from "../../domain/models/Goal.js";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";

export class UpdateGoalEvaluationCommand extends S.Class<UpdateGoalEvaluationCommand>("UpdateGoalEvaluationCommand")({
  goalId: S.String.pipe(S.minLength(1)),
  progress: S.Number.pipe(S.between(0, 100)),
  completionEstimate: S.optional(S.Number),
  blockers: S.Array(S.String),
  nextSteps: S.Array(S.String),
  notes: S.optional(S.String),
}) {}

export const updateGoalEvaluationHandler = (
  command: UpdateGoalEvaluationCommand
): Effect.Effect<Goal, Error, GoalRepository> =>
  Effect.gen(function* () {
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

    // Create new evaluation data
    const evaluation = new GoalEvaluation({
      progress: command.progress,
      completionEstimate: command.completionEstimate,
      blockers: command.blockers,
      nextSteps: command.nextSteps,
      notes: command.notes,
    });

    // Update goal with new evaluation
    const updatedGoal = existingGoal.updateEvaluation(evaluation);

    // Save updated goal
    yield* repo.update(updatedGoal);

    return updatedGoal;
  });
