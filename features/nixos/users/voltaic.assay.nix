# Colocated suite for voltaic.nix: the oracle for the users/groups subtree Voltaic owns
# (#457, #417 S3).
#
# 1. The generated fragments equal, record for record, what the features wrote in Nix
#    before #457. The literals below are that Nix, frozen. A change to a fragment fails
#    here until this file is updated with it, deliberately: the subtree is moved, not
#    changed.
# 2. The users feature, evaluated in a real NixOS system, ends up with the same operator,
#    root and groups as before, with the host-settings parts (name, home, full name)
#    still coming from Nix.
#
# The per-host oracle (every host's users.users, users.groups and toplevel .drv path
# identical before and after) is docs/research/417/s3a-oracle.nix; it is a full host
# eval each, so it runs by hand, not in this suite.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  voltaic = import ./voltaic.nix;

  # The pre-#457 Nix definitions, as they were in each feature.
  frozen = {
    flexget = {
      users.flexget = {
        isSystemUser = true;
        home = "/home/flexget";
        createHome = true;
        group = "flexget";
        extraGroups = ["data"];
      };
      groups.flexget = {};
    };
    textfile-collector.groups.prometheus-textfile = {};
    vexporter = {
      users.vexporter = {
        isSystemUser = true;
        group = "vexporter";
        description = "vexporter, the Nix and fleet metrics";
      };
      groups.vexporter = {};
    };
    vci = {
      users.vci = {
        isSystemUser = true;
        group = "vci";
        home = "/var/lib/vci";
        description = "vci, the fleet's CI builds";
      };
      groups.vci = {};
    };
    vci-token.users.vci-token = {
      isSystemUser = true;
      group = "vci";
      description = "vci-token, the GitHub App token vci posts statuses with";
    };
    vhealth = {
      users.vhealth = {
        isSystemUser = true;
        group = "vhealth";
        description = "vhealth probes";
      };
      groups.vhealth = {};
    };
    vpush = {
      users.vpush = {
        isSystemUser = true;
        group = "vpush";
        home = "/var/lib/vpush";
        description = "vpush, pushes builds to the fleet cache";
      };
      groups.vpush = {};
    };
    users.groups = {
      data.gid = 1111;
      games.gid = 1112;
    };
    root.users.root.hashedPassword = "!";
  };
  frozenOperator = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = ["audio" "networkmanager" "plugdev" "render" "video" "wheel" "data" "games"];
  };

  settings = {
    hostname = "h";
    username = "alice";
    userdir = "/home/alice";
    userfullname = "Alice";
  };
  cfg = nixos.eval {
    modules = [./default.nix];
    inherit settings;
  };
  alice = cfg.users.users.alice;
in
  assay.suite "users-voltaic" {
    # 1. The subtree, moved unchanged.
    fragmentNames = assay.eq (builtins.attrNames voltaic.fragments) (builtins.attrNames frozen);
    fragmentsAreTheFrozenNix = assay.eq voltaic.fragments frozen;
    operatorIsTheFrozenNix = assay.eq voltaic.operator frozenOperator;

    # 2. Through NixOS: the operator keeps its record, with the settings parts from Nix.
    operatorRecord =
      assay.eq {inherit (alice) isNormalUser uid extraGroups home description;}
      (frozenOperator
        // {
          home = "/home/alice";
          description = "Alice";
        });
    # NixOS also lists a user in the members of each of its extraGroups, so the operator
    # appears twice in its own groups; the set is what matters.
    sharedGroups =
      assay.eq {
        data = {
          inherit (cfg.users.groups.data) gid;
          members = nixos.lib.unique cfg.users.groups.data.members;
        };
        games = {
          inherit (cfg.users.groups.games) gid;
          members = nixos.lib.unique cfg.users.groups.games.members;
        };
      } {
        data = {
          gid = 1111;
          members = ["alice"];
        };
        games = {
          gid = 1112;
          members = ["alice"];
        };
      };
    rootLocked = assay.eq cfg.users.users.root.hashedPassword "!";
  }
