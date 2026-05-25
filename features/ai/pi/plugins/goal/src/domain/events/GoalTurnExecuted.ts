/**
 * GoalTurnExecuted Event — one agent/subagent turn completed for a goal.
 */
import { Schema as S } from "@effect/schema";
import { DomainEvent } from "./DomainEvent.js";

export class GoalTurnExecutedPayload extends S.Class<GoalTurnExecutedPayload>(
  "GoalTurnExecutedPayload"
)({
  turn: S.Number,
  judgeStatus: S.String,
  judgeConfidence: S.Number,
  outputPreview: S.String,
}) {}

export class GoalTurnExecuted extends S.Class<GoalTurnExecuted>("GoalTurnExecuted")({
  eventId: S.String,
  eventType: S.Literal("GoalTurnExecuted"),
  aggregateId: S.String,
  aggregateType: S.Literal("Goal"),
  version: S.Number,
  timestamp: S.Number,
  payload: GoalTurnExecutedPayload,
}) {
  static create(
    aggregateId: string,
    version: number,
    payload: GoalTurnExecutedPayload
  ): GoalTurnExecuted {
    return new GoalTurnExecuted({
      eventId: DomainEvent.generateEventId(),
      eventType: "GoalTurnExecuted",
      aggregateId,
      aggregateType: "Goal",
      version,
      timestamp: DomainEvent.now(),
      payload,
    });
  }
}
