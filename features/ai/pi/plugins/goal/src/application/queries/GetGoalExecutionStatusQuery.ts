import { Effect } from "effect";
import { Schema as S } from "@effect/schema";
import { GoalExecutionRepository } from "../../domain/repositories/GoalExecutionRepository.js";
import { GoalIterationRepository } from "../../domain/repositories/GoalIterationRepository.js";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";

export class GetGoalExecutionStatusQuery extends S.Class<GetGoalExecutionStatusQuery>(
  "GetGoalExecutionStatusQuery"
)({
  goalId: S.String,
}) {}

export const getGoalExecutionStatusHandler = (
  query: GetGoalExecutionStatusQuery
) =>
  Effect.gen(function* () {
    const goals = yield* GoalRepository;
    const executions = yield* GoalExecutionRepository;
    const iterations = yield* GoalIterationRepository;

    const goal = yield* goals.findById(query.goalId);
    if (!goal) {
      return yield* Effect.fail(new Error(`Goal not found: ${query.goalId}`));
    }

    const checkpoint = yield* executions.get(query.goalId);
    const latestIteration = yield* iterations.findLatest(query.goalId);
    const iterationCount = yield* iterations.countByGoalId(query.goalId);

    return {
      goal: {
        id: goal.id,
        objective: goal.objective,
        status: goal.status,
      },
      execution: checkpoint
        ? {
            cumulativeTurn: checkpoint.cumulativeTurn,
            status: checkpoint.status,
            updatedAt: checkpoint.updatedAt,
            lastJudge: checkpoint.lastJudgeJson
              ? JSON.parse(checkpoint.lastJudgeJson)
              : null,
          }
        : null,
      latestIteration: latestIteration
        ? {
            id: latestIteration.id,
            iterationNumber: latestIteration.iterationNumber,
            completedAt: latestIteration.completedAt,
            outcome: latestIteration.outcome,
          }
        : null,
      iterationCount,
    };
  });
