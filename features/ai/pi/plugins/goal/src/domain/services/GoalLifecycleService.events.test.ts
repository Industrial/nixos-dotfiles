/**
 * GoalLifecycleService - Event sourcing BDD Tests
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { GoalLifecycleService } from "./GoalLifecycleService.js";
import { EventStore } from "../repositories/EventStore.js";
import { GoalLifecycleTestLayer } from "../../testing/TestLayers.js";

describe("GoalLifecycleService event sourcing", () => {
  const TestLayer = GoalLifecycleTestLayer;

  it("When creating a goal, Then appends GoalCreated to the event store", async () => {
    const program = Effect.gen(function* () {
      const lifecycle = yield* GoalLifecycleService;
      const store = yield* EventStore;
      const goal = yield* lifecycle.createGoal("Evented objective", "ctx");
      const events = yield* store.getEvents(goal.id);
      return { goal, events };
    });

    const { events } = await Effect.runPromise(
      program.pipe(Effect.provide(TestLayer))
    );

    expect(events).toHaveLength(1);
    expect(events[0].eventType).toBe("GoalCreated");
    expect(events[0].version).toBe(1);
  });

  it("When pausing a goal, Then appends GoalPaused with incremented version", async () => {
    const program = Effect.gen(function* () {
      const lifecycle = yield* GoalLifecycleService;
      const store = yield* EventStore;
      const goal = yield* lifecycle.createGoal("Pause me");
      yield* lifecycle.pauseGoal(goal.id);
      return yield* store.getEvents(goal.id);
    });

    const events = await Effect.runPromise(
      program.pipe(Effect.provide(TestLayer))
    );

    expect(events).toHaveLength(2);
    expect(events[1].eventType).toBe("GoalPaused");
    expect(events[1].version).toBe(2);
  });
});
