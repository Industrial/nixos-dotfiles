# OTP Supervision Patterns

Supervision trees for fault-tolerant Gleam/OTP applications.
Uses **gleam_otp v1.2.0** — verified against `server/build/packages/gleam_otp/src/`.

## Why Supervise

Without supervision, actors die silently:

```gleam
// CURRENT my_app.gleam pattern — actor crash = permanent loss
let assert Ok(store) = store.start()
let assert Ok(limiter) = rate_limiter.start()
// If store crashes at runtime, it's gone. No restart. No log. Silent failure.
```

A supervisor automatically restarts crashed children, isolates failures, and enforces startup ordering.

## Static Supervisor (`gleam/otp/static_supervisor`)

For a fixed set of children known at compile time:

```gleam
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleam/otp/actor

pub fn start_app() -> actor.StartResult(supervisor.Supervisor) {
  supervisor.new(supervisor.OneForOne)
  |> supervisor.restart_tolerance(intensity: 5, period: 60)
  |> supervisor.add(supervision.worker(store.start))
  |> supervisor.add(supervision.worker(rate_limiter.start))
  |> supervisor.start()
}

pub fn main() {
  let assert Ok(_) = start_app()
  process.sleep_forever()  // Keep VM alive!
}
```

### Builder API

```gleam
// Create supervisor with restart strategy
supervisor.new(strategy: Strategy) -> Builder

// Configure restart tolerance — max `intensity` restarts in `period` seconds
// Default: 2 restarts per 5 seconds. Exceeding this terminates the supervisor.
supervisor.restart_tolerance(builder, intensity: Int, period: Int) -> Builder

// Auto-shutdown when significant children terminate
supervisor.auto_shutdown(builder, value: AutoShutdown) -> Builder

// Add a child — children start in order added
supervisor.add(builder, child: ChildSpecification(data)) -> Builder

// Start the supervisor (links to parent)
supervisor.start(builder) -> Result(Started(Supervisor), StartError)

// Convert to ChildSpecification for nesting under another supervisor
supervisor.supervised(builder) -> ChildSpecification(Supervisor)
```

### AutoShutdown

```gleam
type AutoShutdown {
  Never            // Default — supervisor stays up regardless
  AnySignificant   // Shutdown when ANY significant child terminates normally
  AllSignificant   // Shutdown when ALL significant children terminate normally
}
```

## Restart Strategies

```gleam
type Strategy {
  OneForOne    // Only restart the crashed child
  OneForAll    // Restart ALL children when one crashes
  RestForOne   // Restart crashed child + all children started after it
}
```

| Strategy | Use When | Example |
|----------|----------|---------|
| `OneForOne` | Children are independent | Cache + rate limiter (default) |
| `OneForAll` | Children share state that must be consistent | Actor pair sharing a protocol |
| `RestForOne` | Later children depend on earlier ones | DB pool → cache → HTTP server |

**Default to `OneForOne`** unless you have a specific reason for the others.

## Child Specifications (`gleam/otp/supervision`)

```gleam
import gleam/otp/supervision

// Worker child — default: Permanent restart, 5000ms shutdown
supervision.worker(start_fn)

// Supervisor child — default: Permanent restart, unlimited shutdown
supervision.supervisor(start_fn)

// Customize restart behavior
supervision.restart(child, restart: Restart)

// Customize shutdown timeout (workers only)
supervision.timeout(child, ms: Int)

// Mark as significant for auto_shutdown
supervision.significant(child, significant: Bool)
```

### Restart Modes

```gleam
type Restart {
  Permanent   // Always restart — for long-lived services (DEFAULT)
  Transient   // Restart only on abnormal exit — for tasks that complete
  Temporary   // Never restart — for one-shot work
}
```

| Restart | When Child Exits Normally | When Child Crashes |
|---------|--------------------------|-------------------|
| `Permanent` | Restart | Restart |
| `Transient` | Don't restart | Restart |
| `Temporary` | Don't restart | Don't restart |

## Making Actors Supervisable

The start function must return `Result(Started(data), StartError)`:

```gleam
// actor.start() already returns this type!
pub fn start() -> actor.StartResult(Subject(Message)) {
  actor.new(initial_state())
  |> actor.on_message(handle_message)
  |> actor.start()
  // Returns Result(Started(Subject(Message)), StartError)
}
```

To pass the Subject to other parts of the app when using a supervisor, use `new_with_initialiser` + named lookup, or restructure so the supervisor returns child data.

### Named Actor Under Supervisor

```gleam
import gleam/erlang/process

// Create name ONCE at module level or startup
let store_name = process.new_name("store")

pub fn start() -> actor.StartResult(Subject(StoreMessage)) {
  actor.new(initial_state())
  |> actor.on_message(handle_message)
  |> actor.named(store_name)
  |> actor.start()
}

// Lookup from anywhere after supervisor starts
let store_subject = process.named_subject(store_name)
```

## Factory Supervisor (`gleam/otp/factory_supervisor`) — Dynamic Children

For spawning children at runtime from a template:

```gleam
import gleam/otp/factory_supervisor as factory
import gleam/otp/supervision

// Template: how to start each child, given an argument
pub fn start_pool() -> actor.StartResult(factory.Supervisor(Config, Subject(Msg))) {
  factory.worker_child(fn(config: Config) {
    actor.new(State(config: config))
    |> actor.on_message(handle_message)
    |> actor.start()
  })
  |> factory.restart_tolerance(intensity: 10, period: 60)
  |> factory.timeout(ms: 10_000)
  |> factory.start()
}

// At runtime — spawn a child with specific config
let assert Ok(started) = factory.start_child(pool, Config(url: "ftp://..."))
let child_subject = started.data
```

### Factory Builder API

```gleam
// Worker child template (default: Transient, 5000ms shutdown)
factory.worker_child(fn(arg) -> StartResult(data)) -> Builder

// Supervisor child template (unlimited shutdown)
factory.supervisor_child(fn(arg) -> StartResult(data)) -> Builder

// Register for named lookup
factory.named(builder, name) -> Builder

// Restart tolerance (default: 2 per 5s)
factory.restart_tolerance(builder, intensity: Int, period: Int) -> Builder

// Shutdown timeout for workers (default: 5000ms)
factory.timeout(builder, ms: Int) -> Builder

// Restart strategy (default: Transient)
factory.restart_strategy(builder, restart: Restart) -> Builder

// Start standalone
factory.start(builder) -> StartResult(Supervisor)

// Convert to child spec for nesting under static supervisor
factory.supervised(builder) -> ChildSpecification(Supervisor)

// Runtime operations
factory.start_child(supervisor, argument) -> StartResult(data)
factory.get_by_name(name) -> Supervisor  // lookup by registered name
```

### Example: Dynamic FTP Upload Workers

```gleam
import gleam/otp/factory_supervisor as factory

pub type UploadConfig {
  UploadConfig(host: String, path: String, data: BitArray)
}

pub fn start_upload_pool() -> actor.StartResult(factory.Supervisor(UploadConfig, Subject(UploadMsg))) {
  factory.worker_child(fn(config: UploadConfig) {
    actor.new(UploadState(config: config, status: Pending))
    |> actor.on_message(handle_upload)
    |> actor.start()
  })
  |> factory.restart_strategy(supervision.Transient)
  |> factory.timeout(ms: 30_000)
  |> factory.start()
}

// Spawn upload worker on demand
pub fn upload_file(pool, config: UploadConfig) {
  factory.start_child(pool, config)
}
```

## Recommended Supervision Tree for Web App

```
AppSupervisor (RestForOne)
├── Store actor (Permanent worker)
├── RateLimiter actor (Permanent worker)
└── Mist HTTP server (Permanent worker)
```

`RestForOne` because HTTP server depends on Store and RateLimiter — if either crashes, HTTP server should also restart to pick up the new Subject references.

```gleam
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision

pub fn start_supervised() -> actor.StartResult(supervisor.Supervisor) {
  supervisor.new(supervisor.RestForOne)
  |> supervisor.restart_tolerance(intensity: 5, period: 60)
  |> supervisor.add(supervision.worker(store.start))
  |> supervisor.add(supervision.worker(rate_limiter.start))
  |> supervisor.add(supervision.worker(fn() { start_http_server() }))
  |> supervisor.start()
}
```

## Nesting Supervisors

Use `supervisor.supervised()` to nest a supervisor as a child of another:

```gleam
let worker_pool_spec =
  factory.worker_child(worker_template)
  |> factory.supervised()  // → ChildSpecification

supervisor.new(supervisor.OneForOne)
|> supervisor.add(supervision.worker(store.start))
|> supervisor.add(worker_pool_spec)  // nested supervisor
|> supervisor.start()
```

## Common Supervision Mistakes

1. **`let assert Ok()` with no supervisor** — current `my_app.gleam` pattern. Actors die silently at runtime.

2. **`OneForAll` when `OneForOne` suffices** — unnecessary restarts of healthy children.

3. **Not handling `StartError`** — supervisor.start() can fail if children fail to init.

4. **`Permanent` for tasks that should complete** — use `Transient` for work that naturally finishes (e.g., file upload workers).

5. **Missing `process.sleep_forever()` in main** — main exits → all children die.

6. **Too-tight restart tolerance** — intensity: 1, period: 1 means one crash kills the supervisor. Use reasonable values (e.g., 5/60).

7. **Creating `process.new_name()` in the template function** — each call creates a new atom. Create once, pass as argument or use a single registration.
