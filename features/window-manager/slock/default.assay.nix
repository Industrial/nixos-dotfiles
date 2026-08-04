# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { slock = "slock"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "slock" {
    systemPackages = assay.eq mod.environment.systemPackages [ "slock" ];
  }
