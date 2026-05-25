/**
 * GoalCancelled Event - BDD Tests
 * 
 * Comprehensive tests for the GoalCancelled domain event.
 */
import { describe, it, expect } from "bun:test";
import { GoalCancelled, GoalCancelledPayload } from "./GoalCancelled.js";

describe("GoalCancelled Event", () => {
  describe("Factory method", () => {
    it("Given valid parameters, When creating event, Then event is created with all required fields", () => {
      const event = GoalCancelled.create("goal-123", 5);

      expect(event.eventId).toBeDefined();
      expect(event.eventType).toBe("GoalCancelled");
      expect(event.aggregateId).toBe("goal-123");
      expect(event.aggregateType).toBe("Goal");
      expect(event.version).toBe(5);
      expect(event.timestamp).toBeGreaterThan(0);
      expect(event.payload).toBeInstanceOf(GoalCancelledPayload);
    });

    it("Given different aggregate IDs, When creating events, Then each stores correct ID", () => {
      const event1 = GoalCancelled.create("goal-1", 1);
      const event2 = GoalCancelled.create("goal-2", 1);

      expect(event1.aggregateId).toBe("goal-1");
      expect(event2.aggregateId).toBe("goal-2");
    });
  });

  describe("Event ID uniqueness", () => {
    it("Given multiple events created, When checking event IDs, Then each ID is unique", () => {
      const event1 = GoalCancelled.create("goal-1", 1);
      const event2 = GoalCancelled.create("goal-1", 2);
      const event3 = GoalCancelled.create("goal-2", 1);

      expect(event1.eventId).not.toBe(event2.eventId);
      expect(event1.eventId).not.toBe(event3.eventId);
      expect(event2.eventId).not.toBe(event3.eventId);
    });

    it("Given events created in rapid succession, When checking IDs, Then all are unique", () => {
      const ids = new Set<string>();

      for (let i = 0; i < 100; i++) {
        const event = GoalCancelled.create(`goal-${i}`, 1);
        ids.add(event.eventId);
      }

      expect(ids.size).toBe(100);
    });
  });

  describe("Event type literal", () => {
    it("Given event created, When checking eventType, Then it matches exact literal", () => {
      const event = GoalCancelled.create("goal-123", 1);

      expect(event.eventType).toBe("GoalCancelled");
      const literalCheck: "GoalCancelled" = event.eventType;
      expect(literalCheck).toBe("GoalCancelled");
    });
  });

  describe("Aggregate type", () => {
    it("Given event created, When checking aggregateType, Then it is always Goal", () => {
      const event = GoalCancelled.create("goal-123", 1);

      expect(event.aggregateType).toBe("Goal");
      const literalCheck: "Goal" = event.aggregateType;
      expect(literalCheck).toBe("Goal");
    });
  });

  describe("Version", () => {
    it("Given version 5, When creating event, Then version is set correctly", () => {
      const event = GoalCancelled.create("goal-123", 5);
      expect(event.version).toBe(5);
    });

    it("Given version 25, When creating event, Then version is set correctly", () => {
      const event = GoalCancelled.create("goal-123", 25);
      expect(event.version).toBe(25);
    });

    it("Given large version number, When creating event, Then version is set correctly", () => {
      const event = GoalCancelled.create("goal-123", 999999);
      expect(event.version).toBe(999999);
    });
  });

  describe("Timestamp", () => {
    it("Given event created, When checking timestamp, Then it is set to current time", () => {
      const before = Date.now();
      const event = GoalCancelled.create("goal-123", 1);
      const after = Date.now();

      expect(event.timestamp).toBeGreaterThanOrEqual(before);
      expect(event.timestamp).toBeLessThanOrEqual(after);
    });

    it("Given events created sequentially, When checking timestamps, Then each is later or equal", () => {
      const event1 = GoalCancelled.create("goal-1", 1);
      const event2 = GoalCancelled.create("goal-2", 1);

      expect(event2.timestamp).toBeGreaterThanOrEqual(event1.timestamp);
    });
  });

  describe("Payload schema validation", () => {
    it("Given empty payload, When creating payload directly, Then validation succeeds", () => {
      const payload = new GoalCancelledPayload({});
      expect(payload).toBeInstanceOf(GoalCancelledPayload);
    });

    it("Given event created, When checking payload, Then payload is empty object", () => {
      const event = GoalCancelled.create("goal-123", 1);
      expect(event.payload).toBeInstanceOf(GoalCancelledPayload);
    });
  });

  describe("Payload storage", () => {
    it("Given event created, When checking payload, Then payload is stored correctly", () => {
      const event = GoalCancelled.create("goal-123", 1);
      
      expect(event.payload).toBeDefined();
      expect(event.payload).toBeInstanceOf(GoalCancelledPayload);
    });
  });

  describe("Aggregate ID", () => {
    it("Given aggregate ID with special characters, When creating event, Then aggregateId is stored correctly", () => {
      const event = GoalCancelled.create("goal-abc_123-xyz", 1);
      expect(event.aggregateId).toBe("goal-abc_123-xyz");
    });

    it("Given UUID-style aggregate ID, When creating event, Then aggregateId is stored correctly", () => {
      const event = GoalCancelled.create("550e8400-e29b-41d4-a716-446655440000", 1);
      expect(event.aggregateId).toBe("550e8400-e29b-41d4-a716-446655440000");
    });
  });
});
