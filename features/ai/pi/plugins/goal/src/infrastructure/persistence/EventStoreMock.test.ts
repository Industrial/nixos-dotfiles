/**
 * EventStoreMock - BDD Tests
 * 
 * Comprehensive tests for the in-memory Event Store implementation.
 * Tests event sourcing patterns: append-only, versioning, concurrency control.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { EventStore } from "../../domain/repositories/EventStore.js";
import { EventStoreMock } from "./EventStoreMock.js";
import {
  GoalCreated,
  GoalCreatedPayload,
  GoalPaused,
  GoalResumed,
  GoalCompleted,
} from "../../domain/events/index.js";

describe("EventStoreMock", () => {
  const TestLayer = EventStoreMock;

  describe("appendEvents", () => {
    describe("Given no existing events", () => {
      it("When appending first event with version 1, Then event is stored", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          const event = GoalCreated.create(
            "goal-123",
            1,
            new GoalCreatedPayload({
              objective: "Test goal",
              context: "Test context",
            })
          );

          yield* store.appendEvents("goal-123", [event], 0);
          
          return yield* store.getEvents("goal-123");
        });

        const events = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(events.length).toBe(1);
        expect(events[0].eventType).toBe("GoalCreated");
        expect(events[0].aggregateId).toBe("goal-123");
        expect(events[0].version).toBe(1);
      });

      it("When appending multiple events in sequence, Then all events are stored", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          const event1 = GoalCreated.create(
            "goal-123",
            1,
            new GoalCreatedPayload({ objective: "Test" })
          );
          const event2 = GoalPaused.create("goal-123", 2);

          yield* store.appendEvents("goal-123", [event1], 0);
          yield* store.appendEvents("goal-123", [event2], 1);
          
          return yield* store.getEvents("goal-123");
        });

        const events = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(events.length).toBe(2);
        expect(events[0].version).toBe(1);
        expect(events[1].version).toBe(2);
      });

      it("When appending multiple events at once, Then all are stored in order", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          const events = [
            GoalCreated.create("goal-123", 1, new GoalCreatedPayload({ objective: "Test" })),
            GoalPaused.create("goal-123", 2),
            GoalResumed.create("goal-123", 3),
          ];

          yield* store.appendEvents("goal-123", events, 0);
          
          return yield* store.getEvents("goal-123");
        });

        const storedEvents = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(storedEvents.length).toBe(3);
        expect(storedEvents[0].eventType).toBe("GoalCreated");
        expect(storedEvents[1].eventType).toBe("GoalPaused");
        expect(storedEvents[2].eventType).toBe("GoalResumed");
      });
    });

    describe("Optimistic Concurrency Control", () => {
      it("When expected version matches, Then append succeeds", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          const event1 = GoalCreated.create(
            "goal-123",
            1,
            new GoalCreatedPayload({ objective: "Test" })
          );
          const event2 = GoalPaused.create("goal-123", 2);

          yield* store.appendEvents("goal-123", [event1], 0);
          yield* store.appendEvents("goal-123", [event2], 1);
          
          return yield* store.getEvents("goal-123");
        });

        const events = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(events.length).toBe(2);
      });

      it("When expected version does not match, Then append fails with concurrency error", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          const event1 = GoalCreated.create(
            "goal-123",
            1,
            new GoalCreatedPayload({ objective: "Test" })
          );
          const event2 = GoalPaused.create("goal-123", 2);

          yield* store.appendEvents("goal-123", [event1], 0);
          
          // Try to append with wrong expected version
          return yield* store.appendEvents("goal-123", [event2], 0);
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Concurrency conflict/);
      });

      it("When expected version is higher than actual, Then append fails", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          const event1 = GoalCreated.create(
            "goal-123",
            1,
            new GoalCreatedPayload({ objective: "Test" })
          );
          const event2 = GoalPaused.create("goal-123", 2);

          yield* store.appendEvents("goal-123", [event1], 0);
          
          // Try to append expecting version 5 when actual is 1
          return yield* store.appendEvents("goal-123", [event2], 5);
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/expected version 5, but current version is 1/);
      });

      it("When appending to wrong version after multiple events, Then fails with current version", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          yield* store.appendEvents(
            "goal-123",
            [
              GoalCreated.create("goal-123", 1, new GoalCreatedPayload({ objective: "Test" })),
              GoalPaused.create("goal-123", 2),
              GoalResumed.create("goal-123", 3),
            ],
            0
          );
          
          // Try to append expecting version 2 when actual is 3
          return yield* store.appendEvents(
            "goal-123",
            [GoalCompleted.create("goal-123", 4)],
            2
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/expected version 2, but current version is 3/);
      });
    });

    describe("Multiple aggregates", () => {
      it("When appending events for different aggregates, Then each maintains separate version", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          yield* store.appendEvents(
            "goal-1",
            [GoalCreated.create("goal-1", 1, new GoalCreatedPayload({ objective: "Goal 1" }))],
            0
          );
          
          yield* store.appendEvents(
            "goal-2",
            [GoalCreated.create("goal-2", 1, new GoalCreatedPayload({ objective: "Goal 2" }))],
            0
          );
          
          yield* store.appendEvents(
            "goal-1",
            [GoalPaused.create("goal-1", 2)],
            1
          );

          const events1 = yield* store.getEvents("goal-1");
          const events2 = yield* store.getEvents("goal-2");

          return { events1, events2 };
        });

        const { events1, events2 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(events1.length).toBe(2);
        expect(events2.length).toBe(1);
      });
    });
  });

  describe("getEvents", () => {
    describe("Given events exist", () => {
      it("When getting events, Then returns all events in order", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          const events = [
            GoalCreated.create("goal-123", 1, new GoalCreatedPayload({ objective: "Test" })),
            GoalPaused.create("goal-123", 2),
            GoalResumed.create("goal-123", 3),
            GoalCompleted.create("goal-123", 4),
          ];

          yield* store.appendEvents("goal-123", events, 0);
          
          return yield* store.getEvents("goal-123");
        });

        const storedEvents = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(storedEvents.length).toBe(4);
        expect(storedEvents[0].version).toBe(1);
        expect(storedEvents[1].version).toBe(2);
        expect(storedEvents[2].version).toBe(3);
        expect(storedEvents[3].version).toBe(4);
      });

      it("When getting events, Then event payloads are preserved", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          const event = GoalCreated.create(
            "goal-123",
            1,
            new GoalCreatedPayload({
              objective: "Build a rocket",
              context: "For Mars mission",
            })
          );

          yield* store.appendEvents("goal-123", [event], 0);
          
          return yield* store.getEvents("goal-123");
        });

        const events = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        const firstPayload = events[0].payload as any;
        expect(firstPayload.objective).toBe("Build a rocket");
        expect(firstPayload.context).toBe("For Mars mission");
      });
    });

    describe("Given no events exist", () => {
      it("When getting events for non-existent aggregate, Then returns empty array", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          return yield* store.getEvents("non-existent");
        });

        const events = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(events.length).toBe(0);
      });
    });
  });

  describe("getEventStream", () => {
    describe("Given events exist", () => {
      it("When getting event stream, Then returns stream with correct version", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          yield* store.appendEvents(
            "goal-123",
            [
              GoalCreated.create("goal-123", 1, new GoalCreatedPayload({ objective: "Test" })),
              GoalPaused.create("goal-123", 2),
              GoalResumed.create("goal-123", 3),
            ],
            0
          );
          
          return yield* store.getEventStream("goal-123");
        });

        const stream = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(stream.aggregateId).toBe("goal-123");
        expect(stream.aggregateType).toBe("Goal");
        expect(stream.version).toBe(3);
        expect(stream.events.length).toBe(3);
      });

      it("When getting stream after single event, Then version is 1", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          yield* store.appendEvents(
            "goal-123",
            [GoalCreated.create("goal-123", 1, new GoalCreatedPayload({ objective: "Test" }))],
            0
          );
          
          return yield* store.getEventStream("goal-123");
        });

        const stream = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(stream.version).toBe(1);
        expect(stream.events.length).toBe(1);
      });
    });

    describe("Given no events exist", () => {
      it("When getting event stream, Then returns empty stream with version 0", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          return yield* store.getEventStream("non-existent");
        });

        const stream = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(stream.aggregateId).toBe("non-existent");
        expect(stream.version).toBe(0);
        expect(stream.events.length).toBe(0);
      });
    });
  });

  describe("exists", () => {
    describe("Given aggregate has events", () => {
      it("When checking exists, Then returns true", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          yield* store.appendEvents(
            "goal-123",
            [GoalCreated.create("goal-123", 1, new GoalCreatedPayload({ objective: "Test" }))],
            0
          );
          
          return yield* store.exists("goal-123");
        });

        const exists = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(exists).toBe(true);
      });
    });

    describe("Given aggregate has no events", () => {
      it("When checking exists, Then returns false", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          return yield* store.exists("non-existent");
        });

        const exists = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(exists).toBe(false);
      });
    });

    describe("Given multiple aggregates", () => {
      it("When checking exists for each, Then returns correct results", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          yield* store.appendEvents(
            "goal-1",
            [GoalCreated.create("goal-1", 1, new GoalCreatedPayload({ objective: "Test" }))],
            0
          );

          const exists1 = yield* store.exists("goal-1");
          const exists2 = yield* store.exists("goal-2");

          return { exists1, exists2 };
        });

        const { exists1, exists2 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(exists1).toBe(true);
        expect(exists2).toBe(false);
      });
    });
  });

  describe("getAllAggregateIds", () => {
    describe("Given multiple aggregates exist", () => {
      it("When getting all aggregate IDs, Then returns all IDs sorted", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          yield* store.appendEvents(
            "goal-3",
            [GoalCreated.create("goal-3", 1, new GoalCreatedPayload({ objective: "Test 3" }))],
            0
          );
          
          yield* store.appendEvents(
            "goal-1",
            [GoalCreated.create("goal-1", 1, new GoalCreatedPayload({ objective: "Test 1" }))],
            0
          );
          
          yield* store.appendEvents(
            "goal-2",
            [GoalCreated.create("goal-2", 1, new GoalCreatedPayload({ objective: "Test 2" }))],
            0
          );
          
          return yield* store.getAllAggregateIds("Goal");
        });

        const ids = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(ids).toEqual(["goal-1", "goal-2", "goal-3"]);
      });

      it("When getting aggregate IDs by type, Then filters by aggregateType", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          
          yield* store.appendEvents(
            "goal-1",
            [GoalCreated.create("goal-1", 1, new GoalCreatedPayload({ objective: "Test" }))],
            0
          );
          
          return yield* store.getAllAggregateIds("Goal");
        });

        const ids = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(ids.length).toBe(1);
        expect(ids[0]).toBe("goal-1");
      });
    });

    describe("Given no aggregates exist", () => {
      it("When getting all aggregate IDs, Then returns empty array", async () => {
        const program = Effect.gen(function* () {
          const store = yield* EventStore;
          return yield* store.getAllAggregateIds("Goal");
        });

        const ids = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(ids.length).toBe(0);
      });
    });
  });

  describe("Event ordering and versioning", () => {
    it("When appending events out of version order, Then concurrency control prevents it", async () => {
      const program = Effect.gen(function* () {
        const store = yield* EventStore;
        
        yield* store.appendEvents(
          "goal-123",
          [GoalCreated.create("goal-123", 1, new GoalCreatedPayload({ objective: "Test" }))],
          0
        );
        
        // Skip version 2, try to append version 3
        return yield* store.appendEvents(
          "goal-123",
          [GoalResumed.create("goal-123", 3)],
          2
        );
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
      ).rejects.toThrow(/Concurrency conflict/);
    });

    it("When events are appended correctly, Then they maintain strict version sequence", async () => {
      const program = Effect.gen(function* () {
        const store = yield* EventStore;
        
        yield* store.appendEvents(
          "goal-123",
          [GoalCreated.create("goal-123", 1, new GoalCreatedPayload({ objective: "Test" }))],
          0
        );
        
        yield* store.appendEvents(
          "goal-123",
          [GoalPaused.create("goal-123", 2)],
          1
        );
        
        yield* store.appendEvents(
          "goal-123",
          [GoalResumed.create("goal-123", 3)],
          2
        );
        
        const events = yield* store.getEvents("goal-123");
        
        return events.map(e => e.version);
      });

      const versions = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

      expect(versions).toEqual([1, 2, 3]);
    });

    it("When multiple events appended at once, Then versions must be sequential", async () => {
      const program = Effect.gen(function* () {
        const store = yield* EventStore;
        
        // This should work - versions 1, 2, 3
        yield* store.appendEvents(
          "goal-123",
          [
            GoalCreated.create("goal-123", 1, new GoalCreatedPayload({ objective: "Test" })),
            GoalPaused.create("goal-123", 2),
            GoalResumed.create("goal-123", 3),
          ],
          0
        );
        
        return yield* store.getEvents("goal-123");
      });

      const events = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

      expect(events.map(e => e.version)).toEqual([1, 2, 3]);
    });
  });

  describe("Event payload integrity", () => {
    it("When storing and retrieving events, Then all payload data is preserved", async () => {
      const program = Effect.gen(function* () {
        const store = yield* EventStore;
        
        const createdEvent = GoalCreated.create(
          "goal-123",
          1,
          new GoalCreatedPayload({
            objective: "Build rocket with émojis 🚀",
            context: "Line 1\nLine 2\nLine 3",
          })
        );

        yield* store.appendEvents("goal-123", [createdEvent], 0);
        
        return yield* store.getEvents("goal-123");
      });

      const events = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

      const firstPayload = events[0].payload as any;
      expect(firstPayload.objective).toContain("🚀");
      expect(firstPayload.context).toContain("\n");
    });

    it("When storing events with metadata, Then all metadata is preserved", async () => {
      const program = Effect.gen(function* () {
        const store = yield* EventStore;
        
        const event = GoalCreated.create(
          "goal-123",
          1,
          new GoalCreatedPayload({ objective: "Test" })
        );

        yield* store.appendEvents("goal-123", [event], 0);
        
        return yield* store.getEvents("goal-123");
      });

      const events = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

      expect(events[0].eventId).toBeDefined();
      expect(events[0].eventType).toBe("GoalCreated");
      expect(events[0].aggregateId).toBe("goal-123");
      expect(events[0].aggregateType).toBe("Goal");
      expect(events[0].timestamp).toBeGreaterThan(0);
    });
  });
});
