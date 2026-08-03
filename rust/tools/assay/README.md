# Assay

Hybrid Nix unit testing: **claims authored as Nix values**, **outcomes produced by a Rust + `id_effect` runner** with isolated evaluation, normalization, and structured reporting.

## Why hybrid?

Pure Nix runners (`lib.runTests`, nix-unit, namaka, nixt) cannot reliably:

- catch per-case throws without polluting sibling cases,
- compare derivations safely (deep force → stack overflow),
- classify eval failures, enforce force-set claims, or run properties with shrink.

Assay keeps **authoring in Nix** and moves **evaluation, isolation, and diffing** to a capability-injected runner.

Full design lock: [history/20260803-232133-nix-assay-testing.md](../../../history/20260803-232133-nix-assay-testing.md).

Reimplementation plan: [history/20260804-002152-assay-id-effect-reimplementation.md](../../../history/20260804-002152-assay-id-effect-reimplementation.md).

Nix DSL reference: [common/assay/README.md](../../../common/assay/README.md).

## Architecture

```text
Nix suites (common/assay)  →  assay run  →  Rust runner (id_effect)
                                    ↓
                          Pass | Fail | EvalError | SnapshotMismatch | …
```

| Layer | Location | Role |
|-------|----------|------|
| DSL | `common/assay/default.nix` | `suite`, `eq`, `throws`, `subset`, … |
| Runner | `rust/tools/assay/` | Discover suites, eval in isolation, normalize, report |
| Goldens | `testdata/goldens/` | Snapshot storage |
| Compat | `fixtures/compat/` | runTests / nix-unit shaped fixtures |

## id_effect runner

**Doctrine:** library code returns `Effect`; capabilities are the only I/O; cases run as fibers; soft assertion results are `CaseVerdict` in `Exit::Success`; infra is `Fail(InfraError)`; panics/leaks are `Die`. The CLI is a thin `run_with` edge.

Skill router (start here): [.cursor/skills/rust/id_effect/SKILL.md](../../../.cursor/skills/rust/id_effect/SKILL.md).

### Core signatures

Target (wave 2+ — capability-injected interpreter and orchestrator):

```rust
use id_effect::Effect;

// Claim interpreter — uses ~NixEvaluator / ~SnapshotStore inside effect!
fn interpret_claim(claim: &Claim) -> Effect<CaseVerdict, InfraError, AssayEnv>;

// Suite orchestrator — discover, run cases, aggregate report
fn run_suite(path: &Path, opts: &RunOptions) -> Effect<SuiteReport, InfraError, AssayEnv>;
```

Current v0 sync API (migration shim; `eval` passed explicitly until wave 2 lands):

```rust
pub fn interpret_claim(claim: &Claim, eval: &dyn EvalBackend) -> AssayOutcome;
pub fn run_suite(path: &Path, opts: &RunOptions) -> Vec<(String, AssayOutcome)>;
```

`normalize` / `diff` stay pure value morphisms — no `Effect` wrapper (decision D6).

### Capability providers

Injected via `Caps` / `AssayEnv = caps!(…)` — never globals.

| Capability | Marker (`caps.rs`) | Role | Live provider (v1) |
|------------|-------------------|------|---------------------|
| Nix evaluator | `NixEvaluator` | `eval_json` for claim expressions | `ProcessNixEval` (`nix eval` subprocess — see [SPIKE.md](SPIKE.md)) |
| Snapshot store | `SnapshotStore` | Golden read/write under `testdata/goldens/` | Filesystem-backed store |
| Clock | `TestClock` | Timeouts, fiber races, deterministic tests | `LiveClock` at CLI edge; `TestClock` in unit tests |

Optional: `FakeStore` (sandbox / IFD module tests) and `NixWorkerPool` (bounded concurrency) are planned behind separate capability keys.

Unit tests use `mock_capability!` + `build_env` + `run_test` — see the id_effect testing chapter below.

### id_effect book anchors

Local book checkout (adjust if your `id_effect` path differs):

| Topic | Chapter | Path |
|-------|---------|------|
| `Exit` / verdict vs `Cause` | ch08 — Exit | `/data/Code/rust/id_effect/crates/id_effect/book/src/part3/ch08-02-exit.md` |
| Fibers, spawn, collect-all | ch09 — Concurrency | `/data/Code/rust/id_effect/crates/id_effect/book/src/part3/ch09-00-concurrency.md` |
| `run_test`, mocks, TestClock | ch15 — Testing | `/data/Code/rust/id_effect/crates/id_effect/book/src/part4/ch15-00-testing.md` |

## CLI

```bash
devenv shell -- assay run <path>          # file or directory of suites
devenv shell -- assay run common/assay/tests
```

Options (see `assay run --help`):

- `--format human|json|tap` — report format (default: human)
- `--json` — alias for `--format json` (backward compatible)
- `--update-snapshots` — refresh golden files

### Report formats

| Format | Use case |
|--------|----------|
| `human` | Local dev (PASS/FAIL lines + summary) |
| `json` | CI artifact / machine parsing |
| `tap` | Test Anything Protocol consumers |

Reporting uses `id_effect::Stream::from_iterable` over collected outcomes.
**v1 backpressure:** outcomes are buffered entirely before formatted output is
emitted (no live per-case streaming yet).

## Writing tests

```nix
let assay = import ../../../common/assay/default.nix;
in
  assay.suite "example" {
    ok = assay.eq (builtins.add 2 2) 4;
    fails = assay.throws (_: builtins.throw "nope") "nope";
  }
```

See [common/assay/README.md](../../../common/assay/README.md) for all claim types and authoring rules.

## runTests / nix-unit compatibility

Drop-in attrset shape is accepted for migration:

```nix
{
  myTest = {
    expr = builtins.length [1 2 3];
    expected = 3;
  };
}
```

The runner maps `expr` / `expected` to internal `eq` claims. Fixtures live under `fixtures/compat/`.

## Development

```bash
cd rust && cargo test -p assay
cd rust && cargo clippy -p assay --all-targets -- -D warnings
```

Rust testing conventions for this workspace: [../TESTING.md](../TESTING.md).

## Status

Wave 0 (`id_effect` deps) shipped. Waves 1–5 (caps, Effect interpreter, fibers, snapshots, schema/optics) are in flight. The Nix DSL in `common/assay/` is stable as **data**; runner APIs may evolve until wave 6 regression gate is green.

Evaluator backend: process-isolated `nix eval` is the v1 Live provider; the Nix C API remains **optional** (see [SPIKE.md](SPIKE.md)).

## Related tools in devenv

`nix-unit`, `namaka`, and `nixt` remain available in devenv for comparison and migration. Assay does not remove them in v0.
