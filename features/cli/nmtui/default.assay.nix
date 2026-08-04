# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { networkmanager = "networkmanager"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "nmtui" {
    systemPackages = assay.eq mod.environment.systemPackages [ "networkmanager" ];
  }
