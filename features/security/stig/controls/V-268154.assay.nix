# Colocated suite: V-268154 (CAT I) — substituted store paths must be signed.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268154.nix {};
  config = fixture.evalWith [./V-268154.nix];
in
  assay.suite "stig-V-268154" {
    requireSigs = assay.eq mod.nix.settings.require-sigs true;
    reachesEvaluatedConfig = assay.eq config.nix.settings.require-sigs true;

    # Declared explicitly even though it matches the nixpkgs default, so the report proves it
    # rather than inferring it. This case documents that the declaration is intentional
    # redundancy, not an oversight.
    isDeclaredNotInherited = assay.eq (mod.nix.settings ? require-sigs) true;
  }
