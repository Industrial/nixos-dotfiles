{pkgs, ...}: let
  mockPkgs = {
    zellij = "mock-zellij-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "zellij" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = module.environment.systemPackages;
    expected = ["mock-zellij-package"];
  };

  # Test that config file is set
  testConfigFile = {
    expr = builtins.hasAttr "source" module.environment.etc."zellij/config.kdl";
    expected = true;
  };

  # Test that layout file is set
  testLayoutFile = {
    expr = builtins.hasAttr "source" module.environment.etc."zellij/layouts/system.kdl";
    expected = true;
  };
}
