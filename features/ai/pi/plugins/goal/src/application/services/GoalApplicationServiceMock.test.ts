/**
 * GoalApplicationServiceMock - BDD Tests
 *
 * Comprehensive tests for the mock application service implementation.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { GoalApplicationService } from "./GoalApplicationService.js";
import { GoalApplicationServiceMock } from "./GoalApplicationServiceMock.js";
import {
  CreateGoalCommand,
  PauseGoalCommand,
  ResumeGoalCommand,
  CompleteGoalCommand,
} from "../commands/index.js";
import { GetGoalQuery, ListGoalsQuery } from "../queries/index.js";

describe("GoalApplicationServiceMock", () => {
  describe("Command: createGoal", () => {
    describe("Given valid command", () => {
      it("When creating goal with objective only, Then goal is created", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test goal" })
          );
        });

        const goal = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(goal.objective).toBe("Test goal");
        expect(goal.status).toBe("active");
        expect(goal.id).toBeDefined();
        expect(goal.createdAt).toBeGreaterThan(0);
      });

      it("When creating goal with context, Then both fields are set", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.createGoal(
            new CreateGoalCommand({
              objective: "Test goal",
              context: "Test context",
            })
          );
        });

        const goal = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(goal.objective).toBe("Test goal");
        expect(goal.context).toBe("Test context");
      });

      it("When creating multiple goals sequentially, Then each gets unique ID", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal1 = yield* service.createGoal(
            new CreateGoalCommand({ objective: "First" })
          );
          const goal2 = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Second" })
          );
          const goal3 = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Third" })
          );

          return { goal1, goal2, goal3 };
        });

        const { goal1, goal2, goal3 } = await Effect.runPromise(
          // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(goal1.id).not.toBe(goal2.id);
        expect(goal2.id).not.toBe(goal3.id);
        expect(goal1.id).not.toBe(goal3.id);
      });
    });

    describe("Edge cases", () => {
      it("When creating goal with Unicode emoji, Then emoji is preserved", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.createGoal(
            new CreateGoalCommand({ objective: "Launch 🚀 to Mars 🔴" })
          );
        });

        const goal = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(goal.objective).toContain("🚀");
        expect(goal.objective).toContain("🔴");
      });

      it("When creating goal with very long objective, Then full text is stored", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          const longObjective = "x".repeat(10000);
          return yield* service.createGoal(
            new CreateGoalCommand({ objective: longObjective })
          );
        });

        const goal = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(goal.objective.length).toBe(10000);
      });
    });
  });

  describe("Command: pauseGoal", () => {
    describe("Given goal exists", () => {
      it("When pausing active goal, Then status changes to paused", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* service.pauseGoal(
            new PauseGoalCommand({ goalId: goal.id })
          );
        });

        const pausedGoal = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(pausedGoal.status).toBe("paused");
      });

      it("When pausing goal, Then updatedAt changes", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* Effect.sleep("1 millis");

          const paused = yield* service.pauseGoal(
            new PauseGoalCommand({ goalId: goal.id })
          );

          return { goal, paused };
        });

        const { goal, paused } = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(paused.updatedAt).toBeGreaterThan(goal.updatedAt);
      });
    });

    describe("Given goal does not exist", () => {
      it("When pausing nonexistent goal, Then operation fails", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.pauseGoal(
            new PauseGoalCommand({ goalId: "nonexistent-id" })
          );
        });

        await expect(
          Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
            program.pipe(Effect.provide(GoalApplicationServiceMock))
          )
        ).rejects.toThrow(/Goal not found/);
      });
    });
  });

  describe("Command: resumeGoal", () => {
    describe("Given paused goal exists", () => {
      it("When resuming goal, Then status changes to active", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.pauseGoal(new PauseGoalCommand({ goalId: goal.id }));

          return yield* service.resumeGoal(
            new ResumeGoalCommand({ goalId: goal.id })
          );
        });

        const resumedGoal = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(resumedGoal.status).toBe("active");
      });
    });

    describe("Given goal does not exist", () => {
      it("When resuming nonexistent goal, Then operation fails", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.resumeGoal(
            new ResumeGoalCommand({ goalId: "nonexistent-id" })
          );
        });

        await expect(
          Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
            program.pipe(Effect.provide(GoalApplicationServiceMock))
          )
        ).rejects.toThrow(/Goal not found/);
      });
    });
  });

  describe("Command: completeGoal", () => {
    describe("Given active goal exists", () => {
      it("When completing goal, Then status changes to completed", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* service.completeGoal(
            new CompleteGoalCommand({ goalId: goal.id })
          );
        });

        const completedGoal = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(completedGoal.status).toBe("completed");
        expect(completedGoal.completedAt).toBeDefined();
        expect(completedGoal.completedAt).toBeGreaterThan(0);
      });

      it("When completing goal, Then completedAt equals updatedAt", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* service.completeGoal(
            new CompleteGoalCommand({ goalId: goal.id })
          );
        });

        const completedGoal = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(completedGoal.completedAt).toBe(completedGoal.updatedAt);
      });
    });

    describe("Given goal does not exist", () => {
      it("When completing nonexistent goal, Then operation fails", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.completeGoal(
            new CompleteGoalCommand({ goalId: "nonexistent-id" })
          );
        });

        await expect(
          Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
            program.pipe(Effect.provide(GoalApplicationServiceMock))
          )
        ).rejects.toThrow(/Goal not found/);
      });
    });
  });

  describe("Query: getGoal", () => {
    describe("Given goal exists", () => {
      it("When querying by ID, Then goal is returned", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const created = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          return yield* service.getGoal(
            new GetGoalQuery({ goalId: created.id })
          );
        });

        const goal = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(goal.objective).toBe("Test goal");
      });

      it("When querying multiple times, Then same goal is returned", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const created = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          const query = new GetGoalQuery({ goalId: created.id });
          const result1 = yield* service.getGoal(query);
          const result2 = yield* service.getGoal(query);

          return { result1, result2 };
        });

        const { result1, result2 } = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(result1.id).toBe(result2.id);
        expect(result1.objective).toBe(result2.objective);
      });
    });

    describe("Given goal does not exist", () => {
      it("When querying by nonexistent ID, Then operation fails", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.getGoal(
            new GetGoalQuery({ goalId: "nonexistent-id" })
          );
        });

        await expect(
          Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
            program.pipe(Effect.provide(GoalApplicationServiceMock))
          )
        ).rejects.toThrow(/Goal not found/);
      });
    });
  });

  describe("Query: listGoals", () => {
    describe("Given no goals exist", () => {
      it("When listing goals, Then empty array is returned", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.listGoals(new ListGoalsQuery({}));
        });

        const goals = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(goals).toBeInstanceOf(Array);
        expect(goals.length).toBe(0);
      });
    });

    describe("Given multiple goals exist", () => {
      it("When listing without filters, Then all goals are returned", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          yield* service.createGoal(
            new CreateGoalCommand({ objective: "Goal 1" })
          );
          yield* service.createGoal(
            new CreateGoalCommand({ objective: "Goal 2" })
          );
          yield* service.createGoal(
            new CreateGoalCommand({ objective: "Goal 3" })
          );

          return yield* service.listGoals(new ListGoalsQuery({}));
        });

        const goals = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(goals.length).toBe(3);
      });

      it("When listing with status filter, Then only matching goals returned", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const _goal1 = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Active" })
          );

          const goal2 = yield* service.createGoal(
            new CreateGoalCommand({ objective: "To Pause" })
          );
          yield* service.pauseGoal(new PauseGoalCommand({ goalId: goal2.id }));

          return yield* service.listGoals(
            new ListGoalsQuery({ status: "active" })
          );
        });

        const goals = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(goals.length).toBe(1);
        expect(goals[0].status).toBe("active");
      });

      it("When listing with limit, Then limited results returned", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          for (let i = 1; i <= 5; i++) {
            yield* service.createGoal(
              new CreateGoalCommand({ objective: `Goal ${i}` })
            );
          }

          return yield* service.listGoals(new ListGoalsQuery({ limit: 2 }));
        });

        const goals = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(goals.length).toBe(2);
      });

      it("When listing with offset, Then skips specified number", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          for (let i = 1; i <= 5; i++) {
            yield* service.createGoal(
              new CreateGoalCommand({ objective: `Goal ${i}` })
            );
          }

          return yield* service.listGoals(new ListGoalsQuery({ offset: 2 }));
        });

        const goals = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(goals.length).toBe(3);
      });

      it("When listing goals, Then sorted by createdAt descending", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal1 = yield* service.createGoal(
            new CreateGoalCommand({ objective: "First" })
          );

          yield* Effect.sleep("1 millis");

          const goal2 = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Second" })
          );

          yield* Effect.sleep("1 millis");

          const goal3 = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Third" })
          );

          const goals = yield* service.listGoals(new ListGoalsQuery({}));

          return { goals, goal1, goal2, goal3 };
        });

        const { goals, goal1, goal2, goal3 } = await Effect.runPromise(
          // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(goals[0].id).toBe(goal3.id); // Most recent first
        expect(goals[1].id).toBe(goal2.id);
        expect(goals[2].id).toBe(goal1.id);
      });
    });
  });

  describe("Query: getActiveGoal", () => {
    describe("Given no active goal exists", () => {
      it("When querying active goal, Then returns null", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.getActiveGoal();
        });

        const activeGoal = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(activeGoal).toBeNull();
      });
    });

    describe("Given one active goal exists", () => {
      it("When querying active goal, Then returns the goal", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Active goal" })
          );

          const active = yield* service.getActiveGoal();

          return { goal, active };
        });

        const { goal, active } = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(active?.id).toBe(goal.id);
        expect(active?.status).toBe("active");
      });
    });

    describe("Given multiple goals with only one active", () => {
      it("When querying active goal, Then returns only the active one", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal1 = yield* service.createGoal(
            new CreateGoalCommand({ objective: "First" })
          );
          yield* service.completeGoal(
            new CompleteGoalCommand({ goalId: goal1.id })
          );

          const goal2 = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Second Active" })
          );

          const active = yield* service.getActiveGoal();

          return { goal2, active };
        });

        const { goal2, active } = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(active?.id).toBe(goal2.id);
        expect(active?.objective).toBe("Second Active");
      });
    });

    describe("Given paused goal exists", () => {
      it("When querying active goal, Then returns null", async () => {
        const program = Effect.gen(function* () {
          const service = yield* GoalApplicationService;

          const goal = yield* service.createGoal(
            new CreateGoalCommand({ objective: "Test goal" })
          );

          yield* service.pauseGoal(new PauseGoalCommand({ goalId: goal.id }));

          return yield* service.getActiveGoal();
        });

        const activeGoal = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
          program.pipe(Effect.provide(GoalApplicationServiceMock))
        );

        expect(activeGoal).toBeNull();
      });
    });
  });

  describe("Integration scenarios", () => {
    it("When performing full lifecycle, Then all operations succeed", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;

        // Create
        const created = yield* service.createGoal(
          new CreateGoalCommand({ objective: "Full lifecycle test" })
        );

        // Query by ID
        const fetched = yield* service.getGoal(
          new GetGoalQuery({ goalId: created.id })
        );

        // Query active
        const active1 = yield* service.getActiveGoal();

        // Pause
        const paused = yield* service.pauseGoal(
          new PauseGoalCommand({ goalId: created.id })
        );

        // Query active again
        const active2 = yield* service.getActiveGoal();

        // Resume
        const resumed = yield* service.resumeGoal(
          new ResumeGoalCommand({ goalId: created.id })
        );

        // Complete
        const completed = yield* service.completeGoal(
          new CompleteGoalCommand({ goalId: created.id })
        );

        // List all
        const allGoals = yield* service.listGoals(new ListGoalsQuery({}));

        return {
          created,
          fetched,
          active1,
          paused,
          active2,
          resumed,
          completed,
          allGoals,
        };
      });

      const result = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
        program.pipe(Effect.provide(GoalApplicationServiceMock))
      );

      expect(result.created.status).toBe("active");
      expect(result.fetched.id).toBe(result.created.id);
      expect(result.active1?.id).toBe(result.created.id);
      expect(result.paused.status).toBe("paused");
      expect(result.active2).toBeNull();
      expect(result.resumed.status).toBe("active");
      expect(result.completed.status).toBe("completed");
      expect(result.allGoals.length).toBe(1);
    });

    it("When managing multiple goals, Then state is maintained correctly", async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;

        const goal1 = yield* service.createGoal(
          new CreateGoalCommand({ objective: "Goal 1" })
        );

        yield* service.completeGoal(
          new CompleteGoalCommand({ goalId: goal1.id })
        );

        const goal2 = yield* service.createGoal(
          new CreateGoalCommand({ objective: "Goal 2" })
        );

        const goal3 = yield* service.createGoal(
          new CreateGoalCommand({ objective: "Goal 3" })
        );

        const allGoals = yield* service.listGoals(new ListGoalsQuery({}));
        const activeGoals = yield* service.listGoals(
          new ListGoalsQuery({ status: "active" })
        );
        const completedGoals = yield* service.listGoals(
          new ListGoalsQuery({ status: "completed" })
        );

        return { allGoals, activeGoals, completedGoals, goal1, goal2, goal3 };
      });

      const result = await Effect.runPromise(
        // @ts-expect-error - Type mismatch in test layer setup
        program.pipe(Effect.provide(GoalApplicationServiceMock))
      );

      expect(result.allGoals.length).toBe(3);
      expect(result.activeGoals.length).toBe(2);
      expect(result.completedGoals.length).toBe(1);
    });
  });
});
