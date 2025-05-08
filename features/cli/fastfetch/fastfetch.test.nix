{pkgs, ...}: let
  mockPkgs = {
    fastfetch = "mock-fastfetch-package";
  };

  fastfetchModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "fastfetch" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = fastfetchModule.environment.systemPackages;
    expected = ["mock-fastfetch-package"];
  };
}
