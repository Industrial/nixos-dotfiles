/**
 * Prepares one execution turn: builds prompts for the hosting Pi agent.
 */
import { Effect, Layer } from "effect";
import { AgentExecutionPort } from "../../domain/ports/AgentExecutionPort.js";
import { TurnOutput } from "../../domain/models/TurnOutput.js";
import { PromptGeneratorService } from "../../domain/services/PromptGeneratorService.js";

export const AgentTurnExecutorLive = Layer.effect(
  AgentExecutionPort,
  Effect.succeed({
    runTurn: (input) =>
      Effect.gen(function* () {
        const prompts = yield* PromptGeneratorService;
        const prompt =
          input.turn <= 1
            ? yield* prompts.generateInitialPrompt(input.goal)
            : yield* prompts.generateContinuationPrompt(input.continuation);

        const text = [
          `Goal turn ${input.turn} (plugin prepared — perform work in Pi session).`,
          "",
          prompt,
        ].join("\n");

        return new TurnOutput({
          text,
          toolResults: [],
          nextPrompt: prompt,
          delegated: true,
        });
      }),
  })
);
