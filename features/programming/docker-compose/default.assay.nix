# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    docker = "docker";
    "docker-compose" = "docker-compose";
  };
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "docker-compose" {
    systemPackages = assay.eq mod.environment.systemPackages ["docker" "docker-compose"];
  }
