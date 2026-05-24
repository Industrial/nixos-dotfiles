# README-MCP

This document explains how to create an MCP (Model Context Protocol) server and make it available to the Pi agent, typically as a plugin.

## What is an MCP Server?

MCP is a protocol that enables AI models and clients to interact with various tools, resources, and prompts. An MCP server exposes these functionalities in a standardized way, allowing AI agents like Pi to discover and utilize them. This is crucial for extending the agent's capabilities beyond its built-in functions.

## Creating an MCP Server

MCP servers can be built using various programming languages, including TypeScript, Python, .NET, Java, and Rust. The core idea is to expose specific functionalities (tools, prompts, data) through an MCP-compatible interface.

**General Steps:**

1.  **Set up Development Environment**: Install necessary SDKs and dependencies for your chosen language.
2.  **Define Server Logic**: Implement the core functionality you want to expose. This could be anything from simple calculations to complex data retrieval or task execution.
3.  **Expose Tools and Prompts**: Structure your implementation to make these functionalities callable via the MCP protocol. Common examples include:
    *   **Tool Functions**: Functions that perform specific actions (e.g., `search_web`, `run_command`).
    *   **Prompts**: Standardized text prompts that the server can process.
4.  **Choose a Transport Layer**: Select how your server will communicate. Common transport types supported by Pi include:
    *   `stdio` (Standard Input/Output)
    *   `SSE` (Server-Sent Events)
    *   `StreamableHTTP`
    *   `WebSocket`
    *   Many examples utilize libraries like `pi-mcp-adapter` or specific server frameworks.
5.  **Testing**: Test your MCP server using tools like the MCP Inspector or by connecting it to an AI agent.

**Example:** A simple "calculator server" might implement arithmetic operations as MCP tools.

## Making an MCP Server Available to Pi Agent

To integrate an MCP server with the Pi agent, you typically configure Pi to connect to your server. This can be done globally or on a per-project basis.

### Configuration File: `~/.pi/agent/mcp.json`

Pi uses a configuration file (typically located at `~/.pi/agent/mcp.json` for global settings, or `.pi/mcp.json` for project-specific settings) to manage MCP server connections.

**Key Configuration Aspects:**

*   **Server Definitions**: You define your MCP server(s) in this JSON file, specifying connection details and parameters.
*   **Lazy Connections**: By default, MCP connections in Pi are "lazy." This means the server only starts or connects when one of its tools is actually invoked, which is efficient for managing context budgets.
*   **Tool Registration**: Tools exposed by the MCP server are automatically discovered and registered as native Pi tools. This allows you to call them directly within Pi agent tasks.

**Example `~/.pi/agent/mcp.json` structure:**

```json
{
  "servers": [
    {
      "name": "my-custom-mcp-server",
      "path": "/path/to/your/server/executable", // Or connection URL for HTTP/WebSocket
      "transport": "stdio", // or "SSE", "StreamableHTTP", "WebSocket"
      "environment": {
        "MY_VARIABLE": "some_value"
      },
      "allowlist": ["tool1", "tool2"], // Optional: only expose specific tools
      "denylist": ["internal_tool"] // Optional: exclude specific tools
    }
  ]
}
```

### Using Pi Plugins/Extensions

For more structured integration, you can create a Pi plugin that wraps your MCP server.

*   **Plugin Structure**: A Pi plugin is typically a TypeScript module (`.ts` file) that exports specific interfaces or functions.
*   **`pi-mcp-adapter`**: Libraries like `pi-mcp-adapter` can help in creating plugins that act as bridges between Pi and your MCP server. You would configure the adapter with your server's details and the tools it exposes.
*   **Tool Discovery**: Tools exposed by your plugin (which in turn connect to your MCP server) become available to the Pi agent.
*   **Placement**: Plugins are usually placed in directories like `.pi/extensions/` (local) or `~/.pi/agent/extensions/` (global).

**Example (Conceptual - using a hypothetical adapter):**

```typescript
// In your plugin file (e.g., features/ai/pi/plugins/pi-mcp-beads/index.ts)
import { createMcpAdapter } from "@pi-agent/mcp-adapter"; // Hypothetical library

export const piMcpBeadsPlugin = {
    name: "pi-mcp-beads",
    description: "An MCP server encapsulating Beads commands.",
    version: "0.1.0",
    // This tool definition connects to your MCP server
    mcpServerTool: createMcpAdapter({
        serverName: "beads-mcp-server",
        endpoint: "http://localhost:8080", // Or path for stdio transport
        transport: "StreamableHTTP",
        tools: [ // Tools exposed by your Beads MCP server
            "bd_list",
            "bd_show",
            "bd_create"
            // ... other Beads commands
        ]
    }),
    // Other plugin functionalities
};
```

## Key Concepts and Caveats

*   **Lazy Connections**: Leverage this for efficiency; the server only activates when needed.
*   **Transport Types**: `stdio`, `SSE`, `StreamableHTTP`, `WebSocket` are supported for communication.
*   **Tool Management**: Use `allowlist` and `denylist` in configuration to control which tools are exposed.
*   **Dependencies**: Be mindful of library dependencies. Some adapters might have conflicts (e.g., Zod version issues).
*   **Documentation**: Official Pi documentation and GitHub repositories for various MCP adapters are essential resources. Always refer to the latest documentation for specific setup instructions and best practices.

This README provides a general overview. Specific implementation details will depend on the MCP server implementation language and the chosen Pi integration method (direct configuration vs. plugin).
