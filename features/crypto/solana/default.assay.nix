# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {"solana-cli" = "solana-cli";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "solana" {
    systemPackages = assay.eq mod.environment.systemPackages ["solana-cli"];
  }
