/**
 * GoalResumed Event
 * 
 * Emitted when a paused goal is resumed.
 */
import { Schema as S } from "@effect/schema";
import { DomainEvent } from "./DomainEvent.js";

/**
 * GoalResumed Event Payload
 */
export class GoalResumedPayload extends S.Class<GoalResumedPayload>("GoalResumedPayload")({}) {}

/**
 * GoalResumed Domain Event
 */
export class GoalResumed extends S.Class<GoalResumed>("GoalResumed")({
  eventId: S.String,
  eventType: S.Literal("GoalResumed"),
  aggregateId: S.String,
  aggregateType: S.Literal("Goal"),
  version: S.Number,
  timestamp: S.Number,
  payload: GoalResumedPayload,
}) {
  /**
   * Factory method to create a GoalResumed event
   */
  static create(aggregateId: string, version: number): GoalResumed {
    return new GoalResumed({
      eventId: DomainEvent.generateEventId(),
      eventType: "GoalResumed",
      aggregateId,
      aggregateType: "Goal",
      version,
      timestamp: DomainEvent.now(),
      payload: new GoalResumedPayload({}),
    });
  }
}
