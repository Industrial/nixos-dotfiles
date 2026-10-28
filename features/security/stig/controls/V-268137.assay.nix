# Colocated suite: V-268137 — no direct root login over SSH.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268137.nix {};
  config = fixture.evalWith [{services.openssh.enable = true;} ./V-268137.nix];
in
  assay.suite "stig-V-268137" {
    permitRootLogin = assay.eq mod.services.openssh.settings.PermitRootLogin "no";
    reachesEvaluatedConfig = assay.eq config.services.openssh.settings.PermitRootLogin "no";

    # "prohibit-password" would still allow key-based root login and is NOT what the control
    # asks for; this pins the stricter value.
    isFullyDisabledNotKeyOnly = assay.eq (mod.services.openssh.settings.PermitRootLogin == "prohibit-password") false;
  }
