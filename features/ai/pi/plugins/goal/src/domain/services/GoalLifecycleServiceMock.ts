/**
 * Goal Lifecycle Service - Mock Implementation
 * 
 * In-memory mock for testing without real repository dependencies.
 */
import { Effect, Layer, Ref } from "effect";
import { Goal, createGoal as makeGoal } from "../models/Goal.js";
import { GoalLifecycleService } from "./GoalLifecycleService.js";

/**
 * Mock implementation of GoalLifecycleService
 * Uses in-memory state to simulate service behavior
 */
export const GoalLifecycleServiceMock = Layer.effect(
  GoalLifecycleService,
  Effect.gen(function* () {
    // In-memory storage for mock
    const store = yield* Ref.make<Map<string, Goal>>(new Map());

    const createGoal = (objective: string, context?: string) =>
      Effect.gen(function* () {
        // Mock business rule: Only one active goal at a time
        const map = yield* Ref.get(store);
        const hasActive = Array.from(map.values()).some((g) => g.status === "active");
        
        if (hasActive) {
          return yield* Effect.fail(
            new Error("Cannot create new goal: Active goal already exists. Please pause or complete it first.")
          );
        }

        const goal = makeGoal(objective, context);
        yield* Ref.update(store, (m) => new Map(m).set(goal.id, goal));
        return goal;
      });

    const pauseGoal = (goalId: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const goal = map.get(goalId);
        
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${goalId}`));
        }

        const pausedGoal = yield* goal.pause();
        yield* Ref.update(store, (m) => new Map(m).set(goalId, pausedGoal));
        return pausedGoal;
      });

    const resumeGoal = (goalId: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        
        // Business rule: Only one active goal at a time
        const hasOtherActive = Array.from(map.values()).some(
          (g) => g.status === "active" && g.id !== goalId
        );
        
        if (hasOtherActive) {
          return yield* Effect.fail(
            new Error("Cannot resume goal: Another goal is already active. Please pause it first.")
          );
        }

        const goal = map.get(goalId);
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${goalId}`));
        }

        const resumedGoal = yield* goal.resume();
        yield* Ref.update(store, (m) => new Map(m).set(goalId, resumedGoal));
        return resumedGoal;
      });

    const completeGoal = (goalId: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const goal = map.get(goalId);
        
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${goalId}`));
        }

        const completedGoal = yield* goal.complete();
        yield* Ref.update(store, (m) => new Map(m).set(goalId, completedGoal));
        return completedGoal;
      });

    const cancelGoal = (goalId: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const goal = map.get(goalId);
        
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${goalId}`));
        }

        const cancelledGoal = yield* goal.cancel();
        yield* Ref.update(store, (m) => new Map(m).set(goalId, cancelledGoal));
        return cancelledGoal;
      });

    const canActivateGoal = () =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const hasActive = Array.from(map.values()).some((g) => g.status === "active");
        return !hasActive;
      });

    return {
      createGoal,
      pauseGoal,
      resumeGoal,
      completeGoal,
      cancelGoal,
      canActivateGoal,
    };
  })
);
