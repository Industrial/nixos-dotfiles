# Suite for lib/features.nix — the enable-switch wrapper, evaluated on real features.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  inherit (nixos) lib;
  features = import ./features.nix {inherit lib;};

  sys = modules:
    nixos.eval {
      modules = [(features.feature ../features/storage/nfs-server)] ++ modules;
    };
  off = sys [];
  on = sys [{features.storage.nfs-server.enable = true;}];

  # remote-access imports ../network/ssh (another feature: a dependency) and is a plain
  # file, so its sibling ./operator-ssh.nix is a dependency too, not a part.
  access = extra:
    nixos.eval {
      modules = [(features.feature ../features/fleet/remote-access.nix) {features.fleet.remote-access.enable = true;}] ++ extra;
    };

  # gnome/default.nix imports ./dconf.nix from its own directory: a part, gated by gnome.
  gnome = nixos.evalSystem {modules = [(features.feature ../features/window-manager/gnome)];};

  selectNone = features.evalSelection {};

  # GH-225: a feature's own options in a selection-only evaluation, set from one module or
  # several, merge as NixOS merges them. A host file and the modules a suite adds (a
  # rollback's mkForce, say) are separate modules.
  vdeployOf = modules: (features.evalSelection {inherit modules;}).features.nix.vdeploy;
  host = {
    features.nix.vdeploy = {
      enable = true;
      mode = "deploy";
      healthWindow = "3m";
      wake.operators = ["tom"];
    };
    features.nix.vdaemon-proxy.native = ["IsValidPath"];
  };
  several = vdeployOf [
    host
    {features.nix.vdeploy.wake.enable = true;}
    {features.nix.vdeploy.wake.operators = ["alice"];}
    {features.nix.vdeploy.healthWindow = "3m";}
    {features.nix.vdeploy.debounce = lib.mkDefault "5m";}
    {features.nix.vdeploy.debounce = "2m";}
  ];
  # Still selection-only: a value naming pkgs is accepted, and never forced unless read.
  withPkgs = features.evalSelection {modules = [host ({pkgs, ...}: {features.nix.vdeploy.package = pkgs.hello;})];};
  conflicting = builtins.tryEval (builtins.deepSeq (vdeployOf [host {features.nix.vdeploy.mode = "observe";}]).mode null);
in
  assay.suite "features" {
    # Option name is the path below features/, minus .nix and /default.nix.
    namesFromPath = assay.eq (map features.namePath [../features/fleet/comin.nix ../features/ai/paseo/default.nix]) [["fleet" "comin"] ["ai" "paseo"]];

    offByDefault = assay.eq off.services.nfs.server.enable false;
    onWhenEnabled = assay.eq on.services.nfs.server.enable true;

    dependencyFollowsParent = assay.eq (access []).features.network.ssh.enable true;
    dependencyCanBeForcedOff = assay.eq (access [{features.network.ssh.enable = lib.mkForce false;}]).features.network.ssh.enable false;
    siblingFileIsDependency = assay.eq (access []).features.fleet.operator-ssh.enable true;

    partHasNoSwitch = assay.eq (gnome.config.features.window-manager.gnome ? dconf) false;
    partGatedByParent = assay.eq gnome.config.features.window-manager.gnome.enable false;

    # With no profile or host enabled, nothing is on.
    selectionEmptyByDefault = assay.eq (features.enabledFeatures selectNone) [];

    # GH-225: several non-`enable` values per host, of one feature and of several.
    severalValuesInOneHostFile =
      assay.eq [(vdeployOf [host]).mode (vdeployOf [host]).healthWindow (vdeployOf [host]).wake.operators (features.evalSelection {modules = [host];}).features.nix.vdaemon-proxy.native]
      ["deploy" "3m" ["tom"] ["IsValidPath"]];
    # ... and from several modules: nested sets key by key, lists concatenated, equal
    # scalars accepted, and priorities as usual.
    severalModulesMerge =
      assay.eq [several.mode several.wake.enable several.wake.operators several.healthWindow several.debounce]
      ["deploy" true ["tom" "alice"] "3m" "2m"];
    rollbackForceStillWins = assay.eq (vdeployOf [host {features.nix.vdeploy.mode = lib.mkForce "observe";}]).mode "observe";
    # Two different plain values for one option are still a conflict, as on a real host.
    conflictingValuesFail = assay.eq conflicting.success false;
    # Lazy: the pkgs value is never forced by reading the selection.
    staysSelectionOnly = assay.eq [(builtins.elem "nix.vdeploy" (features.enabledFeatures withPkgs)) withPkgs.features.nix.vdeploy.mode] [true "deploy"];
    pkgsValueThrowsOnlyWhenRead = assay.eq (builtins.tryEval (builtins.deepSeq withPkgs.features.nix.vdeploy.package null)).success false;

    # Every catalog entry exists on disk.
    catalogResolves = assay.eq (lib.all builtins.pathExists features.catalog) true;
  }
