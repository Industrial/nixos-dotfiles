let
  # Assume the system is x86_64-linux.
  # TODO: We should make this configurable, but are using NixOS locally on all
  # systems and in CI for now.
  system = "x86_64-linux";
  pkgs = import <nixpkgs> {inherit system;};
  commonTests = import ./common/common.test.nix {inherit pkgs;};
  featureTests = import ./features/features.test.nix {inherit pkgs;};
in
  commonTests // featureTests
