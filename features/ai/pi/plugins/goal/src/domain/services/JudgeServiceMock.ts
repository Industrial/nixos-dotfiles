/**
 * JudgeServiceMock - Test Implementation
 *
 * Mock implementation of JudgeService for testing.
 * Returns predictable results based on simple heuristics.
 */
import { Effect, Layer } from "effect";
import { JudgeService } from "./JudgeService.js";
import { Goal } from "../models/Goal.js";
import { JudgeResult, JudgeStatus } from "../models/JudgeResult.js";

/**
 * Mock judge service implementation
 *
 * Uses simple heuristics to determine status:
 * - Contains "completed" or "successfully" → COMPLETE
 * - Contains "blocked" or "missing" → BLOCKED
 * - Contains "failed" or "flawed" → FAILED
 * - Otherwise → IN_PROGRESS
 */
class JudgeServiceMockImpl implements JudgeService {
  evaluateGoalProgress(
    goal: Goal,
    context: string,
    turn: number
  ): Effect.Effect<JudgeResult, Error> {
    return Effect.sync(() => {
      const lowerContext = context.toLowerCase();

      // Determine status based on keywords
      let status: JudgeStatus;
      let confidence: number;
      let reasoning: string;
      let recommendations: string[];

      if (
        lowerContext.includes("has been") ||
        lowerContext.includes("successfully")
      ) {
        status = JudgeStatus.COMPLETE;
        confidence = 0.95;
        reasoning = "Goal objective appears to be fully achieved based on context";
        recommendations = ["Verify final output", "Document results"];
      } else if (
        lowerContext.includes("blocked") ||
        lowerContext.includes("missing")
      ) {
        status = JudgeStatus.BLOCKED;
        confidence = 0.85;
        reasoning = "Progress is blocked by missing information or dependencies";
        recommendations = ["Request clarification", "Gather required information"];
      } else if (
        lowerContext.includes("failed") ||
        lowerContext.includes("flawed") ||
        lowerContext.includes("impossible")
      ) {
        status = JudgeStatus.FAILED;
        confidence = 0.9;
        reasoning = "Current approach is not viable";
        recommendations = ["Restart with different strategy", "Reconsider requirements"];
      } else {
        status = JudgeStatus.IN_PROGRESS;
        confidence = 0.7;
        reasoning = "Goal is actively being worked on but not yet complete";
        recommendations = ["Continue with current approach", "Monitor progress"];
      }

      return new JudgeResult({
        status,
        confidence,
        reasoning,
        recommendations,
        goalId: goal.id,
        turn,
        timestamp: Date.now(),
      });
    });
  }
}

/**
 * JudgeServiceMock Layer
 */
export const JudgeServiceMock = Layer.succeed(
  JudgeService,
  new JudgeServiceMockImpl()
);
