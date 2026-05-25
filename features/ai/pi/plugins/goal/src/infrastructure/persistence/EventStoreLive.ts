/**
 * Event Store - SQLite Live Implementation
 * 
 * Stores events in SQLite as the source of truth.
 */
import { Effect, Layer } from "effect";
import { SqlClient } from "@effect/sql";
import { EventStore, EventStream } from "../../domain/repositories/EventStore.js";
import { GoalEvent } from "../../domain/events/index.js";

/**
 * SQLite-based Event Store implementation
 */
export const EventStoreLive = Layer.effect(
  EventStore,
  Effect.gen(function* () {
    const sql = yield* SqlClient.SqlClient;

    const appendEvents = (
      aggregateId: string,
      events: readonly GoalEvent[],
      expectedVersion: number
    ) =>
      Effect.gen(function* () {
        // Optimistic concurrency check
        const currentStream = yield* getEventStream(aggregateId);
        
        if (currentStream.version !== expectedVersion) {
          return yield* Effect.fail(
            new Error(
              `Concurrency conflict: expected version ${expectedVersion}, but current version is ${currentStream.version}`
            )
          );
        }

        // Append each event
        for (const event of events) {
          const eventJson = JSON.stringify(event);
          
          yield* sql`
            INSERT INTO events (
              event_id,
              event_type,
              aggregate_id,
              aggregate_type,
              version,
              timestamp,
              payload
            ) VALUES (
              ${event.eventId},
              ${event.eventType},
              ${event.aggregateId},
              ${event.aggregateType},
              ${event.version},
              ${event.timestamp},
              ${eventJson}
            )
          `;
        }
      });

    const getEvents = (aggregateId: string) =>
      Effect.gen(function* () {
        const results = yield* sql<{
          event_id: string;
          event_type: string;
          aggregate_id: string;
          aggregate_type: string;
          version: number;
          timestamp: number;
          payload: string;
        }>`
          SELECT * FROM events
          WHERE aggregate_id = ${aggregateId}
          ORDER BY version ASC
        `;

        return results.map((row) => JSON.parse(row.payload) as GoalEvent);
      });

    const getEventStream = (aggregateId: string) =>
      Effect.gen(function* () {
        const events = yield* getEvents(aggregateId);
        
        const version = events.length > 0 ? events[events.length - 1].version : 0;
        const aggregateType = events.length > 0 ? events[0].aggregateType : "Goal";

        return {
          aggregateId,
          aggregateType,
          events,
          version,
        };
      });

    const exists = (aggregateId: string) =>
      Effect.gen(function* () {
        const result = yield* sql<{ count: number }>`
          SELECT COUNT(*) as count FROM events
          WHERE aggregate_id = ${aggregateId}
        `;
        return result[0].count > 0;
      });

    const getAllAggregateIds = (aggregateType: string) =>
      Effect.gen(function* () {
        const results = yield* sql<{ aggregate_id: string }>`
          SELECT DISTINCT aggregate_id
          FROM events
          WHERE aggregate_type = ${aggregateType}
          ORDER BY aggregate_id
        `;
        
        return results.map((row) => row.aggregate_id);
      });

    return {
      appendEvents,
      getEvents,
      getEventStream,
      exists,
      getAllAggregateIds,
    };
  })
);
