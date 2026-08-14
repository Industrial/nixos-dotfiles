# Review checklist

Score each item as one of:

- `pass`
- `fail`
- `inconclusive`
- `not_applicable`

## Workflows

- Workflow use case is appropriate for Temporal
- Workflow logic is deterministic
- Replay/versioning concerns are addressed
- Event history growth is managed
- Workflow ID strategy is intentional
- Workflow timeouts are not misused
- Workflow failure semantics are understood
- Workflow retry policy is not added without strong reason

## Child Workflows

- Child workflows are used only where justified
- Parent does not start an excessive number of children
- Parent close policy is intentional
- Parent/child communication model is explicit

## Activities

- Activities are idempotent
- Activity granularity is appropriate
- Long-running activities heartbeat
- Payload sizes are safe
- Large data is passed by reference where possible
- Polling strategy is efficient
- Timeout settings are activity-specific
- Retry policy is intentional
- Cancellation handling is correct
- Local activities are justified

## Signals

- Signals are used where runtime state change is needed
- Signal handlers are deterministic and idempotent
- Signal handlers avoid heavy work
- Signal volume is safe
- Continue-As-New compatibility is considered

## Queries

- Queries are read-only
- Queries are used appropriately for state reads

## Updates

- Updates are deterministic and idempotent
- Validation is used where appropriate
- Update-handler behavior is well scoped

## Workers and Task Queues

- Worker count supports high availability
- Registrations are consistent per task queue
- Task queue strategy is intentional
- Rate limiting is considered
- Ordering assumptions are valid

## Timers / Schedules / Cron

- Timers are used appropriately
- Schedule usage is justified
- Overlap policy is intentional
- Jitter/backfill considerations are addressed
- Cron is avoided unless specifically required

## Data / Visibility

- Data converter choices are intentional
- Compression/encryption concerns are handled
- Datetime cross-language serialization is addressed
- Search attributes are used only for visibility
- Sensitive data is not stored in search attributes
- Eventual consistency is understood for memos/visibility

## Versioning / Long-running execution

- Replay-safe versioning strategy exists
- Patches have a cleanup plan
- Continue-As-New strategy exists where needed
- Timer and state carry-forward behavior is handled
