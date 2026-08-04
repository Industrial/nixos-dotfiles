# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { kdePackages = { kdenlive = "kdePackages.kdenlive"; }; ffmpeg = "ffmpeg"; mediainfo = "mediainfo"; mkvtoolnix = "mkvtoolnix"; handbrake = "handbrake"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "kdenlive" {
    systemPackages = assay.eq packages ''[ "kdePackages.kdenlive" "ffmpeg" "mediainfo" "mkvtoolnix" "handbrake" ]'';
  }
