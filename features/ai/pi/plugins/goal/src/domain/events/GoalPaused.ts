/**
 * GoalPaused Event
 * 
 * Emitted when a goal is paused.
 */
import { Schema as S } from "@effect/schema";
import { DomainEvent } from "./DomainEvent.js";

/**
 * GoalPaused Event Payload
 */
export class GoalPausedPayload extends S.Class<GoalPausedPayload>("GoalPausedPayload")({}) {}

/**
 * GoalPaused Domain Event
 */
export class GoalPaused extends S.Class<GoalPaused>("GoalPaused")({
  eventId: S.String,
  eventType: S.Literal("GoalPaused"),
  aggregateId: S.String,
  aggregateType: S.Literal("Goal"),
  version: S.Number,
  timestamp: S.Number,
  payload: GoalPausedPayload,
}) {
  /**
   * Factory method to create a GoalPaused event
   */
  static create(aggregateId: string, version: number): GoalPaused {
    return new GoalPaused({
      eventId: DomainEvent.generateEventId(),
      eventType: "GoalPaused",
      aggregateId,
      aggregateType: "Goal",
      version,
      timestamp: DomainEvent.now(),
      payload: new GoalPausedPayload({}),
    });
  }
}
