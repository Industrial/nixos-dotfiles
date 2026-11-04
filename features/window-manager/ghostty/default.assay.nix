# Colocated suite: ghostty on systemPackages.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {ghostty = "ghostty";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "ghostty" {
    packages = assay.eq mod.environment.systemPackages ["ghostty"];
  }
