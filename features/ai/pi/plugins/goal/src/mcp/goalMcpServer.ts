/**
 * Goal MCP Server
 *
 * MCP server implementation for Pi Agent integration
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { goalTools } from "./goalTools.js";
import type { GoalTool } from "./goalTools.js";

/**
 * Create Goal MCP Server instance
 */
export function createGoalMcpServer(): Server {
  const server = new Server(
    {
      name: "pi-plugin-goal",
      version: "0.1.0",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  // Handle tool listing
  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: goalTools.map((tool) => ({
      name: tool.name,
      description: tool.description,
      inputSchema: tool.inputSchema,
    })),
  }));

  // Handle tool execution
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const tool = goalTools.find(
      (entry) => entry.name === request.params.name
    ) as GoalTool | undefined;

    if (!tool) {
      throw new Error(`Unknown tool: ${request.params.name}`);
    }

    const args =
      (request.params.arguments as Record<string, unknown> | undefined) ?? {};
    const result = await tool.handler(args);

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  });

  return server;
}

/**
 * Start Goal MCP Server with stdio transport
 */
export async function startGoalMcpServer(): Promise<void> {
  const server = createGoalMcpServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}
