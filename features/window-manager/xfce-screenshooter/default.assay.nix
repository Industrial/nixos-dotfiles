# Colocated suite: xfce4-screenshooter package.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "u";
    };
    pkgs = {
      xfce = {xfce4-screenshooter = "xfce4-screenshooter";};
    };
  };
in
  assay.suite "xfce-screenshooter" {
    packages = assay.eq mod.environment.systemPackages ["xfce4-screenshooter"];
  }
