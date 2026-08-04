# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    kdePackages = {kdenlive = "kdePackages.kdenlive";};
    ffmpeg = "ffmpeg";
    mediainfo = "mediainfo";
    mkvtoolnix = "mkvtoolnix";
    handbrake = "handbrake";
  };
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "kdenlive" {
    systemPackages = assay.eq mod.environment.systemPackages ["kdePackages.kdenlive" "ffmpeg" "mediainfo" "mkvtoolnix" "handbrake"];
  }
