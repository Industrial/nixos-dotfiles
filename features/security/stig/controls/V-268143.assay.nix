# Colocated suite: V-268143 — SSH client-alive count max of 1.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268143.nix {};
  config = fixture.evalWith [{services.openssh.enable = true;} ./V-268142.nix ./V-268143.nix];
in
  assay.suite "stig-V-268143" {
    countMax = assay.eq mod.services.openssh.settings.ClientAliveCountMax 1;
    reachesEvaluatedConfig = assay.eq config.services.openssh.settings.ClientAliveCountMax 1;

    # 0 would disable the keepalive mechanism entirely rather than tighten it.
    isNotZero = assay.eq (mod.services.openssh.settings.ClientAliveCountMax > 0) true;
  }
