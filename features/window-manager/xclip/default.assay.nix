# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { xclip = "xclip"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "xclip" {
    systemPackages = assay.eq mod.environment.systemPackages [ "xclip" ];
  }
