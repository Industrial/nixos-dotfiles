# Temporal Design Skill

Give your AI coding agent the ability to review Temporal workflow designs. Point it at a design doc, architecture spec, pseudocode, or workflow code and get a structured critique covering correctness, production readiness, and best-practice compliance.

> [!WARNING]
> This Skill is currently in Public Preview, and will continue to evolve and improve.
> We would love to hear your feedback - positive or negative - over in the [Community Slack](https://t.mp/slack), in the [#topic-ai channel](https://temporalio.slack.com/archives/C0818FQPYKY)

## What It Reviews

- Whether a use case is a good fit for Temporal
- Workflow-level correctness and determinism
- Anti-patterns, retry/timeout/payload risks, and missing design decisions
- Production readiness of a Temporal architecture
- Worker topology, task queues, and routing choices
- Versioning, visibility, and replay safety

Each review produces a structured verdict (approve / approve with changes / needs revision / high risk) with severity-ranked findings and actionable fixes.

## Installation

### Via manual clone (user-level)

Cloning into `~/.claude/skills/` makes the skill available across all sessions and projects for your user.

```bash
mkdir -p ~/.claude/skills && git clone https://github.com/temporalio/skill-temporal-design ~/.claude/skills/temporal-design
```

### Via CLI flag (per-session)

```bash
claude --plugin-dir /path/to/skill-temporal-design
```

This loads the skill for a single session without permanently installing it.
