/**
 * Goal Repository - In-Memory Mock Implementation
 */
import { Effect, Layer, Ref } from "effect";
import { Goal } from "../../domain/models/Goal.js";
import { GoalRepository, GoalFilters } from "../../domain/repositories/GoalRepository.js";

/**
 * In-memory mock implementation of GoalRepository
 */
export const GoalRepositoryMock = Layer.effect(
  GoalRepository,
  Effect.gen(function* () {
    const store = yield* Ref.make<Map<string, Goal>>(new Map());

    const save = (goal: Goal) =>
      Effect.gen(function* () {
        yield* Ref.update(store, (map) => new Map(map).set(goal.id, goal));
        return goal;
      });

    const findById = (id: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        return map.get(id) ?? null;
      });

    const findAll = (filters?: GoalFilters) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        let goals = Array.from(map.values());

        if (filters?.status) {
          goals = goals.filter((g) => g.status === filters.status);
        }

        goals.sort((a, b) => b.createdAt - a.createdAt);

        const offset = filters?.offset ?? 0;
        const limit = filters?.limit ?? 100;
        goals = goals.slice(offset, offset + limit);

        return goals;
      });

    const findActive = () =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        const activeGoals = Array.from(map.values())
          .filter((g) => g.status === "active")
          .sort((a, b) => b.createdAt - a.createdAt);

        return activeGoals[0] ?? null;
      });

    const update = (goal: Goal) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        
        if (!map.has(goal.id)) {
          return yield* Effect.fail(new Error(`Goal not found: ${goal.id}`));
        }

        yield* Ref.update(store, (m) => new Map(m).set(goal.id, goal));
        return goal;
      });

    const deleteGoal = (id: string) =>
      Effect.gen(function* () {
        yield* Ref.update(store, (map) => {
          const newMap = new Map(map);
          newMap.delete(id);
          return newMap;
        });
      });

    const exists = (id: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        return map.has(id);
      });

    const count = (filters?: GoalFilters) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        let goals = Array.from(map.values());

        if (filters?.status) {
          goals = goals.filter((g) => g.status === filters.status);
        }

        return goals.length;
      });

    return {
      save,
      findById,
      findAll,
      findActive,
      update,
      delete: deleteGoal,
      exists,
      count,
    };
  })
);
