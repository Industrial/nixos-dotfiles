# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { bandwhich = "bandwhich"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "bandwhich" {
    systemPackages = assay.eq mod.environment.systemPackages [ "bandwhich" ];
  }
