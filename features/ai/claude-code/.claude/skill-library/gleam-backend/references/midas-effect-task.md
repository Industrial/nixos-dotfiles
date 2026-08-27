# Midas Effect/Task Guide

## Overview

Midas 2.0 provides an algebraic effects system split into two modules:
- `midas/effect` - Low-level effect types and constructors
- `midas/task` - Higher-level API with `Result` wrapping and `snag` errors

## Module Structure

### midas/effect (import as `e`)

Defines the core `Effect(a, key)` type and all effect constructors.

```gleam
import midas/effect as e

// Types defined in midas/effect:
e.Effect(a, key)      // The core effect type
e.FetchError          // Network error types
e.HashAlgorithm       // Sha1, Sha256, etc.

// Effect constructors (variants):
e.Done(value)         // Effect completed
e.Fetch(request, resume)
e.Read(file, resume)
e.Write(file, bytes, resume)
e.Log(message, resume)
// ... etc
```

### midas/task (import as `t`)

Wraps effects with `Result` types for simpler error handling.

```gleam
import midas/task as t

// Type alias:
pub type Task(return, reason, key) = e.Effect(Result(return, reason), key)

// Task helpers:
t.do(task, next)      // Compose tasks, propagate errors
t.try(result, then)   // Handle non-effectful Results
t.done(value)         // Complete with Ok(value)
t.abort(reason)       // Complete with Error(reason)
t.fetch(request)      // Fetch returning Task (with Result)
```

## Critical: What Lives Where

| Item | Module | Correct Usage |
|------|--------|--------------|
| `Effect(a, key)` | midas/effect | `e.Effect(a, key)` |
| `Done(value)` | midas/effect | Pattern: `e.Done(x)` |
| `Fetch(req, resume)` | midas/effect | Pattern: `e.Fetch(req, resume)` |
| `FetchError` | midas/effect | `e.FetchError`, `e.NetworkError(...)` |
| `do(eff, next)` | midas/task | `t.do(task, fn(x) { ... })` |
| `done(value)` | midas/task | `t.done(data)` |
| `abort(reason)` | midas/task | `t.abort(snag.new("error"))` |
| `fetch(request)` | midas/task | `t.fetch(req)` |

## Common Mistakes

### Wrong: Using `t.` for effect types

```gleam
// WRONG - Effect is not in midas/task
pub fn run(task: t.Effect(a, err)) -> t.Effect(a, err) { ... }

// CORRECT
pub fn run(task: e.Effect(a, key)) -> e.Effect(a, key) { ... }
```

### Wrong: Pattern matching with `t.Fetch`

```gleam
// WRONG - Fetch variant is in midas/effect
case task {
  t.Fetch(request, resume) -> ...
}

// CORRECT
case task {
  e.Fetch(request, resume) -> ...
}
```

### Wrong: Using `t.Abort`

```gleam
// WRONG - There is NO Abort variant
t.Abort(snag.new("error"))

// CORRECT - Return Done with Error result
e.Done(Error(snag.new("error")))

// Or use task helper:
t.abort(snag.new("error"))
```

### Wrong: Using `t.FetchError`

```gleam
// WRONG - FetchError is in midas/effect
fn map_response(r) -> Result(Response, t.FetchError) { ... }

// CORRECT
fn map_response(r) -> Result(Response, e.FetchError) { ... }
```

## Effect Runner Pattern

When writing an effect runner (interpreter), pattern match on `e.Effect` variants:

```gleam
import midas/effect as e
import midas/task as t
import gleam/httpc
import snag

pub fn run(task: e.Effect(a, key)) -> e.Effect(a, key) {
  case task {
    e.Fetch(request, resume) -> {
      let response_result = httpc.send_bits(request)
      let mapped = map_http_response(response_result)
      run(resume(mapped))
    }
    e.Done(value) -> e.Done(value)
    other ->
      e.Done(Error(snag.new("Effect not handled: " <> string.inspect(other))))
  }
}

fn map_http_response(
  response: Result(Response(BitArray), httpc.HttpError),
) -> Result(Response(BitArray), e.FetchError) {
  case response {
    Ok(response) -> Ok(response)
    Error(httpc.InvalidUtf8Response) -> Error(e.UnableToReadBody)
    Error(httpc.FailedToConnect(..)) -> Error(e.NetworkError("Failed to connect"))
    Error(httpc.ResponseTimeout) -> Error(e.NetworkError("Response timeout"))
  }
}
```

## Task Composition Pattern

When writing business logic, use task helpers:

```gleam
import midas/task as t
import snag

pub fn fetch_and_decode(
  request: Request(BitArray),
  decoder: decode.Decoder(a),
) {
  // t.fetch returns Task (Effect with Result)
  use response <- t.do(t.fetch(request))

  // Decode the response
  case json.parse_bits(response.body, decoder) {
    Ok(data) -> t.done(data)
    Error(e) -> t.abort(snag.new("Decode error: " <> string.inspect(e)))
  }
}
```

## Response Decoding Pattern

```gleam
pub fn decode_response(
  response: response.Response(BitArray),
  decoder: decode.Decoder(a),
) {
  case response.status {
    code if code >= 200 && code < 300 ->
      case json.parse_bits(response.body, decoder) {
        Ok(data) -> t.done(data)
        Error(reason) -> t.abort(snag.new("Bad JSON: " <> string.inspect(reason)))
      }
    code ->
      t.abort(snag.new("HTTP error: " <> int.to_string(code)))
  }
}
```

## Sequential Operations

```gleam
// Process list of items sequentially
pub fn process_all(items: List(Item)) {
  t.each(items, fn(item) {
    use result <- t.do(process_one(item))
    t.done(result)
  })
}

// Or use t.sequential for pre-built tasks
let tasks = list.map(items, process_one)
t.sequential(tasks)
```

## Mixing Effects and Tasks

When you need raw effect access (e.g., in a runner):

```gleam
import midas/effect as e
import midas/task as t

// Use e.do for raw effect composition
use resp <- e.do(e.fetch(request))
// resp is Result(Response, FetchError)

// Use t.do for task composition (auto error propagation)
use resp <- t.do(t.fetch(request))
// resp is Response (errors short-circuit)
```

## Type Signatures Reference

```gleam
// Effect module
e.Effect(a, key)  // Generic effect
e.FetchError      // NetworkError(String) | UnableToReadBody | NotImplemented

// Task module
t.Task(return, reason, key) = e.Effect(Result(return, reason), key)

// Common function signatures
t.fetch(Request(BitArray)) -> Task(Response(BitArray), snag.Snag, key)
t.done(a) -> e.Effect(Result(a, r), key)
t.abort(r) -> e.Effect(Result(a, r), key)
t.do(Task(a, r, k), fn(a) -> Task(b, r, k)) -> Task(b, r, k)
```
