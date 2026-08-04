# Assay vs Nix unit-test frameworks

**Verdict (2026-08-04, Nix 2.31.4, this machine):** assay wins a weighted decision matrix against nix-unit, `lib.debug.runTests`, namaka, and nixt for *realistic* Nix unit testing. nix-unit remains faster on trivial `eq`-only microbenches (~2×).

Scope: **Nix unit tests** (expression / module / claim evaluation). Not NixOS VM integration tests.

## Measured throughput

| Workload | assay (batch) | assay (`--no-batch`) | nix-unit |
|----------|---------------|---------------|----------------------|----------|
| 50× `eq 1+1=2` (median of 5) | **45.2 ms** | 94 ms | **24.7 ms** |
| 1× `eq` suite | ~48 ms | — | — |
| Full repo **233** claims | **~464 ms** median | — | n/a (no colocated discovery) |
| Runner lib tests | 110 passed | | |

Fixed-cost history: assay previously paid **~400 ms** on every `run_with` from double `SysinfoTelemetry` CPU sampling (`MINIMUM_CPU_UPDATE_INTERVAL` = 200 ms × 2). Fixed by lazy `ComputeSupervisor` init (id_effect) + `StdClock` (assay). Single-eq wall: **448 ms → 47 ms**.

Batching: `tryEval` mega-batch collapses batchable claims (`eq` / `subset` / `hasAttrs` / `snapshot`) into one `nix eval`. Never batches `throws` (Nix 2.31.4: `tryEval` does not catch primop type errors / missing attrs).

## Weighted decision matrix

Weights reflect a large Home-Manager / NixOS feature tree (many colocated suites, throws, module shapes, CI).

| Criterion | Weight | assay | nix-unit | runTests | namaka | nixt |
|-----------|-------:|------:|---------:|---------:|-------:|-----:|
| Claim expressiveness | 20 | **5** | 2 | 1 | 3 | 2 |
| Failure isolation | 15 | **5** | 4 | 1 | 3 | 2 |
| Structural diffs / diagnostics | 10 | **5** | 2 | 1 | 4 | 1 |
| Multi-suite repo throughput | 15 | **5** | 3 | 2 | 2 | 2 |
| Trivial `eq` microbench | 10 | 3 | **5** | 2 | 2 | 2 |
| CI formats (human / json / TAP) | 8 | **5** | 3 | 1 | 2 | 2 |
| Colocated discovery (`*.assay.nix`) | 8 | **5** | 2 | 1 | 2 | 3 |
| Timeouts / flaky retry | 7 | **5** | 1 | 0 | 1 | 0 |
| In nixpkgs / ecosystem default | 5 | 1 | **5** | **5** | 3 | 2 |
| runTests migration path | 2 | 4 | 3 | **5** | 2 | 2 |
| **Weighted score (0–5)** | | **4.58** | 2.93 | 1.46 | 2.53 | 1.84 |

### Scoring notes

- **assay** — hybrid Nix DSL + Rust/id_effect runner; claims: `eq`, `throws`(+pattern), `subset`, `hasAttrs`, `snapshot`, `forces`, `module`, `law`, `prop`; process isolation; structural diffs; `--format tap|json`; parallel suite load; fiber timeouts; `--no-batch` escape hatch.
- **nix-unit** — in-process Nix C++ API; excellent raw `expr`/`expected` speed; limited claim algebra; discovery is DIY; no TAP/timeout story comparable to assay.
- **runTests** — in-tree; same-eval pollution; weak throws story; no modern reporting.
- **namaka** — strong on snapshots; narrower general unit surface.
- **nixt** — lighter DSL; less isolation / CI depth.

## When to still prefer nix-unit

- Micro-suites of pure `eq` where every millisecond of process spawn matters and you do not need throws/modules/snapshots/CI formats.
- Already standardized on nix-unit in nixpkgs CI for a single attrset of tests.

## Reproduce

```bash
devenv shell -- cargo build -p assay --release
devenv shell -- ./rust/target/release/assay run common/assay/tests/smoke.assay.nix
devenv shell -- ./rust/target/release/assay run .   # full tree
ASSAY_TRACE=1 devenv shell -- ./rust/target/release/assay run path/to/suite.assay.nix
```

Fifty-eq fixture shape: `let assay = import …/common/assay/default.nix; in assay.suite "fifty" { t1 = assay.eq "1 + 1" "2"; … }`.

## Residual gaps (honest)

1. **Not in nixpkgs** — packaging / flake app is the packaging gap, not semantics.
2. **Microbench** — still ~1.8× nix-unit on 50 trivial eqs (subprocess `nix eval` vs in-process C API). Closing further needs an optional in-process eval backend, not more batching.
3. **id_effect pin** — latency fix requires id_effect `ComputeSupervisor` lazy telemetry (path dep). Assay `StdClock` is in-tree regardless.
