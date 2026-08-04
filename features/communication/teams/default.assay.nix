# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { "teams-for-linux" = "teams-for-linux"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "teams" {
    systemPackages = assay.eq packages ''[ "teams-for-linux" ]'';
  }
