/**
 * DomainEvent Base Class - BDD Tests
 *
 * Comprehensive tests for the base domain event class.
 */
import { describe, it, expect } from "bun:test";
import { DomainEvent } from "./DomainEvent.js";

describe("DomainEvent", () => {
  describe("Schema Validation", () => {
    describe("Given valid event data", () => {
      it("When creating event with all required fields, Then event is created successfully", () => {
        const event = new DomainEvent({
          eventId: "evt-123",
          eventType: "TestEvent",
          aggregateId: "agg-456",
          aggregateType: "Goal",
          version: 1,
          timestamp: Date.now(),
          payload: { test: "data" },
        });

        expect(event.eventId).toBe("evt-123");
        expect(event.eventType).toBe("TestEvent");
        expect(event.aggregateId).toBe("agg-456");
        expect(event.aggregateType).toBe("Goal");
        expect(event.version).toBe(1);
        expect(event.timestamp).toBeGreaterThan(0);
        expect(event.payload).toEqual({ test: "data" });
      });

      it("When creating event with version 0, Then event is created", () => {
        const event = new DomainEvent({
          eventId: "evt-123",
          eventType: "TestEvent",
          aggregateId: "agg-456",
          aggregateType: "Goal",
          version: 0,
          timestamp: Date.now(),
          payload: {},
        });

        expect(event.version).toBe(0);
      });

      it("When creating event with large version number, Then event is created", () => {
        const event = new DomainEvent({
          eventId: "evt-123",
          eventType: "TestEvent",
          aggregateId: "agg-456",
          aggregateType: "Goal",
          version: 999999,
          timestamp: Date.now(),
          payload: {},
        });

        expect(event.version).toBe(999999);
      });

      it("When creating event with null payload, Then event is created", () => {
        const event = new DomainEvent({
          eventId: "evt-123",
          eventType: "TestEvent",
          aggregateId: "agg-456",
          aggregateType: "Goal",
          version: 1,
          timestamp: Date.now(),
          payload: null,
        });

        expect(event.payload).toBeNull();
      });

      it("When creating event with undefined payload, Then event is created", () => {
        const event = new DomainEvent({
          eventId: "evt-123",
          eventType: "TestEvent",
          aggregateId: "agg-456",
          aggregateType: "Goal",
          version: 1,
          timestamp: Date.now(),
          payload: undefined,
        });

        expect(event.payload).toBeUndefined();
      });

      it("When creating event with complex nested payload, Then payload is preserved", () => {
        const complexPayload = {
          nested: {
            deeply: {
              value: "test",
            },
          },
          array: [1, 2, 3],
          nullValue: null,
        };

        const event = new DomainEvent({
          eventId: "evt-123",
          eventType: "TestEvent",
          aggregateId: "agg-456",
          aggregateType: "Goal",
          version: 1,
          timestamp: Date.now(),
          payload: complexPayload,
        });

        expect(event.payload).toEqual(complexPayload);
      });
    });

    describe("Given event with special characters", () => {
      it("When creating event with Unicode in eventType, Then event is created", () => {
        const event = new DomainEvent({
          eventId: "evt-123",
          eventType: "TestEvent🚀",
          aggregateId: "agg-456",
          aggregateType: "Goal",
          version: 1,
          timestamp: Date.now(),
          payload: {},
        });

        expect(event.eventType).toBe("TestEvent🚀");
      });

      it("When creating event with special characters in IDs, Then event is created", () => {
        const event = new DomainEvent({
          eventId: "evt-abc_123-xyz",
          eventType: "TestEvent",
          aggregateId: "agg-abc_123-xyz",
          aggregateType: "Goal",
          version: 1,
          timestamp: Date.now(),
          payload: {},
        });

        expect(event.eventId).toBe("evt-abc_123-xyz");
        expect(event.aggregateId).toBe("agg-abc_123-xyz");
      });
    });
  });

  describe("Static utility methods", () => {
    describe("generateEventId", () => {
      it("When generating event ID, Then ID starts with 'evt-' prefix", () => {
        const eventId = DomainEvent.generateEventId();
        expect(eventId).toMatch(/^evt-/);
      });

      it("When generating event ID, Then ID contains timestamp", () => {
        const beforeGeneration = Date.now();
        const eventId = DomainEvent.generateEventId();
        const afterGeneration = Date.now();

        // Extract timestamp from ID (format: evt-{timestamp}-{random})
        const timestampStr = eventId.split("-")[1];
        const timestamp = parseInt(timestampStr, 10);

        expect(timestamp).toBeGreaterThanOrEqual(beforeGeneration);
        expect(timestamp).toBeLessThanOrEqual(afterGeneration);
      });

      it("When generating multiple event IDs, Then each ID is unique", () => {
        const id1 = DomainEvent.generateEventId();
        const id2 = DomainEvent.generateEventId();
        const id3 = DomainEvent.generateEventId();

        expect(id1).not.toBe(id2);
        expect(id2).not.toBe(id3);
        expect(id1).not.toBe(id3);
      });

      it("When generating many event IDs rapidly, Then all are unique", () => {
        const ids = new Set<string>();
        const count = 1000;

        for (let i = 0; i < count; i++) {
          ids.add(DomainEvent.generateEventId());
        }

        expect(ids.size).toBe(count);
      });

      it("When generating event ID, Then ID format is consistent", () => {
        const eventId = DomainEvent.generateEventId();

        // Format: evt-{timestamp}-{random}
        const parts = eventId.split("-");
        expect(parts.length).toBe(3);
        expect(parts[0]).toBe("evt");
        expect(parts[1]).toMatch(/^\d+$/); // Timestamp is numeric
        expect(parts[2].length).toBeGreaterThan(0); // Random part exists
      });
    });

    describe("now", () => {
      it("When calling now(), Then returns current timestamp", () => {
        const before = Date.now();
        const timestamp = DomainEvent.now();
        const after = Date.now();

        expect(timestamp).toBeGreaterThanOrEqual(before);
        expect(timestamp).toBeLessThanOrEqual(after);
      });

      it("When calling now() multiple times, Then timestamps are monotonically increasing or equal", () => {
        const t1 = DomainEvent.now();
        const t2 = DomainEvent.now();
        const t3 = DomainEvent.now();

        expect(t2).toBeGreaterThanOrEqual(t1);
        expect(t3).toBeGreaterThanOrEqual(t2);
      });

      it("When calling now(), Then returns numeric timestamp", () => {
        const timestamp = DomainEvent.now();
        expect(typeof timestamp).toBe("number");
        expect(timestamp).toBeGreaterThan(0);
      });
    });
  });

  describe("Event immutability", () => {
    it("When creating event, Then event properties are accessible", () => {
      const event = new DomainEvent({
        eventId: "evt-123",
        eventType: "TestEvent",
        aggregateId: "agg-456",
        aggregateType: "Goal",
        version: 1,
        timestamp: Date.now(),
        payload: { data: "test" },
      });

      // All properties should be readable
      expect(event.eventId).toBeDefined();
      expect(event.eventType).toBeDefined();
      expect(event.aggregateId).toBeDefined();
      expect(event.aggregateType).toBeDefined();
      expect(event.version).toBeDefined();
      expect(event.timestamp).toBeDefined();
      expect(event.payload).toBeDefined();
    });
  });

  describe("Event with different aggregate types", () => {
    it("When creating event for Goal aggregate, Then aggregateType is set correctly", () => {
      const event = new DomainEvent({
        eventId: "evt-123",
        eventType: "GoalCreated",
        aggregateId: "goal-456",
        aggregateType: "Goal",
        version: 1,
        timestamp: Date.now(),
        payload: {},
      });

      expect(event.aggregateType).toBe("Goal");
    });

    it("When creating event for different aggregate types, Then type is preserved", () => {
      const aggregateTypes = ["Goal", "Iteration", "Task", "User", "Project"];

      aggregateTypes.forEach((type) => {
        const event = new DomainEvent({
          eventId: `evt-${type}`,
          eventType: "TestEvent",
          aggregateId: `agg-${type}`,
          aggregateType: type,
          version: 1,
          timestamp: Date.now(),
          payload: {},
        });

        expect(event.aggregateType).toBe(type);
      });
    });
  });

  describe("Version sequencing", () => {
    it("When creating events with incrementing versions, Then versions are preserved", () => {
      const events = [1, 2, 3, 4, 5].map((version) =>
        new DomainEvent({
          eventId: `evt-${version}`,
          eventType: "TestEvent",
          aggregateId: "agg-123",
          aggregateType: "Goal",
          version,
          timestamp: Date.now(),
          payload: {},
        })
      );

      events.forEach((event, index) => {
        expect(event.version).toBe(index + 1);
      });
    });
  });

  describe("Edge cases", () => {
    it("When creating event with very long string fields, Then event is created", () => {
      const longString = "x".repeat(10000);
      const event = new DomainEvent({
        eventId: longString,
        eventType: longString,
        aggregateId: longString,
        aggregateType: longString,
        version: 1,
        timestamp: Date.now(),
        payload: { longData: longString },
      });

      expect(event.eventId.length).toBe(10000);
      expect(event.eventType.length).toBe(10000);
    });

    it("When creating event with timestamp 0, Then event is created", () => {
      const event = new DomainEvent({
        eventId: "evt-123",
        eventType: "TestEvent",
        aggregateId: "agg-456",
        aggregateType: "Goal",
        version: 1,
        timestamp: 0,
        payload: {},
      });

      expect(event.timestamp).toBe(0);
    });

    it("When creating event with negative version, Then event is created", () => {
      const event = new DomainEvent({
        eventId: "evt-123",
        eventType: "TestEvent",
        aggregateId: "agg-456",
        aggregateType: "Goal",
        version: -1,
        timestamp: Date.now(),
        payload: {},
      });

      expect(event.version).toBe(-1);
    });
  });
});
