# Colocated suite: mullvad VPN enable.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (import ${modFile} {
      config = { };
      lib = (import <nixpkgs> {}).lib;
      pkgs = { mullvad = "mullvad"; mullvad-vpn = "mullvad-vpn"; };
    })
  '';
in
  assay.suite "mullvad" {
    enabled = assay.eq "${mod}.services.mullvad-vpn.enable" "true";
  }
