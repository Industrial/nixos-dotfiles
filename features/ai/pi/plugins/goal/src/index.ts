#!/usr/bin/env bun
/**
 * Goal Plugin Entry Point
 *
 * Pi Agent plugin for managing persistent, long-running goals with:
 * - Automated continuation loops
 * - LLM-as-Judge evaluation
 * - Context-aware prompting
 * - Tool execution integration
 */
import { Effect, Layer } from "effect";

// Infrastructure
import { GoalRepositoryMock } from "./infrastructure/persistence/GoalRepositoryMock.js";
import { GoalIterationRepositoryMock } from "./infrastructure/persistence/GoalIterationRepositoryMock.js";
import { EventStoreMock } from "./infrastructure/persistence/EventStoreMock.js";

// Domain Services
import { GoalLifecycleServiceLive } from "./domain/services/GoalLifecycleServiceLive.js";
import { JudgeServiceMock } from "./domain/services/JudgeServiceMock.js";
import { PromptGeneratorServiceMock } from "./domain/services/PromptGeneratorServiceMock.js";
import { ToolExecutionServiceMock } from "./domain/services/ToolExecutionServiceMock.js";

// Application
import {
  GoalApplicationService,
  GoalApplicationServiceLive,
} from "./application/GoalApplicationService.js";

/**
 * Complete application layer with all dependencies
 *
 * Layer composition:
 * - Infrastructure: Mock repositories (in-memory for development)
 * - Domain Services: Lifecycle, Judge, Prompt Generator, Tool Execution
 * - Application: GoalApplicationService facade
 */
const DomainServicesLayer = Layer.mergeAll(
  GoalLifecycleServiceLive.pipe(Layer.provide(GoalRepositoryMock)),
  JudgeServiceMock,
  PromptGeneratorServiceMock,
  ToolExecutionServiceMock
);

const InfrastructureLayer = Layer.mergeAll(
  GoalRepositoryMock,
  GoalIterationRepositoryMock,
  EventStoreMock
);

export const AppLayer = Layer.mergeAll(
  GoalApplicationServiceLive,
  DomainServicesLayer,
  InfrastructureLayer
);

/**
 * CLI Example: Demonstrate goal plugin capabilities
 */
async function runExample() {
  const program = Effect.gen(function* () {
    const service = yield* GoalApplicationService;

    console.log("=== Goal Plugin Demo ===\n");

    // 1. Create a goal
    console.log("1. Creating goal...");
    const goal = yield* service.createGoal({
      objective: "Implement user authentication system",
      context: "Need JWT-based auth with refresh tokens",
    });
    console.log(`✓ Created: ${goal.id}`);
    console.log(`  Objective: ${goal.objective}`);
    console.log(`  Status: ${goal.status}\n`);

    // 2. Get active goal
    console.log("2. Checking active goal...");
    const active = yield* service.getActiveGoal();
    console.log(`✓ Active goal: ${active?.id || "none"}\n`);

    // 3. Execute goal (1 turn demo)
    console.log("3. Executing goal (1 turn)...");
    const execution = yield* service.executeGoal(goal.id, { maxTurns: 1 });
    console.log(`✓ Execution complete`);
    console.log(`  Success: ${execution.success}`);
    console.log(`  Turns: ${execution.context.currentTurn}`);
    console.log(
      `  Judge evaluations: ${execution.context.judgeEvaluations.length}`
    );

    const latestJudge = execution.context.getLatestJudgeEvaluation();
    if (latestJudge) {
      console.log(`  Judge status: ${latestJudge.status}`);
      console.log(`  Confidence: ${latestJudge.confidence.toFixed(2)}\n`);
    }

    // 4. Pause goal
    console.log("4. Pausing goal...");
    const paused = yield* service.pauseGoal(goal.id);
    console.log(`✓ Status: ${paused.status}\n`);

    // 5. Resume goal
    console.log("5. Resuming goal...");
    const resumed = yield* service.resumeGoal(goal.id);
    console.log(`✓ Status: ${resumed.status}\n`);

    // 6. Complete goal
    console.log("6. Completing goal...");
    const completed = yield* service.completeGoal(goal.id);
    console.log(`✓ Status: ${completed.status}`);
    if (completed.completedAt) {
      console.log(
        `  Completed: ${new Date(completed.completedAt).toISOString()}\n`
      );
    }

    // 7. Get statistics
    console.log("7. Getting statistics...");
    yield* service.getGoalStatistics();
    console.log(`✓ Statistics retrieved\n`);

    console.log("=== Demo Complete ===");
  });

  await Effect.runPromise(program.pipe(Effect.provide(AppLayer)));
}

/**
 * Main entry point
 */
async function main() {
  try {
    await runExample();
    process.exit(0);
  } catch (error) {
    console.error("\n✗ Goal plugin failed:");
    console.error(error);
    process.exit(1);
  }
}

// Run if executed directly
if (import.meta.main) {
  main();
}

// Export for use as library
export { GoalApplicationService };
export * from "./domain/models/index.js";
export * from "./domain/services/index.js";
export * from "./application/commands/index.js";
export * from "./application/queries/index.js";
