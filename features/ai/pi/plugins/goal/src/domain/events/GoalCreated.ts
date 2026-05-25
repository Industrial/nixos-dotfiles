/**
 * GoalCreated Event
 * 
 * Emitted when a new goal is created.
 */
import { Schema as S } from "@effect/schema";
import { DomainEvent } from "./DomainEvent.js";

/**
 * GoalCreated Event Payload
 */
export class GoalCreatedPayload extends S.Class<GoalCreatedPayload>("GoalCreatedPayload")({
  objective: S.String,
  context: S.optional(S.String),
}) {}

/**
 * GoalCreated Domain Event
 */
export class GoalCreated extends S.Class<GoalCreated>("GoalCreated")({
  eventId: S.String,
  eventType: S.Literal("GoalCreated"),
  aggregateId: S.String,
  aggregateType: S.Literal("Goal"),
  version: S.Number,
  timestamp: S.Number,
  payload: GoalCreatedPayload,
}) {
  /**
   * Factory method to create a GoalCreated event
   */
  static create(aggregateId: string, version: number, payload: GoalCreatedPayload): GoalCreated {
    return new GoalCreated({
      eventId: DomainEvent.generateEventId(),
      eventType: "GoalCreated",
      aggregateId,
      aggregateType: "Goal",
      version,
      timestamp: DomainEvent.now(),
      payload,
    });
  }
}
