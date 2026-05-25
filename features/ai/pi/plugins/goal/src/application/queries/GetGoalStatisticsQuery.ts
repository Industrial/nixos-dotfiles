/**
 * GetGoalStatisticsQuery - Application Layer
 *
 * Query to retrieve aggregate statistics about goals.
 */
import { Schema as S } from "@effect/schema";
import { Effect } from "effect";
import { GoalRepository } from "../../domain/repositories/GoalRepository.js";

/**
 * Goal statistics data structure
 */
export class GoalStatistics extends S.Class<GoalStatistics>("GoalStatistics")({
  totalCount: S.Number,
  activeCount: S.Number,
  pausedCount: S.Number,
  completedCount: S.Number,
  cancelledCount: S.Number,
  draftCount: S.Number,
  completionRate: S.Number.pipe(S.between(0, 1)),
}) {}

/**
 * GetGoalStatisticsQuery Input
 */
export class GetGoalStatisticsQuery extends S.Class<GetGoalStatisticsQuery>("GetGoalStatisticsQuery")({}) {}

/**
 * GetGoalStatisticsQuery Handler
 */
export const getGoalStatisticsHandler = (
  _query: GetGoalStatisticsQuery
): Effect.Effect<GoalStatistics, Error, GoalRepository> =>
  Effect.gen(function* () {
    const repo = yield* GoalRepository;

    // Get all goals
    const allGoals = yield* repo.findAll();

    // Count by status
    const activeCount = allGoals.filter(g => g.status === "active").length;
    const pausedCount = allGoals.filter(g => g.status === "paused").length;
    const completedCount = allGoals.filter(g => g.status === "completed").length;
    const cancelledCount = allGoals.filter(g => g.status === "cancelled").length;
    const draftCount = allGoals.filter(g => g.status === "draft").length;
    const totalCount = allGoals.length;

    // Calculate completion rate
    const completionRate = totalCount > 0 ? completedCount / totalCount : 0;

    return new GoalStatistics({
      totalCount,
      activeCount,
      pausedCount,
      completedCount,
      cancelledCount,
      draftCount,
      completionRate,
    });
  });
