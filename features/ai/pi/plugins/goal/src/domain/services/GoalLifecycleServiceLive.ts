/**
 * Goal Lifecycle Service - Live Implementation
 */
import { Effect, Layer } from "effect";
import { createGoal as makeGoal } from "../models/Goal.js";
import { GoalRepository } from "../repositories/GoalRepository.js";
import { GoalLifecycleService } from "./GoalLifecycleService.js";
import { appendGoalEvent } from "./goalEventAppend.js";
import { GoalCreated, GoalCreatedPayload } from "../events/GoalCreated.js";
import { GoalPaused } from "../events/GoalPaused.js";
import { GoalResumed } from "../events/GoalResumed.js";
import { GoalCompleted } from "../events/GoalCompleted.js";
import { GoalCancelled } from "../events/GoalCancelled.js";

/**
 * Live implementation of GoalLifecycleService
 */
export const GoalLifecycleServiceLive = Layer.effect(
  GoalLifecycleService,
  Effect.gen(function* () {
    const goalRepo = yield* GoalRepository;

    const createGoal = (objective: string, context?: string) =>
      Effect.gen(function* () {
        const activeGoal = yield* goalRepo.findActive();
        if (activeGoal) {
          return yield* Effect.fail(
            new Error(
              `Cannot create new goal: Active goal already exists (${activeGoal.id}). Please pause or complete it first.`
            )
          );
        }

        const goal = makeGoal(objective, context);
        const saved = yield* goalRepo.save(goal);

        yield* appendGoalEvent(saved.id, (version) =>
          GoalCreated.create(
            saved.id,
            version,
            new GoalCreatedPayload({
              objective: saved.objective,
              context: saved.context,
            })
          )
        );

        return saved;
      });

    const pauseGoal = (goalId: string) =>
      Effect.gen(function* () {
        const goal = yield* goalRepo.findById(goalId);
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${goalId}`));
        }

        const pausedGoal = yield* goal.pause();
        const updated = yield* goalRepo.update(pausedGoal);

        yield* appendGoalEvent(goalId, (version) =>
          GoalPaused.create(goalId, version)
        );

        return updated;
      });

    const resumeGoal = (goalId: string) =>
      Effect.gen(function* () {
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
        const updated = yield* goalRepo.update(resumedGoal);

        yield* appendGoalEvent(goalId, (version) =>
          GoalResumed.create(goalId, version)
        );

        return updated;
      });

    const completeGoal = (goalId: string) =>
      Effect.gen(function* () {
        const goal = yield* goalRepo.findById(goalId);
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${goalId}`));
        }

        const completedGoal = yield* goal.complete();
        const updated = yield* goalRepo.update(completedGoal);

        yield* appendGoalEvent(goalId, (version) =>
          GoalCompleted.create(goalId, version)
        );

        return updated;
      });

    const cancelGoal = (goalId: string) =>
      Effect.gen(function* () {
        const goal = yield* goalRepo.findById(goalId);
        if (!goal) {
          return yield* Effect.fail(new Error(`Goal not found: ${goalId}`));
        }

        const cancelledGoal = yield* goal.cancel();
        const updated = yield* goalRepo.update(cancelledGoal);

        yield* appendGoalEvent(goalId, (version) =>
          GoalCancelled.create(goalId, version)
        );

        return updated;
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
