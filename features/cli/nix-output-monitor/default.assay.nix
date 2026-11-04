# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {nix-output-monitor = "nix-output-monitor";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "nix-output-monitor" {
    systemPackages = assay.eq mod.environment.systemPackages ["nix-output-monitor"];
  }
