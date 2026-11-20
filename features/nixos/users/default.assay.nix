# Colocated suite: primary user from settings.
let
  assay = import ./../../../common/assay/default.nix;
  # Provide lib stub with mkForce function that just returns the value
  lib = {
    mkForce = x: x;
  };
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
    };
    inherit lib;
  };
in
  assay.suite "users" {
    username = assay.eq mod.users.users.alice.isNormalUser true;
    # NFS authorises by number: uid and the data gid must be identical on every host for
    # mimir's /data ownership to mean the same user on its clients.
    nfsStableIds = assay.eq [mod.users.users.alice.uid mod.users.groups.data.gid] [1000 1111];
  }
