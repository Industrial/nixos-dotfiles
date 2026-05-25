/**
 * Event Store - In-Memory Mock Implementation
 */
import { Effect, Layer, Ref } from "effect";
import { GoalEvent } from "../../domain/events/index.js";

/**
 * In-memory Event Store for testing
 * 
 * Stores events in a Map keyed by aggregate ID.
 */
export const EventStoreMock = Layer.effect(
  EventStore,
  Effect.gen(function* () {
    // Map<aggregateId, events[]>
    const store = yield* Ref.make<Map<string, GoalEvent[]>>(new Map());

    const appendEvents = (
      aggregateId: string,
      events: readonly GoalEvent[],
      expectedVersion: number
    ) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const existingEvents = map.get(aggregateId) || [];
        
        // Optimistic concurrency check
        const currentVersion = existingEvents.length > 0 
          ? existingEvents[existingEvents.length - 1].version 
          : 0;
        
        if (currentVersion !== expectedVersion) {
          return yield* Effect.fail(
            new Error(
              `Concurrency conflict: expected version ${expectedVersion}, but current version is ${currentVersion}`
            )
          );
        }

        // Append events
        const newEvents = [...existingEvents, ...events];
        yield* Ref.update(store, (m) => new Map(m).set(aggregateId, newEvents));
      });

    const getEvents = (aggregateId: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        return map.get(aggregateId) || [];
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
        const map = yield* Ref.get(store);
        return map.has(aggregateId) && (map.get(aggregateId)?.length || 0) > 0;
      });

    const getAllAggregateIds = (aggregateType: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const ids: string[] = [];
        
        for (const [aggregateId, events] of map.entries()) {
          if (events.length > 0 && events[0].aggregateType === aggregateType) {
            ids.push(aggregateId);
          }
        }
        
        return ids.sort();
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
