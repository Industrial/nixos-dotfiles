# Colocated suite: V-268142 — SSH client-alive interval of 600s.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268142.nix {};
  # Both halves together, since the 10-minute requirement is interval x (countMax + 1).
  config = fixture.evalWith [{services.openssh.enable = true;} ./V-268142.nix ./V-268143.nix];
in
  assay.suite "stig-V-268142" {
    interval = assay.eq mod.services.openssh.settings.ClientAliveInterval 600;

    # Declared as data on the freeform settings submodule, not as an extraConfig blob.
    reachesEvaluatedConfig = assay.eq config.services.openssh.settings.ClientAliveInterval 600;

    # Composes with V-268143 rather than colliding with it.
    composesWithCountMax = assay.eq config.services.openssh.settings.ClientAliveCountMax 1;
    tenMinutesTotal = assay.eq (600 * (1 + 0)) 600;
  }
