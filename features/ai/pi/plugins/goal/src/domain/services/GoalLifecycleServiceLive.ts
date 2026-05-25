/**
 * Goal Lifecycle Service - Live Implementation
 */
import { Effect, Layer } from "effect";
import { Goal, createGoal as makeGoal } from "../models/Goal.js";
import { GoalRepository } from "../repositories/GoalRepository.js";
import { GoalLifecycleService } from "./GoalLifecycleService.js";

/**
 * Live implementation of GoalLifecycleService
 */
export const GoalLifecycleServiceLive = Layer.effect(
  GoalLifecycleService,
  Effect.gen(function* () {
    const goalRepo = yield* GoalRepository;

    const createGoal = (objective: string, context?: string) =>
      Effect.gen(function* () {
        // Business rule: Only one active goal at a time
        const activeGoal = yield* goalRepo.findActive();
        if (activeGoal) {
          return yield* Effect.fail(
            new Error(
              `Cannot create new goal: Active goal already exists (${activeGoal.id}). Please pause or complete it first.`
            )
          );
        }

        const goal = makeGoal(objective, context);
        return yield* goalRepo.save(goal);
      });

    const pauseGoal = (goalId: string) =>
      Effect.gen(function* () {
        const goal = yield* goalRepo.findById(goalId);
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${goalId}`));
        }

        const pausedGoal = yield* goal.pause();
        return yield* goalRepo.update(pausedGoal);
      });

    const resumeGoal = (goalId: string) =>
      Effect.gen(function* () {
        // Business rule: Only one active goal at a time
        const activeGoal = yield* goalRepo.findActive();
        if (activeGoal && activeGoal.id !== goalId) {
          return yield* Effect.fail(
            new Error(
              `Cannot resume goal: Another goal is already active (${activeGoal.id}). Please pause it first.`
            )
          );
        }

        const goal = yield* goalRepo.findById(goalId);
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${goalId}`));
        }

        const resumedGoal = yield* goal.resume();
        return yield* goalRepo.update(resumedGoal);
      });

    const completeGoal = (goalId: string) =>
      Effect.gen(function* () {
        const goal = yield* goalRepo.findById(goalId);
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${goalId}`));
        }

        const completedGoal = yield* goal.complete();
        return yield* goalRepo.update(completedGoal);
      });

    const cancelGoal = (goalId: string) =>
      Effect.gen(function* () {
        const goal = yield* goalRepo.findById(goalId);
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${goalId}`));
        }

        const cancelledGoal = yield* goal.cancel();
        return yield* goalRepo.update(cancelledGoal);
      });

    const canActivateGoal = () =>
      Effect.gen(function* () {
        const activeGoal = yield* goalRepo.findActive();
        return activeGoal === null;
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
