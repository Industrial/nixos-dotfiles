# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { insomnia = "insomnia"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "insomnia" {
    systemPackages = assay.eq mod.environment.systemPackages [ "insomnia" ];
  }
