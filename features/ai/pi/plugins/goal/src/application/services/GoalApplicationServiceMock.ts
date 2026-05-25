/**
 * Goal Application Service - Mock Implementation
 * 
 * Simplified mock for testing higher-level components without
 * full infrastructure dependencies.
 */
import { Effect, Layer, Ref } from "effect";
import { Goal, createGoal as makeGoal } from "../../domain/models/Goal.js";
import { GoalApplicationService } from "./GoalApplicationService.js";
import {
  CreateGoalCommand,
  PauseGoalCommand,
  ResumeGoalCommand,
  CompleteGoalCommand,
} from "../commands/index.js";
import { GetGoalQuery, ListGoalsQuery } from "../queries/index.js";

/**
 * Mock implementation of GoalApplicationService
 * Uses in-memory state for testing
 */
export const GoalApplicationServiceMock = Layer.effect(
  GoalApplicationService,
  Effect.gen(function* () {
    const store = yield* Ref.make<Map<string, Goal>>(new Map());

    const createGoal = (command: CreateGoalCommand) =>
      Effect.gen(function* () {
        const goal = makeGoal(command.objective, command.context);
        yield* Ref.update(store, (map) => new Map(map).set(goal.id, goal));
        return goal;
      });

    const pauseGoal = (command: PauseGoalCommand) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const goal = map.get(command.goalId);
        
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${command.goalId}`));
        }

        const pausedGoal = yield* goal.pause();
        yield* Ref.update(store, (m) => new Map(m).set(goal.id, pausedGoal));
        return pausedGoal;
      });

    const resumeGoal = (command: ResumeGoalCommand) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const goal = map.get(command.goalId);
        
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${command.goalId}`));
        }

        const resumedGoal = yield* goal.resume();
        yield* Ref.update(store, (m) => new Map(m).set(goal.id, resumedGoal));
        return resumedGoal;
      });

    const completeGoal = (command: CompleteGoalCommand) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const goal = map.get(command.goalId);
        
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${command.goalId}`));
        }

        const completedGoal = yield* goal.complete();
        yield* Ref.update(store, (m) => new Map(m).set(goal.id, completedGoal));
        return completedGoal;
      });

    const getGoal = (query: GetGoalQuery) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const goal = map.get(query.goalId);
        
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${query.goalId}`));
        }
        
        return goal;
      });

    const listGoals = (query: ListGoalsQuery) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        let goals = Array.from(map.values());

        if (query.status) {
          goals = goals.filter((g) => g.status === query.status);
        }

        goals.sort((a, b) => b.createdAt - a.createdAt);

        const offset = query.offset ?? 0;
        const limit = query.limit ?? 100;
        return goals.slice(offset, offset + limit);
      });

    const getActiveGoal = () =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const activeGoals = Array.from(map.values())
          .filter((g) => g.status === "active")
          .sort((a, b) => b.createdAt - a.createdAt);

        return activeGoals[0] ?? null;
      });

    return {
      createGoal,
      pauseGoal,
      resumeGoal,
      completeGoal,
      getGoal,
      listGoals,
      getActiveGoal,
    };
  })
);
