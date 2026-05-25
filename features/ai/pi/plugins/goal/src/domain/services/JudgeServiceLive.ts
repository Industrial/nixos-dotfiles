/**
 * JudgeServiceLive - Production Implementation
 *
 * Real implementation of JudgeService using Pi's local model system.
 * Integrates with Pi Agent's model interface for LLM evaluation.
 */
import { Effect, Layer } from "effect";
import { JudgeService } from "./JudgeService.js";
import { Goal } from "../models/Goal.js";
import { JudgeResult, JudgeStatus } from "../models/JudgeResult.js";

/**
 * Judge prompt template
 *
 * Structured prompt for LLM-as-Judge evaluation following best practices:
 * - Clear role definition
 * - Explicit evaluation criteria
 * - Structured output format
 * - Confidence scoring
 */
function createJudgePrompt(goal: Goal, context: string, turn: number): string {
  return `You are an objective judge evaluating goal progress. Your role is to assess whether a goal has been achieved, is in progress, is blocked, or has failed.

GOAL OBJECTIVE:
${goal.objective}

${goal.context ? `GOAL CONTEXT:\n${goal.context}\n\n` : ""}CURRENT TURN: ${turn}

EXECUTION CONTEXT:
${context || "No execution context provided yet"}

EVALUATION CRITERIA:
- COMPLETE: Goal objective is fully achieved, no further work needed
- IN_PROGRESS: Making progress toward goal, should continue
- BLOCKED: Progress is stopped by missing information or dependencies
- FAILED: Current approach is not viable, cannot achieve goal

Provide your evaluation in the following JSON format:
{
  "status": "COMPLETE" | "IN_PROGRESS" | "BLOCKED" | "FAILED",
  "confidence": 0.0-1.0,
  "reasoning": "Brief explanation of your assessment",
  "recommendations": ["Actionable next steps or improvements"]
}

Be objective and precise. Base your judgment only on the evidence provided.`;
}

/**
 * Parse judge response from LLM
 */
function _parseJudgeResponse(
  response: string,
  goalId: string,
  turn: number
): JudgeResult {
  try {
    // Extract JSON from response (may have markdown code blocks)
    const jsonMatch = response.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error("No JSON found in judge response");
    }

    const parsed = JSON.parse(jsonMatch[0]);

    // Validate required fields
    if (!parsed.status || typeof parsed.confidence !== "number") {
      throw new Error("Invalid judge response format");
    }

    // Ensure status is valid
    const validStatuses = [
      JudgeStatus.COMPLETE,
      JudgeStatus.IN_PROGRESS,
      JudgeStatus.BLOCKED,
      JudgeStatus.FAILED,
    ];
    if (!validStatuses.includes(parsed.status)) {
      throw new Error(`Invalid status: ${parsed.status}`);
    }

    return new JudgeResult({
      status: parsed.status,
      confidence: Math.max(0, Math.min(1, parsed.confidence)),
      reasoning: parsed.reasoning || "No reasoning provided",
      recommendations: Array.isArray(parsed.recommendations)
        ? parsed.recommendations
        : [],
      goalId,
      turn,
      timestamp: Date.now(),
    });
  } catch (error) {
    // Fallback to conservative assessment on parse error
    return new JudgeResult({
      status: JudgeStatus.IN_PROGRESS,
      confidence: 0.5,
      reasoning: `Judge response parse error: ${error instanceof Error ? error.message : String(error)}`,
      recommendations: ["Review judge model output format"],
      goalId,
      turn,
      timestamp: Date.now(),
    });
  }
}

/**
 * Production judge service implementation
 *
 * TODO: Integrate with Pi Agent's model system
 * - Access Pi's model registry (~/.pi/agent/models.json)
 * - Use Pi's ModelService for vendor-agnostic LLM calls
 * - Support Ollama, vLLM, llama.cpp backends
 * - Add retry logic with exponential backoff
 * - Add timeout handling
 * - Add streaming support for large contexts
 */
class JudgeServiceLiveImpl implements JudgeService {
  evaluateGoalProgress(
    goal: Goal,
    context: string,
    turn: number
  ): Effect.Effect<JudgeResult, Error> {
    return Effect.gen(function* () {
      const _prompt = createJudgePrompt(goal, context, turn);

      // TODO: Replace with Pi ModelService integration
      // const modelService = yield* ModelService;
      // const response = yield* modelService.generate({
      //   model: "judge-model", // Configurable judge model name
      //   prompt,
      //   temperature: 0.3, // Low temperature for consistent evaluation
      //   maxTokens: 500,
      // });

      // Placeholder: For now, return a basic result
      // This will be replaced with actual Pi model integration
      yield* Effect.logWarning(
        "JudgeServiceLive: Pi model integration not yet implemented, using placeholder"
      );

      // Placeholder implementation
      return new JudgeResult({
        status: JudgeStatus.IN_PROGRESS,
        confidence: 0.7,
        reasoning:
          "Placeholder: Judge model integration with Pi Agent pending",
        recommendations: ["Integrate with Pi ModelService", "Configure judge model"],
        goalId: goal.id,
        turn,
        timestamp: Date.now(),
      });

      // When Pi integration is ready, uncomment:
      // return parseJudgeResponse(response, goal.id, turn);
    });
  }
}

/**
 * JudgeServiceLive Layer
 */
export const JudgeServiceLive = Layer.succeed(
  JudgeService,
  new JudgeServiceLiveImpl()
);
