# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { bun = "bun"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "bun" {
    systemPackages = assay.eq mod.environment.systemPackages [ "bun" ];
  }
