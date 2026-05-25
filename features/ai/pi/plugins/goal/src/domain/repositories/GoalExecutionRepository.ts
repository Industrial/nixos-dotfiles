import { Context, Effect } from "effect";
import type { StoppedReason } from "../execution/StoppedReason.js";

export type GoalExecutionStatus = "running" | "blocked" | "completed" | "failed";

export interface GoalExecutionCheckpoint {
  readonly goalId: string;
  readonly cumulativeTurn: number;
  readonly status: GoalExecutionStatus;
  readonly lastJudgeJson: string | null;
  readonly updatedAt: number;
}

export class GoalExecutionRepository extends Context.Tag(
  "@goal/GoalExecutionRepository"
)<
  GoalExecutionRepository,
  {
    readonly get: (
      goalId: string
    ) => Effect.Effect<GoalExecutionCheckpoint | null, Error>;
    readonly upsert: (
      checkpoint: GoalExecutionCheckpoint
    ) => Effect.Effect<void, Error>;
    readonly delete: (goalId: string) => Effect.Effect<void, Error>;
  }
>() {}

export function initialCheckpoint(goalId: string): GoalExecutionCheckpoint {
  return {
    goalId,
    cumulativeTurn: 0,
    status: "running",
    lastJudgeJson: null,
    updatedAt: Date.now(),
  };
}

export function statusFromStoppedReason(
  reason: StoppedReason
): GoalExecutionStatus {
  switch (reason) {
    case "judge_complete":
      return "completed";
    case "judge_failed":
      return "failed";
    case "judge_blocked":
      return "blocked";
    case "goal_turn_budget":
      return "failed";
    default:
      return "running";
  }
}
