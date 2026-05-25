/**
 * GoalEvaluationUpdated Event - BDD Tests
 * 
 * Comprehensive tests for the GoalEvaluationUpdated domain event.
 */
import { describe, it, expect } from "bun:test";
import { GoalEvaluationUpdated, GoalEvaluationUpdatedPayload } from "./GoalEvaluationUpdated.js";

describe("GoalEvaluationUpdated Event", () => {
  describe("Factory method", () => {
    it("Given valid parameters, When creating event, Then event is created with all required fields", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: ["Need approval"],
        nextSteps: ["Get sign-off", "Begin implementation"],
      });

      const event = GoalEvaluationUpdated.create("goal-123", 6, payload);

      expect(event.eventId).toBeDefined();
      expect(event.eventType).toBe("GoalEvaluationUpdated");
      expect(event.aggregateId).toBe("goal-123");
      expect(event.aggregateType).toBe("Goal");
      expect(event.version).toBe(6);
      expect(event.timestamp).toBeGreaterThan(0);
      expect(event.payload).toEqual(payload);
    });

    it("Given payload with all optional fields, When creating event, Then all fields are stored", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 75,
        completionEstimate: 1704067200000,
        blockers: ["Blocked on dependency"],
        nextSteps: ["Wait for unblock", "Continue work"],
        notes: "Making good progress",
      });

      const event = GoalEvaluationUpdated.create("goal-123", 1, payload);

      expect(event.payload.progress).toBe(75);
      expect(event.payload.completionEstimate).toBe(1704067200000);
      expect(event.payload.blockers).toEqual(["Blocked on dependency"]);
      expect(event.payload.nextSteps).toEqual(["Wait for unblock", "Continue work"]);
      expect(event.payload.notes).toBe("Making good progress");
    });

    it("Given payload without optional fields, When creating event, Then optional fields are undefined", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });

      const event = GoalEvaluationUpdated.create("goal-123", 1, payload);

      expect(event.payload.progress).toBe(50);
      expect(event.payload.completionEstimate).toBeUndefined();
      expect(event.payload.notes).toBeUndefined();
    });
  });

  describe("Event ID uniqueness", () => {
    it("Given multiple events created, When checking event IDs, Then each ID is unique", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });

      const event1 = GoalEvaluationUpdated.create("goal-1", 1, payload);
      const event2 = GoalEvaluationUpdated.create("goal-1", 2, payload);
      const event3 = GoalEvaluationUpdated.create("goal-2", 1, payload);

      expect(event1.eventId).not.toBe(event2.eventId);
      expect(event1.eventId).not.toBe(event3.eventId);
      expect(event2.eventId).not.toBe(event3.eventId);
    });

    it("Given events created in rapid succession, When checking IDs, Then all are unique", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });
      const ids = new Set<string>();

      for (let i = 0; i < 100; i++) {
        const event = GoalEvaluationUpdated.create(`goal-${i}`, 1, payload);
        ids.add(event.eventId);
      }

      expect(ids.size).toBe(100);
    });
  });

  describe("Event type literal", () => {
    it("Given event created, When checking eventType, Then it matches exact literal", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });
      const event = GoalEvaluationUpdated.create("goal-123", 1, payload);

      expect(event.eventType).toBe("GoalEvaluationUpdated");
      const literalCheck: "GoalEvaluationUpdated" = event.eventType;
      expect(literalCheck).toBe("GoalEvaluationUpdated");
    });
  });

  describe("Aggregate type", () => {
    it("Given event created, When checking aggregateType, Then it is always Goal", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });
      const event = GoalEvaluationUpdated.create("goal-123", 1, payload);

      expect(event.aggregateType).toBe("Goal");
      const literalCheck: "Goal" = event.aggregateType;
      expect(literalCheck).toBe("Goal");
    });
  });

  describe("Version", () => {
    it("Given version 6, When creating event, Then version is set correctly", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });
      const event = GoalEvaluationUpdated.create("goal-123", 6, payload);

      expect(event.version).toBe(6);
    });

    it("Given large version number, When creating event, Then version is set correctly", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });
      const event = GoalEvaluationUpdated.create("goal-123", 999999, payload);

      expect(event.version).toBe(999999);
    });
  });

  describe("Timestamp", () => {
    it("Given event created, When checking timestamp, Then it is set to current time", () => {
      const before = Date.now();
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });
      const event = GoalEvaluationUpdated.create("goal-123", 1, payload);
      const after = Date.now();

      expect(event.timestamp).toBeGreaterThanOrEqual(before);
      expect(event.timestamp).toBeLessThanOrEqual(after);
    });

    it("Given events created sequentially, When checking timestamps, Then each is later or equal", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });

      const event1 = GoalEvaluationUpdated.create("goal-1", 1, payload);
      const event2 = GoalEvaluationUpdated.create("goal-2", 1, payload);

      expect(event2.timestamp).toBeGreaterThanOrEqual(event1.timestamp);
    });
  });

  describe("Payload schema validation", () => {
    it("Given progress at 0, When creating payload, Then validation succeeds", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 0,
        blockers: [],
        nextSteps: [],
      });

      expect(payload.progress).toBe(0);
    });

    it("Given progress at 100, When creating payload, Then validation succeeds", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 100,
        blockers: [],
        nextSteps: [],
      });

      expect(payload.progress).toBe(100);
    });

    it("Given progress at 50, When creating payload, Then validation succeeds", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });

      expect(payload.progress).toBe(50);
    });

    it("Given empty blocker array, When creating payload, Then validation succeeds", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });

      expect(payload.blockers).toEqual([]);
    });

    it("Given multiple blockers, When creating payload, Then all blockers are stored", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: ["Blocker 1", "Blocker 2", "Blocker 3"],
        nextSteps: [],
      });

      expect(payload.blockers).toEqual(["Blocker 1", "Blocker 2", "Blocker 3"]);
    });

    it("Given empty nextSteps array, When creating payload, Then validation succeeds", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });

      expect(payload.nextSteps).toEqual([]);
    });

    it("Given multiple next steps, When creating payload, Then all steps are stored", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: ["Step 1", "Step 2", "Step 3"],
      });

      expect(payload.nextSteps).toEqual(["Step 1", "Step 2", "Step 3"]);
    });

    it("Given notes with special characters, When creating payload, Then validation succeeds", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
        notes: "Progress notes with émojis 🎯 and spëcial çharacters",
      });

      expect(payload.notes).toContain("🎯");
    });

    it("Given very long notes, When creating payload, Then validation succeeds", () => {
      const longNotes = "x".repeat(10000);
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
        notes: longNotes,
      });

      expect(payload.notes?.length).toBe(10000);
    });
  });

  describe("Payload storage", () => {
    it("Given payload with all fields, When creating event, Then payload is stored correctly", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 75,
        completionEstimate: 1704067200000,
        blockers: ["Blocked"],
        nextSteps: ["Unblock"],
        notes: "Notes",
      });

      const event = GoalEvaluationUpdated.create("goal-123", 1, payload);

      expect(event.payload).toBe(payload);
      expect(event.payload.progress).toBe(75);
      expect(event.payload.completionEstimate).toBe(1704067200000);
      expect(event.payload.blockers).toEqual(["Blocked"]);
      expect(event.payload.nextSteps).toEqual(["Unblock"]);
      expect(event.payload.notes).toBe("Notes");
    });
  });

  describe("Aggregate ID", () => {
    it("Given aggregate ID, When creating event, Then aggregateId is stored correctly", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });
      const event = GoalEvaluationUpdated.create("goal-abc-123", 1, payload);

      expect(event.aggregateId).toBe("goal-abc-123");
    });

    it("Given UUID-style aggregate ID, When creating event, Then aggregateId is stored correctly", () => {
      const payload = new GoalEvaluationUpdatedPayload({
        progress: 50,
        blockers: [],
        nextSteps: [],
      });
      const event = GoalEvaluationUpdated.create("550e8400-e29b-41d4-a716-446655440000", 1, payload);

      expect(event.aggregateId).toBe("550e8400-e29b-41d4-a716-446655440000");
    });
  });
});
