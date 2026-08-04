# Colocated suite: pgadmin desktop package installed.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (import ${modFile} {
      settings = { hostname = "h"; username = "alice"; };
      pkgs = {
        pgadmin4-desktopmode = "pgadmin4-desktopmode";
        writeShellScriptBin = name: text: name;
      };
      lib = (import <nixpkgs> {}).lib;
    })
  '';
in
  assay.suite "pgadmin" {
    packages = assay.eq "${mod}.environment.systemPackages" ''[ "pgadmin4-desktopmode" ]'';
  }
