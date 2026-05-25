/**
 * Goal Iteration Repository - In-Memory Mock Implementation
 */
import { Effect, Layer, Ref } from "effect";
import { GoalIteration } from "../../domain/models/GoalIteration.js";
import { GoalIterationRepository } from "../../domain/repositories/GoalIterationRepository.js";

/**
 * In-memory mock implementation of GoalIterationRepository
 */
export const GoalIterationRepositoryMock = Layer.effect(
  GoalIterationRepository,
  Effect.gen(function* () {
    const store = yield* Ref.make<Map<string, GoalIteration>>(new Map());

    const save = (iteration: GoalIteration) =>
      Effect.gen(function* () {
        yield* Ref.update(store, (map) => new Map(map).set(iteration.id, iteration));
        return iteration;
      });

    const findById = (id: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        return map.get(id) ?? null;
      });

    const findByGoalId = (goalId: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const iterations = Array.from(map.values())
          .filter((i) => i.goalId === goalId)
          .sort((a, b) => b.iterationNumber - a.iterationNumber);

        return iterations;
      });

    const findLatest = (goalId: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const iterations = Array.from(map.values())
          .filter((i) => i.goalId === goalId)
          .sort((a, b) => b.iterationNumber - a.iterationNumber);

        return iterations[0] ?? null;
      });

    const update = (iteration: GoalIteration) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        
        if (!map.has(iteration.id)) {
          return yield* Effect.fail(new Error(`Iteration not found: ${iteration.id}`));
        }

        yield* Ref.update(store, (m) => new Map(m).set(iteration.id, iteration));
        return iteration;
      });

    const deleteIteration = (id: string) =>
      Effect.gen(function* () {
        yield* Ref.update(store, (map) => {
          const newMap = new Map(map);
          newMap.delete(id);
          return newMap;
        });
      });

    const deleteByGoalId = (goalId: string) =>
      Effect.gen(function* () {
        yield* Ref.update(store, (map) => {
          const newMap = new Map(map);
          for (const [id, iteration] of newMap.entries()) {
            if (iteration.goalId === goalId) {
              newMap.delete(id);
            }
          }
          return newMap;
        });
      });

    const countByGoalId = (goalId: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const count = Array.from(map.values()).filter((i) => i.goalId === goalId).length;
        return count;
      });

    return {
      save,
      findById,
      findByGoalId,
      findLatest,
      update,
      delete: deleteIteration,
      deleteByGoalId,
      countByGoalId,
    };
  })
);
