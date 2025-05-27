{pkgs, ...}: let
  mockPkgs = {
    lutris = "mock-lutris-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "lutris" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = module.environment.systemPackages;
    expected = [
      "mock-lutris-package"
    ];
  };
}
