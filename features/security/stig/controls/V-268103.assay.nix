# Colocated suite: V-268103 — auditd acts at 75% volume utilisation.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268103.nix {};
  config = fixture.evalWith [./V-268080.nix ./V-268103.nix];
in
  assay.suite "stig-V-268103" {
    spaceLeft = assay.eq mod.security.auditd.settings.space_left "25%";
    reachesEvaluatedConfig = assay.eq config.security.auditd.settings.space_left "25%";

    # 25% remaining is 75% used — the requirement's threshold, inverted. A value of "75%"
    # here would mean acting at 25% utilisation, which is the easy mistake to make.
    isExpressedAsRemaining = assay.eq (builtins.match "25%" mod.security.auditd.settings.space_left != null) true;
  }
