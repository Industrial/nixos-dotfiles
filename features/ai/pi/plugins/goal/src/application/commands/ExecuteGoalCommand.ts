/**
 * ExecuteGoalCommand - Application Layer
 *
 * Command to execute a goal in a continuation loop.
 */
import { Schema as S } from "@effect/schema";
import { Effect } from "effect";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";
import { createExecutionContext, ExecutionContext } from "../../domain/models/ExecutionContext.js";

/**
 * Execution result
 */
export class ExecutionResult extends S.Class<ExecutionResult>("ExecutionResult")({
  goalId: S.String,
  success: S.Boolean,
  context: ExecutionContext,
}) {}

/**
 * ExecuteGoalCommand Input
 */
export class ExecuteGoalCommand extends S.Class<ExecuteGoalCommand>("ExecuteGoalCommand")({
  goalId: S.String.pipe(S.minLength(1)),
  maxTurns: S.optional(S.Number),
}) {}

/**
 * ExecuteGoalCommand Handler
 *
 * Note: This is a basic implementation that creates an execution context
 * and runs a simple loop. The actual goal execution logic (judge evaluation,
 * prompting, etc.) will be implemented in subsequent tasks.
 */
export const executeGoalHandler = (
  command: ExecuteGoalCommand
): Effect.Effect<ExecutionResult, Error, GoalRepository> =>
  Effect.gen(function* () {
    const repo = yield* GoalRepository;

    // Verify goal exists and is not in terminal state
    const goal = yield* repo.findById(command.goalId);
    if (!goal) {
      return yield* Effect.fail(
        new Error(`Goal not found: ${command.goalId}`)
      );
    }

    if (goal.isTerminal()) {
      return yield* Effect.fail(
        new Error(`Cannot execute goal in terminal state: ${goal.status}`)
      );
    }

    // Create execution context
    const maxTurns = command.maxTurns ?? 50;
    let context = createExecutionContext(command.goalId, maxTurns);

    // Basic execution loop
    // Note: Actual execution logic (judge model, prompting) will be added in future tasks
    while (context.canContinue()) {
      context = context.incrementTurn();

      // Placeholder: In a real implementation, this would:
      // 1. Generate prompt for current turn
      // 2. Execute LLM call
      // 3. Evaluate result with judge model
      // 4. Update goal state
      // 5. Check completion criteria

      // For now, continue looping until turn limit is reached
      // The loop will exit when hasReachedLimit() becomes true
    }

    // Mark as complete when loop exits
    if (!context.isComplete) {
      context = context.markComplete();
    }

    return new ExecutionResult({
      goalId: command.goalId,
      success: true,
      context,
    });
  });
