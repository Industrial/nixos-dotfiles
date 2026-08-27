---
name: id_effect-stm
description: >-
  Teaches id_effect STM: Stm, TRef, commit/atomically, stm!, TQueue/TMap/TSemaphore,
  stm::fail/retry. Use for composable in-memory shared state without mutex deadlocks.
  Transactions must be short and pure — no I/O inside Stm.
---

# id_effect STM (Software Transactional Memory)

**Part IV ch12** — optimistic concurrency for shared mutable state.

**Prerequisites**: `id_effect-fundamentals`, `id_effect-concurrency`.

## Core types

| Type | Role |
|------|------|
| `Stm<A>` | Lazy transactional description (like `Effect`, but for memory) |
| `TRef<T>` | Transactional mutable cell |
| `commit(stm)` | Lift `Stm<A>` → `Effect<A, E, ()>` with automatic retry on conflict |
| `atomically(stm)` | Effect.ts-style alias for `commit` |
| `stm!` | Do-notation for composing `Stm` steps (`~` bind) |

Nothing runs until `commit` / `atomically` executes the transaction.

## TRef basics

```rust
use id_effect::{TRef, stm, commit, run_blocking};

let counter = TRef::new(0_i32);

let txn: Stm<i32> = stm! {
    let n = ~ counter.read_stm();
    ~ counter.write_stm(n + 1);
    n + 1
};

let result = run_blocking(commit(txn), ())?;
```

| Operation | Returns |
|-----------|---------|
| `read_stm()` | `Stm<T>` |
| `write_stm(value)` | `Stm<()>` |
| `modify_stm(\|v\| …)` | `Stm<()>` |
| `update_stm(f)` | `Stm<T>` (read-modify-write) |

Share across fibers via `Arc<TRef<T>>` (`Clone + Send + Sync`).

## commit vs atomically

```rust
use id_effect::{commit, atomically, run_blocking};

// Inside Effect programs
let effect = commit(stm! { ~ cell.read_stm() });

// Quick sync path (equivalent semantics)
let v = run_blocking(atomically(stm), ())?;
```

## Transactional control flow

```rust
use id_effect::stm;

// Typed abort — NOT retried
stm! {
    if balance < amount {
        ~ stm::fail(InsufficientFunds);
    }
    // ...
}

// Block until a read changes (TQueue empty dequeue)
stm! {
    if queue.is_empty() {
        ~ stm::retry();
    }
    // ...
}
```

**Rule: no I/O inside `Stm`.** Network, disk, and long work belong in `Effect` *around* `commit`, not inside `stm!`. I/O inside transactions causes excessive retries and breaks STM assumptions.

## Transactional collections

| Type | Use |
|------|-----|
| `TQueue<T>` | Bounded FIFO; `offer` / `take` block via `stm::retry` |
| `TMap<K, V>` | Transactional hash map; atomic with `TRef` in same `stm!` |
| `TSemaphore` | Permit limiter; `acquire` / `release` inside transactions |

```rust
use id_effect::{TMap, TQueue, TSemaphore, commit, stm};

// TMap
commit(TMap::make().flat_map(|m| m.set("k", 10).flat_map(|_| m.get(&"k"))));

// TQueue — producer offers, consumer take blocks when empty
commit(queue.offer(item));
let job = commit(queue.take());

// TSemaphore — pool admission inside STM
commit(sem.acquire().flat_map(|_| sem.release()));
```

Compose sub-transactions: a large `stm!` retries as a **unit** — all writes commit or none do.

## Examples (workspace)

| Ex | Topic |
|----|-------|
| `077_stm_tref.rs` | `TRef` read/write via `commit` |
| `078_stm_atomically.rs` | `atomically` ≡ `commit` |
| `079_stm_contention.rs` | Two threads serialize on same `TRef` |
| `080_stm_tmap.rs` | `TMap` get/set |
| `081_stm_tqueue.rs` | `TQueue` offer/take |
| `082_stm_tsemaphore.rs` | `TSemaphore` acquire/release |

```bash
cargo run -p id_effect --example 077_stm_tref
cargo run -p id_effect --example 078_stm_atomically
# … through 082
```

## Not this → but that

| Not this | But that |
|----------|----------|
| `Mutex` for multi-value atomic updates | `stm!` over multiple `TRef` / `TMap` |
| `Arc<Mutex<T>>` across composed ops | nest operations in one `commit(stm! { … })` |
| HTTP/DB calls inside `stm!` | `commit` then `Effect` I/O, or I/O then short `commit` |
| `atomically` for effectful programs | `commit` inside `effect!` |
| Busy-wait on empty queue | `stm::retry()` or `TQueue::take` |

## When STM wins / loses

| Wins | Loses |
|------|-------|
| Multiple related values updated atomically | Long operations with I/O |
| Composing smaller transactional ops | High contention hot paths (retry cost) |
| Read-heavy, low-contention state | Holding locks across await points |

## Canonical sources

- Book: `crates/id_effect/book/src/part4/ch12-00-stm.md` (+ `ch12-01` … `ch12-04`)
- Examples: `crates/id_effect/examples/077_*` … `082_*`

## Next

- Structured fiber concurrency: [id_effect-concurrency](../id_effect-concurrency/SKILL.md)
- Compute placement (orthogonal): [id_effect-compute-fabric](../id_effect-compute-fabric/SKILL.md)
