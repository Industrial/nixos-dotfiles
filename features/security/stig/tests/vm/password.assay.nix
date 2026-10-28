# Colocated suite: the password-policy VM specs.
let
  assay = import ./../../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  harness = import ./harness.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };
  specs = import ./password.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };

  manifest = import ./../../lib/manifest.nix;
  ids = map (s: s.id) specs;
  specOf = id: builtins.head (builtins.filter (s: s.id == id) specs);
in
  assay.suite "stig-vm-password" {
    allSpecsWellFormed = assay.eq (builtins.concatLists (map harness.specProblems specs)) [];
    everyIdIsInTheManifest = assay.eq (builtins.all (id: builtins.elem id manifest.ids) ids) true;
    specCount = assay.eq (builtins.length specs) 8;

    everySpecUsesTheRealProfile =
      assay.eq (builtins.all (s: builtins.any (m: builtins.match ".*base-safe\\.nix" (toString m) != null) s.modules) specs) true;

    # The credit specs must reject a POSITIVE value, not merely check the key is present.
    # A positive credit grants length allowance for having a character class instead of
    # requiring one — the inverse of the requirement, and what the checks call a finding.
    creditSpecsRejectPositiveValues = assay.eq (builtins.all (id: builtins.match ".*value < 0.*" (specOf id).script != null)
      ["V-268126" "V-268127" "V-268128" "V-268145"])
    true;

    # One spec has to prove the six-way merge survived, since the published fix texts for
    # these controls are mutually exclusive assignments to one file.
    mergeIsProven =
      assay.eq (builtins.match ".*was lost in the merge.*" (specOf "V-268169").script != null) true;

    # login.defs is written by three controls; the delay spec proves the other two survived.
    loginDefsMergeIsProven =
      assay.eq (builtins.match ".*ENCRYPT_METHOD was lost.*" (specOf "V-268171").script != null) true;
  }
