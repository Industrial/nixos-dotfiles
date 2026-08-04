# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {gitoxide = "gitoxide";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "gix" {
    systemPackages = assay.eq mod.environment.systemPackages ["gitoxide"];
  }
