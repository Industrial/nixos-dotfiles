/**
 * ToolExecutionService - Domain Service Interface
 *
 * Bridge between goal execution and Pi Agent's tooling system.
 * Enables goals to execute Pi tools (read, write, edit, bash, extensions).
 */
import { Context, Effect } from "effect";
import { ToolResult } from "../models/ToolResult.js";

/**
 * Tool descriptor
 */
export interface Tool {
  name: string;
  description: string;
  parameters?: Record<string, unknown>;
}

/**
 * Service for executing Pi Agent tools within goal context
 *
 * Provides safe, validated access to Pi's tool ecosystem:
 * - Core tools: read, write, edit, bash
 * - Extension tools: custom tools from Pi plugins
 * - Safety: validation, sandboxing, error handling
 * - Tracking: execution time, metadata, results
 */
export interface ToolExecutionService {
  /**
   * Execute a Pi Agent tool
   *
   * @param toolName - Name of tool to execute (read, write, edit, bash, etc.)
   * @param args - Tool-specific arguments
   * @returns Tool execution result
   */
  executeTool(
    toolName: string,
    args: Record<string, unknown>
  ): Effect.Effect<ToolResult, Error>;

  /**
   * Get list of available tools
   *
   * @returns Array of available tool descriptors
   */
  getAvailableTools(): Effect.Effect<Tool[], Error>;
}

/**
 * ToolExecutionService tag for dependency injection
 */
export const ToolExecutionService = Context.GenericTag<ToolExecutionService>(
  "@goal/ToolExecutionService"
);
