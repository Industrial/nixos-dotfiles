# Assay Nix DSL

Author-facing claim algebra for [Assay](https://github.com/Industrial/assay). Tests are **data**: plain Nix attrsets the Rust runner evaluates in isolation.

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
| `assay.eq actual expected` | `claim = "eq"`, `actual`, `expected` | Real Nix values; suite eval computes both; runner compares JSON (no re-eval) |
| `assay.throws expr pattern` | `claim = "throws"`, `expr` (Nix **source string**) | Eval fails; optional message substring `pattern` |
| `assay.subset actual expected` | `claim = "subset"`, `actual`, `expected` | `expected` is a sub-attrset of `actual` |
| `assay.hasAttrs actual attrs` | `claim = "hasAttrs"`, `actual`, `attrs` | `actual` has every key in `attrs` |
| `assay.snapshot name expr` | `claim = "snapshot"` | Golden compare via runner store |
| `assay.module args` | `claim = "module"` | `lib.evalModules` + config predicates |
| `assay.drv args` | `claim = "drv"` | Derivation projection before compare |
| `assay.forces expr paths` | `claim = "forces"` | Only listed attrpaths may be forced |

Prefer first-class values for `eq` / `subset` / `hasAttrs` (no quoted Nix blobs):

```nix
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { callPackage = path: args: "local-pkg"; };
  mod = import ./default.nix { inherit pkgs; };
in
  assay.suite "context7" {
    systemPackages = assay.eq mod.environment.systemPackages [ "local-pkg" ];
  }
```

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

Nix evaluates arguments eagerly when they appear in strict contexts, so `assay.throws` takes
the throwing expression as a **Nix source string**; the runner re-evaluates it in isolation.
The pattern is a plain **substring** of the error message, or `null` for "any error". A
function value is rejected (`cannot convert a function to JSON`).

```nix
# Bad — fails at import time
bad = assay.throws (builtins.throw "boom") "boom";

# Good — the runner evaluates the string
good = assay.throws "builtins.throw \"boom\"" "boom";
```

Inside the string, reference repo files as `${toString ./file.nix}`, not `${./file.nix}`:
the latter copies that one file into the store, where its own relative imports no longer
resolve.

## Evaluating NixOS modules (`nixos.nix`)

Assert on what a module **evaluates to**, not on what its source **says**. A suite that
regex-matches `builtins.readFile ./foo.nix` passes whenever the text looks right — a
refactor through `mkMerge`, a helper or an import breaks behaviour without failing it, and
a comment can fail it with no behaviour change.

```nix
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./foo.nix]; settings.hostname = "mimir";};
in
  assay.suite "foo" {
    enables = assay.eq cfg.services.foo.enable true;
    installs = assay.eq (nixos.hasPackage cfg "foo") true;
    noPorts = assay.eq (nixos.openTCPPorts cfg) (nixos.openTCPPorts nixos.baseline);
  }
```

- Evaluates against the **real NixOS option tree**, nixpkgs pinned from the root
  `flake.lock`: an option that does not exist is an eval error, not a silent pass.
- `settings` defaults to `common/settings.nix` for a placeholder host; override per suite.
- `inputs` is every root flake input, resolved from `flake.lock` the way `nix` does
  (follows included) and lazily: a suite pays only for inputs its modules reach. Also
  exposed as `nixos.flakeInputs`, e.g. `nixos.flakeInputs.nixvim.nixosModules.nixvim`.
  Whole hosts evaluate too: `(import ../lib/mk-host.nix {inputs = nixos.flakeInputs;} "mimir").config`
  — see `hosts/fleet.assay.nix`.
- Helpers: `eval`, `evalSystem` (full result incl. `options`), `packageNames`,
  `hasPackage`, `baseline` (empty system to diff against), and two port views:
  `openTCPPorts`/`openUDPPorts` (open on any interface, tailscale0 included: the strict
  bar for "this feature adds no ports") and `publicTCPPorts`/`publicUDPPorts` (reachable
  from an untrusted interface: what a host actually exposes).

Matching text is still right when the **text is the artifact**: a Lua file, a shell
script, or a generated config string such as `programs.ssh.extraConfig`.

`bin/assay-source-match-check` (run in CI) fails any suite that `readFile`s a `.nix` file.
Suites predating it are listed in `source-match-allowlist.txt`: migrate one, delete its
line. An entry that no longer offends fails the check until it is removed, so the list only
shrinks.

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
5. Assert on evaluated config via `nixos.nix`, never on module source text.
6. Do not rely on global `NIX_PATH` mutations — inject `pkgs` via `module` args or capabilities (runner).

## Eval locally (no runner)

```bash
devenv shell -- nix eval --file common/assay/default.nix
devenv shell -- nix eval --file common/assay/tests/smoke.nix
devenv shell -- nix eval --file common/assay/tests/dogfood.nix
```

These check that the DSL and suites are valid Nix data, not that claims pass.

### Value-mode claims (first-class Nix values)

For `eq`, `subset`, and `hasAttrs`, suites may pass **already-evaluated JSON values** instead of Nix expression strings:

- `eq`: use `actual` (or `left`/`right` value fields per schema) — not `expr`/`expected` strings
- `subset`: `actual` + `expected` subset object
- `hasAttrs`: `actual` + `attrs` list

If the JSON object has an `actual` key, the runner uses value-mode variants (`EqValues`, `SubsetValues`, `HasAttrsValues`). Otherwise legacy expr strings are used.

`throws` claims always keep Nix expression strings (and optional `pattern`).

## Coverage gate

Every in-scope `*.nix` must have a colocated `<stem>.assay.nix`.

```bash
devenv shell -- bin/assay-coverage-check
devenv shell -- assay run .
```

Exclusions live in `common/assay/coverage-allowlist.txt` (generated flakes, `Cargo.nix`, hermes templates).
CI runs both via `.github/actions/assay` on main and PRs.
