/**
 * SQLite integration test layer (judge mock — no OpenRouter in CI).
 */
import { Layer } from "effect";
import { DatabaseLayer } from "../infrastructure/database/DatabaseLayer.js";
import { GoalRepositoryLive } from "../infrastructure/persistence/GoalRepositoryLive.js";
import { GoalIterationRepositoryLive } from "../infrastructure/persistence/GoalIterationRepositoryLive.js";
import { GoalExecutionRepositoryLive } from "../infrastructure/persistence/GoalExecutionRepositoryLive.js";
import { EventStoreLive } from "../infrastructure/persistence/EventStoreLive.js";
import { AgentTurnExecutorLive } from "../infrastructure/execution/AgentTurnExecutorLive.js";
import { GoalApplicationServiceLive } from "../application/GoalApplicationService.js";
import { GoalLifecycleServiceLive } from "../domain/services/GoalLifecycleServiceLive.js";
import { JudgeServiceMock } from "../domain/services/JudgeServiceMock.js";
import { PromptGeneratorServiceMock } from "../domain/services/PromptGeneratorServiceMock.js";
import { ToolExecutionServiceMock } from "../domain/services/ToolExecutionServiceMock.js";

const InfrastructureIntegrationLayer = Layer.mergeAll(
  GoalRepositoryLive,
  GoalIterationRepositoryLive,
  GoalExecutionRepositoryLive,
  EventStoreLive
);

const CoreIntegrationLayer = Layer.mergeAll(
  GoalApplicationServiceLive,
  GoalLifecycleServiceLive,
  JudgeServiceMock,
  PromptGeneratorServiceMock,
  ToolExecutionServiceMock
).pipe(Layer.provideMerge(AgentTurnExecutorLive));

export const AppLayerIntegration = CoreIntegrationLayer.pipe(
  Layer.provideMerge(InfrastructureIntegrationLayer),
  Layer.provide(DatabaseLayer)
);
