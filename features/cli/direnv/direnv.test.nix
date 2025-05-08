{pkgs, ...}: let
  mockPkgs = {
    direnv = "mock-direnv-package";
  };

  direnvModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "direnv" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = direnvModule.environment.systemPackages;
    expected = ["mock-direnv-package"];
  };
}
