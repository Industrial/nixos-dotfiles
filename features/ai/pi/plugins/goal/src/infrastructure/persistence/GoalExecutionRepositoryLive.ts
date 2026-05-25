import { Effect, Layer } from "effect";
import { SqlClient } from "@effect/sql";
import {
  GoalExecutionCheckpoint,
  GoalExecutionRepository,
} from "../../domain/repositories/GoalExecutionRepository.js";

export const GoalExecutionRepositoryLive = Layer.effect(
  GoalExecutionRepository,
  Effect.gen(function* () {
    const sql = yield* SqlClient.SqlClient;

    const get = (goalId: string) =>
      Effect.gen(function* () {
        const rows = yield* sql<{
          goal_id: string;
          cumulative_turn: number;
          status: string;
          last_judge: string | null;
          updated_at: number;
        }>`
          SELECT * FROM goal_executions WHERE goal_id = ${goalId}
        `;
        if (rows.length === 0) return null;
        const row = rows[0];
        return {
          goalId: row.goal_id,
          cumulativeTurn: row.cumulative_turn,
          status: row.status as GoalExecutionCheckpoint["status"],
          lastJudgeJson: row.last_judge,
          updatedAt: row.updated_at,
        };
      });

    const upsert = (checkpoint: GoalExecutionCheckpoint) =>
      Effect.gen(function* () {
        yield* sql`
          INSERT INTO goal_executions (
            goal_id, cumulative_turn, status, last_judge, updated_at
          ) VALUES (
            ${checkpoint.goalId},
            ${checkpoint.cumulativeTurn},
            ${checkpoint.status},
            ${checkpoint.lastJudgeJson},
            ${checkpoint.updatedAt}
          )
          ON CONFLICT(goal_id) DO UPDATE SET
            cumulative_turn = ${checkpoint.cumulativeTurn},
            status = ${checkpoint.status},
            last_judge = ${checkpoint.lastJudgeJson},
            updated_at = ${checkpoint.updatedAt}
        `;
      });

    const deleteCheckpoint = (goalId: string) =>
      Effect.gen(function* () {
        yield* sql`DELETE FROM goal_executions WHERE goal_id = ${goalId}`;
      });

    return { get, upsert, delete: deleteCheckpoint };
  })
);
