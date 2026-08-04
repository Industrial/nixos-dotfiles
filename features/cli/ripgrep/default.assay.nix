# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { ripgrep = "ripgrep"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "ripgrep" {
    systemPackages = assay.eq mod.environment.systemPackages [ "ripgrep" ];
  }
