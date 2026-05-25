/**
 * ExecuteGoalCommand - Application Layer
 */
import { Schema as S } from "@effect/schema";
import { Effect } from "effect";
import {
  JUDGE_COMPLETE_CONFIDENCE_THRESHOLD,
  computeMaxTurnsThisCall,
  MAX_GOAL_TURNS_LIFETIME,
} from "../../domain/execution/constants.js";
import { appendGoalEvent } from "../../domain/services/goalEventAppend.js";
import {
  GoalTurnExecuted,
  GoalTurnExecutedPayload,
} from "../../domain/events/GoalTurnExecuted.js";
import type { StoppedReason } from "../../domain/execution/StoppedReason.js";
import { createContinuationContext } from "../../domain/models/ContinuationContext.js";
import {
  createExecutionContext,
  ExecutionContext,
} from "../../domain/models/ExecutionContext.js";
import { IterationOutcome } from "../../domain/models/GoalIteration.js";
import { JudgeStatus } from "../../domain/models/JudgeResult.js";
import { AgentExecutionPort } from "../../domain/ports/AgentExecutionPort.js";
import { GoalIterationRepository } from "../../domain/repositories/GoalIterationRepository.js";
import {
  GoalExecutionRepository,
  initialCheckpoint,
  statusFromStoppedReason,
} from "../../domain/repositories/GoalExecutionRepository.js";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";
import { EventStore } from "../../domain/repositories/EventStore.js";
import { PromptGeneratorService } from "../../domain/services/PromptGeneratorService.js";
import { createIteration } from "../../domain/models/GoalIteration.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { JudgeService } from "../../domain/services/JudgeService.js";

export class ExecutionResult extends S.Class<ExecutionResult>("ExecutionResult")({
  goalId: S.String,
  success: S.Boolean,
  goalAchieved: S.Boolean,
  phaseComplete: S.Boolean,
  turnLimitReached: S.Boolean,
  stoppedReason: S.optional(S.String),
  turnsThisCall: S.Number,
  cumulativeTurn: S.Number,
  nextPrompt: S.optional(S.String),
  context: ExecutionContext,
}) {}

export class ExecuteGoalCommand extends S.Class<ExecuteGoalCommand>("ExecuteGoalCommand")({
  goalId: S.String.pipe(S.minLength(1)),
  maxTurns: S.optional(S.Number),
}) {}

function computeSuccess(
  context: ExecutionContext,
  latestStatus: JudgeStatus | undefined
): boolean {
  if (context.goalAchieved) return true;
  const hasToolWork = context.toolResults.some((t) => t.success);
  if (hasToolWork && latestStatus === JudgeStatus.IN_PROGRESS) return true;
  if (context.stoppedReason === "turn_limit" && !hasToolWork) return false;
  if (context.stoppedReason === "judge_blocked") return false;
  if (context.stoppedReason === "judge_failed") return false;
  if (context.stoppedReason === "goal_turn_budget") return false;
  return false;
}

function isGoalAchievedByJudge(
  status: JudgeStatus,
  confidence: number
): boolean {
  return (
    status === JudgeStatus.COMPLETE &&
    confidence >= JUDGE_COMPLETE_CONFIDENCE_THRESHOLD
  );
}

export const executeGoalHandler = (
  command: ExecuteGoalCommand
): Effect.Effect<
  ExecutionResult,
  Error,
  | GoalRepository
  | JudgeService
  | GoalLifecycleService
  | GoalIterationRepository
  | AgentExecutionPort
  | GoalExecutionRepository
  | EventStore
  | PromptGeneratorService
> =>
  Effect.gen(function* () {
    const repo = yield* GoalRepository;
    const judge = yield* JudgeService;
    const lifecycle = yield* GoalLifecycleService;
    const iterations = yield* GoalIterationRepository;
    const agent = yield* AgentExecutionPort;
    const executions = yield* GoalExecutionRepository;

    const goal = yield* repo.findById(command.goalId);
    if (!goal) {
      return yield* Effect.fail(new Error(`Goal not found: ${command.goalId}`));
    }

    if (goal.isTerminal()) {
      return yield* Effect.fail(
        new Error(`Cannot execute goal in terminal state: ${goal.status}`)
      );
    }

    if (!goal.isActive()) {
      return yield* Effect.fail(
        new Error(
          `Cannot execute goal in status: ${goal.status}. Goal must be active.`
        )
      );
    }

    const stored =
      (yield* executions.get(command.goalId)) ??
      initialCheckpoint(command.goalId);

    const maxTurnsPerCall = computeMaxTurnsThisCall(
      command.maxTurns,
      stored.cumulativeTurn
    );

    if (maxTurnsPerCall <= 0) {
      return yield* Effect.fail(
        new Error(
          `Goal turn budget exhausted (${MAX_GOAL_TURNS_LIFETIME} turns across all agents)`
        )
      );
    }

    let context = createExecutionContext(
      command.goalId,
      maxTurnsPerCall,
      stored.cumulativeTurn
    );

    let continuation = createContinuationContext(goal);
    let stoppedReason: StoppedReason = "none";
    let nextPrompt: string | undefined;

    while (context.canContinue()) {
      context = context.incrementTurn();
      const turn = context.currentTurn;

      const iteration = createIteration(command.goalId, turn);
      yield* iterations.save(iteration);

      const turnOutput = yield* agent.runTurn({
        goal,
        continuation,
        turn,
      });

      nextPrompt = turnOutput.nextPrompt;

      for (const toolResult of turnOutput.toolResults) {
        context = context.recordToolResult(toolResult);
      }

      continuation = continuation
        .incrementTurn()
        .recordTurnOutput(turnOutput.text);

      const judgeResult = yield* judge.evaluateGoalProgress(
        goal,
        turnOutput.text,
        turn
      );

      context = context.recordJudgeEvaluation(judgeResult);
      continuation = continuation.recordJudgeEvaluation(judgeResult);

      const achieved = isGoalAchievedByJudge(
        judgeResult.status,
        judgeResult.confidence
      );

      const iterationOutcome = new IterationOutcome({
        success:
          achieved || turnOutput.toolResults.some((t) => t.success),
        message: judgeResult.reasoning,
        actionsCompleted: [],
        nextActions: [...judgeResult.recommendations],
      });
      const completedIteration = yield* iteration.complete(iterationOutcome);
      yield* iterations.update(completedIteration);

      yield* appendGoalEvent(command.goalId, (version) =>
        GoalTurnExecuted.create(
          command.goalId,
          version,
          new GoalTurnExecutedPayload({
            turn,
            judgeStatus: judgeResult.status,
            judgeConfidence: judgeResult.confidence,
            outputPreview: turnOutput.text.slice(0, 500),
          })
        )
      );

      if (achieved) {
        stoppedReason = "judge_complete";
        yield* lifecycle.completeGoal(command.goalId);
        context = context.finishPhase({
          stoppedReason,
          goalAchieved: true,
          nextPrompt,
        });
        break;
      }

      if (judgeResult.status === JudgeStatus.FAILED) {
        stoppedReason = "judge_failed";
        yield* lifecycle.cancelGoal(command.goalId);
        context = context.finishPhase({
          stoppedReason,
          goalAchieved: false,
          nextPrompt,
        });
        break;
      }

      if (judgeResult.status === JudgeStatus.BLOCKED) {
        stoppedReason = "judge_blocked";
        context = context.finishPhase({
          stoppedReason,
          goalAchieved: false,
          nextPrompt,
        });
        break;
      }
    }

    if (!context.phaseComplete) {
      stoppedReason = "turn_limit";
      context = context.finishPhase({
        stoppedReason,
        goalAchieved: false,
        nextPrompt,
      });
    }

    yield* executions.upsert({
      goalId: command.goalId,
      cumulativeTurn: context.currentTurn,
      status: statusFromStoppedReason(stoppedReason),
      lastJudgeJson: context.getLatestJudgeEvaluation()
        ? JSON.stringify(context.getLatestJudgeEvaluation())
        : null,
      updatedAt: Date.now(),
    });

    const latest = context.getLatestJudgeEvaluation();
    const success = computeSuccess(context, latest?.status);

    return new ExecutionResult({
      goalId: command.goalId,
      success,
      goalAchieved: context.goalAchieved,
      phaseComplete: context.phaseComplete,
      turnLimitReached: context.turnLimitReached,
      stoppedReason: context.stoppedReason,
      turnsThisCall: context.turnsThisCall(),
      cumulativeTurn: context.currentTurn,
      nextPrompt: context.nextPrompt,
      context,
    });
  });
