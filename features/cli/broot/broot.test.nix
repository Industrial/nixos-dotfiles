{pkgs, ...}: let
  mockPkgs = {
    broot = "mock-broot-package";
  };

  brootModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "bat" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = brootModule.environment.systemPackages;
    expected = [
      "mock-broot-package"
    ];
  };
}
