# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {qdirstat = "qdirstat";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "qdirstat" {
    systemPackages = assay.eq mod.environment.systemPackages ["qdirstat"];
  }
