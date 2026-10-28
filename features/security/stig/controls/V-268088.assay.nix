# Colocated suite: V-268088 — SSH logs at VERBOSE.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268088.nix {};
  config = fixture.evalWith [{services.openssh.enable = true;} ./V-268088.nix];
in
  assay.suite "stig-V-268088" {
    logLevel = assay.eq mod.services.openssh.settings.LogLevel "VERBOSE";

    # Set through the canonical option, not the renamed alias, and it reaches sshd_config.
    reachesEvaluatedConfig = assay.eq config.services.openssh.settings.LogLevel "VERBOSE";

    # Raises the nixpkgs default rather than restating it — INFO does not log key
    # fingerprints, so this control is not a no-op.
    differsFromDefault = assay.eq ((fixture.evalWith [{services.openssh.enable = true;}]).services.openssh.settings.LogLevel == "VERBOSE") false;
  }
