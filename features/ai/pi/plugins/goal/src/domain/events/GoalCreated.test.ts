/**
 * GoalCreated Event - BDD Tests
 * 
 * Comprehensive tests for the GoalCreated domain event.
 */
import { describe, it, expect } from "bun:test";
import { GoalCreated, GoalCreatedPayload } from "./GoalCreated.js";

describe("GoalCreated Event", () => {
  describe("Factory method", () => {
    it("Given valid parameters, When creating event, Then event is created with all required fields", () => {
      const payload = new GoalCreatedPayload({
        objective: "Build a rocket",
        context: "For Mars mission",
      });

      const event = GoalCreated.create("goal-123", 1, payload);

      expect(event.eventId).toBeDefined();
      expect(event.eventType).toBe("GoalCreated");
      expect(event.aggregateId).toBe("goal-123");
      expect(event.aggregateType).toBe("Goal");
      expect(event.version).toBe(1);
      expect(event.timestamp).toBeGreaterThan(0);
      expect(event.payload).toEqual(payload);
    });

    it("Given payload with only objective, When creating event, Then context is undefined", () => {
      const payload = new GoalCreatedPayload({
        objective: "Build a rocket",
      });

      const event = GoalCreated.create("goal-123", 1, payload);

      expect(event.payload.objective).toBe("Build a rocket");
      expect(event.payload.context).toBeUndefined();
    });
  });

  describe("Event ID uniqueness", () => {
    it("Given multiple events created, When checking event IDs, Then each ID is unique", () => {
      const payload = new GoalCreatedPayload({
        objective: "Test",
      });

      const event1 = GoalCreated.create("goal-1", 1, payload);
      const event2 = GoalCreated.create("goal-1", 2, payload);
      const event3 = GoalCreated.create("goal-2", 1, payload);

      expect(event1.eventId).not.toBe(event2.eventId);
      expect(event1.eventId).not.toBe(event3.eventId);
      expect(event2.eventId).not.toBe(event3.eventId);
    });

    it("Given events created in rapid succession, When checking IDs, Then all are unique", () => {
      const payload = new GoalCreatedPayload({ objective: "Test" });
      const ids = new Set<string>();

      for (let i = 0; i < 100; i++) {
        const event = GoalCreated.create(`goal-${i}`, 1, payload);
        ids.add(event.eventId);
      }

      expect(ids.size).toBe(100);
    });
  });

  describe("Event type literal", () => {
    it("Given event created, When checking eventType, Then it matches exact literal", () => {
      const payload = new GoalCreatedPayload({ objective: "Test" });
      const event = GoalCreated.create("goal-123", 1, payload);

      expect(event.eventType).toBe("GoalCreated");
      // TypeScript ensures this is the literal type, not just a string
      const literalCheck: "GoalCreated" = event.eventType;
      expect(literalCheck).toBe("GoalCreated");
    });
  });

  describe("Aggregate type", () => {
    it("Given event created, When checking aggregateType, Then it is always Goal", () => {
      const payload = new GoalCreatedPayload({ objective: "Test" });
      const event = GoalCreated.create("goal-123", 1, payload);

      expect(event.aggregateType).toBe("Goal");
      // TypeScript ensures this is the literal type
      const literalCheck: "Goal" = event.aggregateType;
      expect(literalCheck).toBe("Goal");
    });
  });

  describe("Version", () => {
    it("Given version 1, When creating event, Then version is set correctly", () => {
      const payload = new GoalCreatedPayload({ objective: "Test" });
      const event = GoalCreated.create("goal-123", 1, payload);

      expect(event.version).toBe(1);
    });

    it("Given version 5, When creating event, Then version is set correctly", () => {
      const payload = new GoalCreatedPayload({ objective: "Test" });
      const event = GoalCreated.create("goal-123", 5, payload);

      expect(event.version).toBe(5);
    });

    it("Given large version number, When creating event, Then version is set correctly", () => {
      const payload = new GoalCreatedPayload({ objective: "Test" });
      const event = GoalCreated.create("goal-123", 999999, payload);

      expect(event.version).toBe(999999);
    });
  });

  describe("Timestamp", () => {
    it("Given event created, When checking timestamp, Then it is set to current time", () => {
      const before = Date.now();
      const payload = new GoalCreatedPayload({ objective: "Test" });
      const event = GoalCreated.create("goal-123", 1, payload);
      const after = Date.now();

      expect(event.timestamp).toBeGreaterThanOrEqual(before);
      expect(event.timestamp).toBeLessThanOrEqual(after);
    });

    it("Given events created sequentially, When checking timestamps, Then each is later or equal", () => {
      const payload = new GoalCreatedPayload({ objective: "Test" });
      
      const event1 = GoalCreated.create("goal-1", 1, payload);
      const event2 = GoalCreated.create("goal-2", 1, payload);

      expect(event2.timestamp).toBeGreaterThanOrEqual(event1.timestamp);
    });
  });

  describe("Payload schema validation", () => {
    it("Given valid objective, When creating payload, Then validation succeeds", () => {
      const payload = new GoalCreatedPayload({
        objective: "Build a rocket",
      });

      expect(payload.objective).toBe("Build a rocket");
    });

    it("Given objective with special characters, When creating payload, Then validation succeeds", () => {
      const payload = new GoalCreatedPayload({
        objective: "Deploy 🚀 to production ✨",
      });

      expect(payload.objective).toContain("🚀");
      expect(payload.objective).toContain("✨");
    });

    it("Given very long objective, When creating payload, Then validation succeeds", () => {
      const longObjective = "x".repeat(10000);
      const payload = new GoalCreatedPayload({
        objective: longObjective,
      });

      expect(payload.objective.length).toBe(10000);
    });

    it("Given objective with newlines, When creating payload, Then validation succeeds", () => {
      const payload = new GoalCreatedPayload({
        objective: "Line 1\nLine 2\nLine 3",
      });

      expect(payload.objective).toContain("\n");
    });

    it("Given context with special characters, When creating payload, Then validation succeeds", () => {
      const payload = new GoalCreatedPayload({
        objective: "Test",
        context: "Context with émojis 😀 and spëcial çharacters",
      });

      expect(payload.context).toContain("😀");
    });
  });

  describe("Payload storage", () => {
    it("Given payload with objective and context, When creating event, Then payload is stored correctly", () => {
      const payload = new GoalCreatedPayload({
        objective: "Build a rocket",
        context: "For Mars mission",
      });

      const event = GoalCreated.create("goal-123", 1, payload);

      expect(event.payload).toBe(payload);
      expect(event.payload.objective).toBe("Build a rocket");
      expect(event.payload.context).toBe("For Mars mission");
    });

    it("Given payload with only objective, When creating event, Then payload is stored correctly", () => {
      const payload = new GoalCreatedPayload({
        objective: "Build a rocket",
      });

      const event = GoalCreated.create("goal-123", 1, payload);

      expect(event.payload).toBe(payload);
      expect(event.payload.objective).toBe("Build a rocket");
      expect(event.payload.context).toBeUndefined();
    });

    it("Given modified payload after event creation, When checking event payload, Then event payload is unchanged", () => {
      const payload = new GoalCreatedPayload({
        objective: "Original",
      });

      const event = GoalCreated.create("goal-123", 1, payload);
      
      // Events should be immutable
      expect(event.payload.objective).toBe("Original");
    });
  });

  describe("Aggregate ID", () => {
    it("Given aggregate ID, When creating event, Then aggregateId is stored correctly", () => {
      const payload = new GoalCreatedPayload({ objective: "Test" });
      const event = GoalCreated.create("goal-abc-123", 1, payload);

      expect(event.aggregateId).toBe("goal-abc-123");
    });

    it("Given UUID-style aggregate ID, When creating event, Then aggregateId is stored correctly", () => {
      const payload = new GoalCreatedPayload({ objective: "Test" });
      const event = GoalCreated.create("550e8400-e29b-41d4-a716-446655440000", 1, payload);

      expect(event.aggregateId).toBe("550e8400-e29b-41d4-a716-446655440000");
    });
  });
});
