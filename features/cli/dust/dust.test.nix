{pkgs, ...}: let
  mockPkgs = {
    dust = "mock-dust-package";
  };

  dustModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "dust" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = dustModule.environment.systemPackages;
    expected = ["mock-dust-package"];
  };
}
