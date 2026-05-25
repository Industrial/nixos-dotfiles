#!/usr/bin/env bun
/**
 * Goal MCP Server Entry Point
 *
 * Starts the MCP server for Pi Agent integration
 */
import { startGoalMcpServer } from "./goalMcpServer.js";

async function main(): Promise<void> {
  await startGoalMcpServer();
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`pi-plugin-goal MCP server failed to start: ${message}\n`);
  process.exit(1);
});
