# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
    let
      pkgs = { "rusty-path-of-building" = "rusty-path-of-building"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages
  '';
in
  assay.suite "path-of-building" {
    systemPackages = assay.eq packages ''[ "rusty-path-of-building" ]'';
  }
