# OTP Advanced Patterns

Selectors, timers, monitoring, async work, process registry, cleanup, and ETS.
Uses **gleam_otp v1.2.0** and **gleam_erlang** — verified against source.

## Selectors — Receiving Multiple Message Types

By default, an actor receives only from its own Subject. Selectors let an actor receive from multiple sources:

```gleam
import gleam/erlang/process

// Build a selector that receives from multiple subjects
let selector =
  process.new_selector()
  |> process.select(default_subject)            // actor's own messages
  |> process.select(other_subject)              // messages from another actor
  |> process.select_map(raw_subject, transform) // transform on receive

// Combine two selectors
let merged = process.merge_selector(selector_a, selector_b)

// Catch-all for unrecognized messages
let with_fallback = process.select_other(selector, fn(dynamic_msg) {
  // Convert Dynamic to your message type
  UnknownMessage(dynamic_msg)
})
```

### Setting Custom Selector During Init

```gleam
actor.new_with_initialiser(5000, fn(default_subject) {
  let selector =
    process.new_selector()
    |> process.select(default_subject)           // MUST re-add default!
    |> process.select_map(event_subject, fn(event) { EventReceived(event) })

  Ok(
    actor.initialised(initial_state)
    |> actor.selecting(selector)  // replaces default selector entirely
  )
})
```

**Important:** `actor.selecting()` REPLACES the default selector. If you use it, you MUST manually add the default subject to your custom selector, or the actor won't receive its own messages.

### Changing Selector During Message Handling

```gleam
fn handle_message(state, msg) {
  case msg {
    Subscribe(new_source) -> {
      let selector =
        process.new_selector()
        |> process.select(state.self_subject)
        |> process.select_map(new_source, fn(e) { Forwarded(e) })

      actor.continue(State(..state, sources: [new_source, ..state.sources]))
      |> actor.with_selector(selector)
    }
    _ -> actor.continue(state)
  }
}
```

## Timers and Periodic Messages

### `process.send_after` — Delayed Message Delivery

```gleam
import gleam/erlang/process

// Send a message to a subject after a delay
let timer = process.send_after(subject, delay_ms, message)

// Cancel a pending timer
case process.cancel_timer(timer) {
  process.Cancelled(remaining_ms) -> // was pending, cancelled
  process.AlreadyFinished -> // message already sent
}
```

### Self-Tick Pattern — Periodic Cleanup

An actor sends itself a message on a timer to trigger periodic work:

```gleam
pub type Message {
  // ... other messages
  Tick  // periodic self-message
}

pub fn start() -> actor.StartResult(Subject(Message)) {
  actor.new_with_initialiser(5000, fn(self) {
    // Schedule first tick
    process.send_after(self, 60_000, Tick)
    Ok(actor.initialised(initial_state()))
  })
  |> actor.on_message(handle_message)
  |> actor.start()
}

fn handle_message(state: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    Tick -> {
      // Do periodic work (cleanup stale entries, flush buffers, etc.)
      let cleaned = cleanup_stale(state)
      // Schedule next tick
      process.send_after(state.self, 60_000, Tick)
      actor.continue(cleaned)
    }
    // ... other messages
  }
}
```

**To store `self` in state:** receive the subject in `new_with_initialiser`'s callback and include it in the initial state.

## Process Monitoring

Watch another process and receive a message when it exits:

```gleam
import gleam/erlang/process.{type Pid}

// Start monitoring a process
let monitor = process.monitor(pid)

// Add monitor to selector — receive Down message when process exits
let selector =
  process.new_selector()
  |> process.select(self_subject)
  |> process.select_specific_monitor(monitor, fn(down: process.Down) {
    // down.pid — which process died
    // down.reason — why it died
    ProcessDied(down.pid, down.reason)
  })

// Monitor ANY monitored process (not just one specific monitor)
let selector =
  process.new_selector()
  |> process.select_monitors(fn(down) { AnyProcessDied(down) })

// Stop monitoring
process.demonitor_process(monitor)
```

### Actor Watching Another Actor

```gleam
pub type Message {
  WorkerDied(pid: Pid, reason: process.ExitReason)
  // ... other messages
}

fn start_watcher(worker_pid: Pid) -> actor.StartResult(Subject(Message)) {
  actor.new_with_initialiser(5000, fn(self) {
    let monitor = process.monitor(worker_pid)
    let selector =
      process.new_selector()
      |> process.select(self)
      |> process.select_specific_monitor(monitor, fn(down) {
        WorkerDied(down.pid, down.reason)
      })

    Ok(
      actor.initialised(State(worker: worker_pid))
      |> actor.selecting(selector)
    )
  })
  |> actor.on_message(fn(state, msg) {
    case msg {
      WorkerDied(pid, reason) -> {
        wisp.log_warning("[watcher] Worker " <> string.inspect(pid) <> " died: " <> string.inspect(reason))
        // Take recovery action...
        actor.continue(state)
      }
    }
  })
  |> actor.start()
}
```

## Async Work (No Built-in Task Module)

gleam_otp has NO Task abstraction. For one-off async work, use `process.spawn` with a Subject for the result:

```gleam
import gleam/erlang/process

pub fn do_async(work: fn() -> result) -> Subject(result) {
  let result_subject = process.new_subject()
  process.spawn(fn() {
    let result = work()
    process.send(result_subject, result)
  })
  result_subject
}

// Usage — spawn work, receive result later
let result_subject = do_async(fn() { expensive_computation() })
// ... do other work ...
let result = process.receive(result_subject, 30_000)
```

**In an actor context:** spawn the work and use a selector to receive the result as a message:

```gleam
pub type Message {
  StartComputation(data: String)
  ComputationDone(result: String)
}

fn handle_message(state, msg) {
  case msg {
    StartComputation(data) -> {
      let self = state.self_subject
      process.spawn(fn() {
        let result = expensive_work(data)
        process.send(self, ComputationDone(result))
      })
      actor.continue(state)
    }
    ComputationDone(result) -> {
      // Process the result
      actor.continue(State(..state, last_result: result))
    }
  }
}
```

**Third-party option:** Taskle v2.0.0 provides Elixir-style Task API (async/await). NOT in project deps — requires user approval to add.

## Process Registry and Naming

### Built-in: `process.Name`

```gleam
import gleam/erlang/process

// Create a name ONCE — atoms never GC'd, so never create dynamically
let name = process.new_name("store")

// Register actor with name
actor.new(state)
|> actor.named(name)
|> actor.start()

// Lookup from anywhere
let subject: Subject(Message) = process.named_subject(name)
```

### Named Factory Supervisor

```gleam
let pool_name = process.new_name("upload_pool")

factory.worker_child(template)
|> factory.named(pool_name)
|> factory.start()

// Lookup from anywhere
let pool = factory.get_by_name(pool_name)
factory.start_child(pool, config)
```

### Third-Party Registries

These are NOT in project deps — evaluate before adding:

- **Chip** — Process registry with group support
- **Glyn** — PubSub (publish to topic, subscribe to receive)
- **Singularity** — Singleton processes (ensure only one instance cluster-wide)

## Actor Cleanup / Graceful Shutdown

gleam_otp actors have no `terminate` callback. Cleanup options:

### Option 1: Explicit Shutdown Message

```gleam
pub type Message {
  Shutdown
  // ...
}

fn handle_message(state, msg) {
  case msg {
    Shutdown -> {
      // Cleanup work here
      flush_buffers(state)
      close_connections(state)
      actor.stop()
    }
    // ...
  }
}
```

### Option 2: Trap Exits in Initialiser

Trap exit signals and handle them as messages:

```gleam
import gleam/erlang/process

actor.new_with_initialiser(5000, fn(self) {
  // Trap exits — converts exit signals to messages
  process.trap_exits()

  let selector =
    process.new_selector()
    |> process.select(self)
    |> process.select_trapped_exit(fn(exit: process.ExitMessage) {
      CleanupAndStop(exit.reason)
    })

  Ok(
    actor.initialised(state)
    |> actor.selecting(selector)
  )
})
|> actor.on_message(fn(state, msg) {
  case msg {
    CleanupAndStop(reason) -> {
      wisp.log_info("[actor] Shutting down: " <> string.inspect(reason))
      flush_state_to_db(state)
      actor.stop()
    }
    // ... normal messages
  }
})
```

### Supervision Shutdown Timeout

The supervisor sends an exit signal, then waits up to `timeout` ms before force-killing:

```gleam
supervision.worker(start_fn)
|> supervision.timeout(ms: 10_000)  // 10s grace period for cleanup
```

Default: 5000ms for workers. Supervisors get unlimited time.

## ETS (Erlang Term Storage)

**NOT in project deps** — no bravo/carpenter installed.

### When to Consider ETS Over Actor Dict

| Characteristic | Actor Dict | ETS |
|---------------|-----------|-----|
| Read concurrency | Sequential (one at a time) | Fully concurrent |
| Write concurrency | Sequential | Concurrent (with caveats) |
| Consistency | Strong (sequential mailbox) | Eventual (per-key atomic) |
| Read-heavy workload (100k+/sec) | Bottleneck | Ideal |
| This project's scale | Sufficient | Overkill |

**For this project:** Actor Dict is fine. The store and rate_limiter handle moderate traffic. Consider ETS only if profiling shows actor mailbox backlog.

### If ETS Is Approved: Bravo v4.0.1

```gleam
import bravo
import bravo/uset  // Unique Set — most common

// Create table (once, at startup)
let assert Ok(table) = uset.new("cache", bravo.Public)

// Insert/update
uset.insert(table, [#("key", value)])

// Lookup
case uset.lookup(table, "key") {
  [#(_, value)] -> Some(value)
  [] -> None
}

// Delete
uset.delete(table, "key")
```

Table types: `USet` (unique keys), `OSet` (ordered), `Bag` (duplicate keys), `DBag` (duplicate keys+values).

## Best Practices Summary

1. **Keep actor state small** — offload large data to ETS or database
2. **Prefer `actor.call` (sync) for reads** — simple, predictable
3. **Use `process.send` (async) for fire-and-forget writes** — no blocking
4. **Never block in `handle_message`** — spawn a process for heavy work
5. **5000ms timeout** is project convention for `actor.call`
6. **Log actor startup/shutdown** for observability (`wisp.log_info`/`wisp.log_error`)
7. **Name actors** for lookup; pass Subjects for direct references
8. **Supervise everything** — see `otp-supervision.md`

## Common Pitfalls

1. **Unsupervised processes die silently** — always use a supervisor
2. **Unbounded actor state growth** — add cleanup (TTL, max size, periodic flush)
3. **Actor state as database** — state lost on crash; persist critical data to DB
4. **Blocking message handler** with long operations — spawn for heavy work
5. **Dynamic atom creation** — finite table (~1M), never GC'd; create names once
6. **Forgetting `process.sleep_forever()` in main** — all children die when main exits
7. **Sync calls inside message handlers** — deadlock risk if calling self or creating circular dependencies between actors
