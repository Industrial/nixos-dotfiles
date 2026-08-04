# Colocated suite: xfce4-screenshooter package.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (import ${modFile} {
      settings = { hostname = "h"; username = "u"; };
      pkgs = { xfce4-screenshooter = "xfce4-screenshooter"; };
    })
  '';
in
  assay.suite "xfce-screenshooter" {
    packages = assay.eq "${mod}.environment.systemPackages" ''[ "xfce4-screenshooter" ]'';
  }
