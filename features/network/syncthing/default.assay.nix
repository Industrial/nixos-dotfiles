# Colocated suite: services.syncthing.enable with settings stub.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (import ${modFile} {
      settings = { hostname = "testhost"; username = "alice"; };
      pkgs = { };
      lib = (import <nixpkgs> {}).lib;
    })
  '';
in
  assay.suite "syncthing" {
    enabled = assay.eq "${mod}.services.syncthing.enable" "true";
  }
