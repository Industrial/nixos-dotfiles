{pkgs, ...}: let
  mockPkgs = {
    bisq2 = "mock-bisq2-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "bisq-desktop" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = module.environment.systemPackages;
    expected = [
      "mock-bisq2-package"
    ];
  };
}
