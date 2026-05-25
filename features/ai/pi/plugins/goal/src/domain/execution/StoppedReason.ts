export type StoppedReason =
  | "judge_complete"
  | "judge_failed"
  | "judge_blocked"
  | "turn_limit"
  | "goal_turn_budget"
  | "none";
