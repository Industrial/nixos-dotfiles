---
name: agent
description: >
  Agent role selection for Hermes Agent. Choose the appropriate agent role based on task type and ID mode.
  Maps to Cursor's agent rules: researcher, architect, implementer, reviewer.
tags: [agent, role, researcher, architect, implementer, reviewer]
---

# Agent Role Selection

Select the appropriate agent role for your current task. This determines which tools and behaviors are emphasized.

## Agent Roles & Corresponding ID Modes

| Role | Rule Source | Typical ID Mode | Description |
|------|-------------|-----------------|-------------|
| **Researcher** | `agent-researcher.mdc` | ORIENT / RESEARCH | Read-only recon, hypotheses, debate; no implementation |
| **Architect** | `agent-architect.mdc` | PLAN | Design specifications, planning, architecture |
| **Implementer** | `agent-implementer.mdc` | EXECUTE | Code implementation, building, execution |
| **Reviewer** | `agent-reviewer.mdc` | REVIEW / SHIP | Verification, review, quality assurance, shipping |

## Role Details

### Researcher
- Modes: ORIENT support, RESEARCH, debate-only
- Tools: read/search/roam/lean-ctx/Context7/searxng. **No edits, no commits.**
- Output: sharp observations, ranked hypotheses, disproofs, file paths
- Hand off to architect when enough context to plan

### Architect
- Modes: PLAN
- Focus: Creating specifications, Maestro tasks, plan documents
- Tools: Planning skills, Maestro CLI, spec creation
- Output: Maestro specs, execution overlays, plan files, acceptance criteria

### Implementer
- Modes: EXECUTE
- Focus: Writing contract-scoped code, implementing features
- Tools: Coding, editing, building, testing
- Output: Working implementation that satisfies task contracts
- Constraints: Only modify code within task boundaries

### Reviewer
- Modes: REVIEW / SHIP
- Focus: Verification, testing, evidence recording, shipping
- Tools: Testing, verification, Maestro evidence recording, git operations
- Output: PASS/FAIL verdicts, shipped work, evidence records

## Usage

When starting work, declare your agent role alongside your ID mode and lane:

```
[ID:PLAN]
lane:normal
agent:architect

[Response content following architect guidelines...]
```

The agent role helps focus your tool usage and approach on the appropriate activities for the current phase of work.