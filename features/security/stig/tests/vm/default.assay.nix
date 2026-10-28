# Colocated suite: the VM test aggregator.
#
# Validates the aggregation itself without evaluating nixpkgs' test machinery — the specs are
# checked by their own group suites, and whether the resulting derivations build is what
# `moon run stig-vm-test` answers.
let
  assay = import ./../../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  harness = import ./harness.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };
  deferredSpecs = import ./deferred.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };

  manifest = import ./../../lib/manifest.nix;
  ids = map (s: s.id) deferredSpecs;
in
  assay.suite "stig-vm-tests" {
    # The aggregator throws on a malformed spec rather than building a useless VM. Proven by
    # exercising the same validator the aggregator uses.
    aggregatorValidatesSpecs = assay.eq (builtins.concatLists (map harness.specProblems deferredSpecs)) [];

    # Every id under test is a control the STIG actually defines — a typo'd id would otherwise
    # produce a test named after nothing.
    everyIdIsInTheManifest = assay.eq (builtins.all (id: builtins.elem id manifest.ids) ids) true;

    # Test names are the stig-V-<id> form the flake's checks and the moon task expect.
    namesAreStigPrefixed = assay.eq (builtins.all (id: builtins.match "V-[0-9]+" id != null) ids) true;

    # Wave 2 progress, asserted so the number in the runbook cannot drift from reality: 7 of
    # 103 controls have VM coverage so far, and those 7 are the ones with no alternative.
    vmCoverageSoFar = assay.eq (builtins.length ids) 7;
    totalControls = assay.eq manifest.count 103;
  }
