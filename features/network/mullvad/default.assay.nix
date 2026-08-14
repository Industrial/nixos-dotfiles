# Colocated suite: mullvad VPN enable.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    config = {};
    lib = (import <nixpkgs> {}).lib;
    pkgs = {
      mullvad = "mullvad";
      mullvad-vpn = "mullvad-vpn";
    };
  };
in
  assay.suite "mullvad" {
    enabled = assay.eq mod.services.mullvad-vpn.enable true;
  }
