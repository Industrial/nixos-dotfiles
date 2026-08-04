# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { zig = "zig"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "zig" {
    systemPackages = assay.eq mod.environment.systemPackages [ "zig" ];
  }
