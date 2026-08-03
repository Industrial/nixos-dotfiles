# Assay eval spike — `nix eval` process backend

## Context

Design history (`history/20260803-232133-nix-assay-testing.md`) records **H1**: per-test
evaluator isolation via the Nix C API should be fast enough for v0 (50 throw + 50 eq under
~500ms, no cross-case leak). If H1 fails, the fallback is a **process-pool** of isolated
evaluators.

`ProcessNixEval` in `src/lib/eval.rs` is the **v0 spike implementation** of that fallback:
each `eval_json` call runs `nix eval --impure --expr <expr> --json` in a **new OS process**.
Process boundaries give throw/recursion isolation without linking the Nix C API yet.

## Backend comparison

| Backend | Isolation | v0 status |
|---------|-----------|-----------|
| `ProcessNixEval` (`nix eval` subprocess) | Strong (new process per call) | **Implemented** — default Live provider (locked D4) |
| Nix C API (`libnixexpr`) | In-process, resettable state | **Optional** — alternate provider if H1 passes; not required for v1 ship |
| tvix | Alternate evaluator | Future capability |

> **Note:** The Nix C API is an optimization path, not a mission blocker. Assay ships with
> process-isolated `nix eval` as the Live `NixEvaluator` provider; a C API backend can be
> added later behind the same `EvalBackend` / capability trait without changing claim semantics.

## Running timings

From the repo root (with `nix` on `PATH`):

```bash
cd rust
cargo test -p assay eval::tests::nix_throw_isolated_per_call -- --ignored --nocapture
```

Wall-clock comparison (manual spike, not CI):

```bash
# 50 throws — each should fail independently without poisoning the next eval
time for i in $(seq 1 50); do
  nix eval --impure --expr 'builtins.throw "boom"' --json 2>/dev/null || true
done

# 50 trivial successes
time for i in $(seq 1 50); do
  nix eval --impure --expr '1 + 1' --json >/dev/null
done
```

Record results in this file or the history doc. If the C API path later beats subprocess
latency at equal isolation, switch the default `EvalBackend` and keep `ProcessNixEval` as a
portable fallback for environments without `libnixexpr` dev headers.

## stderr → outcome mapping

| `nix eval` signal | `AssayOutcome` |
|-------------------|----------------|
| exit 0 + valid JSON | `EvalResult::Ok` |
| stderr contains `infinite recursion` | `Recursion` |
| other non-zero exit | `EvalError { kind: "throw", … }` |
| `nix` not in `PATH` | `EvalError { kind: "nix_missing", … }` |

## Next steps

1. Benchmark subprocess pool vs single long-lived `nix eval` worker (if any).
2. Spike Nix C API evaluator behind the same `EvalBackend` trait.
3. Wire `interpret_claim` / runner to call `eval_json` and map `EvalResult` into the claim
   algebra.
