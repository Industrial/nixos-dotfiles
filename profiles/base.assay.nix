# Colocated suite for profiles/base.nix — evaluated selection, not source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  cfg = features.evalSelection {modules = [{profiles.base.enable = true;}];};
  on = features.enabledFeatures cfg;
  has = f: builtins.elem f on;

  inherit (nixos) lib;
  fleet = import ../common/fleet.nix;
  # The base profile's vpush switch as host `name` (plus `extra` modules) sees it.
  vpushWith = name: extra:
    (features.evalSelection {
      modules =
        [
          {
            profiles.base.enable = true;
            networking.hostName = name;
          }
        ]
        ++ extra;
    })
    .features
    .nix
    .vpush
    .enable;
  vpushOn = name: vpushWith name [];
  # The base profile's vci switch as host `name` (plus `extra` modules) sees it.
  vciWith = name: extra:
    (features.evalSelection {
      modules =
        [
          {
            profiles.base.enable = true;
            networking.hostName = name;
          }
        ]
        ++ extra;
    })
    .features
    .nix
    .vci
    .enable;
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

    # vpush is automatic: the base profile turns it on for every eligible builder-role host
    # (a builder that is not a cache, common/fleet.nix `pushesToCache`) with nothing
    # opt-in, keeps it off on the cache and on non-builders, and one option rolls it back.
    vpushOnForEveryEligibleBuilder = let
      eligible = lib.filter (n: fleet.hasRole "builder" n && !(fleet.isCacheIn fleet.hosts n)) fleet.order;
    in
      assay.eq [(map vpushOn eligible) (eligible != [])] [(map (_: true) eligible) true];
    vpushFollowsTheFleet = assay.eq (map vpushOn fleet.names) (map fleet.pushesToCache fleet.names);
    vpushOffOnTheCache = assay.eq (map (c: vpushOn c.name) fleet.binaryCaches) (map (_: false) fleet.binaryCaches);
    vpushOffOnNonBuilders = assay.eq (lib.filter vpushOn (lib.filter (n: !(fleet.hasRole "builder" n)) fleet.order)) [];
    vpushRollsBackWithOneOption = assay.eq (lib.filter (n: vpushWith n [{features.nix.vpush.enable = lib.mkForce false;}]) fleet.cachePushers) [];

    # vci runs exactly on the cache hosts (common/fleet.nix `isCacheIn`: drakkar today),
    # whose store vcache serves, and one option turns it off.
    vciOnlyOnTheCache = assay.eq (lib.filter (n: vciWith n []) fleet.order) (lib.filter (fleet.isCacheIn fleet.hosts) fleet.order);
    vciOnSomeHost = assay.eq ((lib.filter (n: vciWith n []) fleet.order) != []) true;
    vciRollsBackWithOneOption = assay.eq (lib.filter (n: vciWith n [{features.nix.vci.enable = lib.mkForce false;}]) fleet.order) [];
  }
