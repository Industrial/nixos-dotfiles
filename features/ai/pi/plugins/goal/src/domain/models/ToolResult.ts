/**
 * ToolResult - Domain Model
 *
 * Represents the result of executing a Pi Agent tool.
 * Tracks success, output, errors, and execution metadata.
 */
import { Schema as S } from "@effect/schema";

/**
 * Result from tool execution
 *
 * Captures outcome of calling Pi Agent tools (read, write, edit, bash, etc.)
 * Used for tracking tool usage and debugging execution flows.
 */
export class ToolResult extends S.Class<ToolResult>("ToolResult")({
  toolName: S.String.pipe(S.minLength(1)),
  success: S.Boolean,
  output: S.String,
  error: S.optional(S.String),
  executionTimeMs: S.Number.pipe(S.greaterThanOrEqualTo(0)),
  metadata: S.optional(S.Record({ key: S.String, value: S.Unknown })),
  timestamp: S.Number,
}) {
  /**
   * Check if tool execution was successful
   */
  isSuccess(): boolean {
    return this.success;
  }

  /**
   * Check if tool execution failed
   */
  isFailure(): boolean {
    return !this.success;
  }

  /**
   * Check if result has an error
   */
  hasError(): boolean {
    return this.error !== undefined && this.error.length > 0;
  }

  /**
   * Get error message if present
   */
  getErrorMessage(): string | undefined {
    return this.error;
  }
}
