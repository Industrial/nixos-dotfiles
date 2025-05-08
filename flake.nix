# This flake is for running the unit tests. It needs to be in the root of the
# repository for imports to resolve correctly.
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {
    self,
    nixpkgs,
    nix-unit,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    featureTests = import ./features/test.nix {inherit pkgs;};
  in {
    tests =
      {
        testSomeShit1 = {
          expr = true;
          expected = true;
        };
      }
      // featureTests;

    checks = {
      "${system}" = {
        default =
          nixpkgs.legacyPackages.${system}.runCommand "tests"
          {
            nativeBuildInputs = [nix-unit.packages.${system}.default];
          }
          ''
            export HOME="$(realpath .)"
            # The nix derivation must be able to find all used inputs in the nix-store because it cannot download it during buildTime.
            nix-unit --eval-store "$HOME" \
              --extra-experimental-features flakes \
              --override-input nixpkgs ${nixpkgs} \
              --flake ${self}#tests
            touch $out
          '';
      };
    };
  };
}
