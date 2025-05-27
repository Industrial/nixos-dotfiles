{pkgs, ...}: let
  mockPkgs = {
    qbittorrent = "mock-qbittorrent-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "qbittorrent" pkgs;
    expected = true;
  };

  # Test system packages
  testSystemPackages = {
    expr = module.environment.systemPackages;
    expected = ["mock-qbittorrent-package"];
  };
}
