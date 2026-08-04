# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { lmstudio = "lmstudio"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "lmstudio" {
    systemPackages = assay.eq mod.environment.systemPackages [ "lmstudio" ];
  }
