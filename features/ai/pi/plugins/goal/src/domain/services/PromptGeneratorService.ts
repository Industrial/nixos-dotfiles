/**
 * PromptGeneratorService - Domain Service Interface
 *
 * Service for generating context-aware prompts for goal execution.
 * Supports initial prompts, continuation prompts, recovery prompts, and completion prompts.
 */
import { Context, Effect } from "effect";
import { Goal } from "../models/Goal.js";
import { ContinuationContext } from "../models/ContinuationContext.js";

/**
 * Service for generating execution prompts with context awareness
 *
 * Supports auto-continuation by generating prompts that incorporate:
 * - Goal objective and context
 * - Previous turn outputs
 * - Judge feedback and recommendations
 * - Error recovery strategies
 */
export interface PromptGeneratorService {
  /**
   * Generate initial prompt for goal
   *
   * @param goal - Goal to generate prompt for
   * @returns Initial execution prompt
   */
  generateInitialPrompt(goal: Goal): Effect.Effect<string, Error>;

  /**
   * Generate continuation prompt with history
   *
   * @param context - Continuation context with history
   * @returns Context-aware continuation prompt
   */
  generateContinuationPrompt(
    context: ContinuationContext
  ): Effect.Effect<string, Error>;

  /**
   * Generate recovery prompt for blocked goal
   *
   * @param context - Continuation context with blocker information
   * @returns Recovery-focused prompt
   */
  generateRecoveryPrompt(
    context: ContinuationContext
  ): Effect.Effect<string, Error>;

  /**
   * Generate completion verification prompt
   *
   * @param context - Continuation context for completed goal
   * @returns Completion verification prompt
   */
  generateCompletionPrompt(
    context: ContinuationContext
  ): Effect.Effect<string, Error>;
}

/**
 * PromptGeneratorService tag for dependency injection
 */
export const PromptGeneratorService = Context.GenericTag<PromptGeneratorService>(
  "@goal/PromptGeneratorService"
);
