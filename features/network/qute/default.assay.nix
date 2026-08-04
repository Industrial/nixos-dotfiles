# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { qutebrowser = "qutebrowser"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "qute" {
    systemPackages = assay.eq mod.environment.systemPackages [ "qutebrowser" ];
  }
