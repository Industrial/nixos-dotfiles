{pkgs, ...}: let
  mockPkgs = {
    ripgrep = "mock-ripgrep-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "ripgrep" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = module.environment.systemPackages;
    expected = ["mock-ripgrep-package"];
  };
}
