/**
 * Execution Domain Errors
 *
 * Specific error types for goal execution failures.
 */

/**
 * Thrown when execution reaches maximum turn limit
 */
export class TurnLimitExceededError extends Error {
  constructor(
    public readonly goalId: string,
    public readonly currentTurn: number,
    public readonly maxTurns: number
  ) {
    super(
      `Turn limit exceeded for goal ${goalId}: ${currentTurn}/${maxTurns} turns`
    );
    this.name = "TurnLimitExceededError";
  }
}

/**
 * Thrown when execution encounters an unrecoverable error
 */
export class ExecutionFailedError extends Error {
  constructor(
    public readonly goalId: string,
    cause: Error,
    public readonly turn: number
  ) {
    super(
      `Execution failed for goal ${goalId} at turn ${turn}: ${cause.message}`
    );
    this.name = "ExecutionFailedError";
    this.cause = cause;
  }
}

/**
 * Thrown when retry limit is exceeded
 */
export class RetryLimitExceededError extends Error {
  constructor(
    public readonly operation: string,
    public readonly attempts: number,
    public readonly lastError: Error
  ) {
    super(
      `Retry limit exceeded for ${operation} after ${attempts} attempts: ${lastError.message}`
    );
    this.name = "RetryLimitExceededError";
    this.cause = lastError;
  }
}

/**
 * Thrown when execution context is in invalid state
 */
export class InvalidExecutionStateError extends Error {
  constructor(
    public readonly reason: string
  ) {
    super(`Invalid execution state: ${reason}`);
    this.name = "InvalidExecutionStateError";
  }
}
