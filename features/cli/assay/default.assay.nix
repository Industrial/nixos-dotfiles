# Colocated suite for features/cli/assay/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {system = "x86_64-linux";};
  inputs = {assay.packages.x86_64-linux.assay = "assay";};
  mod = import ./default.nix {inherit pkgs inputs;};
in
  assay.suite "assay" {
    systemPackages = assay.eq mod.environment.systemPackages ["assay"];
  }
