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
  assay.suite "fish" {
    shape = assay.hasAttrs mod ["programs" "environment"];

    # The sourced Hávamál path is created by havamal.nix's buildPhase; havamal.assay.nix
    # asserts the other half. See docs/adr/0005-shell-strategy.md.
    sourcesVendorConfEntry =
      assay.eq (builtins.match ".*vendor_conf\\.d/Hávamál\\.fish.*" mod.programs.fish.interactiveShellInit != null) true;

    # fish is a fallback, not the login shell: this module must not write
    # users.users.<name>.shell. features/cli/nushell is the single writer.
    declaresNoLoginShell = assay.eq (mod ? users) false;
  }
