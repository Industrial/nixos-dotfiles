/**
 * GoalCancelled Event
 * 
 * Emitted when a goal is cancelled.
 */
import { Schema as S } from "@effect/schema";
import { DomainEvent } from "./DomainEvent.js";

/**
 * GoalCancelled Event Payload
 */
export class GoalCancelledPayload extends S.Class<GoalCancelledPayload>("GoalCancelledPayload")({}) {}

/**
 * GoalCancelled Domain Event
 */
export class GoalCancelled extends S.Class<GoalCancelled>("GoalCancelled")({
  eventId: S.String,
  eventType: S.Literal("GoalCancelled"),
  aggregateId: S.String,
  aggregateType: S.Literal("Goal"),
  version: S.Number,
  timestamp: S.Number,
  payload: GoalCancelledPayload,
}) {
  /**
   * Factory method to create a GoalCancelled event
   */
  static create(aggregateId: string, version: number): GoalCancelled {
    return new GoalCancelled({
      eventId: DomainEvent.generateEventId(),
      eventType: "GoalCancelled",
      aggregateId,
      aggregateType: "Goal",
      version,
      timestamp: DomainEvent.now(),
      payload: new GoalCancelledPayload({}),
    });
  }
}
