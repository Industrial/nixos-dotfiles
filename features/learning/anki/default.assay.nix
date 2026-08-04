# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    anki = "anki";
    "anki-bin" = "anki-bin";
    "anki-sync-server" = "anki-sync-server";
  };
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "anki" {
    systemPackages = assay.eq mod.environment.systemPackages ["anki" "anki-bin" "anki-sync-server"];
  }
