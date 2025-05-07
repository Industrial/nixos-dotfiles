{
  description = "A minimal BDD testing framework for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        testRunner = import ./examples/run-test.nix {
          inherit pkgs;
          inherit (pkgs) lib;
        };
      in {
        lib = import ./default.nix {
          inherit pkgs;
          inherit (pkgs) lib;
        };
        devShells.default = pkgs.mkShell {
          buildInputs = [
            testRunner
            pkgs.jq
          ];
        };
      }
    );
}
