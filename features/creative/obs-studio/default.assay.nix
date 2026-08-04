# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    "v4l-utils" = "v4l-utils";
    obs-studio-plugins = {
      obs-backgroundremoval = "obs-backgroundremoval";
      "obs-pipewire-audio-capture" = "obs-pipewire-audio-capture";
    };
  };
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "obs-studio" {
    systemPackages = assay.eq mod.environment.systemPackages ["v4l-utils"];
  }
