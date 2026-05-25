/**
 * Goal MCP Tools
 */
import { Effect } from "effect";
import { GoalApplicationService, AppLayerLive } from "../index.js";

export interface GoalTool {
  name: string;
  description: string;
  inputSchema: {
    type: "object";
    properties: Record<string, unknown>;
    required?: string[];
  };
  handler: (args: Record<string, unknown>) => Promise<unknown>;
}

async function runWithAppLayer<T, E, R>(
  program: Effect.Effect<T, E, R>
): Promise<T> {
  return Effect.runPromise(
    program.pipe(Effect.provide(AppLayerLive)) as Effect.Effect<T, never, never>
  );
}

function formatExecutionResult(result: {
  success: boolean;
  goalAchieved: boolean;
  phaseComplete: boolean;
  turnLimitReached: boolean;
  stoppedReason?: string;
  turnsThisCall: number;
  cumulativeTurn: number;
  nextPrompt?: string;
  goalId: string;
  context: {
    getLatestJudgeEvaluation: () =>
      | {
          status: string;
          confidence: number;
          reasoning: string;
          recommendations: readonly string[];
        }
      | undefined;
    toolResults: readonly unknown[];
    judgeEvaluations: readonly unknown[];
  };
}) {
  const latestJudge = result.context.getLatestJudgeEvaluation();
  return {
    success: result.success,
    goalAchieved: result.goalAchieved,
    execution: {
      goalId: result.goalId,
      turnsThisCall: result.turnsThisCall,
      cumulativeTurn: result.cumulativeTurn,
      phaseComplete: result.phaseComplete,
      /** @deprecated use phaseComplete */
      isComplete: result.phaseComplete,
      turnLimitReached: result.turnLimitReached,
      stoppedReason: result.stoppedReason ?? "none",
      toolResultsCount: result.context.toolResults.length,
      judgeEvaluationsCount: result.context.judgeEvaluations.length,
      nextPrompt: result.nextPrompt ?? null,
      judge: latestJudge
        ? {
            status: latestJudge.status,
            confidence: latestJudge.confidence,
            reasoning: latestJudge.reasoning,
            recommendations: latestJudge.recommendations,
          }
        : null,
    },
  };
}

export const goalTools: GoalTool[] = [
  {
    name: "goal_create",
    description:
      "Create a new goal with an objective and optional context. Only one active goal is allowed at a time.",
    inputSchema: {
      type: "object",
      properties: {
        objective: { type: "string", description: "The goal objective" },
        context: { type: "string", description: "Optional context" },
      },
      required: ["objective"],
    },
    handler: async (args) => {
      const goal = await runWithAppLayer(
        Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.createGoal({
            objective: args.objective as string,
            context: args.context as string | undefined,
          });
        })
      );
      return {
        success: true,
        goal: {
          id: goal.id,
          objective: goal.objective,
          status: goal.status,
          createdAt: new Date(goal.createdAt).toISOString(),
        },
      };
    },
  },

  {
    name: "goal_get",
    description: "Get a goal by ID.",
    inputSchema: {
      type: "object",
      properties: {
        goalId: { type: "string", description: "Goal ID" },
      },
      required: ["goalId"],
    },
    handler: async (args) => {
      const goal = await runWithAppLayer(
        Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.getGoal(args.goalId as string);
        })
      );
      return { success: true, goal };
    },
  },

  {
    name: "goal_list",
    description: "List goals with optional status filter.",
    inputSchema: {
      type: "object",
      properties: {
        status: {
          type: "string",
          enum: ["active", "paused", "completed", "cancelled", "draft"],
        },
        limit: { type: "number" },
        offset: { type: "number" },
      },
    },
    handler: async (args) => {
      const goals = await runWithAppLayer(
        Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.listGoals({
            status: args.status as
              | "active"
              | "paused"
              | "completed"
              | "cancelled"
              | "draft"
              | undefined,
            limit: args.limit as number | undefined,
            offset: args.offset as number | undefined,
          });
        })
      );
      return { success: true, goals };
    },
  },

  {
    name: "goal_status",
    description: "Get the currently active goal, if any.",
    inputSchema: { type: "object", properties: {} },
    handler: async () => {
      const goal = await runWithAppLayer(
        Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.getActiveGoal();
        })
      );
      if (!goal) return { success: true, activeGoal: null };
      return {
        success: true,
        activeGoal: {
          id: goal.id,
          objective: goal.objective,
          status: goal.status,
          createdAt: new Date(goal.createdAt).toISOString(),
          context: goal.context,
        },
      };
    },
  },

  {
    name: "goal_execution_status",
    description:
      "Get persisted execution checkpoint and latest iteration for a goal.",
    inputSchema: {
      type: "object",
      properties: {
        goalId: { type: "string", description: "Goal ID" },
      },
      required: ["goalId"],
    },
    handler: async (args) => {
      const status = await runWithAppLayer(
        Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.getExecutionStatus(args.goalId as string);
        })
      );
      return { success: true, ...status };
    },
  },

  {
    name: "goal_execute",
    description:
      "Run up to maxTurns execution turns for an active goal (default 1, max 1000 per call). Total turns across all agents and calls cannot exceed 1000 per goal. Each turn runs pi-subagents (or returns nextPrompt when disabled). Call repeatedly until goalAchieved is true.",
    inputSchema: {
      type: "object",
      properties: {
        goalId: { type: "string", description: "ID of the goal to execute" },
        maxTurns: {
          type: "number",
          description:
            "Turns to run in this call only (default 1, max 50). Not cumulative agent steps.",
        },
      },
      required: ["goalId"],
    },
    handler: async (args) => {
      const result = await runWithAppLayer(
        Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.executeGoal(args.goalId as string, {
            maxTurns: args.maxTurns as number | undefined,
          });
        })
      );
      return formatExecutionResult(result);
    },
  },

  {
    name: "goal_pause",
    description: "Pause the currently active goal.",
    inputSchema: {
      type: "object",
      properties: {
        goalId: { type: "string", description: "ID of the goal to pause" },
      },
      required: ["goalId"],
    },
    handler: async (args) => {
      const goal = await runWithAppLayer(
        Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.pauseGoal(args.goalId as string);
        })
      );
      return {
        success: true,
        goal: {
          id: goal.id,
          status: goal.status,
          updatedAt: new Date(goal.updatedAt).toISOString(),
        },
      };
    },
  },

  {
    name: "goal_resume",
    description: "Resume a paused goal.",
    inputSchema: {
      type: "object",
      properties: {
        goalId: { type: "string", description: "ID of the goal to resume" },
      },
      required: ["goalId"],
    },
    handler: async (args) => {
      const goal = await runWithAppLayer(
        Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.resumeGoal(args.goalId as string);
        })
      );
      return {
        success: true,
        goal: {
          id: goal.id,
          status: goal.status,
          updatedAt: new Date(goal.updatedAt).toISOString(),
        },
      };
    },
  },

  {
    name: "goal_complete",
    description: "Mark a goal as completed.",
    inputSchema: {
      type: "object",
      properties: {
        goalId: { type: "string", description: "ID of the goal to complete" },
      },
      required: ["goalId"],
    },
    handler: async (args) => {
      const goal = await runWithAppLayer(
        Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.completeGoal(args.goalId as string);
        })
      );
      return {
        success: true,
        goal: {
          id: goal.id,
          status: goal.status,
          completedAt: goal.completedAt
            ? new Date(goal.completedAt).toISOString()
            : null,
        },
      };
    },
  },

  {
    name: "goal_cancel",
    description: "Cancel a goal.",
    inputSchema: {
      type: "object",
      properties: {
        goalId: { type: "string", description: "ID of the goal to cancel" },
      },
      required: ["goalId"],
    },
    handler: async (args) => {
      const goal = await runWithAppLayer(
        Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.cancelGoal(args.goalId as string);
        })
      );
      return {
        success: true,
        goal: {
          id: goal.id,
          status: goal.status,
          updatedAt: new Date(goal.updatedAt).toISOString(),
        },
      };
    },
  },

  {
    name: "goal_statistics",
    description: "Get goal statistics (total, active, completed, etc.).",
    inputSchema: { type: "object", properties: {} },
    handler: async () => {
      const stats = await runWithAppLayer(
        Effect.gen(function* () {
          const service = yield* GoalApplicationService;
          return yield* service.getGoalStatistics();
        })
      );
      return { success: true, statistics: stats };
    },
  },
];
