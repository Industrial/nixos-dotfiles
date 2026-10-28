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
  args = {
    lib = nixpkgsLib;
    pkgs = {};
  };

  specs =
    import ./deferred.nix args
    ++ import ./audit.nix args
    ++ import ./ssh.nix args
    ++ import ./system.nix args
    ++ import ./password.nix args;

  manifest = import ./../../lib/manifest.nix;
  ids = map (s: s.id) specs;
  deferredSpecs = specs;
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

    # Every control the host-wide profile carries has a VM test. That is the real exit
    # criterion for runtime verification of wave 1, asserted rather than counted by hand.
    vmCoverageSoFar = assay.eq (builtins.length ids) 68;
    totalControls = assay.eq manifest.count 103;

    coversEveryBaseSafeControl = let
      profileControls =
        map (n: builtins.head (builtins.match "(V-[0-9]+)\\.nix" n))
        (builtins.filter (n: builtins.match "V-[0-9]+\\.nix" n != null)
          (map (p: builtins.baseNameOf (toString p)) (import ./../../profiles/base-safe.nix {}).imports));
    in
      assay.eq (builtins.filter (id: !builtins.elem id ids) profileControls) [];

    # No control may appear in two spec groups — two tests named stig-V-<id> would collide
    # in the flake's checks attrset and one would silently shadow the other.
    noIdAppearsTwice = assay.eq (builtins.length ids) (builtins.length (builtins.attrNames (builtins.listToAttrs (map (id: {
        name = id;
        value = true;
      })
      ids))));
  }
