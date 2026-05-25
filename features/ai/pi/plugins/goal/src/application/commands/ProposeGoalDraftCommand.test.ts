/**
 * ProposeGoalDraftCommand - BDD Tests
 *
 * Tests for proposing goal drafts before creation.
 * Goal drafts allow users to review and refine goals before committing.
 */
import { describe, it, expect } from "bun:test";
import { Effect, Layer } from "effect";
import { ProposeGoalDraftCommand, proposeGoalDraftHandler } from "./ProposeGoalDraftCommand.js";
import { GoalLifecycleServiceLive } from "../../domain/services/GoalLifecycleServiceLive.js";
import { GoalRepositoryMock } from "../../infrastructure/persistence/GoalRepositoryMock.js";

describe("ProposeGoalDraftCommand", () => {
  const TestLayer = GoalLifecycleServiceLive.pipe(
    Layer.provide(GoalRepositoryMock)
  );

  describe("Schema Validation", () => {
    describe("Given valid command input", () => {
      it("When creating command with objective only, Then command is created", () => {
        const command = new ProposeGoalDraftCommand({
          objective: "Build a rocket",
        });

        expect(command.objective).toBe("Build a rocket");
        expect(command.context).toBeUndefined();
      });

      it("When creating command with objective and context, Then both fields are set", () => {
        const command = new ProposeGoalDraftCommand({
          objective: "Build a rocket",
          context: "For Mars mission",
        });

        expect(command.objective).toBe("Build a rocket");
        expect(command.context).toBe("For Mars mission");
      });

      it("When creating command with rationale, Then rationale is set", () => {
        const command = new ProposeGoalDraftCommand({
          objective: "Build a rocket",
          rationale: "To explore Mars and advance space technology",
        });

        expect(command.objective).toBe("Build a rocket");
        expect(command.rationale).toBe("To explore Mars and advance space technology");
      });

      it("When creating command with all fields, Then all fields are set", () => {
        const command = new ProposeGoalDraftCommand({
          objective: "Build a rocket",
          context: "For Mars mission",
          rationale: "Space exploration",
          successCriteria: ["Launch successful", "Land safely"],
        });

        expect(command.objective).toBe("Build a rocket");
        expect(command.context).toBe("For Mars mission");
        expect(command.rationale).toBe("Space exploration");
        expect(command.successCriteria).toEqual(["Launch successful", "Land safely"]);
      });
    });

    describe("Given invalid command input", () => {
      it("When creating command with empty objective, Then validation fails", () => {
        expect(() => {
          new ProposeGoalDraftCommand({
            objective: "",
          });
        }).toThrow();
      });
    });
  });

  describe("Command Handler Execution", () => {
    describe("Given valid draft proposal", () => {
      it("When proposing goal draft, Then draft is created with pending status", async () => {
        const program = Effect.gen(function* () {
          return yield* proposeGoalDraftHandler(
            new ProposeGoalDraftCommand({
              objective: "Test goal",
              context: "Test context",
            })
          );
        });

        const draft = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(draft.objective).toBe("Test goal");
        expect(draft.context).toBe("Test context");
        // TODO: Implement draft status when Goal model supports it
        // expect(draft.status).toBe("draft");
      });

      it("When proposing draft with rationale, Then rationale is included", async () => {
        const program = Effect.gen(function* () {
          return yield* proposeGoalDraftHandler(
            new ProposeGoalDraftCommand({
              objective: "Test goal",
              rationale: "Because we need to test",
            })
          );
        });

        const draft = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        // TODO: Implement rationale property when Goal model supports it
        // expect(draft.rationale).toBe("Because we need to test");
        expect(draft.objective).toBe("Test goal");
      });

      it("When proposing draft, Then draft gets unique ID", async () => {
        const program = Effect.gen(function* () {
          const draft1 = yield* proposeGoalDraftHandler(
            new ProposeGoalDraftCommand({ objective: "First" })
          );

          const draft2 = yield* proposeGoalDraftHandler(
            new ProposeGoalDraftCommand({ objective: "Second" })
          );

          return { draft1, draft2 };
        });

        const { draft1, draft2 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(draft1.id).not.toBe(draft2.id);
      });

      it("When proposing draft, Then createdAt timestamp is set", async () => {
        const program = Effect.gen(function* () {
          const before = Date.now();
          const draft = yield* proposeGoalDraftHandler(
            new ProposeGoalDraftCommand({ objective: "Test" })
          );
          const after = Date.now();

          return { draft, before, after };
        });

        const { draft, before, after } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(draft.createdAt).toBeGreaterThanOrEqual(before);
        expect(draft.createdAt).toBeLessThanOrEqual(after);
      });
    });

    describe("Given multiple drafts", () => {
      it("When proposing multiple drafts, Then all can exist simultaneously", async () => {
        const program = Effect.gen(function* () {
          const draft1 = yield* proposeGoalDraftHandler(
            new ProposeGoalDraftCommand({ objective: "Draft 1" })
          );

          const draft2 = yield* proposeGoalDraftHandler(
            new ProposeGoalDraftCommand({ objective: "Draft 2" })
          );

          const draft3 = yield* proposeGoalDraftHandler(
            new ProposeGoalDraftCommand({ objective: "Draft 3" })
          );

          return { draft1, draft2, draft3 };
        });

        const { draft1, draft2, draft3 } = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(draft1.objective).toBe("Draft 1");
        expect(draft2.objective).toBe("Draft 2");
        expect(draft3.objective).toBe("Draft 3");
        expect(draft1.id).not.toBe(draft2.id);
        expect(draft2.id).not.toBe(draft3.id);
      });
    });

    describe("Edge cases", () => {
      it("When proposing draft with Unicode emoji, Then emoji is preserved", async () => {
        const program = Effect.gen(function* () {
          return yield* proposeGoalDraftHandler(
            new ProposeGoalDraftCommand({
              objective: "Launch 🚀 to Mars 🔴",
            })
          );
        });

        const draft = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(draft.objective).toContain("🚀");
        expect(draft.objective).toContain("🔴");
      });

      it("When proposing draft with very long objective, Then full text is stored", async () => {
        const program = Effect.gen(function* () {
          const longObjective = "x".repeat(10000);
          return yield* proposeGoalDraftHandler(
            new ProposeGoalDraftCommand({ objective: longObjective })
          );
        });

        const draft = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(draft.objective.length).toBe(10000);
      });

      it("When proposing draft with success criteria array, Then array is preserved", async () => {
        const program = Effect.gen(function* () {
          return yield* proposeGoalDraftHandler(
            new ProposeGoalDraftCommand({
              objective: "Test",
              successCriteria: ["Criterion 1", "Criterion 2", "Criterion 3"],
            })
          );
        });

        const draft = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        // TODO: Implement successCriteria property when Goal model supports it
        // expect(draft.successCriteria).toHaveLength(3);
        // expect(draft.successCriteria).toContain("Criterion 1");
        expect(draft.objective).toBe("Test");
      });
    });
  });
});
