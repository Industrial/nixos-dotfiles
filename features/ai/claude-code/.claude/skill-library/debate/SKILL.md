---
name: debate
description: >
  Engage in a read-only debate on a topic without making any file changes.
  Use when you want to discuss ideas, explore alternatives, or reason through problems
  without committing to implementation. Aligns with ID RESEARCH mode.
tags: [debate, discussion, research, read-only]
---

# Debate Mode

## Purpose
Engage in a read-only discussion on a topic without making any file changes.
Use when you want to:
- Explore ideas and alternatives
- Reason through problems or trade-offs
- Discuss implications without committing to implementation
- Brainstorm solutions
- Clarify understanding through dialogue

## Guidelines
- **Do not change/generate any files yet.** This is a pure discussion mode.
- Focus on asking questions, sharing observations, and building shared understanding.
- Use read-only tools: read/search/roam/lean-ctx/Context7/searxng to gather information.
- Avoid suggesting specific implementation details that would require file changes.
- Keep the conversation exploratory and open-ended.

## Alignment with ID Workflow
This mode aligns with ID **RESEARCH** (`/id-research`):
- Read-only, no edits or commits
- No mode advance to EXECUTE (remains in research until enough context to plan)
- Ideal for hypothesis generation, disproofs, and file path discovery
- Hand off to architect (PLAN mode) when enough context exists to create a plan

## Usage
When you want to debate a topic:
1. State that you are entering debate mode
2. Use only read-only tools to gather information
3. Discuss ideas, trade-offs, and questions
4. Do not propose specific code changes or file modifications
5. When sufficient context is gathered, transition to PLAN mode (or continue researching)

Example declaration:
```
[ID:RESEARCH]
lane:normal
mode:debate

Let's debate the merits of approach A vs approach B...
```