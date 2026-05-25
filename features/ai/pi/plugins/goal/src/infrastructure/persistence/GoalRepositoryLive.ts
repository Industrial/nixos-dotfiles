/**
 * Goal Repository - SQLite Live Implementation
 */
import { Effect, Layer } from "effect";
import { SqlClient } from "@effect/sql";
import { Goal } from "../../domain/models/Goal.js";
import { GoalRepository, GoalFilters } from "../../domain/repositories/GoalRepository.js";

/**
 * SQLite-based implementation of GoalRepository
 */
export const GoalRepositoryLive = Layer.effect(
  GoalRepository,
  Effect.gen(function* () {
    const sql = yield* SqlClient.SqlClient;

    const save = (goal: Goal) =>
      Effect.gen(function* () {
        const evaluationJson = goal.evaluationData 
          ? JSON.stringify(goal.evaluationData) 
          : null;

        yield* sql`
          INSERT INTO goals (
            id, objective, context, status, 
            created_at, updated_at, completed_at, evaluation_data
          ) VALUES (
            ${goal.id}, 
            ${goal.objective}, 
            ${goal.context ?? null}, 
            ${goal.status},
            ${goal.createdAt}, 
            ${goal.updatedAt}, 
            ${goal.completedAt ?? null}, 
            ${evaluationJson}
          )
        `;

        return goal;
      });

    const findById = (id: string) =>
      Effect.gen(function* () {
        const result = yield* sql<{
          id: string;
          objective: string;
          context: string | null;
          status: string;
          created_at: number;
          updated_at: number;
          completed_at: number | null;
          evaluation_data: string | null;
        }>`
          SELECT * FROM goals WHERE id = ${id}
        `;

        if (result.length === 0) return null;

        const row = result[0];
        return new Goal({
          id: row.id,
          objective: row.objective,
          context: row.context ?? undefined,
          status: row.status as any,
          createdAt: row.created_at,
          updatedAt: row.updated_at,
          completedAt: row.completed_at ?? undefined,
          evaluationData: row.evaluation_data 
            ? JSON.parse(row.evaluation_data) 
            : undefined,
        });
      });

    const findAll = (filters?: GoalFilters) =>
      Effect.gen(function* () {
        const status = filters?.status;
        const limit = filters?.limit ?? 100;
        const offset = filters?.offset ?? 0;

        let query;
        if (status) {
          query = sql<{
            id: string;
            objective: string;
            context: string | null;
            status: string;
            created_at: number;
            updated_at: number;
            completed_at: number | null;
            evaluation_data: string | null;
          }>`
            SELECT * FROM goals 
            WHERE status = ${status}
            ORDER BY created_at DESC 
            LIMIT ${limit} OFFSET ${offset}
          `;
        } else {
          query = sql<{
            id: string;
            objective: string;
            context: string | null;
            status: string;
            created_at: number;
            updated_at: number;
            completed_at: number | null;
            evaluation_data: string | null;
          }>`
            SELECT * FROM goals 
            ORDER BY created_at DESC 
            LIMIT ${limit} OFFSET ${offset}
          `;
        }

        const results = yield* query;

        return results.map(
          (row) =>
            new Goal({
              id: row.id,
              objective: row.objective,
              context: row.context ?? undefined,
              status: row.status as any,
              createdAt: row.created_at,
              updatedAt: row.updated_at,
              completedAt: row.completed_at ?? undefined,
              evaluationData: row.evaluation_data 
                ? JSON.parse(row.evaluation_data) 
                : undefined,
            })
        );
      });

    const findActive = () =>
      Effect.gen(function* () {
        const results = yield* sql<{
          id: string;
          objective: string;
          context: string | null;
          status: string;
          created_at: number;
          updated_at: number;
          completed_at: number | null;
          evaluation_data: string | null;
        }>`
          SELECT * FROM goals 
          WHERE status = 'active' 
          ORDER BY created_at DESC 
          LIMIT 1
        `;

        if (results.length === 0) return null;

        const row = results[0];
        return new Goal({
          id: row.id,
          objective: row.objective,
          context: row.context ?? undefined,
          status: row.status as any,
          createdAt: row.created_at,
          updatedAt: row.updated_at,
          completedAt: row.completed_at ?? undefined,
          evaluationData: row.evaluation_data 
            ? JSON.parse(row.evaluation_data) 
            : undefined,
        });
      });

    const update = (goal: Goal) =>
      Effect.gen(function* () {
        const evaluationJson = goal.evaluationData 
          ? JSON.stringify(goal.evaluationData) 
          : null;

        const existing = yield* findById(goal.id);
        if (!existing) {
          return yield* Effect.fail(new Error(`Goal not found: ${goal.id}`));
        }

        yield* sql`
          UPDATE goals SET
            objective = ${goal.objective},
            context = ${goal.context ?? null},
            status = ${goal.status},
            updated_at = ${goal.updatedAt},
            completed_at = ${goal.completedAt ?? null},
            evaluation_data = ${evaluationJson}
          WHERE id = ${goal.id}
        `;

        return goal;
      });

    const deleteGoal = (id: string) =>
      Effect.gen(function* () {
        yield* sql`DELETE FROM goals WHERE id = ${id}`;
      });

    const exists = (id: string) =>
      Effect.gen(function* () {
        const result = yield* sql<{ count: number }>`
          SELECT COUNT(*) as count FROM goals WHERE id = ${id}
        `;
        return result[0].count > 0;
      });

    const count = (filters?: GoalFilters) =>
      Effect.gen(function* () {
        const status = filters?.status;

        let query;
        if (status) {
          query = sql<{ count: number }>`
            SELECT COUNT(*) as count FROM goals WHERE status = ${status}
          `;
        } else {
          query = sql<{ count: number }>`
            SELECT COUNT(*) as count FROM goals
          `;
        }

        const result = yield* query;
        return result[0].count;
      });

    return {
      save,
      findById,
      findAll,
      findActive,
      update,
      delete: deleteGoal,
      exists,
      count,
    };
  })
);
