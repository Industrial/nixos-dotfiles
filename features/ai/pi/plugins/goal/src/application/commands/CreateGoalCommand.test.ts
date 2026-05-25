/**
 * CreateGoalCommand - BDD Tests
 * 
 * Comprehensive input/output mutation tests using Given/When/Then pattern.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { CreateGoalCommand, createGoalHandler } from "./CreateGoalCommand.js";
import { GoalLifecycleService } from "../../domain/services/GoalLifecycleService.js";
import { GoalLifecycleTestLayer } from "../../testing/TestLayers.js";

describe("CreateGoalCommand", () => {
  const TestLayer = GoalLifecycleTestLayer;

  describe("Schema Validation", () => {
    describe("Given valid command input", () => {
      it("When creating command with objective and context, Then command is created successfully", () => {
        const command = new CreateGoalCommand({
          objective: "Build a rocket",
          context: "For Mars mission",
        });

        expect(command.objective).toBe("Build a rocket");
        expect(command.context).toBe("For Mars mission");
      });

      it("When creating command with objective only, Then context is undefined", () => {
        const command = new CreateGoalCommand({
          objective: "Build a rocket",
        });

        expect(command.objective).toBe("Build a rocket");
        expect(command.context).toBeUndefined();
      });

      it("When creating command with minimum valid objective, Then command is created", () => {
        const command = new CreateGoalCommand({
          objective: "x", // Single character
        });

        expect(command.objective).toBe("x");
      });

      it("When creating command with very long objective, Then command is created", () => {
        const longObjective = "a".repeat(10000);
        const command = new CreateGoalCommand({
          objective: longObjective,
        });

        expect(command.objective).toBe(longObjective);
      });

      it("When creating command with special characters in objective, Then command is created", () => {
        const command = new CreateGoalCommand({
          objective: "Test with émojis 🚀 and spëcial çharacters!",
        });

        expect(command.objective).toContain("🚀");
      });
    });

    describe("Given invalid command input", () => {
      it("When creating command with empty objective, Then validation fails", () => {
        expect(() => {
          new CreateGoalCommand({
            objective: "",
          });
        }).toThrow();
      });

      it("When creating command with whitespace-only objective, Then command is created but may fail business rules", () => {
        const command = new CreateGoalCommand({
          objective: "   ",
        });

        expect(command.objective).toBe("   ");
      });
    });
  });

  describe("Command Handler Execution", () => {
    describe("Given no existing goals", () => {
      it("When executing create command, Then goal is created with active status", async () => {
        const command = new CreateGoalCommand({
          objective: "Test goal",
          context: "Test context",
        });

        const program = Effect.gen(function* () {
          return yield* createGoalHandler(command);
        });

        const goal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goal.objective).toBe("Test goal");
        expect(goal.context).toBe("Test context");
        expect(goal.status).toBe("active");
        expect(goal.id).toBeDefined();
        expect(goal.createdAt).toBeGreaterThan(0);
        expect(goal.updatedAt).toBe(goal.createdAt);
        expect(goal.completedAt).toBeUndefined();
      });

      it("When executing create command without context, Then goal is created with undefined context", async () => {
        const command = new CreateGoalCommand({
          objective: "Test goal",
        });

        const program = Effect.gen(function* () {
          return yield* createGoalHandler(command);
        });

        const goal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goal.objective).toBe("Test goal");
        expect(goal.context).toBeUndefined();
      });

      it("When executing multiple create commands sequentially, Then each gets unique ID", async () => {
        const program = Effect.gen(function* () {
          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 1" })
          );
          
          // Pause first goal to allow creating second
          const service = yield* GoalLifecycleService;
          yield* service.pauseGoal(goal1.id);
          
          const goal2 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Goal 2" })
          );

          return { goal1, goal2 };
        });

        const { goal1, goal2 } = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goal1.id).not.toBe(goal2.id);
        expect(goal1.objective).toBe("Goal 1");
        expect(goal2.objective).toBe("Goal 2");
      });
    });

    describe("Given an existing active goal", () => {
      it("When executing create command, Then creation fails with business rule violation", async () => {
        const program = Effect.gen(function* () {
          // Create first goal
          yield* createGoalHandler(
            new CreateGoalCommand({ objective: "First goal" })
          );

          // Attempt to create second goal while first is active
          return yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Second goal" })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Active goal already exists/);
      });

      it("When executing create command with different context, Then still fails due to active goal", async () => {
        const program = Effect.gen(function* () {
          yield* createGoalHandler(
            new CreateGoalCommand({ 
              objective: "First",
              context: "Context A"
            })
          );

          return yield* createGoalHandler(
            new CreateGoalCommand({ 
              objective: "Second",
              context: "Context B"
            })
          );
        });

        await expect(
          Effect.runPromise(program.pipe(Effect.provide(TestLayer)))
        ).rejects.toThrow(/Active goal already exists/);
      });
    });

    describe("Given an existing paused goal", () => {
      it("When executing create command, Then new goal is created successfully", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          // Create and pause first goal
          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "First goal" })
          );
          yield* service.pauseGoal(goal1.id);

          // Create second goal
          return yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Second goal" })
          );
        });

        const goal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goal.objective).toBe("Second goal");
        expect(goal.status).toBe("active");
      });
    });

    describe("Given an existing completed goal", () => {
      it("When executing create command, Then new goal is created successfully", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          // Create and complete first goal
          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "First goal" })
          );
          yield* service.completeGoal(goal1.id);

          // Create second goal
          return yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Second goal" })
          );
        });

        const goal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goal.objective).toBe("Second goal");
        expect(goal.status).toBe("active");
      });
    });

    describe("Given an existing cancelled goal", () => {
      it("When executing create command, Then new goal is created successfully", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          // Create and cancel first goal
          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "First goal" })
          );
          yield* service.cancelGoal(goal1.id);

          // Create second goal
          return yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Second goal" })
          );
        });

        const goal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goal.objective).toBe("Second goal");
        expect(goal.status).toBe("active");
      });
    });

    describe("Edge cases and boundary conditions", () => {
      it("When creating goal with Unicode emoji in objective, Then goal is created correctly", async () => {
        const command = new CreateGoalCommand({
          objective: "Launch 🚀 to Mars 🔴",
        });

        const program = Effect.gen(function* () {
          return yield* createGoalHandler(command);
        });

        const goal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goal.objective).toContain("🚀");
        expect(goal.objective).toContain("🔴");
      });

      it("When creating goal with newlines in objective, Then goal is created correctly", async () => {
        const command = new CreateGoalCommand({
          objective: "Line 1\nLine 2\nLine 3",
        });

        const program = Effect.gen(function* () {
          return yield* createGoalHandler(command);
        });

        const goal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goal.objective).toContain("\n");
      });

      it("When creating goal with very long context, Then goal is created correctly", async () => {
        const longContext = "x".repeat(100000);
        const command = new CreateGoalCommand({
          objective: "Test",
          context: longContext,
        });

        const program = Effect.gen(function* () {
          return yield* createGoalHandler(command);
        });

        const goal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goal.context?.length).toBe(100000);
      });
    });

    describe("Timestamp behavior", () => {
      it("When creating goal, Then createdAt and updatedAt are set to same value", async () => {
        const command = new CreateGoalCommand({
          objective: "Test timestamps",
        });

        const program = Effect.gen(function* () {
          return yield* createGoalHandler(command);
        });

        const goal = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goal.createdAt).toBe(goal.updatedAt);
      });

      it("When creating goals in sequence, Then each has later timestamp", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalLifecycleService;
          
          const goal1 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "First" })
          );
          
          yield* service.pauseGoal(goal1.id);
          
          // Small delay to ensure different timestamp
          yield* Effect.sleep("1 millis");
          
          const goal2 = yield* createGoalHandler(
            new CreateGoalCommand({ objective: "Second" })
          );

          return { goal1, goal2 };
        });

        const { goal1, goal2 } = await Effect.runPromise(program.pipe(Effect.provide(TestLayer)));

        expect(goal2.createdAt).toBeGreaterThanOrEqual(goal1.createdAt);
      });
    });
  });
});
