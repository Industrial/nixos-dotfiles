/**
 * SQLite database layer for persistent goal storage across MCP process restarts.
 */
import { mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { homedir } from "node:os";
import { SqliteClient } from "@effect/sql-sqlite-bun";
import { Effect, Layer } from "effect";
import { SqlClient } from "@effect/sql";

/**
 * Resolve SQLite database file path.
 *
 * Override with PI_GOAL_DB_PATH for tests or custom layouts.
 */
export function resolveGoalDbPath(): string {
  if (process.env.PI_GOAL_DB_PATH) {
    return process.env.PI_GOAL_DB_PATH;
  }
  return join(homedir(), ".pi", "state", "goal", "goals.db");
}

const runMigrations = Effect.gen(function* () {
  const sql = yield* SqlClient.SqlClient;

  yield* sql`
    CREATE TABLE IF NOT EXISTS goals (
      id TEXT PRIMARY KEY,
      objective TEXT NOT NULL,
      context TEXT,
      status TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      completed_at INTEGER,
      evaluation_data TEXT
    )
  `;

  yield* sql`
    CREATE TABLE IF NOT EXISTS goal_iterations (
      id TEXT PRIMARY KEY,
      goal_id TEXT NOT NULL,
      iteration_number INTEGER NOT NULL,
      started_at INTEGER NOT NULL,
      completed_at INTEGER,
      outcome TEXT,
      evaluation_data TEXT,
      FOREIGN KEY (goal_id) REFERENCES goals(id)
    )
  `;

  yield* sql`
    CREATE TABLE IF NOT EXISTS goal_executions (
      goal_id TEXT PRIMARY KEY,
      cumulative_turn INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'running',
      last_judge TEXT,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (goal_id) REFERENCES goals(id)
    )
  `;

  yield* sql`
    CREATE TABLE IF NOT EXISTS events (
      event_id TEXT PRIMARY KEY,
      event_type TEXT NOT NULL,
      aggregate_id TEXT NOT NULL,
      aggregate_type TEXT NOT NULL,
      version INTEGER NOT NULL,
      timestamp INTEGER NOT NULL,
      payload TEXT NOT NULL
    )
  `;
});

/**
 * SQLite client layer (creates parent directory for the DB file).
 */
export const SqlLive = Layer.unwrapEffect(
  Effect.sync(() => {
    const filename = resolveGoalDbPath();
    mkdirSync(dirname(filename), { recursive: true });
    return SqliteClient.layer({ filename });
  })
);

/**
 * SQLite client plus idempotent schema migrations.
 */
export const DatabaseLayer = Layer.merge(
  SqlLive,
  Layer.effectDiscard(runMigrations).pipe(Layer.provide(SqlLive))
);
