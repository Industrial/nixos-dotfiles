/**
 * ToolExecutionServiceMock - Test Implementation
 *
 * Mock implementation of ToolExecutionService for testing.
 * Simulates Pi Agent tool behavior with predictable responses.
 */
import { Effect, Layer } from "effect";
import { ToolExecutionService, Tool } from "./ToolExecutionService.js";
import { ToolResult } from "../models/ToolResult.js";

/**
 * Mock tool execution implementation
 *
 * Simulates tool behavior based on simple heuristics:
 * - read: succeeds if path doesn't contain "nonexistent"
 * - write: succeeds if args include "content"
 * - edit: succeeds if oldString doesn't contain "nonexistent"
 * - bash: succeeds unless command contains "exit 1"
 */
class ToolExecutionServiceMockImpl implements ToolExecutionService {
  executeTool(
    toolName: string,
    args: Record<string, unknown>
  ): Effect.Effect<ToolResult, Error> {
    return Effect.sync(() => {
      // Simulate execution delay
      const executionTimeMs = Math.floor(Math.random() * 50) + 10;

      const timestamp = Date.now();

      switch (toolName) {
        case "read": {
          const path = args.path as string;
          if (path?.includes("nonexistent")) {
            return new ToolResult({
              toolName: "read",
              success: false,
              output: "",
              error: `File not found: ${path}`,
              executionTimeMs,
              timestamp,
            });
          }
          return new ToolResult({
            toolName: "read",
            success: true,
            output: `Mock file contents from ${path}`,
            executionTimeMs,
            timestamp,
          });
        }

        case "write": {
          const path = args.path as string;
          const content = args.content as string;
          if (!content) {
            return new ToolResult({
              toolName: "write",
              success: false,
              output: "",
              error: "Missing required argument: content",
              executionTimeMs,
              timestamp,
            });
          }
          return new ToolResult({
            toolName: "write",
            success: true,
            output: `File written to ${path}`,
            executionTimeMs,
            timestamp,
          });
        }

        case "edit": {
          const path = args.path as string;
          const oldString = args.oldString as string;
          const newString = args.newString as string;

          if (oldString?.includes("nonexistent")) {
            return new ToolResult({
              toolName: "edit",
              success: false,
              output: "",
              error: "Pattern not found in file",
              executionTimeMs,
              timestamp,
            });
          }

          return new ToolResult({
            toolName: "edit",
            success: true,
            output: `Replaced "${oldString}" with "${newString}" in ${path}`,
            executionTimeMs,
            timestamp,
          });
        }

        case "bash": {
          const command = args.command as string;

          if (command?.includes("exit 1")) {
            return new ToolResult({
              toolName: "bash",
              success: false,
              output: "",
              error: "Command failed",
              executionTimeMs,
              metadata: { exitCode: 1 },
              timestamp,
            });
          }

          // Extract output from echo commands
          let output = "Command executed";
          if (command?.startsWith("echo ")) {
            const match = command.match(/echo ['"]?(.+?)['"]?$/);
            if (match) {
              output = match[1];
            }
          }

          return new ToolResult({
            toolName: "bash",
            success: true,
            output,
            executionTimeMs,
            metadata: { exitCode: 0, stderr: "" },
            timestamp,
          });
        }

        default:
          return new ToolResult({
            toolName,
            success: false,
            output: "",
            error: `Unknown tool: ${toolName}`,
            executionTimeMs,
            timestamp,
          });
      }
    });
  }

  getAvailableTools(): Effect.Effect<Tool[], Error> {
    return Effect.succeed([
      {
        name: "read",
        description: "Read file contents from the filesystem",
        parameters: { path: "string" },
      },
      {
        name: "write",
        description: "Write content to a file",
        parameters: { path: "string", content: "string" },
      },
      {
        name: "edit",
        description: "Edit file by replacing text",
        parameters: {
          path: "string",
          oldString: "string",
          newString: "string",
        },
      },
      {
        name: "bash",
        description: "Execute shell command",
        parameters: { command: "string" },
      },
    ]);
  }
}

/**
 * ToolExecutionServiceMock Layer
 */
export const ToolExecutionServiceMock = Layer.succeed(
  ToolExecutionService,
  new ToolExecutionServiceMockImpl()
);
