/**
 * JudgeService - Domain Service Interface
 *
 * LLM-as-Judge evaluation service for assessing goal progress.
 * Uses separate LLM to maintain objectivity in evaluation.
 */
import { Context, Effect } from "effect";
import { Goal } from "../models/Goal.js";
import { JudgeResult } from "../models/JudgeResult.js";

/**
 * Service for evaluating goal progress using LLM-as-Judge pattern
 *
 * The judge model evaluates goal progress independently to prevent bias.
 * Target: 85%+ human agreement rate (industry standard from research).
 */
export interface JudgeService {
  /**
   * Evaluate goal progress
   *
   * @param goal - Goal being evaluated
   * @param context - Current execution context/history
   * @param turn - Current turn number
   * @returns Judge evaluation result
   */
  evaluateGoalProgress(
    goal: Goal,
    context: string,
    turn: number
  ): Effect.Effect<JudgeResult, Error>;
}

/**
 * JudgeService tag for dependency injection
 */
export const JudgeService = Context.GenericTag<JudgeService>(
  "@goal/JudgeService"
);
