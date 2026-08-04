# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { fzf = "fzf"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "fzf" {
    systemPackages = assay.eq mod.environment.systemPackages [ "fzf" ];
  }
