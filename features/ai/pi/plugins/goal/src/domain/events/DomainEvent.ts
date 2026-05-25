/**
 * Domain Event - Base Class
 * 
 * All domain events extend this base class.
 * Events are immutable facts that have occurred in the domain.
 */
import { Schema as S } from "@effect/schema";

/**
 * Base Domain Event
 * 
 * Contains metadata common to all events:
 * - eventId: Unique identifier for this event
 * - aggregateId: ID of the aggregate this event belongs to
 * - aggregateType: Type of aggregate (e.g., "Goal")
 * - version: Version number of the aggregate after this event
 * - timestamp: When this event occurred
 */
export class DomainEvent extends S.Class<DomainEvent>("DomainEvent")({
  eventId: S.String,
  eventType: S.String,
  aggregateId: S.String,
  aggregateType: S.String,
  version: S.Number,
  timestamp: S.Number,
  payload: S.Unknown,
}) {
  /**
   * Generate a unique event ID
   */
  static generateEventId(): string {
    return `evt-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`;
  }

  /**
   * Get current timestamp
   */
  static now(): number {
    return Date.now();
  }
}
