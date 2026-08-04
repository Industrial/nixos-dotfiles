# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { "v4l-utils" = "v4l-utils"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "obs-studio" {
    systemPackages = assay.eq packages ''[ "v4l-utils" ]'';
  }
