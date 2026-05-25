/**
 * Goal MCP Tools
 *
 * Tool specifications for Pi Agent MCP integration
 */
import { Effect } from "effect";
import { GoalApplicationService, AppLayer } from "../index.js";

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

/**
 * Execute Effect program with AppLayer
 */
async function runWithAppLayer<T, E, R>(
  program: Effect.Effect<T, E, R>
): Promise<T> {
  return Effect.runPromise(
    program.pipe(Effect.provide(AppLayer)) as Effect.Effect<T, never, never>
  );
}

/**
 * Goal tools for MCP
 */
export const goalTools: GoalTool[] = [
  {
    name: "goal_create",
    description:
      "Create a new goal with an objective and optional context. Only one active goal is allowed at a time.",
    inputSchema: {
      type: "object",
      properties: {
        objective: {
          type: "string",
          description: "The goal objective (what you want to achieve)",
        },
        context: {
          type: "string",
          description: "Optional additional context for the goal",
        },
      },
      required: ["objective"],
    },
    handler: async (args) => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.createGoal({
          objective: args.objective as string,
          context: args.context as string | undefined,
        });
      });

      const goal = await runWithAppLayer(program);
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
    name: "goal_status",
    description: "Get the currently active goal, if any.",
    inputSchema: {
      type: "object",
      properties: {},
    },
    handler: async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.getActiveGoal();
      });

      const goal = await runWithAppLayer(program);
      if (!goal) {
        return { success: true, activeGoal: null };
      }

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
    name: "goal_execute",
    description:
      "Execute a goal in a continuation loop with judge evaluation. Specify maxTurns to limit execution.",
    inputSchema: {
      type: "object",
      properties: {
        goalId: {
          type: "string",
          description: "ID of the goal to execute",
        },
        maxTurns: {
          type: "number",
          description: "Maximum number of turns (default: 50)",
        },
      },
      required: ["goalId"],
    },
    handler: async (args) => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.executeGoal(args.goalId as string, {
          maxTurns: args.maxTurns as number | undefined,
        });
      });

      const result = await runWithAppLayer(program);
      const latestJudge = result.context.getLatestJudgeEvaluation();

      return {
        success: result.success,
        execution: {
          goalId: result.goalId,
          turns: result.context.currentTurn,
          isComplete: result.context.isComplete,
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
    },
  },

  {
    name: "goal_pause",
    description: "Pause the currently active goal.",
    inputSchema: {
      type: "object",
      properties: {
        goalId: {
          type: "string",
          description: "ID of the goal to pause",
        },
      },
      required: ["goalId"],
    },
    handler: async (args) => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.pauseGoal(args.goalId as string);
      });

      const goal = await runWithAppLayer(program);
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
        goalId: {
          type: "string",
          description: "ID of the goal to resume",
        },
      },
      required: ["goalId"],
    },
    handler: async (args) => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.resumeGoal(args.goalId as string);
      });

      const goal = await runWithAppLayer(program);
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
        goalId: {
          type: "string",
          description: "ID of the goal to complete",
        },
      },
      required: ["goalId"],
    },
    handler: async (args) => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.completeGoal(args.goalId as string);
      });

      const goal = await runWithAppLayer(program);
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
        goalId: {
          type: "string",
          description: "ID of the goal to cancel",
        },
      },
      required: ["goalId"],
    },
    handler: async (args) => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.cancelGoal(args.goalId as string);
      });

      const goal = await runWithAppLayer(program);
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
    inputSchema: {
      type: "object",
      properties: {},
    },
    handler: async () => {
      const program = Effect.gen(function* () {
        const service = yield* GoalApplicationService;
        return yield* service.getGoalStatistics();
      });

      const stats = await runWithAppLayer(program);
      return {
        success: true,
        statistics: stats,
      };
    },
  },
];
