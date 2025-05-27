{pkgs, ...}: let
  mockPkgs = {
    vlc = "mock-vlc-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "vlc" pkgs;
    expected = true;
  };

  # Test system packages
  testSystemPackages = {
    expr = module.environment.systemPackages;
    expected = ["mock-vlc-package"];
  };
}
