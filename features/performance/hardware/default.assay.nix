# Colocated suite: module top-level shape with stubbed args.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    settings = {
      hostname = "testhost";
      username = "alice";
      useremail = "a@b.c";
    };
    pkgs = {
      callPackage = path: args: "pkg";
      stdenv = {
        mkDerivation = args: args.name or args.pname or "drv";
        hostPlatform = {system = "x86_64-linux";};
      };
      fish = "fish";
      writeShellScript = name: text: name;
      writeText = name: text: name;
    };
    lib = (import <nixpkgs> {}).lib;
    config = {};
  };
in
  assay.suite "hardware" {
    shape = assay.hasAttrs mod ["hardware" "powerManagement"];

    # hardware.graphics belongs to features/nixos/graphics. profiles/base.nix imports both
    # modules, so declaring it here too was a duplicate definition.
    graphicsNotDeclaredHere = assay.eq (mod.hardware ? graphics) false;
  }
