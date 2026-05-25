/**
 * Append domain events with optimistic concurrency on the goal aggregate stream.
 */
import { Effect } from "effect";
import type { GoalEvent } from "../events/index.js";
import { EventStore } from "../repositories/EventStore.js";

export const appendGoalEvent = (
  aggregateId: string,
  create: (nextVersion: number) => GoalEvent
): Effect.Effect<void, Error, EventStore> =>
  Effect.gen(function* () {
    const store = yield* EventStore;
    const stream = yield* store.getEventStream(aggregateId);
    const event = create(stream.version + 1);
    yield* store.appendEvents(aggregateId, [event], stream.version);
  });
