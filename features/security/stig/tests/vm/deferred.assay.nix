# Colocated suite: the deferred-control specs are well formed and cover exactly the controls
# the baseline admits it cannot otherwise verify.
#
# This is the suite that keeps `security.stig.deferredVerification` honest from the other
# side: base-safe's suites assert every deferred control is registered with a reason, and this
# one asserts every registered control has a VM spec that actually inspects a booted system.
# Together they make it impossible to quietly leave a control unproven.
let
  assay = import ./../../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  harness = import ./harness.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };
  specs = import ./deferred.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };

  ids = map (s: s.id) specs;
  deferred = builtins.attrNames (import ./../../profiles/base-safe.nix {}).security.stig.deferredVerification;
  specOf = id: builtins.head (builtins.filter (s: s.id == id) specs);
in
  assay.suite "stig-vm-deferred" {
    allSpecsWellFormed = assay.eq (builtins.concatLists (map harness.specProblems specs)) [];

    # Exactly the deferred set — no more, no fewer.
    coversEveryDeferredControl = assay.eq (builtins.filter (id: !builtins.elem id ids) deferred) [];
    coversNothingElse = assay.eq (builtins.filter (id: !builtins.elem id deferred) ids) [];
    specCount = assay.eq (builtins.length specs) 7;

    # Every spec imports the control it claims to verify, so a copy-paste slip that tests the
    # wrong module is caught.
    everySpecImportsItsOwnControl =
      assay.eq (builtins.all (s: builtins.any (m: builtins.match ".*${s.id}\\.nix" (toString m) != null) s.modules) specs) true;

    # These controls exist precisely because configuration cannot answer them, so no spec here
    # should be inspecting a Nix option — it must be looking at the running system.
    everyScriptInspectsTheRunningSystem =
      assay.eq (builtins.all (s: builtins.match ".*machine\\.succeed.*" s.script != null) specs) true;

    # Spot-check the two with the most subtle assertions.
    stickyBitSpecEnumeratesRatherThanListing =
      assay.eq (builtins.match ".*find / -xdev -type d -perm -0002.*" (specOf "V-268140").script != null) true;
    shadowSpecProvisionsARealAccount =
      assay.eq ((specOf "V-268175") ? extraModules) true;
  }
