/**
 * JudgeServiceLive - Production Implementation (OpenRouter / openrouter/free)
 */
import { Effect, Layer } from "effect";
import { JudgeService } from "./JudgeService.js";
import { Goal } from "../models/Goal.js";
import { JudgeResult, JudgeStatus } from "../models/JudgeResult.js";
import {
  openRouterChatCompletion,
  resolveJudgeModel,
  resolveOpenRouterApiKey,
} from "../../infrastructure/llm/openRouterClient.js";

/**
 * Judge prompt template
 */
export function createJudgePrompt(goal: Goal, context: string, turn: number): string {
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
export function parseJudgeResponse(
  response: string,
  goalId: string,
  turn: number
): JudgeResult {
  try {
    const jsonMatch = response.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error("No JSON found in judge response");
    }

    const parsed = JSON.parse(jsonMatch[0]) as {
      status?: string;
      confidence?: number;
      reasoning?: string;
      recommendations?: string[];
    };

    if (!parsed.status || typeof parsed.confidence !== "number") {
      throw new Error("Invalid judge response format");
    }

    const validStatuses = [
      JudgeStatus.COMPLETE,
      JudgeStatus.IN_PROGRESS,
      JudgeStatus.BLOCKED,
      JudgeStatus.FAILED,
    ];
    if (!validStatuses.includes(parsed.status as JudgeStatus)) {
      throw new Error(`Invalid status: ${parsed.status}`);
    }

    return new JudgeResult({
      status: parsed.status as JudgeStatus,
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

class JudgeServiceLiveImpl implements JudgeService {
  evaluateGoalProgress(
    goal: Goal,
    context: string,
    turn: number
  ): Effect.Effect<JudgeResult, Error> {
    return Effect.gen(function* () {
      const apiKey = resolveOpenRouterApiKey();
      if (!apiKey) {
        return yield* Effect.fail(
          new Error(
            "OPENROUTER_API_KEY is required for JudgeServiceLive (set in environment)"
          )
        );
      }

      const prompt = createJudgePrompt(goal, context, turn);
      const model = resolveJudgeModel();

      const response = yield* Effect.tryPromise({
        try: () =>
          openRouterChatCompletion({
            apiKey,
            model,
            prompt,
          }),
        catch: (e) => (e instanceof Error ? e : new Error(String(e))),
      });

      return parseJudgeResponse(response, goal.id, turn);
    });
  }
}

export const JudgeServiceLive = Layer.succeed(
  JudgeService,
  new JudgeServiceLiveImpl()
);
