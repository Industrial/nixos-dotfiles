---
name: id_effect-compute-fabric
description: >-
  Teaches id_effect Compute Fabric: ResourcePolicy, supervisor admission, run/run_with
  installation, implicit parallelism (ADR 0007/0008), AdaptiveContext, and EDG auto-parallel
  effect! binds. Use when tuning CPU/memory policy, debugging throttling, or migrating off
  removed Parallelism APIs. No public Parallelism type in 0.4.0+.
---

# id_effect Compute Fabric

**Part III ch12** + ADRs **0007** (Compute Fabric) and **0008** (implicit parallelism).

**Prerequisites**: `id_effect-fundamentals`, `id_effect-capabilities`, `id_effect-concurrency`.

## Core idea

Every effect crosses **Compute Fabric** at the runtime boundary. Programs stay lazy `Effect` descriptions; Fabric decides **where, when, and how concurrently** work runs — subject to `ResourcePolicy`.

There is **no public `Parallelism` type** and no `*_with` / `*_par` policy surface (ADR 0008). Fabric is the only parallelism control plane.

## ResourcePolicy

Declarative CPU/memory rules via `MetricMode` (`Max`, `Target`, `Spread`, `Unlimited`):

```rust
use id_effect::compute::{ResourcePolicy, MetricMode, MetricPolicy, RebalanceStrategy};

let policy = ResourcePolicy {
  memory: MetricPolicy::new(MetricMode::Max { ceiling: 0.85 }),
  cpu: MetricPolicy::new(MetricMode::Max { ceiling: 1.0 }),
  rebalance: RebalanceStrategy::ThrottleAdmission,
};

// Helpers
let cap_mem = ResourcePolicy::memory_cap_max_cpu(0.85);
let spread = ResourcePolicy::unlimited_memory_cpu_spread(0.25);
```

| Component | Role |
|-----------|------|
| `TelemetryEngine` | Live CPU/memory feedback |
| `ComputeSupervisor` | Monitor → admit → place → rebalance loop |
| `AdmissionController` | Global permits from telemetry vs policy |
| `AdaptiveContext` | Thread-local snapshot: admission budget, Rayon threads, element threshold |
| `FiberPool` / `RayonComputePool` / `IoRuntime` | Unified local executors |

## Installing Fabric

**Default:** `run()` and `run_with()` install Fabric for the application run.

```rust
use id_effect::{run_with, provide!, succeed};

run_with([/* providers */], succeed(42));
// Fabric + AdaptiveContext refreshed at every run_blocking / run_async entry
```

Explicit fabric for custom runtimes:

```rust
use id_effect::compute::ComputeFabric;
use id_effect::{ThreadSleepRuntime, run_fork, succeed};

let fabric = ComputeFabric::memory_cap_max_cpu(0.85);
fabric.supervisor().tick();
let rt = ThreadSleepRuntime::with_fabric(fabric);
```

**Test escape hatch:** `run_blocking_serial` — no Fabric parallelism.

## Implicit parallelism (0.4.0)

| Workload | API | Escape hatch |
|----------|-----|--------------|
| Pure bulk (`vec::map`, stream chunks, …) | `map`, `filter`, `sort_with`, … | `*_serial` |
| Effectful stream | `Stream::map_effect` | `map_serial` |
| `effect!` independent `~` binds | EDG auto-parallel bind sets | `#[effect(serial)]` |

Dispatch path: `parallel_if_profitable` → `should_parallelize_current(len)` → Rayon when profitable.

**Removed (do not use):** `Parallelism`, `*_with`, `*_par`, `map_par_n`, `map_par_adaptive`, `compute::effective_threshold`.

## Effect Dependency Graph (EDG)

Independent `~` steps in `effect!` may run concurrently when EDG finds no data or capability conflict. Overlapping `&mut R` borrows and capability-key binds stay sequential.

```rust
#[effect(serial)]
effect! { |r| {
    ~step_a();
    ~step_b();
}}
```

## Examples (workspace)

| Ex | Topic |
|----|-------|
| `120_compute_fabric_memory_cap.rs` | Mock telemetry, admission headroom vs pressure, fiber on shared pool |
| `121_compute_fabric_cpu_spread.rs` | `MetricMode::Spread`, `CpuSpreadBucket`, scale-out job spec |
| `122_compute_fabric_effect_parallel.rs` | `Stream::map_effect` capped by admission budget |

```bash
cargo run -p id_effect --example 120_compute_fabric_memory_cap
cargo run -p id_effect --example 121_compute_fabric_cpu_spread
cargo run -p id_effect --example 122_compute_fabric_effect_parallel
```

## Not this → but that

| Not this | But that |
|----------|----------|
| `Parallelism::Auto { threshold: 1024 }` | primary `map` / `filter` — Fabric decides |
| `map_with(Parallelism::…, f)` | `map(f)` or `map_serial(f)` |
| `Stream::map_par_n(8, f)` | `Stream::map_effect(f)` (admission-bounded) |
| Manual thread pool per fiber | `ThreadSleepRuntime::with_fabric` + `FiberPool` |
| Caller picks Rayon threshold | `ResourcePolicy` + supervisor tick |

## Canonical sources

- Book: `crates/id_effect/book/src/part3/ch12-00-compute-fabric.md`
- Implicit parallelism: `book/src/part4/ch13-05-parallelism.md`
- ADRs: `docs/adrs/0007-compute-fabric.md`, `docs/adrs/0008-implicit-parallelism.md`

## Next

- Fibers/scopes (orthogonal to Fabric placement): [id_effect-concurrency](../id_effect-concurrency/SKILL.md)
- Streams under Fabric: [id_effect-streams](../id_effect-streams/SKILL.md)
- STM for shared state (not Fabric): [id_effect-stm](../id_effect-stm/SKILL.md)
