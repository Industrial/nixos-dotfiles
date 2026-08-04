# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {"gemini-cli" = "gemini-cli";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "gemini-cli" {
    systemPackages = assay.eq mod.environment.systemPackages ["gemini-cli"];
  }
