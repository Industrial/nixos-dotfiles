# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { nodejs = "nodejs"; pnpm = "pnpm"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "node" {
    systemPackages = assay.eq packages ''[ "nodejs" "pnpm" ]'';
  }
