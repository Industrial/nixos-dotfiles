# Colocated suite: Terax installed on x86_64-linux via callPackage.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      lib = (import <nixpkgs> {}).lib;
      pkgs = {
        stdenv = { hostPlatform = { system = "x86_64-linux"; }; };
        callPackage = path: args: "terax";
        "gdk-pixbuf" = "gdk-pixbuf";
      };
      mod = import ${modFile} { inherit lib pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "terax" {
    systemPackages = assay.eq packages ''[ "terax" ]'';
  }
