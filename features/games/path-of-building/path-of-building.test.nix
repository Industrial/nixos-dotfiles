{pkgs, ...}: let
  mockPkgs = {
    path-of-building = "mock-path-of-building-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "path-of-building" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = module.environment.systemPackages;
    expected = [
      "mock-path-of-building-package"
    ];
  };
}
