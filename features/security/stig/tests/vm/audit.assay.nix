# Colocated suite: the audit-subsystem VM specs.
let
  assay = import ./../../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  harness = import ./harness.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };
  specs = import ./audit.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };

  manifest = import ./../../lib/manifest.nix;
  ids = map (s: s.id) specs;
  specOf = id: builtins.head (builtins.filter (s: s.id == id) specs);
in
  assay.suite "stig-vm-audit" {
    allSpecsWellFormed = assay.eq (builtins.concatLists (map harness.specProblems specs)) [];
    everyIdIsInTheManifest = assay.eq (builtins.all (id: builtins.elem id manifest.ids) ids) true;
    noDuplicateIds = assay.eq (builtins.length ids) (builtins.length (builtins.attrNames (builtins.listToAttrs (map (id: {
        name = id;
        value = true;
      })
      ids))));

    # Every spec boots the real base-safe profile, so each test also exercises the
    # composition of all 36 audit rules rather than one control in isolation.
    everySpecUsesTheRealProfile =
      assay.eq (builtins.all (s: builtins.any (m: builtins.match ".*base-safe\\.nix" (toString m) != null) s.modules) specs) true;

    # Audit rules are loaded by a unit, so every spec must wait for it. A spec that greps
    # auditctl before the unit has run is racy and would fail intermittently in CI.
    everySpecWaitsForAuditd =
      assay.eq (builtins.all (s: builtins.match ".*wait_for_unit\\(\"auditd\\.service\"\\).*" s.script != null) specs) true;

    # The two specs whose assertions carry the most design weight.
    # V-268148 must prove the rules are present AND not duplicated -- that is the entire
    # reason it emits nothing.
    duplicateGuardSpecCountsRules =
      assay.eq (builtins.match ".*len\\(set\\(rules\\)\\) == 4.*" (specOf "V-268148").script != null) true;
    # V-268105 must prove the action is accepted AND is not the host-halting one.
    haltGuardSpecRejectsHalt =
      assay.eq (builtins.match ".*action != \"HALT\".*" (specOf "V-268105").script != null) true;
  }
