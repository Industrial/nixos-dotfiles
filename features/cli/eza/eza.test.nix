{pkgs, ...}: let
  mockPkgs = {
    eza = "mock-eza-package";
  };

  ezaModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "eza" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = ezaModule.environment.systemPackages;
    expected = ["mock-eza-package"];
  };
}
