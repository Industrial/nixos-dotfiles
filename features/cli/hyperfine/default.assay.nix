# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {hyperfine = "hyperfine";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "hyperfine" {
    systemPackages = assay.eq mod.environment.systemPackages ["hyperfine"];
  }
