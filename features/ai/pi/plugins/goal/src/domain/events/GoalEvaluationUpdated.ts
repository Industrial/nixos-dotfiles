/**
 * GoalEvaluationUpdated Event
 * 
 * Emitted when goal evaluation data is updated.
 */
import { Schema as S } from "@effect/schema";
import { DomainEvent } from "./DomainEvent.js";

/**
 * GoalEvaluationUpdated Event Payload
 */
export class GoalEvaluationUpdatedPayload extends S.Class<GoalEvaluationUpdatedPayload>("GoalEvaluationUpdatedPayload")({
  progress: S.Number.pipe(S.between(0, 100)),
  completionEstimate: S.optional(S.Number),
  blockers: S.Array(S.String),
  nextSteps: S.Array(S.String),
  notes: S.optional(S.String),
}) {}

/**
 * GoalEvaluationUpdated Domain Event
 */
export class GoalEvaluationUpdated extends S.Class<GoalEvaluationUpdated>("GoalEvaluationUpdated")({
  eventId: S.String,
  eventType: S.Literal("GoalEvaluationUpdated"),
  aggregateId: S.String,
  aggregateType: S.Literal("Goal"),
  version: S.Number,
  timestamp: S.Number,
  payload: GoalEvaluationUpdatedPayload,
}) {
  /**
   * Factory method to create a GoalEvaluationUpdated event
   */
  static create(aggregateId: string, version: number, payload: GoalEvaluationUpdatedPayload): GoalEvaluationUpdated {
    return new GoalEvaluationUpdated({
      eventId: DomainEvent.generateEventId(),
      eventType: "GoalEvaluationUpdated",
      aggregateId,
      aggregateType: "Goal",
      version,
      timestamp: DomainEvent.now(),
      payload,
    });
  }
}
