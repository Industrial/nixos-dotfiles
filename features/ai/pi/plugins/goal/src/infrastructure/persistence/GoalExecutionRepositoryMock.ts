import { Effect, Layer, Ref } from "effect";
import {
  GoalExecutionCheckpoint,
  GoalExecutionRepository,
} from "../../domain/repositories/GoalExecutionRepository.js";

export const GoalExecutionRepositoryMock = Layer.effect(
  GoalExecutionRepository,
  Effect.gen(function* () {
    const store = yield* Ref.make<Map<string, GoalExecutionCheckpoint>>(
      new Map()
    );

    const get = (goalId: string) =>
      Effect.gen(function* () {
        const map = yield* Ref.get(store);
        return map.get(goalId) ?? null;
      });

    const upsert = (checkpoint: GoalExecutionCheckpoint) =>
      Effect.gen(function* () {
        yield* Ref.update(store, (m) =>
          new Map(m).set(checkpoint.goalId, checkpoint)
        );
      });

    const deleteCheckpoint = (goalId: string) =>
      Effect.gen(function* () {
        yield* Ref.update(store, (m) => {
          const next = new Map(m);
          next.delete(goalId);
          return next;
        });
      });

    return { get, upsert, delete: deleteCheckpoint };
  })
);
