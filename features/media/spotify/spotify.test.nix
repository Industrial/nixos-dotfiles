{pkgs, ...}: let
  mockPkgs = {
    spotify = "mock-spotify-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "spotify" pkgs;
    expected = true;
  };

  # Test system packages
  testSystemPackages = {
    expr = module.environment.systemPackages;
    expected = ["mock-spotify-package"];
  };
}
