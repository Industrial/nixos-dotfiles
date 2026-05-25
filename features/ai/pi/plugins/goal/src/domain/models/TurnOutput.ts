import { Schema as S } from "@effect/schema";
import { ToolResult } from "./ToolResult.js";

export class TurnOutput extends S.Class<TurnOutput>("TurnOutput")({
  text: S.String,
  toolResults: S.Array(ToolResult),
  /** Prompt for the hosting Pi agent to act on when execution is delegated */
  nextPrompt: S.optional(S.String),
  delegated: S.Boolean,
}) {}
