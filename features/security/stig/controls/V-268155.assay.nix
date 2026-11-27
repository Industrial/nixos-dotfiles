# Colocated suite: V-268155 — no sudo credential caching.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  inherit (import <nixpkgs> {}) lib;
  # The definition is wrapped in mkAfter (see the module); the text is its content.
  ordering = (import ./V-268155.nix {inherit lib;}).security.sudo.extraConfig;
  mod.security.sudo.extraConfig = ordering.content;
  config = fixture.evalWith [./V-268155.nix ./V-268156.nix];
  # With the fleet's own sudo feature, which sets timestamp_timeout=-1 in the same option.
  withFleetSudo = fixture.evalWith [./V-268155.nix ./../../../nixos/security/sudo/default.nix];
  timeouts = text:
    builtins.filter (l: builtins.match ".*timestamp_timeout=.*" l != null) (lib.splitString "\n" text);
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

    # sudoers takes the LAST Defaults for a setting. The fleet's sudo feature sets -1 in the
    # same option, so this control's line has to be rendered after it or it is overridden.
    isOrderedAfterOtherDefinitions = assay.eq [(ordering._type or null) (ordering.priority or null)] ["order" 1500];
    fleetSudoAlsoSetsTheTimeout = assay.eq (builtins.length (timeouts withFleetSudo.security.sudo.extraConfig)) 2;
    winsOverTheFleetSudoTimeout =
      assay.eq (builtins.match ".*timestamp_timeout=0" (lib.last (timeouts withFleetSudo.security.sudo.extraConfig)) != null) true;
  }
