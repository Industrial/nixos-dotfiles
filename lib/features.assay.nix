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

    # Every catalog entry exists on disk.
    catalogResolves = assay.eq (lib.all builtins.pathExists features.catalog) true;
  }
