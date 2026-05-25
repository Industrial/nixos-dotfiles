/**
 * GoalCompleted Event
 * 
 * Emitted when a goal is completed.
 */
import { Schema as S } from "@effect/schema";
import { DomainEvent } from "./DomainEvent.js";

/**
 * GoalCompleted Event Payload
 */
export class GoalCompletedPayload extends S.Class<GoalCompletedPayload>("GoalCompletedPayload")({}) {}

/**
 * GoalCompleted Domain Event
 */
export class GoalCompleted extends S.Class<GoalCompleted>("GoalCompleted")({
  eventId: S.String,
  eventType: S.Literal("GoalCompleted"),
  aggregateId: S.String,
  aggregateType: S.Literal("Goal"),
  version: S.Number,
  timestamp: S.Number,
  payload: GoalCompletedPayload,
}) {
  /**
   * Factory method to create a GoalCompleted event
   */
  static create(aggregateId: string, version: number): GoalCompleted {
    return new GoalCompleted({
      eventId: DomainEvent.generateEventId(),
      eventType: "GoalCompleted",
      aggregateId,
      aggregateType: "Goal",
      version,
      timestamp: DomainEvent.now(),
      payload: new GoalCompletedPayload({}),
    });
  }
}
