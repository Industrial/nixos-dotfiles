# Review rubric

## 1. Temporal fit

Determine whether the use case is appropriate for Temporal.

### Good fit indicators

- long-running, multi-step business process
- need for durable execution
- retries and failure recovery matter
- coordination across services matters
- human-in-the-loop or asynchronous progression exists
- waiting, timers, external callbacks, or approvals are required

### Poor fit indicators

- extreme low-latency requirements where milliseconds matter
- simple synchronous read-only operations
- using Temporal as a data plane instead of a control plane
- pushing large data blobs through workflows unnecessarily

### Flag the design if Temporal is used primarily for:

- direct query serving
- high-frequency micro-latency trading or similarly latency-critical paths
- bulk data transport instead of orchestration

### Questions to ask

- What business process is being orchestrated?
- Where does Temporal fit in the architecture?
- What starts the workflow?
- How often does it run?
- How long does it run?
- Is Temporal being used only where durable orchestration is needed?

## 2. Workflow review

Check whether workflow definitions follow Temporal execution constraints and best practices.

### Determinism

Workflows must be deterministic.

Flag:

- non-deterministic branching
- reliance on wall clock, random values, or mutable external state in workflow code
- use of run IDs for logic
- code changes that would break replay without versioning

Ask:

- Does the design acknowledge workflow replay?
- Are replay tests or replayer usage included?
- Is there a versioning plan for workflow evolution?

### Event history awareness

Workflows must account for event history growth.

Flag:

- unbounded loops without Continue-As-New strategy
- too many signals, activities, child workflows, or updates in one execution
- repeated large payloads in history
- no partitioning strategy for long-running or high-volume workflows

Recommend:

- use Continue-As-New at or before warning levels
- partition work with child workflows where justified
- keep workflow state compact

### Workflow ID usage

Verify:

- workflow IDs are meaningful business identifiers where appropriate
- uniqueness constraints are intentionally used as idempotency protection
- reuse policy is explicitly considered for closed workflows

Flag:

- frequent reuse of the same workflow ID
- logic based on run ID

### Timeouts

Assume default workflow timeouts are usually correct unless the design justifies changes.

Flag:

- workflow execution or run timeouts set without clear reason
- workflow timeouts used instead of explicit timers for business deadlines
- workflow task timeout implications ignored when histories are large or converters are expensive

Recommend:

- use timers inside workflows to model business timeouts
- tune workflow task timeout only when justified

### Failure semantics

Verify the design understands:

- non-Temporal failures fail workflow tasks and are retried
- workflow failures should not be used for transient operational issues
- workflow retry policies are generally not recommended

Flag:

- workflow retries added without strong justification
- assumptions that workflow exceptions behave like activity retries

## 3. Child workflow review

### Default rule

When in doubt, prefer an activity over a child workflow.

### Valid reasons to use child workflows

- partition large workloads to control event history growth
- isolate ownership boundaries
- route execution by task queue, trust boundary, or workload type
- model durable sub-processes with their own lifecycle

### Weak reasons

- organizing code structure
- reducing cost
- replacing normal language modularity

### Flag:

- child workflows used only for code organization
- too many child workflows started by one parent
- missing parent close policy reasoning
- assumptions that parent and child share local state

### Guidance

- starting more than 1000 child workflows from one parent is a design smell
- starting hundreds may already create latency concerns
- parent-child state sharing must happen through signals or explicit communication

### Questions to ask

- Why is this a child workflow instead of an activity?
- How many children can one parent start?
- Does the parent need the child result?
- What happens to children if the parent closes?

## 4. Activity review

### Core principle

Activities must be idempotent and treated as at-least-once.

### Idempotency

Flag:

- side-effecting activities without idempotency protection
- reliance on "this only runs once" assumptions
- lack of idempotency keys where external actions occur

### Granularity

Evaluate whether activities are too broad or too granular.

Guidance:

- bundling multiple operations is acceptable if timeout and retry boundaries are intentional
- too much bundling reduces observability and makes retries too coarse
- too much fragmentation increases event history and orchestration complexity

### Long-running activities

Verify:

- long-running activities heartbeat
- heartbeat timeout is short enough for timely failure detection
- heartbeat payload contains resumable progress where useful

### Payload size

Flag:

- large inputs or outputs that risk payload limits
- designs that pass blobs instead of references
- repeated large payload serialization in workflow history

Recommend:

- pass references instead of full payloads
- move data-heavy handling into activities
- compress payloads through a converter where appropriate

### Polling

Evaluate whether polling is designed efficiently.

Guidance:

- frequent polling should usually happen inside one activity loop
- infrequent polling can often use activity retries
- signals or async activity completion may be better than polling

### Timeouts

Verify:

- each activity has intentionally chosen timeout settings
- Start-To-Close is usually set
- Schedule-To-Close is used intentionally
- Schedule-To-Start is usually unset unless needed for host-specific routing or queue-unavailability detection

Flag:

- identical timeout policies applied blindly to all activities
- server-side timeouts shorter than normal upstream completion time
- duplicate-action risk from retries ignored

### Local activities

Prefer regular activities unless there is a specific need for:

- very high throughput
- very short-lived work
- large fan-out of short tasks

Flag local activities that:

- run longer than a few seconds
- are used without understanding tradeoffs
- require worker-side rate limiting or routing they cannot support well

### Cancellation

Verify cancellable activities heartbeat, or otherwise use supported semantics correctly.

## 5. Signal review

Signals are appropriate when workflow state must change during execution.

### Required understanding

Signals are:

- recorded in event history
- delivered with the next workflow task
- ordered per workflow execution
- subject to replay and determinism requirements

### Flag:

- signal handlers that perform heavy logic
- signal handlers invoking activities directly without strong reason
- non-idempotent signal handlers
- signal rates too high for one workflow execution
- signal volume that risks history growth or blocks Continue-As-New

### Best practice

Signal handlers should usually:

- update workflow state only
- avoid expensive computation
- let main workflow logic react afterward

### Questions to ask

- What sends the signal?
- How often can it happen?
- Can duplicates occur?
- Is Continue-As-New required?
- Could the signal rate prevent it?

## 6. Query review

Queries are best for reading workflow state.

### Rules

- queries are synchronous
- queries must be read-only
- queries are available for running and completed workflows, but require a worker on the task queue

### Flag:

- queries that mutate workflow state
- external stores used for live workflow state when queries would be simpler
- assumptions that query data is always available without workers running

## 7. Update review

Updates are appropriate when callers need validated, synchronous workflow state changes.

### Rules

- update handlers must be deterministic
- update handlers must be idempotent
- validation is recommended
- validators must not mutate workflow state
- rejected updates via validation are not written to history

### Flag:

- update handlers that mutate state non-deterministically
- missing validation for business-critical mutations
- designs that ignore latency or handler contention

### Guidance

Calling activities from update handlers is generally acceptable when justified and carefully designed.

If low latency matters, ask whether early-return patterns are needed.

## 8. Worker and task queue review

Check topology and routing for correctness, availability, and intent.

### Best practices

- run at least two workers for high availability
- all workers on the same task queue must register identical workflows and activities that may be dispatched there

### Unique task queues are justified for:

- rate limiting
- routing to special hardware such as GPUs
- worker-local filesystem or privileged environment access
- workload isolation or differentiated priority

### Flag:

- arbitrary task queue splits that add complexity without routing value
- inconsistent registrations on one queue
- assumptions of strict FIFO ordering
- intentional backlog growth without understanding Temporal's consumption semantics

### Rate limiting checks

Inspect whether:

- worker-side concurrency and rate limits are intentional
- server-side task queue activity limits are configured consistently

Note: server-side rate limiting is configured differently on Cloud (namespace settings via UI/tcld) vs self-hosted (dynamic config). Verify the design targets the correct mechanism.

### Questions to ask

- Why are there multiple task queues?
- Are special hardware or trust-boundary requirements involved?
- Is ordering assumed?
- Is backlog growth acceptable?

## 9. Timers, schedules, and cron

### Timers

Verify:

- timers are used for relative delays inside a workflow
- timer durations are at least one second when reliability matters

### Schedules

Use schedules when:

- a whole workflow execution must start at a calendar time
- execution is recurring
- a scheduled launch is more appropriate than an internal timer

Use timers instead when:

- the delay is relative to workflow state
- the delay belongs inside an already running workflow
- schedule action-per-second limits would be exceeded

### Flag:

- schedules used for single delayed starts when a normal workflow plus timer would be simpler
- overlap policy not considered
- jitter not considered when many schedules fire together
- risky backfill strategies

### Cron

Generally recommend schedules instead of cron workflows.

Flag:

- cron used where schedules are better supported
- cron combined with unsafe Continue-As-New assumptions

## 10. Side effects

Use side effects carefully.

### Guidance

- if the side effect can fail, prefer an activity
- side effects are not general-purpose integration hooks

### Flag:

- side effects used for failure-prone work
- side effects treated like normal external integration steps

## 11. Data converter and payload codec review

Check whether serialization, compression, and encryption choices are safe and operationally sound.

### Best practices

- compression is generally recommended
- encryption may justify a custom converter or codec
- key rotation must be considered if encryption is used
- search attributes are not protected by custom converters or codecs

Note: both Cloud and self-hosted support codec servers for decoding payloads in the UI and CLI. Cloud encrypts data at rest automatically with AES-256-GCM — custom encryption via a Payload Codec is for zero-trust requirements. Self-hosted has no automatic encryption at rest — you must implement a custom Payload Codec if encryption is needed.

### Cross-language datetime/duration warning

Flag designs that:

- assume datetimes or durations serialize consistently across languages
- mix languages without a common converter format

### Latency

Verify whether converter or codec latency:

- contributes to workflow task execution time
- risks workflow task timeout under large histories or high throughput

## 12. Visibility review

### Search attributes

Verify search attributes are used only for operational visibility, not business logic.

Note: both Cloud and self-hosted support custom search attributes, but per-namespace limits differ. Cloud allows up to 40 Keyword attributes and 20 of most other types. Self-hosted with SQL (v1.20+) allows fewer per namespace (e.g., 10 Keyword, 3 of most others). Self-hosted with Elasticsearch has no per-namespace limits but is subject to Elasticsearch mapping limits. Verify limits against the target deployment.

Flag:

- sensitive data in search attributes
- search attributes used to drive workflow decisions
- large duplicate state stored there
- assumptions of immediate consistency

### Memos and visibility APIs

Note:

- memos are eventually consistent
- visibility APIs are eventually consistent
- control flow must not depend on immediate freshness

## 13. Versioning review

Check whether workflow evolution is safe for replay and in-flight executions.

### Best practices

- prefer worker versioning for short-running workflows where appropriate
- use workflow patch/versioning APIs when needed for replay compatibility
- do not let patches accumulate forever
- remove version markers only after in-flight execution and retention concerns are handled

### Flag:

- workflow logic changing without replay-safe versioning
- patches with no retirement plan
- long-running workflows ignoring patch retention needs
- absent replayer-based testing

## 14. Continue-As-New and long-running workflows

Check whether long-lived workflows remain healthy over time.

### Best practices

- use Continue-As-New before history becomes too large
- pass forward enough state to resume safely
- recalculate and re-establish timers after Continue-As-New
- ensure pending activities and handlers are resolved before Continue-As-New

### Flag:

- timers assumed to carry over automatically
- child workflow behavior on parent close misunderstood
- signal or update handlers possibly still running during Continue-As-New
- missing state handoff design

## 15. Sessions and worker-specific routing

### Sessions

Sessions are only available in Go.

Note:

- if a worker process dies, session-related activities may retry together
- sessions should be clearly justified

### Worker-specific task queues

Approve these when used for:

- local files
- privileged environments
- specialized hardware
- sticky locality requirements

## 16. Storage optimization review

Check whether long-running workflows control storage growth and event-history cost.

### Best practices

- keep payloads small
- use references for large objects
- use Continue-As-New strategically
- avoid unnecessary history growth through over-fragmentation or excessive messaging

Note: Cloud retention is configurable from 1-90 days (default 30) via UI or tcld. Self-hosted retention is set when creating or updating a namespace via CLI or SDK. Verify the retention period is appropriate for the workflow's expected duration and audit requirements.
