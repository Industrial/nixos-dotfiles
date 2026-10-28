# Colocated suite: V-268155 — no sudo credential caching.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268155.nix {};
  config = fixture.evalWith [./V-268155.nix ./V-268156.nix];
in
  assay.suite "stig-V-268155" {
    disablesTimestampCache =
      assay.eq (builtins.match ".*timestamp_timeout=0.*" mod.security.sudo.extraConfig != null) true;

    # Zero, not merely short: any positive value leaves a window in which sudo does not
    # reauthenticate, which is what the control forbids.
    timeoutIsExactlyZero =
      assay.eq (builtins.match ".*timestamp_timeout=[1-9].*" mod.security.sudo.extraConfig) null;

    # Composes with V-268156 (sudo requires a password at all) rather than replacing it.
    composesWithWheelNeedsPassword = assay.eq config.security.sudo.wheelNeedsPassword true;
    reachesEvaluatedConfig =
      assay.eq (builtins.match ".*timestamp_timeout=0.*" config.security.sudo.extraConfig != null) true;
  }
