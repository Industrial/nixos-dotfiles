# pi-plugin-goal

A Pi plugin for managing persistent, long-running goals with automated continuation loops.

## Overview

This plugin implements the `<goal>` command functionality for the Pi Agent, enabling:

- Persistent, long-running objectives stored in SQLite
- Automated continuation loops for goal execution
- User control commands (propose, pause, resume, clear)
- Goal evaluation and status reporting
- Integration with Pi's tooling system

## Architecture

### Data Structure

Goals are stored in a SQLite database with the following schema:

```sql
CREATE TABLE goals (
  id TEXT PRIMARY KEY,
  objective TEXT NOT NULL,
  context TEXT,
  status TEXT NOT NULL, -- 'active', 'paused', 'completed', 'cancelled'
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  completed_at INTEGER,
  evaluation_data TEXT -- JSON
);

CREATE TABLE goal_iterations (
  id TEXT PRIMARY KEY,
  goal_id TEXT NOT NULL,
  iteration_number INTEGER NOT NULL,
  started_at INTEGER NOT NULL,
  completed_at INTEGER,
  outcome TEXT,
  evaluation_data TEXT, -- JSON
  FOREIGN KEY (goal_id) REFERENCES goals(id)
);
```

### Components

1. **Goal Storage** (`goalStorage.ts`): SQLite-based persistence layer
2. **Goal Commands** (`goalCommands.ts`): User control commands implementation
3. **Goal Execution** (`goalExecution.ts`): Continuation loop logic
4. **Goal Evaluation** (`goalEvaluation.ts`): Progress assessment and status reporting
5. **Plugin Entry Point** (`index.ts`): Pi plugin registration and initialization

## Usage

### Setting a Goal

```typescript
// Propose a goal draft
await proposeGoalDraft({
  objective: "Refactor authentication system to use JWT",
  context: "Current system uses sessions, need to migrate"
});
```

### Managing Goals

```typescript
// Pause active goal
await pauseGoal(goalId);

// Resume paused goal
await resumeGoal(goalId);

// Clear completed/cancelled goal
await clearGoal(goalId);
```

### Goal Status

```typescript
// Get current goal status
const status = await getGoalStatus(goalId);
console.log(status);
```

## Development

```bash
# Install dependencies
bun install

# Run tests
bun test

# Type check
bun run typecheck

# Lint
bun run lint
```

## Integration

This plugin is designed to integrate with the Pi Agent's tooling system and the `<assistant>` extension for seamless goal execution.
