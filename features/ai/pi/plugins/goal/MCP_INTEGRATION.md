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

The plugin exposes 11 MCP tools to Pi Agent:

1. **goal_create** - Create a new goal
   - Parameters: `objective` (string, required), `context` (string, optional)
   - Returns: Goal object with id, objective, status, createdAt

2. **goal_status** - Get currently active goal
   - Parameters: None
   - Returns: Active goal or null

3. **goal_execute** - Run up to `maxTurns` plugin turns (default **1**, max **1000** per call, **1000 lifetime** per goal across all agents)
   - Parameters: `goalId` (required), `maxTurns` (optional)
   - Returns: `success`, `goalAchieved`, `phaseComplete`, `turnLimitReached`, `stoppedReason`, `turnsThisCall`, `cumulativeTurn`, `nextPrompt`, `judge`
   - **Not** 1000 agent steps in one call — invoke repeatedly until `goalAchieved: true`

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

8. **goal_get** - Get goal by ID
9. **goal_list** - List goals (optional status filter)
10. **goal_execution_status** - Checkpoint + latest iteration
11. **goal_statistics** - Get goal statistics
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
3. **Execution via pi-subagents** (implemented): each `goal_execute` turn spawns `pi-goal-subagent-run` → `runSync()` with agent `worker` (override: `PI_GOAL_SUBAGENT_AGENT`). Requires `npm:pi-subagents` in `settings.json`. Disable: `PI_GOAL_SUBAGENT_DISABLE=1`.
4. **JudgeServiceLive** (implemented): OpenRouter `openrouter/free` via `OPENROUTER_API_KEY` (override model: `PI_JUDGE_MODEL`).
5. **Event store** (implemented): lifecycle + turn events in SQLite `events` table via `EventStoreLive`.
6. **PromptGeneratorServiceLive** (remaining mock)
7. ~~**Add SQLite persistence**~~ Done — goals persist at `~/.pi/state/goal/goals.db`
6. **Implement streaming** for execution updates
7. **Add retry logic** for transient failures

### Environment (goal_execute + subagents)

| Variable | Default | Purpose |
|----------|---------|---------|
| `PI_GOAL_SUBAGENT_AGENT` | `worker` | pi-subagents agent name |
| `PI_GOAL_SUBAGENT_CWD` | `BEADS_MCP_CWD` or `~/.dotfiles` | Working directory for subagent |
| `PI_SUBAGENTS_ROOT` | `~/.dotfiles/features/ai/pi/.pi/agent/npm/node_modules/pi-subagents` | Package path |
| `PI_CODING_AGENT_DIR` | `~/.dotfiles/features/ai/pi/.pi/agent` | Pi agent dir (agent discovery) |
| `PI_GOAL_SUBAGENT_DISABLE` | unset | Set `1` to use prompt-only delegation (no spawn) |
| `OPENROUTER_API_KEY` | — | Required for JudgeServiceLive |
| `PI_JUDGE_MODEL` | `openrouter/free` | Judge LLM (matches Pi settings.json) |
| `GOAL_SMOKE_TEST` | unset | Set `1` with API key to run `src/goal.smoke.test.ts` |

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
- 756 tests covering all functionality
- BDD/TDD approach throughout
- Full domain, application, and infrastructure coverage
- No MCP-specific tests (integration point only)
