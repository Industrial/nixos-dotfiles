/** Default turns per goal_execute MCP call */
export const DEFAULT_MAX_TURNS_PER_CALL = 1;

/** Maximum turns allowed for a goal across all agents and execute calls */
export const MAX_GOAL_TURNS_LIFETIME = 1000;

/** @deprecated Use MAX_GOAL_TURNS_LIFETIME — per-call request ceiling matches lifetime cap */
export const MAX_TURNS_PER_CALL = MAX_GOAL_TURNS_LIFETIME;

/** Judge confidence required to mark goal achieved */
export const JUDGE_COMPLETE_CONFIDENCE_THRESHOLD = 0.85;

export function normalizeMaxTurnsPerCall(value: number | undefined): number {
  if (value === undefined) {
    return DEFAULT_MAX_TURNS_PER_CALL;
  }
  if (!Number.isFinite(value) || !Number.isInteger(value) || value < 1) {
    throw new Error(
      `maxTurns must be a positive integer (1–${MAX_GOAL_TURNS_LIFETIME}), got: ${value}`
    );
  }
  if (value > MAX_GOAL_TURNS_LIFETIME) {
    throw new Error(
      `maxTurns cannot exceed ${MAX_GOAL_TURNS_LIFETIME} (lifetime turn budget per goal).`
    );
  }
  return value;
}

/**
 * Clamp requested per-call turns to remaining lifetime budget for the goal.
 */
export function computeMaxTurnsThisCall(
  requestedMaxTurns: number | undefined,
  cumulativeTurnAtStart: number
): number {
  const requested = normalizeMaxTurnsPerCall(requestedMaxTurns);
  const remaining = MAX_GOAL_TURNS_LIFETIME - cumulativeTurnAtStart;
  if (remaining <= 0) {
    return 0;
  }
  return Math.min(requested, remaining);
}
