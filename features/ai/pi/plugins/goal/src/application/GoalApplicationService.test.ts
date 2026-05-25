/**
 * GoalApplicationService - BDD Tests
 *
 * Tests for the main application facade that coordinates all goal operations.
 */
import { describe, it, expect } from "bun:test";
import { Effect, Layer } from "effect";
import {
  GoalApplicationService,
  GoalApplicationServiceLive,
} from "./GoalApplicationService.js";
import { GoalLifecycleServiceLive } from "../domain/services/GoalLifecycleServiceLive.js";
import { JudgeServiceMock } from "../domain/services/JudgeServiceMock.js";
import { PromptGeneratorServiceMock } from "../domain/services/PromptGeneratorServiceMock.js";
import { ToolExecutionServiceMock } from "../domain/services/ToolExecutionServiceMock.js";
import { GoalRepositoryMock } from "../infrastructure/persistence/GoalRepositoryMock.js";

describe("GoalApplicationService", () => {
  // Simplified: Just use the domain layers directly
  // Application service doesn't need DI since it calls handlers directly
  const TestLayer = Layer.mergeAll(
    GoalRepositoryMock,
    GoalLifecycleServiceLive.pipe(Layer.provide(GoalRepositoryMock)),
    JudgeServiceMock,
    PromptGeneratorServiceMock,
    ToolExecutionServiceMock,
    GoalApplicationServiceLive
  );

  describe("createGoal", () => {
    it("When creating goal with objective, Then returns goal", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.createGoal({ objective: "Test goal" });
      });

      const result = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(result.objective).toBe("Test goal");
      expect(result.status).toBe("active");
    });

    it("When creating goal with context, Then includes context", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.createGoal({
          objective: "Complex task",
          context: "Additional context here",
        });
      });

      const result = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(result.context).toBe("Additional context here");
    });
  });

  describe("pauseGoal", () => {
    it("When pausing active goal, Then goal becomes paused", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        const goal = yield* service.createGoal({ objective: "Test" });
        return yield* service.pauseGoal(goal.id);
      });

      const result = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(result.status).toBe("paused");
    });
  });

  describe("resumeGoal", () => {
    it("When resuming paused goal, Then goal becomes active", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        const goal = yield* service.createGoal({ objective: "Test" });
        const paused = yield* service.pauseGoal(goal.id);
        return yield* service.resumeGoal(paused.id);
      });

      const result = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(result.status).toBe("active");
    });
  });

  describe("completeGoal", () => {
    it("When completing active goal, Then goal becomes completed", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        const goal = yield* service.createGoal({ objective: "Test" });
        return yield* service.completeGoal(goal.id);
      });

      const result = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(result.status).toBe("completed");
    });
  });

  describe("getActiveGoal", () => {
    it("When no active goal exists, Then returns undefined", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.getActiveGoal();
      });

      const result = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(result).toBeUndefined();
    });

    it("When active goal exists, Then returns goal", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        yield* service.createGoal({ objective: "Active goal" });
        return yield* service.getActiveGoal();
      });

      const result = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(result).toBeDefined();
      expect(result?.objective).toBe("Active goal");
    });
  });

  describe("getGoalStatistics", () => {
    it("When getting statistics, Then returns valid structure", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.getGoalStatistics();
      });

      const stats = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      // Statistics object structure validation
      expect(stats).toBeDefined();
      expect(typeof stats).toBe("object");
    });
  });

  describe("executeGoal", () => {
    it("When executing goal, Then returns execution result", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        const goal = yield* service.createGoal({ objective: "Executable goal" });
        return yield* service.executeGoal(goal.id, { maxTurns: 2 });
      });

      const result = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(result.success).toBe(true);
      expect(result.context).toBeDefined();
    });
  });

});
