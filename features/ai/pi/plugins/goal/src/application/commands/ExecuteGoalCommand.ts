/**
 * ExecuteGoalCommand - Application Layer
 *
 * Command to execute a goal in a continuation loop.
 */
import { Schema as S } from "@effect/schema";
import { Effect } from "effect";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";
import { JudgeService } from "../../domain/services/JudgeService.js";
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
 * Executes a goal in a continuation loop with judge evaluation.
 * Integrates LLM-as-Judge pattern for objective progress assessment.
 */
export const executeGoalHandler = (
  command: ExecuteGoalCommand
): Effect.Effect<ExecutionResult, Error, GoalRepository | JudgeService> =>
  Effect.gen(function* () {
    const repo = yield* GoalRepository;
    const judge = yield* JudgeService;

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

    // Execution loop with judge evaluation
    while (context.canContinue()) {
      context = context.incrementTurn();

      // 1. Generate prompt for current turn
      // TODO: Implement PromptGeneratorService (task dotfiles-csa.3.2)
      const turnContext = `Turn ${context.currentTurn}: Placeholder execution context`;

      // 2. Execute LLM call
      // TODO: Implement goal execution logic (task dotfiles-csa.3.2)
      // For now, skip to judge evaluation

      // 3. Evaluate progress with judge model
      const judgeResult = yield* judge.evaluateGoalProgress(
        goal,
        turnContext,
        context.currentTurn
      );

      // 4. Record judge evaluation
      context = context.recordJudgeEvaluation(judgeResult);

      // 5. Check completion criteria from judge
      if (judgeResult.isTerminal()) {
        // Judge determined goal is complete or failed
        context = context.markComplete();
        break;
      }

      // 6. Check if judge says we should not continue (blocked)
      if (!judgeResult.shouldContinue()) {
        // Goal is blocked or in terminal state
        context = context.markComplete();
        break;
      }

      // Continue to next turn if judge says IN_PROGRESS and turn limit not reached
    }

    // Mark as complete if loop exited due to turn limit
    if (!context.isComplete) {
      context = context.markComplete();
    }

    return new ExecutionResult({
      goalId: command.goalId,
      success: true,
      context,
    });
  });
