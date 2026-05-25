/**
 * Event Store - Domain Interface
 * 
 * The Event Store is the source of truth in Event Sourcing.
 * All state changes are stored as a sequence of events.
 */
import { Context, Effect } from "effect";
import { GoalEvent } from "../events/index.js";

/**
 * Stream of events for an aggregate
 */
export interface EventStream {
  readonly aggregateId: string;
  readonly aggregateType: string;
  readonly events: readonly GoalEvent[];
  readonly version: number;
}

/**
 * Event Store Repository
 * 
 * Stores and retrieves events for Event Sourcing.
 */
export class EventStore extends Context.Tag("EventStore")<
  EventStore,
  {
    /**
     * Append events to the event store
     * 
     * @param aggregateId - ID of the aggregate
     * @param events - Events to append
     * @param expectedVersion - Expected current version (for optimistic concurrency)
     */
    readonly appendEvents: (
      aggregateId: string,
      events: readonly GoalEvent[],
      expectedVersion: number
    ) => Effect.Effect<void, Error, never>;

    /**
     * Get all events for an aggregate
     * 
     * @param aggregateId - ID of the aggregate
     */
    readonly getEvents: (
      aggregateId: string
    ) => Effect.Effect<readonly GoalEvent[], Error, never>;

    /**
     * Get event stream for an aggregate
     * 
     * @param aggregateId - ID of the aggregate
     */
    readonly getEventStream: (
      aggregateId: string
    ) => Effect.Effect<EventStream, Error, never>;

    /**
     * Check if aggregate exists
     * 
     * @param aggregateId - ID of the aggregate
     */
    readonly exists: (aggregateId: string) => Effect.Effect<boolean, Error, never>;

    /**
     * Get all aggregate IDs of a specific type
     * 
     * @param aggregateType - Type of aggregate (e.g., "Goal")
     */
    readonly getAllAggregateIds: (
      aggregateType: string
    ) => Effect.Effect<readonly string[], Error, never>;
  }
>() {}
