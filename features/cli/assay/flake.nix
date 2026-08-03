{
  description = "Assay — Nix unit testing CLI";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    assay-src = {
      url = "path:../../rust/tools/assay";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    assay-src,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
      assay = pkgs.callPackage assay-src {};
    in {
      inherit assay;
      default = assay;
    });

    checks = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
      assay = pkgs.callPackage assay-src {};
      testsRoot = self + "/../../../common/assay/tests";
    in {
      assay = pkgs.runCommand "assay-dogfood" {} ''
        ${assay}/bin/assay run ${testsRoot}
        touch $out
      '';
    });
  };
}
