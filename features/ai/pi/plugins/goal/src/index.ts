/**
 * Goal Plugin Entry Point
 * 
 * Wires together all layers following DDD architecture:
 * - Domain: Models, repositories (interfaces), domain services
 * - Application: Commands, queries, application services
 * - Infrastructure: Repository implementations, database
 */
import { Effect, Layer } from "effect";
import { SqlClient } from "@effect/sql";

// Infrastructure
import { DatabaseLayer } from "./infrastructure/database/index.js";
import {
  GoalRepositoryLive,
  GoalRepositoryMock,
  GoalIterationRepositoryLive,
  GoalIterationRepositoryMock,
} from "./infrastructure/persistence/index.js";

// Domain
import { GoalLifecycleServiceLive } from "./domain/services/GoalLifecycleServiceLive.js";

// Application
import { GoalApplicationService, GoalApplicationServiceLive } from "./application/services/index.js";
import {
  CreateGoalCommand,
  PauseGoalCommand,
  ResumeGoalCommand,
  CompleteGoalCommand,
} from "./application/commands/index.js";
import {
  GetGoalQuery,
  ListGoalsQuery,
} from "./application/queries/index.js";

/**
 * Main application layer combining all dependencies
 * Uses live SQLite implementations
 */
const RepositoryLayer = Layer.merge(
  GoalRepositoryLive,
  GoalIterationRepositoryLive
).pipe(Layer.provide(DatabaseLayer));

const DomainLayer = GoalLifecycleServiceLive.pipe(
  Layer.provide(RepositoryLayer)
);

export const AppLayer = GoalApplicationServiceLive.pipe(
  Layer.provide(DomainLayer)
);

/**
 * Test/Mock layer using in-memory implementations
 */
export const AppLayerMock = GoalApplicationServiceLive.pipe(
  Layer.provide(GoalLifecycleServiceLive),
  Layer.provide(GoalRepositoryMock),
  Layer.provide(GoalIterationRepositoryMock)
);

/**
 * Example: Create and manage goals
 */
const exampleProgram = Effect.gen(function* () {
  const appService = yield* GoalApplicationService;

  console.log("=== Goal Plugin Example ===\n");

  // Create a new goal
  console.log("1. Creating a new goal...");
  const goal = yield* appService.createGoal(
    new CreateGoalCommand({
      objective: "Refactor authentication system to use JWT tokens",
      context: "Current system uses sessions. Need to migrate to stateless JWT for better scalability.",
    })
  );
  console.log(`✓ Created goal: ${goal.id}`);
  console.log(`  Objective: ${goal.objective}`);
  console.log(`  Status: ${goal.status}\n`);

  // Get active goal
  console.log("2. Getting active goal...");
  const activeGoal = yield* appService.getActiveGoal();
  if (activeGoal) {
    console.log(`✓ Active goal: ${activeGoal.id}`);
    console.log(`  Objective: ${activeGoal.objective}\n`);
  }

  // Pause the goal
  console.log("3. Pausing the goal...");
  const pausedGoal = yield* appService.pauseGoal(
    new PauseGoalCommand({ goalId: goal.id })
  );
  console.log(`✓ Paused goal: ${pausedGoal.id}`);
  console.log(`  Status: ${pausedGoal.status}\n`);

  // Resume the goal
  console.log("4. Resuming the goal...");
  const resumedGoal = yield* appService.resumeGoal(
    new ResumeGoalCommand({ goalId: goal.id })
  );
  console.log(`✓ Resumed goal: ${resumedGoal.id}`);
  console.log(`  Status: ${resumedGoal.status}\n`);

  // Complete the goal
  console.log("5. Completing the goal...");
  const completedGoal = yield* appService.completeGoal(
    new CompleteGoalCommand({ goalId: goal.id })
  );
  console.log(`✓ Completed goal: ${completedGoal.id}`);
  console.log(`  Status: ${completedGoal.status}`);
  console.log(`  Completed at: ${new Date(completedGoal.completedAt!).toISOString()}\n`);

  // List all goals
  console.log("6. Listing all goals...");
  const goals = yield* appService.listGoals(new ListGoalsQuery({}));
  console.log(`✓ Total goals: ${goals.length}`);
  for (const g of goals) {
    console.log(`  - ${g.id}: ${g.objective.substring(0, 50)}... [${g.status}]`);
  }

  console.log("\n=== Example completed successfully ===");
});

/**
 * Main entry point
 */
const main = Effect.gen(function* () {
  yield* exampleProgram;
});

/**
 * Run with full application layer
 */
const runnable = main.pipe(Effect.provide(AppLayer));

// Execute
Effect.runPromise(runnable)
  .then(() => {
    console.log("\n✓ Goal plugin example completed");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n✗ Goal plugin example failed:");
    console.error(error);
    process.exit(1);
  });
