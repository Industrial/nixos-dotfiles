---
name: beads-task-management
description: "How to use bd (beads) for task management: epics, task trees, deps, parallel subagent swarms, session hygiene."
tags: [beads, bd, task-management, agents, parallel, workflow]
---

# Beads (bd) Task Management

## What is Beads

bd is the project issue tracker backed by Dolt (versioned SQL). Every issue
has an ID like `prefix-abc123` or hierarchical like `prefix-abc123.1.2`.
Run `bd prime` at session start to restore full workflow context.

## Core Workflow

### Session Start
```bash
bd prime          # Full workflow context + session close protocol
bd ready          # Issues with no active blockers (start here)
bd show <id>      # Full issue detail before claiming
bd update <id> --claim  # Atomically set assignee + status=in_progress
```

### Creating Issues

Single issue:
```bash
bd create --type=task --priority=1 \
  --title="Short imperative title" \
  --description="Why this exists and what done looks like"
```

Silent mode (returns ID only, safe for scripting):
```bash
ID=$(bd create --type=task --priority=0 --title="..." --silent)
```

Types: task, bug, feature, epic, chore, decision
Priority: 0=critical, 1=high, 2=medium, 3=low, 4=backlog

Hierarchical children (use --parent):
```bash
EPIC=$(bd create --type=epic --title="Big thing" --silent)
CHILD=$(bd create --type=task --parent=$EPIC --title="Sub-task" --silent)
```

### Closing Work
```bash
bd close <id>                      # Mark complete
bd close <id1> <id2> <id3>        # Close multiple at once
bd close <id> --reason="why"      # With reason
```

### Updating
```bash
bd update <id> --status=in_progress
bd update <id> --notes="Found X, trying Y"
bd update <id> --title="New title"
```

## Dependencies

Dependencies express "A cannot start until B is done":
```bash
bd dep add <blocked-id> <blocker-id>        # blocked depends on blocker
bd dep <blocker-id> --blocks <blocked-id>   # same, alternative syntax
bd dep list <id>    # show what this blocks or is blocked by
bd dep tree <id>    # recursive tree
bd dep cycles       # check for cycles
```

## Visualising the Task Tree

```bash
bd graph <epic-id>              # terminal DAG (default)
bd graph --compact <epic-id>    # tree format, one line per node
bd graph --box <epic-id>        # ASCII boxes with layers
bd graph --dot <id> | dot -Tsvg > out.svg
bd graph --html <id> > out.html              # interactive D3 browser view
```

The compact graph shows layers -- same layer = can run in parallel.

## Bulk Operations with batch

For creating many issues or deps in one transaction:
```bash
printf 'close bd-1 done\nupdate bd-2 status=in_progress\n' | bd batch
bd batch -f operations.txt
```

Grammar accepted by batch (one command per line):
- `close <id> [reason]`
- `update <id> key=value [key=value ...]`  (keys: status, priority, title, assignee)
- `create <type> <priority> <title>`
- `dep add <from-id> <to-id> [type]`
- `dep remove <from-id> <to-id>`

## Building a Deep Task Tree

When planning a large feature, create hierarchy top-down then wire deps:

```bash
# 1. Create root epic
ROOT=$(bd create --type=epic --priority=0 --title="Feature X" --silent)

# 2. Create phase epics as children
P1=$(bd create --type=epic --priority=0 --parent=$ROOT --title="Phase 1: Foundation" --silent)
P2=$(bd create --type=epic --priority=0 --parent=$ROOT --title="Phase 2: Core" --silent)

# 3. Create leaf tasks under each phase
T1=$(bd create --type=task --priority=0 --parent=$P1 --title="Do thing A" --silent)
T2=$(bd create --type=task --priority=0 --parent=$P1 --title="Do thing B" --silent)
T3=$(bd create --type=task --priority=0 --parent=$P2 --title="Do thing C" --silent)

# 4. Wire phase-level sequencing
bd dep add $P2 $P1       # Phase 2 blocked by Phase 1

# 5. Wire internal deps within phases
bd dep add $T2 $T1       # T2 depends on T1

# 6. Verify the graph
bd graph --compact $ROOT
```

Rule: wire deps AFTER creating all issues. Avoids ID guessing mid-loop.

## Parallel Subagent Pattern with Beads

Beads is built for parallel agent work. The swarm model:

1. Orchestrator creates epic + task tree with deps
2. Orchestrator creates a swarm: `bd swarm create <epic-id>`
3. Worker subagents each call `bd ready` and claim independent tasks
4. Workers cannot start a task whose blocker is still open (enforced by deps)
5. Workers close tasks as they finish; newly unblocked tasks appear in `bd ready`

### Worker Safety Flags

Workers should use `--readonly` for queries:
```bash
bd ready --readonly
bd show <id> --readonly
```

Workers write with `--sandbox` to disable auto-sync during work:
```bash
bd update <id> --claim --sandbox
bd close <id> --sandbox
```

### Swarm Coordination

```bash
bd swarm create <epic-id>          # register swarm
bd swarm status <epic-id>          # see: completed / active / ready / blocked
bd swarm status <epic-id> --json   # machine-readable for orchestrators
```

Orchestrators poll `bd swarm status --json` to decide when to spawn the next
wave of workers or detect stuck work.

### Gate Pattern

Block downstream work until a human or CI resolves it:
```bash
bd gate create <blocked-id> --type=human
bd gate list
bd gate resolve <gate-id>
```

### Parallel Issue Creation with Subagents

When creating many issues in parallel across subagents:
1. Each subagent receives the parent epic ID in context
2. Each subagent creates its own subtree using `--parent=<epic-id>`
3. Each subagent returns all created IDs to the orchestrator
4. Orchestrator wires cross-subtree deps in a final step

This avoids serialising creation and cuts wall time for large task trees.

Example orchestrator prompt fragment to pass to a subagent:
```
Parent epic ID: prefix-abc123
Create tasks for the "Venue Protocol" subsystem.
Use --parent=prefix-abc123 on every bd create call.
Return all created IDs at the end of your response.
```

## Epic and Status Commands

```bash
bd epic status <id>          # completion % of all children
bd epic close-eligible       # auto-close epics where all children done
```

## Persistent Memory

Store cross-session knowledge in beads, not in files:
```bash
bd remember "The HL testnet wallet address must start with 0x"
bd memories hyperliquid      # search memories by keyword
bd recall <memory-id>        # retrieve specific memory
bd forget <memory-id>        # delete a memory
```

## Search and Query

```bash
bd search "keyword"
bd query "type=task AND status=open"
bd list --status=open
bd list --status=in_progress
bd stale
bd blocked
bd ready
```

## Session Close Protocol

NEVER skip before ending a session:
```bash
git status
git add <files>
git commit -m "feat: ..."
git pull --rebase
bd dolt push          # push beads data to remote
git push              # MUST show up-to-date with origin
```

Work is NOT complete until `git push` succeeds.

## Common Pitfalls

- NEVER use `bd edit` -- opens $EDITOR and blocks agents indefinitely
- NEVER track ephemeral in-session TODO state in beads (use shell vars)
- Always `bd ready` before claiming -- avoids picking blocked work
- Use `--silent` in scripts; without it bd prints human output that breaks ID capture
- `bd batch` only accepts a narrow grammar subset -- check it before using
- Priority is 0-4 integers (not strings like "high"/"medium"/"low")
- Wire phase deps AFTER creating all issues, not interleaved with creation
- `--dry-run` on create produces no actual issue -- do not use in pipelines
- Workers using `bd ready` in parallel is safe (reads are concurrent)
- Writers should claim before writing to avoid conflicts
