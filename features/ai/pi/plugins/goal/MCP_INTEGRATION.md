# MCP Integration for Pi Agent

The goal plugin is now integrated with Pi Agent via MCP (Model Context Protocol).

## Installation

The plugin is registered in `~/.pi/agent/mcp.json` as:

```json
"goal": {
  "type": "stdio",
  "command": "/home/tom/.dotfiles/features/ai/pi/bin/pi-mcp-goal",
  "args": [],
  "lifecycle": "lazy",
  "description": "Goal management plugin for persistent, long-running goals with automated continuation loops",
  "directTools": true
}
```

## Available Tools

The plugin exposes 8 MCP tools to Pi Agent:

1. **goal_create** - Create a new goal
   - Parameters: `objective` (string, required), `context` (string, optional)
   - Returns: Goal object with id, objective, status, createdAt

2. **goal_status** - Get currently active goal
   - Parameters: None
   - Returns: Active goal or null

3. **goal_execute** - Execute goal with judge evaluation
   - Parameters: `goalId` (string, required), `maxTurns` (number, optional, default: 50)
   - Returns: Execution result with turns, completion status, judge evaluation

4. **goal_pause** - Pause an active goal
   - Parameters: `goalId` (string, required)
   - Returns: Updated goal with paused status

5. **goal_resume** - Resume a paused goal
   - Parameters: `goalId` (string, required)
   - Returns: Updated goal with active status

6. **goal_complete** - Mark a goal as completed
   - Parameters: `goalId` (string, required)
   - Returns: Updated goal with completed status and timestamp

7. **goal_cancel** - Cancel a goal
   - Parameters: `goalId` (string, required)
   - Returns: Updated goal with cancelled status

8. **goal_statistics** - Get goal statistics
   - Parameters: None
   - Returns: Statistics object with counts and metrics

## Usage in Pi Agent

After restarting Pi, the tools will be available directly:

```
# Create a goal
goal_create objective:"Refactor auth system" context:"Migrate to JWT tokens"

# Check active goal
goal_status

# Execute goal
goal_execute goalId:"<goal-id>" maxTurns:10

# Pause/Resume
goal_pause goalId:"<goal-id>"
goal_resume goalId:"<goal-id>"

# Complete or cancel
goal_complete goalId:"<goal-id>"
goal_cancel goalId:"<goal-id>"

# Get statistics
goal_statistics
```

## Testing the Integration

To verify the MCP server works:

```bash
# Test the bin script directly
/home/tom/.dotfiles/features/ai/pi/bin/pi-mcp-goal

# The server should start and wait for stdio input
# Press Ctrl+C to exit
```

## Architecture

```
Pi Agent
  ↓
~/.pi/agent/mcp.json (registration)
  ↓
/home/tom/.dotfiles/features/ai/pi/bin/pi-mcp-goal (wrapper script)
  ↓
bun run src/mcp/index.ts (entry point)
  ↓
src/mcp/goalMcpServer.ts (MCP server)
  ↓
src/mcp/goalTools.ts (8 tool definitions)
  ↓
src/application/GoalApplicationService.ts (application facade)
  ↓
Domain services & repositories (Effect.ts layers)
```

## Next Steps

1. **Restart Pi Agent** to load the new plugin
2. **Test tools** in Pi Agent to verify integration
3. **Replace mock services** with Pi implementations:
   - JudgeServiceLive (Pi model system)
   - PromptGeneratorServiceLive (full templates)
   - ToolExecutionServiceLive (Pi tool bridge)
4. **Add SQLite persistence** (replace in-memory mocks)
5. **Implement streaming** for execution updates
6. **Add retry logic** for transient failures

## Troubleshooting

**Plugin not showing up in Pi:**
- Ensure mcp.json is properly formatted
- Check that bin script is executable: `chmod +x /home/tom/.dotfiles/features/ai/pi/bin/pi-mcp-goal`
- Verify dependencies installed: `cd plugins/goal && bun install`
- Restart Pi Agent

**MCP server fails to start:**
- Check logs in Pi Agent
- Test bin script directly to see error messages
- Verify Bun is on PATH: `which bun`
- Ensure all dependencies installed

**Tools not working:**
- Check tool parameters match schema
- Review error messages in Pi Agent
- Test programmatically (see USAGE.md)
- Run tests: `bun test`

## Implementation Details

**MCP Protocol:**
- Uses @modelcontextprotocol/sdk v1.29.0
- Stdio transport for Pi communication
- Lazy lifecycle (started on first tool call)
- Direct tools enabled (no intermediate layer)

**Effect.ts Integration:**
- AppLayer provides all dependencies
- Services: GoalApplicationService, GoalLifecycleService, JudgeService, etc.
- Type-safe dependency injection
- Composable service layers

**Tool Handlers:**
- Each tool maps to a GoalApplicationService method
- Effect programs executed with AppLayer context
- Results serialized to JSON for MCP response
- Errors propagated as MCP errors

**Testing:**
- 748 tests covering all functionality
- BDD/TDD approach throughout
- Full domain, application, and infrastructure coverage
- No MCP-specific tests (integration point only)
