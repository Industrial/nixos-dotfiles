# Colocated suite: V-268087 — a user-initiated session lock exists.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;

  # Unlike most controls in this set, this one is a function of pkgs.
  mod = import ./V-268087.nix {pkgs = {vlock = "vlock-derivation";};};
  config = fixture.evalWith [./V-268087.nix];
  packageNames = map (p: p.pname or p.name or "") config.environment.systemPackages;
in
  assay.suite "stig-V-268087" {
    installsOnePackage = assay.eq (builtins.length mod.environment.systemPackages) 1;
    installsVlock = assay.eq mod.environment.systemPackages ["vlock-derivation"];

    # The check is `which vlock`, so the real assertion is that it lands in the system profile.
    reachesEvaluatedConfig = assay.eq (builtins.elem "vlock" packageNames) true;

    # Not present by default — this control adds something.
    differsFromDefault = assay.eq (builtins.elem "vlock" (map (p: p.pname or p.name or "") (fixture.evalWith []).environment.systemPackages)) false;
  }
