# OTP Actor Patterns (Erlang Target Only)

These patterns apply only when targeting Erlang/BEAM. They do not apply to JavaScript target.
Uses **gleam_otp v1.2.0** API — verified against `server/build/packages/gleam_otp/src/`.

## Actor Builder API

Create actors using the builder pattern:

```gleam
import gleam/otp/actor
import gleam/erlang/process.{type Subject}

// Simple actor — returns Subject(Message) to parent
actor.new(initial_state)
|> actor.on_message(handle_message)
|> actor.start()
// → Result(Started(Subject(Message)), StartError)

// Named actor — registered for lookup
actor.new(initial_state)
|> actor.on_message(handle_message)
|> actor.named(name)
|> actor.start()

// Custom initialiser — return any data to parent, custom selector
actor.new_with_initialiser(timeout_ms, fn(default_subject) {
  // Setup work here...
  Ok(
    actor.initialised(state)
    |> actor.selecting(custom_selector)  // optional: replace default selector
    |> actor.returning(data_for_parent)  // optional: return custom data
  )
})
|> actor.on_message(handle_message)
|> actor.start()
```

**Key types:**
- `Started(pid: Pid, data: data)` — returned on successful start; `data` is typically `Subject(Message)`
- `StartResult(data)` = `Result(Started(data), StartError)`
- `StartError` = `InitTimeout` | `InitFailed(String)` | `InitExited(ExitReason)`
- `Next(state, message)` — opaque; created via `continue()`, `stop()`, `stop_abnormal()`

## Message Handler

The handler receives current state and a message, returns what to do next:

```gleam
fn handle_message(state: MyState, msg: MyMessage) -> actor.Next(MyState, MyMessage) {
  case msg {
    Push(value) -> actor.continue(State(..state, data: value))
    Shutdown -> actor.stop()
    BadState(reason) -> actor.stop_abnormal(reason)
  }
}
```

- `actor.continue(new_state)` — keep running with updated state
- `actor.stop()` — normal exit, supervisor may restart depending on strategy
- `actor.stop_abnormal(reason)` — abnormal exit, linked processes also exit
- `actor.with_selector(next, selector)` — change which messages to receive going forward

## Message Design Patterns

### Fire-and-Forget (async)

```gleam
pub type Message {
  Push(value: String)
}

// Caller sends without waiting
process.send(actor_subject, Push("hello"))
// Or use the re-export:
actor.send(actor_subject, Push("hello"))
```

### Request-Reply (sync)

```gleam
pub type Message {
  Get(reply_to: Subject(String))
}

// In handler — send reply
fn handle_message(state, msg) {
  case msg {
    Get(reply_to) -> {
      process.send(reply_to, state.value)
      actor.continue(state)
    }
  }
}

// Caller waits for reply — panics on timeout (by design)
let value = actor.call(actor_subject, 5000, fn(reply_to) { Get(reply_to) })
```

`actor.call` panics on timeout intentionally — handle crashes via supervision, not error codes. Do NOT implement `try_call` — it was removed from gleam_erlang because it causes memory leaks (replies after timeout leak in mailbox).

## Client API Pattern (MANDATORY)

Every actor MUST have public client functions. Callers NEVER construct Message variants directly:

```gleam
// --- Public client API ---

pub fn get_record(store: Subject(StoreMessage), id: String) -> Option(Record) {
  actor.call(store, 5000, fn(reply_to) { GetRecord(reply_to, id) })
}

pub fn save_record(store: Subject(StoreMessage), record: Record) -> Result(Nil, String) {
  actor.call(store, 5000, fn(reply_to) { SaveRecord(reply_to, record) })
}

pub fn notify(store: Subject(StoreMessage), event: Event) -> Nil {
  process.send(store, Notify(event))  // fire-and-forget
}

// --- Message type (opaque or internal) ---

pub type StoreMessage {
  GetRecord(reply_to: Subject(Option(Record)), id: String)
  SaveRecord(reply_to: Subject(Result(Nil, String)), record: Record)
  Notify(event: Event)
}
```

This pattern is used by `helper/state/store.gleam` and `core/auth/rate_limiter.gleam` in this project.

## State Management Patterns

### Dict-based Cache

```gleam
pub type State {
  State(
    records: Dict(String, Record),
    config: Config,
  )
}

fn handle_message(state: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    Get(reply_to, id) -> {
      let result = dict.get(state.records, id) |> option.from_result
      process.send(reply_to, result)
      actor.continue(state)
    }
    Save(reply_to, record) -> {
      let records = dict.insert(state.records, record.id, record)
      process.send(reply_to, Ok(Nil))
      actor.continue(State(..state, records: records))
    }
    Delete(id) -> {
      let records = dict.delete(state.records, id)
      actor.continue(State(..state, records: records))
    }
  }
}
```

### Config Holder

```gleam
pub type State {
  State(max_retries: Int, base_url: String, api_key: String)
}
```

### Start Function Pattern

Extract Subject from Started:

```gleam
pub fn start() -> Result(Subject(Message), actor.StartError) {
  let builder =
    actor.new(initial_state())
    |> actor.on_message(handle_message)

  case actor.start(builder) {
    Ok(started) -> Ok(started.data)  // data = Subject(Message)
    Error(e) -> Error(e)
  }
}
```

## When to Use Actor vs Alternatives

| Need | Use |
|------|-----|
| Mutable state + concurrent access | Actor |
| High-read shared data (100k+ reads/sec) | ETS (see `otp-advanced.md`) |
| Persistent cross-restart state | Database |
| Stateless transformations | Plain functions |
| One-off async work | process.spawn (see `otp-advanced.md`) |
| Periodic background work | Actor with send_after (see `otp-advanced.md`) |

## Critical Rules

1. **`actor.named()` for registration — NEVER `process.register()`**

2. **`process.new_name()` once, reuse everywhere** — atoms never GC'd:
   ```gleam
   // WRONG — creates different atoms each call
   process.new_name("store")  // in two places = two atoms

   // RIGHT — create once at startup, pass everywhere
   let name = process.new_name("store")
   ```

3. **Trust blocking ops** — `supervisor.start()` and `actor.start()` block until children/actor ready. No defensive polling needed.

4. **NO try_call** — causes memory leaks (removed from gleam_erlang). Let timeouts crash; handle via supervision.

5. **Self-call deadlock** — actor can't receive while handling a message:
   ```gleam
   // DEADLOCK! Actor is busy handling, can't receive the call
   fn handle_message(state, msg) {
     let data = actor.call(self_subject, 5000, GetData)
   }
   ```

6. **Subject ownership** — only the process that created a Subject can receive on it:
   ```gleam
   // WRONG — subject created here, received in spawned process
   let subject = process.new_subject()
   process.spawn(fn() {
     process.receive(subject, 5000)  // FAILS! Wrong owner
   })
   ```

7. **5000ms timeout convention** — this project uses 5000ms for `actor.call` timeouts.

8. **Every actor needs supervision** — see `otp-supervision.md`. Bare `let assert Ok()` means silent death on crash.
