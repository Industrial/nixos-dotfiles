# Decision rubric

## Approve

Use when the design:

- follows Temporal fundamentals correctly
- shows awareness of determinism, idempotency, history growth, and failure handling
- has no critical or high-severity flaws

## Approve with changes

Use when the design is broadly sound but has:

- several medium-severity issues
- missing operational details
- review questions that should be resolved before production

## Needs revision

Use when the design has:

- one or more high-severity issues
- unclear Temporal primitive selection
- insufficient handling of history, payload size, retries, or long-running behavior

## High risk

Use when the design includes:

- critical non-determinism risks
- obvious misuse of Temporal as data plane
- major idempotency gaps
- unbounded history growth
- signal or payload patterns likely to fail in production

# Open questions template

When the source material is incomplete, ask targeted questions such as:

- Is the target deployment Temporal Cloud or self-hosted?
- What is the expected peak workflow start rate?
- What is the longest expected workflow duration?
- How many activities and child workflows can occur per execution?
- What are the largest expected payload sizes?
- Are any activities side-effecting external systems?
- What is the retry and timeout policy per activity?
- How many signals or updates can one execution receive?
- Is Continue-As-New planned?
- Are there cross-namespace or cross-service workflow communications?
- Are search attributes used only for visibility?
- What is the versioning plan for workflow changes?

# Optional structured output

Use this when the user asks for machine-readable output:

```json
{
  "verdict": "approve_with_changes",
  "summary": "The design is broadly sound but has unresolved event history and signal-volume risks.",
  "issues": [
    {
      "severity": "high",
      "category": "Signals",
      "title": "Signal volume may block Continue-As-New",
      "why_it_matters": "High sustained signal rates can prevent workflow progress and cause history-limit failures.",
      "recommendation": "Aggregate signals, shard by workflow, or reduce per-workflow signal rate."
    }
  ],
  "checklist": {
    "workflow_determinism": "pass",
    "activity_idempotency": "pass",
    "history_management": "fail",
    "signal_safety": "fail",
    "versioning_strategy": "inconclusive"
  },
  "open_questions": [
    "What is the maximum sustained signal rate per workflow execution?"
  ]
}
```
