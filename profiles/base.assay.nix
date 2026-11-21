# Colocated suite for profiles/base.nix — evaluated selection, not source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  cfg = features.evalSelection {modules = [{profiles.base.enable = true;}];};
  on = features.enabledFeatures cfg;
  has = f: builtins.elem f on;
in
  assay.suite "base" {
    # base carries the headless-safe CLI set via cli-core, not cli-desktop.
    enablesCliCore = assay.eq cfg.profiles.cli-core.enable true;
    leavesCliDesktopOff = assay.eq cfg.profiles.cli-desktop.enable false;

    enablesCoreNixos = assay.eq (has "nixos") true;
    enablesUsers = assay.eq (has "nixos.users") true;
    # Store maintenance on every host is the Voltaic tools', not nix-collect-garbage /
    # auto-optimise-store.
    collectsWithVgc = assay.eq (has "nixos.vgc") true;
    optimisesWithVopt = assay.eq (has "nixos.vopt") true;

    # The STIG option surface must be on every host (flake.nix builds stigReport for all
    # four), but the base-safe control set is mimir's alone — ADR-0004.
    enablesStigSurface = assay.eq (has "security.stig") true;
    enablesExternalEvidence = assay.eq (has "security.stig.profiles.external-evidence") true;
    leavesBaseSafeOff = assay.eq (has "security.stig.profiles.base-safe") false;

    # vpush follows common/fleet.nix: on exactly where `pushesToCache` says (a builder
    # that asks for it and is not a cache), for every fleet host; so off on the cache.
    vpushFollowsTheFleet = let
      fleet = import ../common/fleet.nix;
      onFor = name:
        (features.evalSelection {
          modules = [
            {
              profiles.base.enable = true;
              networking.hostName = name;
            }
          ];
        })
        .features
        .nix
        .vpush
        .enable;
    in
      assay.eq (map onFor fleet.names) (map fleet.pushesToCache fleet.names);
    vpushOffOnTheCache = let
      fleet = import ../common/fleet.nix;
      cache = (builtins.head fleet.binaryCaches).name;
    in
      assay.eq
      (features.evalSelection {
        modules = [
          {
            profiles.base.enable = true;
            networking.hostName = cache;
          }
        ];
      })
      .features
      .nix
      .vpush
      .enable
      false;
  }
