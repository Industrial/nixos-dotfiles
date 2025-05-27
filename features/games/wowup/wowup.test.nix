{pkgs, ...}: let
  mockPkgs = {
    wowup-cf = "mock-wowup-cf-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "wowup-cf" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = module.environment.systemPackages;
    expected = [
      "mock-wowup-cf-package"
    ];
  };
}
