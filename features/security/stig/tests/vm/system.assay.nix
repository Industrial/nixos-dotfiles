# Colocated suite: the kernel/network/time/session VM specs.
let
  assay = import ./../../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  harness = import ./harness.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };
  specs = import ./system.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };

  manifest = import ./../../lib/manifest.nix;
  ids = map (s: s.id) specs;
  specOf = id: builtins.head (builtins.filter (s: s.id == id) specs);
in
  assay.suite "stig-vm-system" {
    allSpecsWellFormed = assay.eq (builtins.concatLists (map harness.specProblems specs)) [];
    everyIdIsInTheManifest = assay.eq (builtins.all (id: builtins.elem id manifest.ids) ids) true;
    specCount = assay.eq (builtins.length specs) 13;

    everySpecUsesTheRealProfile =
      assay.eq (builtins.all (s: builtins.any (m: builtins.match ".*base-safe\\.nix" (toString m) != null) s.modules) specs) true;

    # The sysctl specs must read the RUNNING kernel. A Nix-declared sysctl proves nothing
    # about what the kernel ended up with, and the STIG's checks run `sysctl`.
    sysctlSpecsReadTheRunningKernel = assay.eq (builtins.all (id: builtins.match ".*sysctl -n.*" (specOf id).script != null)
      ["V-268141" "V-268160" "V-268161"])
    true;

    # V-268160's check is an equality test against 1, so the stricter value 2 is a finding.
    # The spec must say so, because "tighten it" is the natural instinct. See ADR-0003.
    kptrSpecRejectsTheStricterValue =
      assay.eq (builtins.match ".*value != \"2\".*" (specOf "V-268160").script != null) true;

    # V-268131 is satisfied by an absence, so it must assert the absence rather than a value.
    telnetSpecAssertsAbsence =
      assay.eq (builtins.match ".*machine\\.fail.*telnet.*" (specOf "V-268131").script != null) true;

    # AppArmor: the check requires enabled AND active, and the spec also proves the LSM is
    # present in the kernel, which the unit state alone does not show.
    apparmorSpecChecksTheKernelLsm =
      assay.eq (builtins.match ".*sys/kernel/security/lsm.*" (specOf "V-268173").script != null) true;
  }
