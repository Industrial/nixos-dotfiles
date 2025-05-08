{pkgs, ...}: let
  mockPkgs = {
    fd = "mock-fd-package";
  };

  fdModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "fd" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = fdModule.environment.systemPackages;
    expected = ["mock-fd-package"];
  };
}
