/**
 * Shared Effect layers for unit tests.
 */
import { Layer } from "effect";
import { GoalLifecycleServiceLive } from "../domain/services/GoalLifecycleServiceLive.js";
import { GoalRepositoryMock } from "../infrastructure/persistence/GoalRepositoryMock.js";
import { EventStoreMock } from "../infrastructure/persistence/EventStoreMock.js";

/** GoalLifecycleServiceLive with in-memory repo + event store */
export const GoalLifecycleTestLayer = GoalLifecycleServiceLive.pipe(
  Layer.provideMerge(Layer.mergeAll(GoalRepositoryMock, EventStoreMock))
);
