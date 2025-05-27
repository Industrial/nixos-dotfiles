{pkgs, ...}: let
  mockPkgs = {
    calibre = "mock-calibre-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "calibre" pkgs;
    expected = true;
  };

  # Test system packages
  testSystemPackages = {
    expr = module.environment.systemPackages;
    expected = ["mock-calibre-package"];
  };
}
