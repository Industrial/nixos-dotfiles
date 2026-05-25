import { Context, Effect } from "effect";
import type { Goal } from "../models/Goal.js";
import type { ContinuationContext } from "../models/ContinuationContext.js";
import { TurnOutput } from "../models/TurnOutput.js";

export interface AgentTurnInput {
  readonly goal: Goal;
  readonly continuation: ContinuationContext;
  readonly turn: number;
}

export class AgentExecutionPort extends Context.Tag("@goal/AgentExecutionPort")<
  AgentExecutionPort,
  {
    readonly runTurn: (
      input: AgentTurnInput
    ) => Effect.Effect<TurnOutput, Error>;
  }
>() {}
