# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {qbittorrent-nox = "qbittorrent-nox";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "qbittorrent" {
    systemPackages = assay.eq mod.environment.systemPackages ["qbittorrent-nox"];
  }
