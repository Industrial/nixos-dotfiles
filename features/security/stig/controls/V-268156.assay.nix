# Colocated suite: V-268156 — sudo requires a password.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268156.nix {};
  config = fixture.evalWith [./V-268156.nix];
in
  assay.suite "stig-V-268156" {
    wheelNeedsPassword = assay.eq mod.security.sudo.wheelNeedsPassword true;
    reachesEvaluatedConfig = assay.eq config.security.sudo.wheelNeedsPassword true;
  }
