# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { nodejs = "nodejs"; pnpm = "pnpm"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "node" {
    systemPackages = assay.eq mod.environment.systemPackages [ "nodejs" "pnpm" ];
  }
