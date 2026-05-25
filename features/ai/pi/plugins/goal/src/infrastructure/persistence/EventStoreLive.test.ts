/**
 * EventStoreLive - BDD Tests (SQLite)
 */
import { describe, it, expect, afterAll } from "bun:test";
import { Effect, Layer } from "effect";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { EventStore } from "../../domain/repositories/EventStore.js";
import { GoalCreated, GoalCreatedPayload } from "../../domain/events/GoalCreated.js";
import { GoalPaused } from "../../domain/events/GoalPaused.js";
import { DatabaseLayer } from "../database/DatabaseLayer.js";
import { EventStoreLive } from "./EventStoreLive.js";

describe("EventStoreLive", () => {
  const dir = mkdtempSync(join(tmpdir(), "goal-events-"));
  const dbPath = join(dir, "events.db");

  afterAll(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  const makeLayer = () =>
    EventStoreLive.pipe(Layer.provideMerge(DatabaseLayer));

  it("When appending GoalCreated, Then persists and reads back in order", async () => {
    const prev = process.env.PI_GOAL_DB_PATH;
    process.env.PI_GOAL_DB_PATH = dbPath;

    try {
      const goalId = "goal-event-live-1";

      const program = Effect.gen(function* () {
        const store = yield* EventStore;
        const created = GoalCreated.create(
          goalId,
          1,
          new GoalCreatedPayload({ objective: "Persist events" })
        );
        yield* store.appendEvents(goalId, [created], 0);
        return yield* store.getEvents(goalId);
      });

      const events = await Effect.runPromise(
        program.pipe(Effect.provide(makeLayer()))
      );

      expect(events).toHaveLength(1);
      expect(events[0].eventType).toBe("GoalCreated");
      expect(events[0].version).toBe(1);
    } finally {
      if (prev === undefined) delete process.env.PI_GOAL_DB_PATH;
      else process.env.PI_GOAL_DB_PATH = prev;
    }
  });

  it("When appending with wrong expected version, Then concurrency error", async () => {
    const prev = process.env.PI_GOAL_DB_PATH;
    process.env.PI_GOAL_DB_PATH = dbPath;

    try {
      const goalId = "goal-event-live-2";

      const program = Effect.gen(function* () {
        const store = yield* EventStore;
        const created = GoalCreated.create(
          goalId,
          1,
          new GoalCreatedPayload({ objective: "v1" })
        );
        yield* store.appendEvents(goalId, [created], 0);
        const paused = GoalPaused.create(goalId, 2);
        return yield* store.appendEvents(goalId, [paused], 0);
      });

      await expect(
        Effect.runPromise(program.pipe(Effect.provide(makeLayer())))
      ).rejects.toThrow(/Concurrency conflict/);
    } finally {
      if (prev === undefined) delete process.env.PI_GOAL_DB_PATH;
      else process.env.PI_GOAL_DB_PATH = prev;
    }
  });
});
