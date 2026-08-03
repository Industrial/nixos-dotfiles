# Assay

Hybrid Nix unit testing: **claims authored as Nix values**, **outcomes produced by a Rust + `id_effect` runner** with isolated evaluation, normalization, and structured reporting.

## Why hybrid?

Pure Nix runners (`lib.runTests`, nix-unit, namaka, nixt) cannot reliably:

- catch per-case throws without polluting sibling cases,
- compare derivations safely (deep force → stack overflow),
- classify eval failures, enforce force-set claims, or run properties with shrink.

Assay keeps **authoring in Nix** and moves **evaluation, isolation, and diffing** to a capability-injected runner.

Full design lock: [history/20260803-232133-nix-assay-testing.md](../../../history/20260803-232133-nix-assay-testing.md).

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

## CLI

```bash
devenv shell -- assay run <path>          # file or directory of suites
devenv shell -- assay run common/assay/tests
```

Options (runner; see `assay run --help` when implemented):

- `--update-snapshots` — refresh golden files
- JSON / TAP output for CI

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

Runner and claim interpreter are under active development. The Nix DSL in `common/assay/` is stable as **data**; CLI behavior may evolve until wave-1 leaves ship.

## Related tools in devenv

`nix-unit`, `namaka`, and `nixt` remain available in devenv for comparison and migration. Assay does not remove them in v0.
