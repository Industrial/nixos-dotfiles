/**
 * PromptGeneratorServiceMock - Test Implementation
 *
 * Mock implementation of PromptGeneratorService for testing.
 * Generates simple template-based prompts.
 */
import { Effect, Layer } from "effect";
import { PromptGeneratorService } from "./PromptGeneratorService.js";
import { Goal } from "../models/Goal.js";
import { ContinuationContext } from "../models/ContinuationContext.js";

/**
 * Mock prompt generator implementation
 *
 * Uses simple templates for predictable test behavior.
 */
class PromptGeneratorServiceMockImpl implements PromptGeneratorService {
  generateInitialPrompt(goal: Goal): Effect.Effect<string, Error> {
    return Effect.sync(() => {
      let prompt = `Goal: ${goal.objective}\n\n`;

      if (goal.context) {
        prompt += `Context: ${goal.context}\n\n`;
      }

      prompt += "Please work on achieving this goal.";

      return prompt;
    });
  }

  generateContinuationPrompt(
    context: ContinuationContext
  ): Effect.Effect<string, Error> {
    return Effect.sync(() => {
      let prompt = `Goal: ${context.goal.objective}\n\n`;

      // Include recent output history
      const recentOutputs = context.getOutputHistory(3);
      if (recentOutputs.length > 0) {
        prompt += "Previous work:\n";
        recentOutputs.forEach((output, index) => {
          prompt += `${index + 1}. ${output}\n`;
        });
        prompt += "\n";
      }

      // Include latest judge feedback
      const latestJudge = context.getLatestJudgeEvaluation();
      if (latestJudge && latestJudge.recommendations.length > 0) {
        prompt += "Recommendations:\n";
        latestJudge.recommendations.forEach((rec) => {
          prompt += `- ${rec}\n`;
        });
        prompt += "\n";
      }

      prompt += "Please continue working on this goal.";

      return prompt;
    });
  }

  generateRecoveryPrompt(
    context: ContinuationContext
  ): Effect.Effect<string, Error> {
    return Effect.sync(() => {
      let prompt = `Goal: ${context.goal.objective}\n\n`;

      const latestJudge = context.getLatestJudgeEvaluation();
      if (latestJudge) {
        prompt += `Status: ${latestJudge.status}\n`;
        prompt += `Issue: ${latestJudge.reasoning}\n\n`;

        if (latestJudge.recommendations.length > 0) {
          prompt += "Suggested actions:\n";
          latestJudge.recommendations.forEach((rec) => {
            prompt += `- ${rec}\n`;
          });
          prompt += "\n";
        }
      }

      prompt += "The goal is currently blocked. Please address the blockers and try again.";

      return prompt;
    });
  }

  generateCompletionPrompt(
    context: ContinuationContext
  ): Effect.Effect<string, Error> {
    return Effect.sync(() => {
      let prompt = `Goal: ${context.goal.objective}\n\n`;

      const latestOutput = context.getLatestOutput();
      if (latestOutput) {
        prompt += `Latest work: ${latestOutput}\n\n`;
      }

      prompt += "Please verify that this goal is complete and provide final summary.";

      return prompt;
    });
  }
}

/**
 * PromptGeneratorServiceMock Layer
 */
export const PromptGeneratorServiceMock = Layer.succeed(
  PromptGeneratorService,
  new PromptGeneratorServiceMockImpl()
);
