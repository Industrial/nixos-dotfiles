# Colocated suite: local callPackage lands on systemPackages.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { callPackage = path: args: "local-pkg"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "lean-ctx" {
    systemPackages = assay.eq mod.environment.systemPackages [ "local-pkg" ];
  }
