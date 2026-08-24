# Colocated suite: rootless-only docker (rootful daemon disabled).
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
    };
    pkgs = {docker = "docker";};
  };
in
  assay.suite "docker" {
    rootfulDisabled = assay.eq mod.virtualisation.docker.enable false;
    rootlessEnabled = assay.eq mod.virtualisation.docker.rootless.enable true;
    socketVariableSet = assay.eq mod.virtualisation.docker.rootless.setSocketVariable true;
  }
