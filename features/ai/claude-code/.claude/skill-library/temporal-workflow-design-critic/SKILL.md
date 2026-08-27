---
name: temporal-workflow-design-critic
description: Critique, audit, or score a Temporal workflow design for correctness, production readiness, and best-practice compliance. Use when asked to review a Temporal architecture, evaluate whether a design is production ready, identify anti-patterns or risks, assess Temporal fitness for a use case, or give a design a thumbs up/down. Not for writing or debugging Temporal code — use temporal-developer for that.
---

# Temporal Workflow Design Critic

Use this skill to review a Temporal workflow design, spec, architecture document, implementation plan, pseudocode, workflow code, or code-generation output.

This skill is for critique and review, not implementation.

## What this skill does

This skill helps you:

- determine whether a use case is a good fit for Temporal
- inspect usage of Temporal primitives
- identify determinism, retry, timeout, event-history, signal-volume, and payload-size risks
- detect anti-patterns and missing design decisions
- evaluate production readiness
- give concrete remediation guidance
- produce consistent review output across designs

## When to use this skill

Use this skill when the user asks you to:

- review a Temporal workflow design
- critique a Temporal architecture or implementation plan
- evaluate workflow code or pseudocode against best practices
- assess whether a design is production ready
- identify risks, anti-patterns, or missing decisions in a Temporal-based design
- score or checklist a Temporal design

Do not use this skill for:

- deep debugging of a live production incident
- replacing SDK documentation
- writing the full implementation unless the user explicitly asks for that
- deciding product strategy unrelated to Temporal workflow design

## Primary review goal

Prioritize:

1. correctness
2. operability
3. production readiness

Do not demand perfection. Accept reasonable tradeoffs, but clearly flag risks, anti-patterns, and missing information.

## Expected inputs

This skill works best when the user provides some combination of:

- deployment model (Temporal Cloud or self-hosted)
- use-case description
- workflow diagram
- workflow code or pseudocode
- Temporal UI execution history
- activity definitions
- signal, query, or update usage
- timeout and retry settings
- task queue and worker topology
- expected scale, volume, and duration

If important inputs are missing, explicitly call that out and mark affected checks as `inconclusive`.

## Review method

When reviewing a design, follow this sequence:

1. Decide whether the use case is actually a good fit for Temporal.
2. Inspect workflow-level correctness and determinism.
3. Evaluate use of Temporal primitives.
4. Check event-history growth, payload size, and long-running execution strategy.
5. Inspect retries, timeouts, idempotency, and cancellation behavior.
6. Evaluate worker topology, task queues, and routing choices.
7. Check visibility, versioning, and replay safety.
8. Return a structured critique with severity-ranked findings and actionable fixes.

## Reference materials

For detailed guidance during review, consult these supporting files:

- [rubric.md](references/rubric.md) — Complete review rubric covering Temporal fit, workflows, child workflows, activities, signals, queries, updates, workers, timers, side effects, data converters, visibility, versioning, Continue-As-New, sessions, and storage optimization (sections 1-16).
- [checklist.md](references/checklist.md) — Structured pass/fail/inconclusive checklist for all review categories.
- [decision-guide.md](references/decision-guide.md) — Verdict rubric (approve, approve with changes, needs revision, high risk), open questions template, and optional structured JSON output format.

## Output contract

Always return results in this structure:

```md
# Workflow Design Critique

## Verdict
- status: approve | approve_with_changes | needs_revision | high_risk
- summary: <1-3 paragraph summary>

## Top Issues
1. [severity] <issue title>
   - why it matters
   - evidence from design
   - recommended fix

## Category Review
### Temporal fit
### Workflows
### Child Workflows
### Activities
### Signals
### Queries
### Updates
### Workers and Task Queues
### Timers / Schedules / Cron
### Data / Payloads / Converters
### Visibility
### Versioning
### Long-running execution

## Open Questions
- <question>

## Checklist Result
- pass/fail/inconclusive per item
```

## Severity levels

Use only these severity levels:

- `critical` — likely to fail, become non-deterministic, exceed limits, or cause production incidents
- `high` — serious design problem likely to impair correctness, scale, or operability
- `medium` — suboptimal design likely to cause friction, cost, or maintenance issues
- `low` — improvement opportunity or missing optimization
- `info` — observation or tradeoff explanation

## Default judgments

Apply these defaults unless the design clearly justifies otherwise.

### Local activity vs regular activity

Default to regular activities.

Use local activities only when very short execution and high-throughput fan-out justify them.

### Child workflow vs activity

Default to activity.

Use child workflows only when partitioning, lifecycle isolation, or routing semantics justify them.

### Workflow-to-workflow communication

Acceptable options include:

- signals
- queries
- updates
- Nexus where applicable
- activity-mediated client calls for cross-namespace interaction where needed

### Large payload handling

Prefer:

- passing references
- moving data-heavy work into activities
- compression
- explicit handling over hidden remote payload fetches

### Large workflow history

Prefer:

- Continue-As-New
- partitioning with child workflows where justified
- reducing per-event data size and message volume

### Parallelism

Parallel execution should use async invocation patterns with promise or future collection and later aggregation.

### Worker-specific activity queues

Use when capabilities, locality, security, or rate control justify them.

### Schedule vs timer

Use timers for relative delays inside workflows.

Use schedules for calendar-based or recurring launches.

## Reviewer operating style

When using this skill:

- be specific, practical, and conservative
- do not assume missing details are safe
- distinguish between blocking issues and reasonable tradeoffs
- provide concrete remediation guidance, not vague advice
- clearly separate evidence, risk, and recommendation
- mark missing-information areas as `inconclusive` instead of guessing

## Anti-pattern catalog

Explicitly call out the following when present.

### Critical anti-patterns

- non-deterministic workflow logic
- workflow logic depending directly on external mutable state
- passing large data blobs through workflow history
- activity side effects without idempotency
- signal floods against a single workflow
- search attributes used as business-state storage
- workflow retry policy used to compensate for transient activity failures

### High-risk anti-patterns

- child workflows used purely for code organization
- local activities used for long or failure-prone work
- schedules used for one-time delayed starts without need
- cron used where schedules should be used
- missing Continue-As-New strategy in high-volume or long-running workflows
- no replay or versioning strategy

### Medium-risk anti-patterns

- identical timeout policies for all activities
- over-fragmented activities causing event-history bloat
- memo or visibility data assumed to be strongly consistent
- arbitrary task queue splitting

## Maintainer note

Keep this skill:

- stable enough for repeatable agent use
- readable by humans
- extensible as Temporal features evolve
- opinionated toward production safety

When updating, preserve:

- explicit rules
- default recommendations
- anti-pattern detection
- structured output expectations
- practical review questions
