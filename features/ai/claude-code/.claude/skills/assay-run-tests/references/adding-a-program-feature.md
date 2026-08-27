# Adding a `program-<name>` feature — worked example

This is the session detail for adding a new program to `nix/features/`. It is the kind of operation that *looks* like one file edit but is actually five coordinated edits. Skipping any of them fails the assay.

## Real case: porting `maestro` from `~/.dotfiles/features/ai/maestro/`

Source: a NixOS-style `default.nix` with `environment.systemPackages = [ (pkgs.callPackage ./package.nix {}) ];` plus a separate `package.nix` derivation and standalone `*.assay.nix` files at each level.

Target: the devenv feature layout used by every other program in this repo.

### Step 1 — copy/port the derivation

Create `nix/features/maestro/package.nix` from the source `package.nix` verbatim, with one header line noting the port. The `stdenv.mkDerivation` body is unchanged.

The header gain was:

```nix
# Ported from ~/.dotfiles/features/ai/maestro/package.nix (NixOS module → devenv feature).
```

`pname` here is the single most important string — the assay test will match on it.

### Step 2 — write the feature wrapper

`nix/features/program-maestro.nix` (16 lines, mirrors `program-serena.nix`):

```nix
{
  lib,
  config,
  pkgs,
  ...}:
let
  cfg = config.cursor.features.program-maestro;
  maestro = pkgs.callPackage ./maestro/package.nix {};
in {
  options.cursor.features.program-maestro.enable =
    lib.mkEnableOption "Maestro local-first agent harness CLI (spec-to-ship loop)";

  config = lib.mkIf cfg.enable {
    packages = [maestro];
  };
}
```

If you find yourself adding `env`, `scripts`, or `enterShell`, you have moved past the minimal pattern. Check `program-hermes.nix` for the larger shape, but only if a real need drives it.

### Step 3 — write the co-located assay

`nix/features/program-maestro.assay.nix` (11 lines, mirrors `program-serena.assay.nix`):

```nix
let
  assay = import ../lib/assay.nix;
  h = import ../lib/feature-eval.nix {};
  off = h.feature ./program-maestro.nix {};
  on = h.feature ./program-maestro.nix {cursor.features.program-maestro.enable = true;};
  has = name: names: builtins.elem name names;
in
  assay.suite "program-maestro" {
    disabled = assay.eq off.packages [];
    package = assay.eq (has "maestro" on.packages) true;
  }
```

The string `"maestro"` in `has "maestro"` must equal `pname` from `package.nix`. Mismatch = silent `false`.

### Step 4 — register in the barrel

`nix/devenv.nix`: append `./features/program-maestro.nix` to the `imports` list. Order does not matter; alphabetical is fine for diff hygiene.

### Step 5 — update BOTH barrel-level assay files

This is the one that bites. Both files assert the feature list **and** the count, by literal name.

`nix/devenv.assay.nix`:

```nix
expected = [
  "program-context7"
  "program-hermes"
  "program-maestro"      # <-- new
  "program-omniroute"
  "program-roam-code-pypi"
  "program-serena"
];
# ...
featureCount = assay.eq (builtins.length names) 6;  # was 5
```

`nix/default.assay.nix`:

```nix
hermesFeatures = [
  "program-context7"
  "program-hermes"
  "program-maestro"      # <-- new
  "program-omniroute"
  "program-roam-code-pypi"
  "program-serena"
];
# ...
hermesFeatureCount = assay.eq (builtins.length (builtins.filter has hermesFeatures)) 6;  # was 5
```

`default.assay.nix` ALSO has a `sharedSmoke` list of features that come from the shared `../.cursor/nix` import. Don't add new program features there — only the project-specific barrel lists grow.

### Verification

```bash
assay run nix/
# expect: 30/30 passed, 0 failed, 0 errored (was 28/28 before; +2 from the new feature's two claims)
```

The 30/30 number is the sanity check. If the count is 28/30, 29/30, 31/30, or anything other than `previous + 2`, a barrel file is out of sync.

## Quick checklist

- [ ] `nix/features/<name>/package.nix` — derivation with `pname = "<name>"`
- [ ] `nix/features/program-<name>.nix` — wrapper with `mkEnableOption` + `packages = [...]` under `mkIf`
- [ ] `nix/features/program-<name>.assay.nix` — `disabled` + `package` claims
- [ ] `nix/devenv.nix` — added to `imports`
- [ ] `nix/devenv.assay.nix` — added to `expected`, bumped `featureCount`
- [ ] `nix/default.assay.nix` — added to `hermesFeatures`, bumped `hermesFeatureCount`
- [ ] `assay run nix/` green and `previous_count + 2` new claims
