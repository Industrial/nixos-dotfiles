/**
 * Database Schema Management
 * 
 * Handles database initialization and migrations.
 */
import { Effect, Layer } from "effect";
import { SqlClient } from "@effect/sql";
import { SqliteClient } from "@effect/sql-sqlite-bun";
import * as path from "node:path";
import * as os from "node:os";

/**
 * Initialize database schema
 */
export const initializeSchema = (sql: SqlClient.SqlClient) =>
  Effect.gen(function* () {
    // ===== EVENT SOURCING =====
    // Events table - source of truth for all state changes
    yield* sql`
      CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT NOT NULL UNIQUE,
        event_type TEXT NOT NULL,
        aggregate_id TEXT NOT NULL,
        aggregate_type TEXT NOT NULL,
        version INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        payload TEXT NOT NULL,
        UNIQUE(aggregate_id, version)
      )
    `;

    // Index for retrieving events by aggregate
    yield* sql`
      CREATE INDEX IF NOT EXISTS idx_events_aggregate
      ON events(aggregate_id, version ASC)
    `;

    // Index for event type queries
    yield* sql`
      CREATE INDEX IF NOT EXISTS idx_events_type
      ON events(event_type, timestamp DESC)
    `;

    // Index for aggregate type queries
    yield* sql`
      CREATE INDEX IF NOT EXISTS idx_events_aggregate_type
      ON events(aggregate_type, aggregate_id)
    `;

    // ===== READ MODELS (CQRS) =====
    // Goals read model - optimized for queries
    yield* sql`
      CREATE TABLE IF NOT EXISTS goals (
        id TEXT PRIMARY KEY,
        objective TEXT NOT NULL,
        context TEXT,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        completed_at INTEGER,
        evaluation_data TEXT,
        version INTEGER NOT NULL DEFAULT 0
      )
    `;

    // Create goals status index
    yield* sql`
      CREATE INDEX IF NOT EXISTS idx_goals_status ON goals(status)
    `;

    // Create goals created_at index for sorting
    yield* sql`
      CREATE INDEX IF NOT EXISTS idx_goals_created_at ON goals(created_at DESC)
    `;

    // Create goal_iterations table
    yield* sql`
      CREATE TABLE IF NOT EXISTS goal_iterations (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        iteration_number INTEGER NOT NULL,
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        outcome TEXT,
        evaluation_data TEXT,
        FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE CASCADE
      )
    `;

    // Create iterations index
    yield* sql`
      CREATE INDEX IF NOT EXISTS idx_iterations_goal_id 
      ON goal_iterations(goal_id, iteration_number DESC)
    `;
  });

/**
 * Get database path (in user's home directory)
 */
export const getDbPath = (): string => {
  const homeDir = os.homedir();
  const dbDir = path.join(homeDir, ".dotfiles", ".pi-data");
  return path.join(dbDir, "goals.db");
};

/**
 * Ensure database directory exists
 */
const ensureDbDirectory = Effect.sync(() => {
  const dbPath = getDbPath();
  const dbDir = path.dirname(dbPath);
  const fs = require("node:fs");
  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
  }
});

/**
 * SQLite client layer
 */
export const SqliteLive = Layer.unwrapEffect(
  Effect.gen(function* () {
    yield* ensureDbDirectory;
    const dbPath = getDbPath();
    
    return SqliteClient.layer({
      filename: dbPath,
    });
  })
);

/**
 * Schema initialization as a layer
 */
const SchemaInitLayer = Layer.effectDiscard(
  Effect.gen(function* () {
    const sql = yield* SqlClient.SqlClient;
    yield* initializeSchema(sql);
  })
);

/**
 * Database initialization layer
 * Combines SQLite client with schema initialization
 */
export const DatabaseLayer = Layer.merge(
  SqliteLive,
  SchemaInitLayer.pipe(Layer.provide(SqliteLive))
);
