# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { nvtopPackages = { full = "nvtopPackages.full"; }; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "nvtop" {
    systemPackages = assay.eq packages ''[ "nvtopPackages.full" ]'';
  }
