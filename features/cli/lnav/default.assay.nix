# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { lnav = "lnav"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "lnav" {
    systemPackages = assay.eq packages ''[ "lnav" ]'';
  }
