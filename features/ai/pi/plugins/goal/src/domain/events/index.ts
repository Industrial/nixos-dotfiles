/**
 * Domain events exports
 */
export * from "./DomainEvent.js";
export * from "./GoalCreated.js";
export * from "./GoalPaused.js";
export * from "./GoalResumed.js";
export * from "./GoalCompleted.js";
export * from "./GoalCancelled.js";
export * from "./GoalEvaluationUpdated.js";

// Re-export union type
import type { GoalCreated } from "./GoalCreated.js";
import type { GoalPaused } from "./GoalPaused.js";
import type { GoalResumed } from "./GoalResumed.js";
import type { GoalCompleted } from "./GoalCompleted.js";
import type { GoalCancelled } from "./GoalCancelled.js";
import type { GoalEvaluationUpdated } from "./GoalEvaluationUpdated.js";

/**
 * Union type of all Goal events
 */
export type GoalEvent =
  | GoalCreated
  | GoalPaused
  | GoalResumed
  | GoalCompleted
  | GoalCancelled
  | GoalEvaluationUpdated;
