# Assay Nix DSL

Author-facing claim algebra for [Assay](../../rust/tools/assay/README.md). Tests are **data**: plain Nix attrsets the Rust runner evaluates in isolation.

Design background: [history/20260803-232133-nix-assay-testing.md](../../history/20260803-232133-nix-assay-testing.md).

## Import

```nix
let assay = import ./common/assay/default.nix;
in
  assay.suite "my-suite" { /* cases */ }
```

Or from a flake / nixpkgs overlay once wired:

```nix
assay = import (path + "/common/assay");
```

## Suites and cases

A **suite** groups named **cases**. Each case is a claim attrset.

```nix
assay.suite "arithmetic" {
  add = assay.eq (builtins.add 1 1) 2;
  divideByZero = assay.throws (_: 1 / 0) ".*divide.*";
}
```

`nix eval` on a suite file succeeds when throw expressions are deferred (see below).

## Claim constructors

| Constructor | Fields | Meaning |
|-------------|--------|---------|
| `assay.eq expr expected` | `claim = "eq"` | Normalized structural equality |
| `assay.throws expr pattern` | `claim = "throws"` | Eval fails; message matches regex `pattern` |
| `assay.subset expr expected` | `claim = "subset"` | `expected` is a sub-attrset of `expr` |
| `assay.hasAttrs expr attrs` | `claim = "hasAttrs"` | `expr` has every key in `attrs` |
| `assay.snapshot name expr` | `claim = "snapshot"` | Golden compare via runner store |
| `assay.module args` | `claim = "module"` | `lib.evalModules` + config predicates |
| `assay.drv args` | `claim = "drv"` | Derivation projection before compare |
| `assay.forces expr paths` | `claim = "forces"` | Only listed attrpaths may be forced |

`module` and `drv` merge `args` into the claim; typical keys:

```nix
assay.module {
  imports = [ ./my-module.nix ];
  args = { pkgs = /* ... */; };
  expect = { config.services.foo.enable = true; };
}

assay.drv {
  project = [ "name" "outPath" ];
  expr = pkgs.hello;
  expected = { name = "hello"; };
}
```

## Deferred expressions (throws)

Nix evaluates arguments eagerly when they appear in strict contexts. Wrap side-effecting or throwing code in a **lambda** so building the suite does not throw:

```nix
# Bad — fails at import time
bad = assay.throws (builtins.throw "boom") ".*";

# Good — runner applies the function in isolation
good = assay.throws (_: builtins.throw "boom") ".*";
```

## runTests / nix-unit compatibility

The runner also accepts the familiar attrset shape (mapped internally to `eq`):

```nix
{
  testAdd = {
    expr = builtins.add 1 1;
    expected = 2;
  };
}
```

Prefer `assay.suite` for new tests; use compat shape when migrating from `lib.runTests` or nix-unit.

## Examples in this repo

| File | Purpose |
|------|---------|
| [tests/smoke.nix](tests/smoke.nix) | One case per claim type; safe for `nix eval` |
| [tests/dogfood.nix](tests/dogfood.nix) | ≥15 cases mirroring [common/assert.nix](../assert.nix) helpers |

Run (once the CLI is installed):

```bash
devenv shell -- assay run common/assay/tests
```


## Whole-repo moon task

Discover and run every `*.assay.nix` under the repository (skips `.git`, `.devenv`, `node_modules`, `target`, …):

```bash
moon run test
# equivalent:
devenv shell -- assay run .
```

Colocate suites next to the Nix they exercise (`common/settings.assay.nix`, `features/…/foo.assay.nix`).

## Authoring checklist

1. One logical assertion per case name.
2. Use `assay.drv` instead of raw `eq` on derivations (avoids deep-compare stack overflow).
3. Prefer `subset` / `hasAttrs` for large configs.
4. Keep fixtures in separate `.nix` files; import them in `expr`.
5. Do not rely on global `NIX_PATH` mutations — inject `pkgs` via `module` args or capabilities (runner).

## Eval locally (no runner)

```bash
devenv shell -- nix eval --file common/assay/default.nix
devenv shell -- nix eval --file common/assay/tests/smoke.nix
devenv shell -- nix eval --file common/assay/tests/dogfood.nix
```

These check that the DSL and suites are valid Nix data, not that claims pass.
