# Colocated suite: module top-level shape with stubbed args.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  expr = ''
    (import ${modFile} {
      settings = { hostname = "testhost"; username = "alice"; useremail = "a@b.c"; };
      pkgs = {
        callPackage = path: args: "pkg";
        stdenv = {
          mkDerivation = args: args.name or args.pname or "drv";
          hostPlatform = { system = "x86_64-linux"; };
        };
        fish = "fish";
        writeShellScript = name: text: name;
        writeText = name: text: name;
      };
      lib = (import <nixpkgs> {}).lib;
      config = { };
    })
  '';
in
  assay.suite "fish" {
    shape = assay.hasAttrs expr [ "programs" "environment" "users" ];
  }
