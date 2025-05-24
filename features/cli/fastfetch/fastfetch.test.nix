{pkgs, ...}: let
  mockPkgs = {
    fastfetch = "mock-fastfetch-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "fastfetch" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = module.environment.systemPackages;
    expected = ["mock-fastfetch-package"];
  };
}
