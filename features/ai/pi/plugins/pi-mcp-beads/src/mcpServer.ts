import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
    CallToolRequestSchema,
    ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { beadsTools } from "./beadsMcpServer";
import type { BeadsTool } from "./bdTypes";

export function createBeadsMcpServer(): Server {
    const server = new Server(
        {
            name: "pi-mcp-beads",
            version: "0.1.0",
        },
        {
            capabilities: {
                tools: {},
            },
        },
    );

    server.setRequestHandler(ListToolsRequestSchema, async () => ({
        tools: beadsTools.map((tool) => ({
            name: tool.name,
            description: tool.description,
            inputSchema: tool.parameters,
        })),
    }));

    server.setRequestHandler(CallToolRequestSchema, async (request) => {
        const tool = beadsTools.find(
            (entry) => entry.name === request.params.name,
        ) as BeadsTool | undefined;

        if (!tool) {
            throw new Error(`Unknown tool: ${request.params.name}`);
        }

        const args =
            (request.params.arguments as Record<string, unknown> | undefined) ??
            {};
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

export async function startBeadsMcpServer(): Promise<void> {
    const server = createBeadsMcpServer();
    const transport = new StdioServerTransport();
    await server.connect(transport);
}
