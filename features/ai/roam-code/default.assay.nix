# Colocated suite: local callPackage lands on systemPackages.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { callPackage = path: args: "local-pkg"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "roam-code" {
    systemPackages = assay.eq packages ''[ "local-pkg" ]'';
  }
