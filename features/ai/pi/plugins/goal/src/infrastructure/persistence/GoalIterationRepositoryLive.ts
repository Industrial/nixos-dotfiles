/**
 * Goal Iteration Repository - SQLite Live Implementation
 */
import { Effect, Layer } from "effect";
import { SqlClient } from "@effect/sql";
import { GoalIteration } from "../../domain/models/GoalIteration.js";
import { GoalIterationRepository } from "../../domain/repositories/GoalIterationRepository.js";

/**
 * SQLite-based implementation of GoalIterationRepository
 */
export const GoalIterationRepositoryLive = Layer.effect(
  GoalIterationRepository,
  Effect.gen(function* () {
    const sql = yield* SqlClient.SqlClient;

    const save = (iteration: GoalIteration) =>
      Effect.gen(function* () {
        const outcomeJson = iteration.outcome 
          ? JSON.stringify(iteration.outcome) 
          : null;
        const evaluationJson = iteration.evaluationData 
          ? JSON.stringify(iteration.evaluationData) 
          : null;

        yield* sql`
          INSERT INTO goal_iterations (
            id, goal_id, iteration_number, started_at, 
            completed_at, outcome, evaluation_data
          ) VALUES (
            ${iteration.id},
            ${iteration.goalId},
            ${iteration.iterationNumber},
            ${iteration.startedAt},
            ${iteration.completedAt ?? null},
            ${outcomeJson},
            ${evaluationJson}
          )
        `;

        return iteration;
      });

    const findById = (id: string) =>
      Effect.gen(function* () {
        const result = yield* sql<{
          id: string;
          goal_id: string;
          iteration_number: number;
          started_at: number;
          completed_at: number | null;
          outcome: string | null;
          evaluation_data: string | null;
        }>`
          SELECT * FROM goal_iterations WHERE id = ${id}
        `;

        if (result.length === 0) return null;

        const row = result[0];
        return new GoalIteration({
          id: row.id,
          goalId: row.goal_id,
          iterationNumber: row.iteration_number,
          startedAt: row.started_at,
          completedAt: row.completed_at ?? undefined,
          outcome: row.outcome ? JSON.parse(row.outcome) : undefined,
          evaluationData: row.evaluation_data 
            ? JSON.parse(row.evaluation_data) 
            : undefined,
        });
      });

    const findByGoalId = (goalId: string) =>
      Effect.gen(function* () {
        const results = yield* sql<{
          id: string;
          goal_id: string;
          iteration_number: number;
          started_at: number;
          completed_at: number | null;
          outcome: string | null;
          evaluation_data: string | null;
        }>`
          SELECT * FROM goal_iterations 
          WHERE goal_id = ${goalId} 
          ORDER BY iteration_number DESC
        `;

        return results.map(
          (row) =>
            new GoalIteration({
              id: row.id,
              goalId: row.goal_id,
              iterationNumber: row.iteration_number,
              startedAt: row.started_at,
              completedAt: row.completed_at ?? undefined,
              outcome: row.outcome ? JSON.parse(row.outcome) : undefined,
              evaluationData: row.evaluation_data 
                ? JSON.parse(row.evaluation_data) 
                : undefined,
            })
        );
      });

    const findLatest = (goalId: string) =>
      Effect.gen(function* () {
        const results = yield* sql<{
          id: string;
          goal_id: string;
          iteration_number: number;
          started_at: number;
          completed_at: number | null;
          outcome: string | null;
          evaluation_data: string | null;
        }>`
          SELECT * FROM goal_iterations 
          WHERE goal_id = ${goalId} 
          ORDER BY iteration_number DESC 
          LIMIT 1
        `;

        if (results.length === 0) return null;

        const row = results[0];
        return new GoalIteration({
          id: row.id,
          goalId: row.goal_id,
          iterationNumber: row.iteration_number,
          startedAt: row.started_at,
          completedAt: row.completed_at ?? undefined,
          outcome: row.outcome ? JSON.parse(row.outcome) : undefined,
          evaluationData: row.evaluation_data 
            ? JSON.parse(row.evaluation_data) 
            : undefined,
        });
      });

    const update = (iteration: GoalIteration) =>
      Effect.gen(function* () {
        const outcomeJson = iteration.outcome 
          ? JSON.stringify(iteration.outcome) 
          : null;
        const evaluationJson = iteration.evaluationData 
          ? JSON.stringify(iteration.evaluationData) 
          : null;

        yield* sql`
          UPDATE goal_iterations SET
            completed_at = ${iteration.completedAt ?? null},
            outcome = ${outcomeJson},
            evaluation_data = ${evaluationJson}
          WHERE id = ${iteration.id}
        `;

        const exists = yield* findById(iteration.id);
        if (!exists) {
          return yield* Effect.fail(new Error(`Iteration not found: ${iteration.id}`));
        }

        return iteration;
      });

    const deleteIteration = (id: string) =>
      Effect.gen(function* () {
        yield* sql`DELETE FROM goal_iterations WHERE id = ${id}`;
      });

    const deleteByGoalId = (goalId: string) =>
      Effect.gen(function* () {
        yield* sql`DELETE FROM goal_iterations WHERE goal_id = ${goalId}`;
      });

    const countByGoalId = (goalId: string) =>
      Effect.gen(function* () {
        const result = yield* sql<{ count: number }>`
          SELECT COUNT(*) as count 
          FROM goal_iterations 
          WHERE goal_id = ${goalId}
        `;
        return result[0].count;
      });

    return {
      save,
      findById,
      findByGoalId,
      findLatest,
      update,
      delete: deleteIteration,
      deleteByGoalId,
      countByGoalId,
    };
  })
);
