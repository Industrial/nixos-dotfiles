# Colocated suite: V-268104 — auditd acts at 90% volume utilisation.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268104.nix {};
  config = fixture.evalWith [./V-268080.nix ./V-268103.nix ./V-268104.nix];
in
  assay.suite "stig-V-268104" {
    adminSpaceLeft = assay.eq mod.security.auditd.settings.admin_space_left "10%";
    reachesEvaluatedConfig = assay.eq config.security.auditd.settings.admin_space_left "10%";

    # Composes with V-268103 rather than overwriting it: both thresholds must survive together,
    # and the admin threshold must be the tighter one.
    composesWithSpaceLeft = assay.eq config.security.auditd.settings.space_left "25%";
  }
