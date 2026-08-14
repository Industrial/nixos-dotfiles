# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {"spotify-player" = "spotify-player";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "spotify-player" {
    systemPackages = assay.eq mod.environment.systemPackages ["spotify-player"];
  }
